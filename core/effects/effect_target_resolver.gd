extends RefCounted

const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const TARGET_DIRECTORY := "res://core/effects/targets"

var _registry: RefCounted = ScriptPluginRegistryScript.new().configure(TARGET_DIRECTORY, &"plugin_id", [&"resolve"])


func targets(context: Dictionary, effect: Dictionary) -> Array:
	var target_id := EffectVocabularyScript.target_id(effect)
	var handler: RefCounted = _registry.plugin(target_id)
	if handler == null:
		return []
	return Array(handler.call(&"resolve", context, effect))


func supported_types() -> Array[String]:
	return _registry.ids()


func is_valid() -> bool:
	return bool(_registry.call(&"is_valid"))


func validation_errors() -> Array[String]:
	var result: Array[String] = []
	for value in Array(_registry.call(&"validation_errors")):
		result.append(String(value))
	return result
