extends RefCounted

const ConditionEvaluatorScript := preload("res://core/effects/condition_evaluator.gd")
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")

var _condition_evaluator: RefCounted = ConditionEvaluatorScript.new()


func configure(condition_evaluator: RefCounted) -> RefCounted:
	if condition_evaluator != null:
		_condition_evaluator = condition_evaluator
	return self


func apply(
	unit: Dictionary,
	status_id: String,
	catalog: Dictionary,
	stacks: int = 1,
	duration: int = 0,
	source_id: String = "",
	applied_seq: int = 0
) -> bool:
	var definition := Dictionary(catalog.get(status_id, {}))
	if status_id == "" or definition.is_empty():
		return false
	var values := normalized(unit, catalog)
	var max_stacks: int = max(1, int(definition.get("max_stacks", 1)))
	var wanted_duration: int = max(1, duration if duration > 0 else int(definition.get("default_duration", 1)))
	for index in range(values.size()):
		var current := Dictionary(values[index])
		if EffectVocabularyScript.status_id(current) != status_id:
			continue
		current["stacks"] = min(max_stacks, int(current.get("stacks", 1)) + max(1, stacks))
		match String(definition.get("duration_policy", "refresh")):
			"extend":
				current["remaining_rounds"] = int(current.get("remaining_rounds", 0)) + wanted_duration
			"replace":
				current["remaining_rounds"] = wanted_duration
			_:
				current["remaining_rounds"] = max(int(current.get("remaining_rounds", 0)), wanted_duration)
		current["source_id"] = source_id if source_id != "" else String(current.get("source_id", ""))
		current["applied_seq"] = max(int(current.get("applied_seq", 0)), applied_seq)
		values[index] = current
		unit["statuses"] = values
		return true
	values.append({
		"status_id": status_id,
		"stacks": min(max_stacks, max(1, stacks)),
		"remaining_rounds": wanted_duration,
		"source_id": source_id,
		"applied_seq": applied_seq,
	})
	values.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_seq := int(left.get("applied_seq", 0))
		var right_seq := int(right.get("applied_seq", 0))
		if left_seq != right_seq:
			return left_seq < right_seq
		return EffectVocabularyScript.status_id(left) < EffectVocabularyScript.status_id(right)
	)
	unit["statuses"] = values
	return true


func remove(unit: Dictionary, status_id: String, stacks: int = 0) -> bool:
	var values := Array(unit.get("statuses", [])).duplicate(true)
	for index in range(values.size() - 1, -1, -1):
		var current := Dictionary(values[index])
		if EffectVocabularyScript.status_id(current) != status_id:
			continue
		if stacks <= 0 or int(current.get("stacks", 1)) <= stacks:
			values.remove_at(index)
		else:
			current["stacks"] = int(current.get("stacks", 1)) - stacks
			values[index] = current
		unit["statuses"] = values
		return true
	return false


func advance_round(unit: Dictionary, catalog: Dictionary, rounds: int = 1) -> void:
	var values := normalized(unit, catalog)
	for index in range(values.size() - 1, -1, -1):
		var current := Dictionary(values[index])
		current["remaining_rounds"] = int(current.get("remaining_rounds", 0)) - max(1, rounds)
		if int(current.get("remaining_rounds", 0)) <= 0:
			values.remove_at(index)
		else:
			values[index] = current
	unit["statuses"] = values


func normalized(unit: Dictionary, catalog: Dictionary) -> Array:
	var result: Array = []
	for value in Array(unit.get("statuses", [])):
		var current := Dictionary(value).duplicate(true)
		var status_id := EffectVocabularyScript.text(current, EffectVocabularyScript.FIELD_STATUS_ID, String(current.get("id", "")))
		var definition := Dictionary(catalog.get(status_id, {}))
		if status_id == "":
			continue
		current["status_id"] = status_id
		if definition.is_empty():
			current["orphaned"] = true
			current["stacks"] = max(1, int(current.get("stacks", 1)))
			current["remaining_rounds"] = max(1, int(current.get("remaining_rounds", 1)))
			current["source_id"] = String(current.get("source_id", ""))
			current["applied_seq"] = int(current.get("applied_seq", 0))
			result.append(current)
			continue
		current.erase("orphaned")
		current["stacks"] = clampi(int(current.get("stacks", 1)), 1, max(1, int(definition.get("max_stacks", 1))))
		current["remaining_rounds"] = max(1, int(current.get("remaining_rounds", definition.get("default_duration", 1))))
		current["source_id"] = String(current.get("source_id", ""))
		current["applied_seq"] = int(current.get("applied_seq", 0))
		result.append(current)
	return result


func modifiers(unit: Dictionary, catalog: Dictionary, hook: String, context: Dictionary = {}) -> Array:
	var result: Array = []
	for status_value in normalized(unit, catalog):
		var status := Dictionary(status_value)
		var status_id := EffectVocabularyScript.status_id(status)
		var definition := Dictionary(catalog.get(status_id, {}))
		for effect_value in Array(definition.get("effects", [])):
			var effect := Dictionary(effect_value)
			var effect_hook := EffectVocabularyScript.hook_id(effect)
			if effect_hook != EffectHookIdsScript.ALWAYS and effect_hook != hook:
				continue
			var condition_context := context.duplicate(true)
			condition_context["unit"] = unit
			condition_context[EffectVocabularyScript.FIELD_HOOK] = hook
			if not _condition_evaluator.matches(EffectVocabularyScript.condition(effect), condition_context):
				continue
			if EffectVocabularyScript.effect_type(effect) != EffectVocabularyScript.TYPE_MODIFY_STAT:
				continue
			var modifier := effect.duplicate(true)
			modifier["source_type"] = "status"
			modifier["source_id"] = status_id
			modifier["instance_id"] = "%s:%d" % [status_id, int(status.get("applied_seq", 0))]
			modifier["phase"] = String(effect.get("phase", "status"))
			if EffectVocabularyScript.operation_id(modifier) == StatOperationIdsScript.FLAT_ADD_PER_STACK:
				modifier[EffectVocabularyScript.FIELD_OPERATION] = StatOperationIdsScript.FLAT_ADD
				modifier["value"] = int(effect.get("value", 0)) * int(status.get("stacks", 1))
			result.append(modifier)
	return result


func trigger_effects(unit: Dictionary, catalog: Dictionary, hook: String, context: Dictionary = {}) -> Array:
	var result: Array = []
	for status_value in normalized(unit, catalog):
		var status := Dictionary(status_value)
		var status_id := EffectVocabularyScript.status_id(status)
		for effect_value in Array(Dictionary(catalog.get(status_id, {})).get("effects", [])):
			var effect := Dictionary(effect_value)
			var effect_hook := EffectVocabularyScript.text(effect, EffectVocabularyScript.FIELD_HOOK)
			if EffectVocabularyScript.effect_type(effect) == EffectVocabularyScript.TYPE_MODIFY_STAT or effect_hook != hook:
				continue
			var condition_context := context.duplicate(true)
			condition_context["unit"] = unit
			condition_context[EffectVocabularyScript.FIELD_HOOK] = hook
			if _condition_evaluator.matches(EffectVocabularyScript.condition(effect), condition_context):
				var triggered := effect.duplicate(true)
				triggered["source_status_id"] = status_id
				triggered["stacks"] = int(status.get("stacks", 1))
				result.append(triggered)
	return result
