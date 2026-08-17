extends RefCounted

const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")
const CompatibilityAdapterScript := preload("res://core/shop/shop_effect_compatibility_adapter.gd")
const DispatchHandlerScript := preload("res://core/shop/shop_effect_dispatch_handler.gd")

const HANDLER_DIRECTORY := "res://core/shop/handlers"

var _plugins: RefCounted
var _compatibility: RefCounted


func _init(directory: String = HANDLER_DIRECTORY) -> void:
	_compatibility = CompatibilityAdapterScript.new()
	_plugins = ScriptPluginRegistryScript.new().configure(
		directory,
		&"plugin_id",
		[&"execute"],
		{"execute": 3}
	)


func handler_for(effect_type: String) -> RefCounted:
	if not is_valid():
		return null
	var normalized := Dictionary(_compatibility.normalize({"type": effect_type}))
	var canonical_type := String(normalized.get("type", ""))
	var plugin: RefCounted = _plugins.plugin(canonical_type)
	return DispatchHandlerScript.new(plugin, _compatibility) if plugin != null else null


func registered_effects() -> Array[String]:
	if not is_valid():
		return []
	var effects: Array[String] = _plugins.ids()
	for legacy_type in _compatibility.legacy_effect_types():
		var normalized := Dictionary(_compatibility.normalize({"type": legacy_type}))
		if _plugins.plugin(String(normalized.get("type", ""))) != null:
			effects.append(String(legacy_type))
	effects.sort()
	return effects


func is_valid() -> bool:
	return _plugins != null and _plugins.is_valid()


func validation_errors() -> Array[String]:
	return _plugins.validation_errors() if _plugins != null else ["Shop effect plugin registry is unavailable."]
