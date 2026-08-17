extends RefCounted

## Deterministic repository-owned plugin discovery. Data may select a registered
## id, but it can never provide a script path.

var _plugins: Dictionary = {}
var _directory := ""
var _id_method: StringName = &"plugin_id"
var _required_methods: Array[StringName] = []
var _required_method_arities: Dictionary = {}
var _validation_errors: Array[String] = []


func configure(
	directory: String,
	id_method: StringName = &"plugin_id",
	required_methods: Array[StringName] = [],
	required_method_arities: Dictionary = {}
) -> RefCounted:
	_directory = directory.trim_suffix("/")
	_id_method = id_method
	_required_methods = required_methods.duplicate()
	_required_method_arities = required_method_arities.duplicate(true)
	reload()
	return self


func reload() -> void:
	_plugins.clear()
	_validation_errors.clear()
	if DirAccess.open(_directory) == null:
		_validation_errors.append("Missing plugin directory '%s'." % _directory)
		return
	var files := DirAccess.get_files_at(_directory)
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".gd"):
			continue
		var script := load("%s/%s" % [_directory, file_name]) as Script
		if script == null:
			_validation_errors.append("Plugin script failed to load in %s (%s)." % [_directory, file_name])
			continue
		var plugin := script.new() as RefCounted
		if plugin == null:
			_validation_errors.append("Plugin failed to instantiate in %s (%s)." % [_directory, file_name])
			continue
		if not plugin.has_method(_id_method):
			_validation_errors.append("Plugin is missing %s in %s (%s)." % [_id_method, _directory, file_name])
			continue
		var id_arity := _method_argument_count(plugin, _id_method)
		if id_arity != 0:
			_validation_errors.append("Plugin id method %s must declare 0 arguments, found %d in %s (%s)." % [_id_method, id_arity, _directory, file_name])
			continue
		var plugin_id := String(plugin.call(_id_method))
		if plugin_id == "":
			_validation_errors.append("Plugin returned an empty id in %s (%s)." % [_directory, file_name])
			continue
		var missing_methods: Array[String] = []
		var invalid_arities: Array[String] = []
		for method_name in _required_methods:
			if not plugin.has_method(method_name):
				missing_methods.append(String(method_name))
				continue
			var method_key := String(method_name)
			if _required_method_arities.has(method_key):
				var expected_arity := int(_required_method_arities.get(method_key, -1))
				var actual_arity := _method_argument_count(plugin, method_name)
				if actual_arity != expected_arity:
					invalid_arities.append("%s expected %d found %d" % [method_key, expected_arity, actual_arity])
		if not missing_methods.is_empty():
			_validation_errors.append("Plugin '%s' is missing required methods [%s] in %s (%s)." % [
				plugin_id,
				", ".join(missing_methods),
				_directory,
				file_name,
			])
			continue
		if not invalid_arities.is_empty():
			_validation_errors.append("Plugin '%s' has invalid method arity [%s] in %s (%s)." % [
				plugin_id,
				", ".join(invalid_arities),
				_directory,
				file_name,
			])
			continue
		if _plugins.has(plugin_id):
			_validation_errors.append("Duplicate plugin id '%s' in %s (%s)." % [plugin_id, _directory, file_name])
			continue
		_plugins[plugin_id] = plugin
	if not _validation_errors.is_empty():
		_plugins.clear()


func _method_argument_count(plugin: RefCounted, method_name: StringName) -> int:
	for method_value in plugin.get_method_list():
		var method := Dictionary(method_value)
		if StringName(method.get("name", "")) == method_name:
			return Array(method.get("args", [])).size()
	return -1


func plugin(plugin_id: String) -> RefCounted:
	return _plugins.get(plugin_id) as RefCounted


func ids() -> Array[String]:
	var result: Array[String] = []
	for plugin_id in _plugins.keys():
		result.append(String(plugin_id))
	result.sort()
	return result


func plugins() -> Array:
	var result: Array = []
	for plugin_id in ids():
		result.append(_plugins[plugin_id])
	return result


func is_valid() -> bool:
	return _validation_errors.is_empty()


func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()
