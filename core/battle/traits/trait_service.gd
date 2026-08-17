extends RefCounted

## Pure Type Object resolver for pet traits. Definitions live in planner data;
## this service only aggregates hook-scoped modifiers and never mutates battle state.

const ConditionEvaluatorScript := preload("res://core/effects/condition_evaluator.gd")
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")

var _condition_evaluator: RefCounted = ConditionEvaluatorScript.new()


func configure(condition_evaluator: RefCounted) -> RefCounted:
	if condition_evaluator != null:
		_condition_evaluator = condition_evaluator
	return self


func modifiers(unit: Dictionary, catalog: Dictionary, hook: String, context: Dictionary = {}) -> Dictionary:
	var result := {
		"trait_ids": [],
		"trait_names": [],
		"modifiers": [],
		"trigger_effects": [],
		"physical_power_bonus_permille": 0,
		"element_layer_bonus": 0,
	}
	for trait_id in trait_ids(unit):
		var definition := Dictionary(catalog.get(trait_id, {}))
		if definition.is_empty():
			continue
		var applied := false
		var effect_index := 0
		for effect_value in Array(definition.get("effects", [])):
			var effect := Dictionary(effect_value)
			var effect_hook := EffectVocabularyScript.hook_id(effect)
			if effect_hook != EffectHookIdsScript.ALWAYS and effect_hook != hook:
				effect_index += 1
				continue
			var condition_context := context.duplicate(true)
			condition_context["unit"] = unit
			condition_context[EffectVocabularyScript.FIELD_HOOK] = hook
			if not _condition_evaluator.matches(EffectVocabularyScript.condition(effect), condition_context):
				effect_index += 1
				continue
			var normalized := _normalized_effect(effect, trait_id, hook, effect_index)
			if EffectVocabularyScript.effect_type(normalized) == EffectVocabularyScript.TYPE_MODIFY_STAT:
				Array(result["modifiers"]).append(normalized)
				var stat_id := EffectVocabularyScript.stat_id(normalized)
				if EffectVocabularyScript.operation_id(normalized) == StatOperationIdsScript.FLAT_ADD:
					if stat_id == StatIdsScript.PHYSICAL_POWER_PERMILLE:
						result["physical_power_bonus_permille"] = int(result["physical_power_bonus_permille"]) + int(normalized.get("value", 0))
					elif stat_id == StatIdsScript.ELEMENT_LAYER_BONUS:
						result["element_layer_bonus"] = int(result["element_layer_bonus"]) + int(normalized.get("value", 0))
				applied = true
			elif effect_hook == hook and not normalized.is_empty():
				Array(result["trigger_effects"]).append(normalized)
				applied = true
			effect_index += 1
		if applied:
			Array(result["trait_ids"]).append(trait_id)
			Array(result["trait_names"]).append(String(definition.get("name", trait_id)))
	return result


func _normalized_effect(effect: Dictionary, trait_id: String, hook: String, effect_index: int) -> Dictionary:
	var result := EffectVocabularyScript.normalize_for_owner(effect, EffectVocabularyScript.OWNER_TRAIT_CATALOG)
	if EffectVocabularyScript.effect_type(result) == EffectVocabularyScript.TYPE_MODIFY_STAT:
		result[EffectVocabularyScript.FIELD_OPERATION] = EffectVocabularyScript.operation_id(result)
		result["phase"] = String(result.get("phase", "trait"))
		result["priority"] = int(result.get("priority", 100))
	result["source_type"] = "trait"
	result["source_id"] = trait_id
	result["instance_id"] = "%s:%s:%d" % [trait_id, hook, effect_index]
	return result


func trait_ids(unit: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = unit.get("traits", unit.get("trait_ids", []))
	var values: Array = Array(raw) if raw is Array else Array(String(raw).replace("，", ",").split(",", false))
	for value in values:
		var trait_id := String(value).strip_edges()
		if trait_id != "" and not result.has(trait_id):
			result.append(trait_id)
	return result


func entries(unit: Dictionary, catalog: Dictionary) -> Array:
	var result: Array = []
	for trait_id in trait_ids(unit):
		var definition := Dictionary(catalog.get(trait_id, {}))
		if definition.is_empty():
			continue
		result.append(definition.duplicate(true))
	return result
