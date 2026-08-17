extends RefCounted

const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const CONDITION_DIRECTORY := "res://core/effects/conditions"

var _registry: RefCounted = ScriptPluginRegistryScript.new().configure(CONDITION_DIRECTORY, &"plugin_id", [&"matches"])

## Whitelist-only condition interpreter. Planner data can select supported
## operations but cannot load scripts or call arbitrary methods.


func matches(condition: Dictionary, context: Dictionary) -> bool:
	if condition.is_empty():
		return true
	var condition_type := EffectVocabularyScript.condition_type(condition)
	match condition_type:
		EffectVocabularyScript.CONDITION_ALL:
			for child_value in Array(condition.get(EffectVocabularyScript.FIELD_CONDITIONS, [])):
				if not matches(Dictionary(child_value), context):
					return false
			return true
		EffectVocabularyScript.CONDITION_ANY:
			for child_value in Array(condition.get(EffectVocabularyScript.FIELD_CONDITIONS, [])):
				if matches(Dictionary(child_value), context):
					return true
			return false
		EffectVocabularyScript.CONDITION_NOT:
			return not matches(Dictionary(condition.get(EffectVocabularyScript.FIELD_CONDITION, {})), context)
	var handler: RefCounted = _registry.plugin(condition_type)
	return handler != null and bool(handler.call(&"matches", condition, context))


func supported_types() -> Array[String]:
	var result: Array[String] = _registry.ids()
	result.append_array([
		EffectVocabularyScript.CONDITION_ALL,
		EffectVocabularyScript.CONDITION_ANY,
		EffectVocabularyScript.CONDITION_NOT,
	])
	result.sort()
	return result


func is_valid() -> bool:
	return bool(_registry.call(&"is_valid"))


func validation_errors() -> Array[String]:
	var result: Array[String] = []
	for value in Array(_registry.call(&"validation_errors")):
		result.append(String(value))
	return result


func content_schema_errors(condition: Dictionary) -> Array[String]:
	var condition_type := EffectVocabularyScript.condition_type(condition)
	if [
		EffectVocabularyScript.CONDITION_ALL,
		EffectVocabularyScript.CONDITION_ANY,
		EffectVocabularyScript.CONDITION_NOT,
	].has(condition_type):
		return []
	var handler: RefCounted = _registry.plugin(condition_type)
	if handler == null or not handler.has_method(&"content_schema_errors"):
		return []
	var result: Array[String] = []
	for value in Array(handler.call(&"content_schema_errors", condition)):
		result.append(String(value))
	return result
