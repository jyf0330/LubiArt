extends RefCounted

const SkillActionRulesScript := preload("res://core/battle/skills/skill_action_rules.gd")

# Ordered tag combos are intentionally disabled. Their implicit names and
# triggers are not legible enough for the current battle rules; any future
# combination mechanic must use explicit spatial language such as left/right
# or front/back and define that geometry in the rule itself.
const COMBOS_ENABLED := false

## Pure ordered-combination matcher. A combo only inspects the suffix ending at
## the current skill and returns data definitions; authoritative effects remain
## behind SkillExecutionService and SkillEffectPort.


func matches_at(
	queue: Array,
	current_index: int,
	skill_catalog: Dictionary,
	combo_catalog: Dictionary,
	already_triggered: Dictionary = {}
) -> Array:
	var result: Array = []
	if not COMBOS_ENABLED:
		return result
	if current_index < 0 or current_index >= queue.size():
		return result
	for combo_id in _ordered_combo_ids(combo_catalog):
		if bool(already_triggered.get(combo_id, false)):
			continue
		var definition := Dictionary(combo_catalog.get(combo_id, {}))
		var pattern := Array(definition.get("pattern", []))
		if pattern.is_empty() or pattern.size() > current_index + 1:
			continue
		var start_index := current_index + 1 - pattern.size()
		if not _matches_pattern(queue, start_index, pattern, String(definition.get("match_type", "skill_ids")), skill_catalog):
			continue
		var matched_combo := definition.duplicate(true)
		matched_combo["start_index"] = start_index
		matched_combo["end_index"] = current_index
		matched_combo["matched_skill_ids"] = queue.slice(start_index, current_index + 1)
		result.append(matched_combo)
	return result


func planned_matches(queue: Array, skill_catalog: Dictionary, combo_catalog: Dictionary) -> Array:
	var result: Array = []
	var triggered := {}
	for current_index in range(queue.size()):
		for match_value in matches_at(queue, current_index, skill_catalog, combo_catalog, triggered):
			var matched_combo := Dictionary(match_value)
			var combo_id := String(matched_combo.get("id", ""))
			if combo_id == "":
				continue
			triggered[combo_id] = true
			result.append(matched_combo)
	return result


func _ordered_combo_ids(catalog: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for value in catalog.keys():
		ids.append(String(value))
	ids.sort_custom(func(left: String, right: String) -> bool:
		var left_definition := Dictionary(catalog.get(left, {}))
		var right_definition := Dictionary(catalog.get(right, {}))
		var left_order := int(left_definition.get("order_index", 0))
		var right_order := int(right_definition.get("order_index", 0))
		return left_order < right_order or (left_order == right_order and left < right)
	)
	return ids


func _matches_pattern(
	queue: Array,
	start_index: int,
	pattern: Array,
	match_type: String,
	skill_catalog: Dictionary
) -> bool:
	for offset in range(pattern.size()):
		var skill_id := String(queue[start_index + offset])
		var definition := Dictionary(skill_catalog.get(skill_id, {}))
		var expected: Variant = pattern[offset]
		match match_type:
			"tag_sequence":
				if not Array(definition.get("tags", [])).has(String(expected)):
					return false
			"element_sources":
				if String(definition.get("element_source", "primary")) != String(expected):
					return false
			"shape_slots":
				if SkillActionRulesScript.action_slot_index(definition) != int(expected):
					return false
			_:
				if skill_id != String(expected):
					return false
	return true
