extends RefCounted

## Ordered whitelist dispatcher. Definitions select operation IDs only; the
## concrete mutation remains behind an explicit port owned by the authority.

const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")
const ConditionEvaluatorScript := preload("res://core/effects/condition_evaluator.gd")
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const HANDLER_DIRECTORY := "res://core/effects/handlers"

var _registry: RefCounted = ScriptPluginRegistryScript.new().configure(
	HANDLER_DIRECTORY,
	&"plugin_id",
	[&"execute", &"consumed_stats"],
	{"execute": 3, "consumed_stats": 2}
)
var _condition_evaluator: RefCounted = ConditionEvaluatorScript.new()


func configure(condition_evaluator: RefCounted) -> RefCounted:
	if condition_evaluator != null:
		_condition_evaluator = condition_evaluator
	return self


func supported_types() -> Array[String]:
	return _registry.ids()


func is_valid() -> bool:
	return bool(_registry.call(&"is_valid"))


func validation_errors() -> Array[String]:
	var result: Array[String] = []
	for value in Array(_registry.call(&"validation_errors")):
		result.append(String(value))
	return result


func execute(port: RefCounted, context: Dictionary, effects: Array) -> bool:
	if port == null or not is_valid():
		if port != null and port.has_method(&"log"):
			for error in validation_errors():
				port.call(&"log", "效果插件契约无效：%s" % error)
		return false
	var accepted := true
	for effect_value in effects:
		var effect := Dictionary(effect_value)
		var effect_type := EffectVocabularyScript.effect_type(effect)
		var handler: RefCounted = _registry.plugin(effect_type)
		if handler == null or not handler.has_method(&"execute"):
			accepted = false
			if port.has_method(&"log"):
				port.call(&"log", "跳过未注册效果：%s。" % effect_type)
			continue
		var condition_context := context.duplicate(true)
		if port.has_method(&"condition_context"):
			condition_context = Dictionary(port.call(&"condition_context", context, effect))
		if not _condition_evaluator.matches(EffectVocabularyScript.condition(effect), condition_context):
			continue
		var raw_outcome: Variant = handler.call(&"execute", port, context, effect)
		var outcome := _normalized_outcome(raw_outcome)
		outcome["consumed_stats"] = _handler_consumed_stats(handler, effect, String(context.get("source_kind", EffectHookIdsScript.SKILL)))
		if bool(outcome.get("applied", false)) and port.has_method(&"effect_applied"):
			port.call(&"effect_applied", context, effect, outcome)
	return accepted


func relevant_bundle(port: RefCounted, context: Dictionary, bundle: Dictionary, effects: Array, source_kind: String) -> Dictionary:
	var result := bundle.duplicate(true)
	var consumed := consumed_stats(effects, source_kind)
	var filtered: Array = []
	var trait_ids: Array[String] = []
	var trait_names_by_id := {}
	var original_ids := Array(bundle.get("trait_ids", []))
	var original_names := Array(bundle.get("trait_names", []))
	for index in range(min(original_ids.size(), original_names.size())):
		trait_names_by_id[String(original_ids[index])] = String(original_names[index])
	for modifier_value in Array(bundle.get("modifiers", [])):
		var modifier := Dictionary(modifier_value)
		if not consumed.has(EffectVocabularyScript.stat_id(modifier)):
			continue
		var condition_context := context.duplicate(true)
		if port.has_method(&"condition_context"):
			condition_context = Dictionary(port.call(&"condition_context", context, modifier))
		if not _condition_evaluator.matches(EffectVocabularyScript.condition(modifier), condition_context):
			continue
		filtered.append(modifier)
		if String(modifier.get("source_type", "")) == "trait":
			var trait_id := String(modifier.get("source_id", ""))
			if trait_id != "" and not trait_ids.has(trait_id): trait_ids.append(trait_id)
	result["modifiers"] = filtered
	result["trait_ids"] = trait_ids
	result["trait_names"] = trait_ids.map(func(value: String) -> String: return String(trait_names_by_id.get(value, value)))
	return result


func consumed_stats(effects: Array, source_kind: String = EffectHookIdsScript.SKILL) -> Array[String]:
	var result: Array[String] = []
	for effect_value in effects:
		var effect := Dictionary(effect_value)
		var handler: RefCounted = _registry.plugin(EffectVocabularyScript.effect_type(effect))
		if handler == null or not handler.has_method(&"consumed_stats"):
			continue
		for value in _handler_consumed_stats(handler, effect, source_kind):
			var stat_id := String(value)
			if stat_id != "" and not result.has(stat_id): result.append(stat_id)
	result.sort()
	return result


func _handler_consumed_stats(handler: RefCounted, effect: Dictionary, source_kind: String) -> Array:
	var result: Array[String] = []
	for value in Array(handler.call(&"consumed_stats", effect, source_kind)):
		var stat_id := String(value)
		if stat_id != "" and not result.has(stat_id):
			result.append(stat_id)
	result.sort()
	return result


func _normalized_outcome(value: Variant) -> Dictionary:
	if value is Dictionary:
		var result := Dictionary(value).duplicate(true)
		result["applied"] = bool(result.get("applied", true))
		return result
	if value is bool:
		return {"applied": bool(value)}
	return {"applied": true}
