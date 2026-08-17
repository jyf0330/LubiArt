extends RefCounted

const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")

var _trait_service: RefCounted
var _status_service: RefCounted


func configure(trait_service: RefCounted, status_service: RefCounted) -> RefCounted:
	_trait_service = trait_service
	_status_service = status_service
	return self


func collect(unit: Dictionary, data: Dictionary, hook: String, context: Dictionary = {}) -> Dictionary:
	var result := {
		"modifiers": [],
		"trigger_effects": [],
		"trait_ids": [],
		"trait_names": [],
		"physical_power_bonus_permille": 0,
		"element_layer_bonus": 0,
	}
	if unit.is_empty():
		return result
	var effective_context := context.duplicate(true)
	effective_context["unit"] = unit
	effective_context[EffectVocabularyScript.FIELD_HOOK] = hook
	var trait_result := Dictionary(_trait_service.modifiers(unit, Dictionary(data.get("trait_catalog", {})), hook, effective_context))
	Array(result["modifiers"]).append_array(Array(trait_result.get("modifiers", [])))
	Array(result["trigger_effects"]).append_array(Array(trait_result.get("trigger_effects", [])))
	result["trait_ids"] = Array(trait_result.get("trait_ids", [])).duplicate(true)
	result["trait_names"] = Array(trait_result.get("trait_names", [])).duplicate(true)
	result["physical_power_bonus_permille"] = int(trait_result.get("physical_power_bonus_permille", 0))
	result["element_layer_bonus"] = int(trait_result.get("element_layer_bonus", 0))
	Array(result["modifiers"]).append_array(_status_service.modifiers(unit, Dictionary(data.get("status_catalog", {})), hook, effective_context))
	Array(result["trigger_effects"]).append_array(_status_service.trigger_effects(unit, Dictionary(data.get("status_catalog", {})), hook, effective_context))
	return result
