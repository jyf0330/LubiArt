extends RefCounted

## Read-only JSON data source. Gameplay layers decide how documents are merged;
## this repository owns only resource access and JSON decoding.

const ContentPackReaderScript := preload("res://persistence/content_pack_reader.gd")
const ContentPackRegistryScript := preload("res://persistence/content_pack_registry.gd")
const ContentPackAssemblerScript := preload("res://persistence/content_pack_assembler.gd")
const EffectContentValidatorScript := preload("res://core/effects/effect_content_validator.gd")
const RuntimeExtensionValidatorScript := preload("res://core/content/runtime_extension_validator.gd")

var _content_pack_reader: RefCounted = ContentPackReaderScript.new()
var _content_pack_registry: RefCounted = ContentPackRegistryScript.new()
var _content_pack_assembler: RefCounted = ContentPackAssemblerScript.new()
var _effect_content_validator: RefCounted = EffectContentValidatorScript.new()
var _runtime_extension_validator: RefCounted = RuntimeExtensionValidatorScript.new()
var _content_errors: Array[String] = []
var _content_cache: Dictionary = {}


func read_dictionary(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return Dictionary(parsed)


func read_content_pack(path: String) -> Dictionary:
	if _content_cache.has(path):
		var cached := Dictionary(_content_cache[path])
		_content_errors = _strings(Array(cached.get("errors", [])))
		return Dictionary(cached.get("data", {})).duplicate(true)
	var read_result := Dictionary(_content_pack_reader.read(path))
	if not bool(read_result.get("ok", false)):
		_content_errors = _strings(Array(read_result.get("errors", [])))
		_store_cache(path, {})
		return {}
	var registry_result := Dictionary(_content_pack_registry.register(Array(read_result.get("packages", []))))
	if not bool(registry_result.get("ok", false)):
		_content_errors = _strings(Array(registry_result.get("errors", [])))
		_store_cache(path, {})
		return {}
	var assembled := Dictionary(_content_pack_assembler.assemble(Array(registry_result.get("packages", []))))
	_content_errors = _strings(Array(assembled.get("errors", [])))
	var data := Dictionary(assembled.get("data", {})) if bool(assembled.get("ok", false)) else {}
	if not data.is_empty():
		_content_errors = _strings(Array(_effect_content_validator.call(&"validate", data)))
		if _content_errors.is_empty():
			_content_errors = _strings(Array(_runtime_extension_validator.call(&"validate", data)))
		if not _content_errors.is_empty():
			data = {}
	_store_cache(path, data)
	return data.duplicate(true)


func content_errors() -> Array[String]:
	return _content_errors.duplicate()


func _store_cache(path: String, data: Dictionary) -> void:
	_content_cache[path] = {"data": data.duplicate(true), "errors": _content_errors.duplicate()}


func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
