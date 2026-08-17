extends RefCounted

const StatCatalogServiceScript := preload("res://core/stats/stat_catalog_service.gd")
const ConditionEvaluatorScript := preload("res://core/effects/condition_evaluator.gd")
const ScriptPluginRegistryScript := preload("res://core/plugins/script_plugin_registry.gd")
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const OPERATION_DIRECTORY := "res://core/stats/operations"

const PHASE_ORDER := {
	"permanent": 100,
	"equipment": 200,
	"trait": 300,
	"status": 400,
	"runtime": 500,
	"final": 600,
}

var _catalog_service := StatCatalogServiceScript.new()
var _condition_evaluator: RefCounted = ConditionEvaluatorScript.new()
var _operation_registry: RefCounted = ScriptPluginRegistryScript.new().configure(OPERATION_DIRECTORY, &"plugin_id", [&"order", &"apply"])


func configure(condition_evaluator: RefCounted) -> RefCounted:
	if condition_evaluator != null:
		_condition_evaluator = condition_evaluator
	return self


func value(
	unit: Dictionary,
	stat_id: String,
	catalog: Dictionary,
	extra_modifiers: Array = [],
	context: Dictionary = {}
) -> int:
	return int(resolve(unit, stat_id, catalog, extra_modifiers, context).get("value", 0))


func resolve(
	unit: Dictionary,
	stat_id: String,
	catalog: Dictionary,
	extra_modifiers: Array = [],
	context: Dictionary = {}
) -> Dictionary:
	var definition := _catalog_service.definition(catalog, stat_id)
	var base: int = _catalog_service.base_value(unit, stat_id, catalog)
	var modifiers := _collect_modifiers(unit, stat_id, extra_modifiers, context)
	var breakdown: Array = [{
		"stage": "base",
		"source_id": String(unit.get("id", "catalog_default")),
		"operation": "base",
		"value": base,
		"before": base,
		"after": base,
	}]
	var current := base
	var operation_handlers: Array = _operation_registry.plugins()
	operation_handlers.sort_custom(func(left: RefCounted, right: RefCounted) -> bool:
		return int(left.call(&"order")) < int(right.call(&"order"))
	)
	for handler_value in operation_handlers:
		var handler := handler_value as RefCounted
		var operation_id := String(handler.call(&"plugin_id"))
		for modifier_value in _operation_modifiers(modifiers, operation_id):
			var modifier := Dictionary(modifier_value)
			var before := current
			current = int(handler.call(&"apply", current, modifier))
			breakdown.append(_breakdown_row(modifier, before, current))
	var before_catalog_clamp := current
	current = clampi(current, int(definition.get("min_value", -2147483648)), int(definition.get("max_value", 2147483647)))
	if current != before_catalog_clamp:
		breakdown.append({
			"stage": "catalog_clamp",
			"source_id": stat_id,
			"operation": "clamp",
			"value": current,
			"before": before_catalog_clamp,
			"after": current,
		})
	return {
		"stat_id": stat_id,
		"name": String(definition.get("name", stat_id)),
		"value": current,
		"value_type": String(definition.get("value_type", "integer")),
		"display_unit": String(definition.get("display_unit", "")),
		"breakdown": breakdown,
	}


func resolve_all(
	unit: Dictionary,
	catalog: Dictionary,
	extra_modifiers: Array = [],
	context: Dictionary = {}
) -> Dictionary:
	var result := {}
	for stat_id in _catalog_service.ordered_ids(catalog):
		result[stat_id] = resolve(unit, stat_id, catalog, extra_modifiers, context)
	return result


func values_from_resolved(resolved: Dictionary) -> Dictionary:
	var result := {}
	for stat_id_value in resolved.keys():
		var stat_id := String(stat_id_value)
		result[stat_id] = int(Dictionary(resolved.get(stat_id, {})).get("value", 0))
	return result


func breakdown_from_resolved(resolved: Dictionary) -> Dictionary:
	var result := {}
	for stat_id_value in resolved.keys():
		var stat_id := String(stat_id_value)
		result[stat_id] = Array(Dictionary(resolved.get(stat_id, {})).get("breakdown", [])).duplicate(true)
	return result


func _collect_modifiers(unit: Dictionary, stat_id: String, extra_modifiers: Array, context: Dictionary) -> Array:
	var values: Array = []
	for key in ["permanent_modifiers", "equipment_modifiers", "runtime_modifiers"]:
		for modifier_value in Array(unit.get(key, [])):
			values.append(Dictionary(modifier_value).duplicate(true))
	for modifier_value in extra_modifiers:
		values.append(Dictionary(modifier_value).duplicate(true))
	var filtered: Array = []
	var condition_context := context.duplicate(true)
	condition_context["unit"] = unit
	var query_hook := EffectVocabularyScript.text(context, EffectVocabularyScript.FIELD_HOOK, EffectHookIdsScript.ALWAYS)
	for modifier_value in values:
		var modifier := Dictionary(modifier_value)
		if EffectVocabularyScript.stat_id(modifier) != stat_id:
			continue
		var modifier_hook := EffectVocabularyScript.hook_id(modifier)
		if modifier_hook != EffectHookIdsScript.ALWAYS and modifier_hook != query_hook:
			continue
		if not bool(modifier.get("enabled", true)) or bool(modifier.get("materialized", false)):
			continue
		if not _condition_evaluator.matches(EffectVocabularyScript.condition(modifier), condition_context):
			continue
		modifier[EffectVocabularyScript.FIELD_STAT] = stat_id
		filtered.append(modifier)
	filtered.sort_custom(Callable(self, "_modifier_less"))
	return filtered


func _modifier_less(left: Dictionary, right: Dictionary) -> bool:
	var left_phase := int(PHASE_ORDER.get(String(left.get("phase", "runtime")), 500))
	var right_phase := int(PHASE_ORDER.get(String(right.get("phase", "runtime")), 500))
	if left_phase != right_phase:
		return left_phase < right_phase
	var left_priority := int(left.get("priority", 0))
	var right_priority := int(right.get("priority", 0))
	if left_priority != right_priority:
		return left_priority < right_priority
	var left_source := String(left.get("source_id", ""))
	var right_source := String(right.get("source_id", ""))
	if left_source != right_source:
		return left_source < right_source
	return String(left.get("instance_id", "")) < String(right.get("instance_id", ""))


func _operation_modifiers(modifiers: Array, operation: String) -> Array:
	var result: Array = []
	for modifier_value in modifiers:
		if EffectVocabularyScript.operation_id(Dictionary(modifier_value)) == operation:
			result.append(modifier_value)
	return result


func _breakdown_row(modifier: Dictionary, before: int, after: int) -> Dictionary:
	return {
		"stage": String(modifier.get("phase", "runtime")),
		"source_id": String(modifier.get("source_id", "")),
		"instance_id": String(modifier.get("instance_id", "")),
		"operation": EffectVocabularyScript.operation_id(modifier),
		"value": int(modifier.get("value", 0)),
		"before": before,
		"after": after,
	}


func supported_operations() -> Array[String]:
	return _operation_registry.ids()


func is_valid() -> bool:
	return bool(_operation_registry.call(&"is_valid"))


func validation_errors() -> Array[String]:
	var result: Array[String] = []
	for value in Array(_operation_registry.call(&"validation_errors")):
		result.append(String(value))
	return result
