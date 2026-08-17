extends RefCounted

const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")
const SkillActionRulesScript := preload("res://core/battle/skills/skill_action_rules.gd")
const SkillShapeRulesScript := preload("res://core/battle/skills/skill_shape_rules.gd")

## Deterministic action-slot state rules. The caller owns every authoritative
## Dictionary and keeps phase, actor, board, preview, selection, and logging
## coordination outside this service. Legacy shape cadence is normalized once
## into `strike_count`; attack options remain geometry-only and formal skills
## use their own effect cadence.


func project_slots(unit: Dictionary, input: Dictionary) -> Array:
	if unit.is_empty():
		return []
	var slots: Array = []
	var elements: Array = SkillShapeRulesScript.slot_elements(unit)
	var used: Dictionary = Dictionary(unit.get("action_slots_used", {}))
	var base_layers: int = max(1, int(unit.get("base_layers", 1)))
	var definition := Dictionary(input.get("shapeDefinition", {}))
	var available_ap := int(input.get("availableAp", 0))
	var selected_ap_choices := Dictionary(input.get("selectedApChoices", {}))
	var directions := Dictionary(input.get("directions", {}))
	for index in range(elements.size()):
		var used_key := str(index)
		var is_used := bool(used.get(used_key, false))
		var selected_ap_value := selected_ap(unit, index, selected_ap_choices, available_ap)
		var direction := ShapeGeometryScript.normalize_direction(stored_direction(unit, index, directions))
		slots.append({
			"slot_id": "%s_slot_%d" % [String(unit.get("id", "")), index + 1],
			"index": index,
			"label": "第%d槽" % (index + 1),
			"element": String(elements[index]),
			"layers": base_layers,
			"base_layers": base_layers,
			"selected_ap": selected_ap_value,
			"effective_layers": base_layers * selected_ap_value,
			"strike_count": SkillActionRulesScript.legacy_action_strike_count(unit, definition),
			"shape_id": String(definition.get("shape_id", unit.get("shape_id", "01"))),
			"shape_name": String(definition.get("label", unit.get("shape_name", "形状01"))),
			"hit_cells": max(1, int(unit.get("hit_cells", definition.get("cell_count", 1)))),
			"direction": direction,
			"direction_label": ShapeGeometryScript.direction_label(direction),
			"used": is_used,
			"available_ap": available_ap,
			"can_use": not is_used and available_ap > 0,
		})
	return slots


func slot_key(unit: Dictionary, index: int) -> String:
	return "%s:slot%d" % [String(unit.get("id", "")), index]


func stored_direction(unit: Dictionary, index: int, directions: Dictionary) -> String:
	var key := slot_key(unit, index)
	if directions.has(key):
		return String(directions[key])
	if directions.has(str(index)):
		return String(directions[str(index)])
	return "right"


func set_direction(unit: Dictionary, index: int, direction: String, directions: Dictionary) -> bool:
	if unit.is_empty() or index < 0 or direction == "":
		return false
	directions[slot_key(unit, index)] = direction
	return true


func selected_ap(unit: Dictionary, index: int, choices: Dictionary, available_ap: int) -> int:
	if unit.is_empty():
		return 1
	var wanted: int = max(1, int(choices.get(slot_key(unit, index), 1)))
	return clampi(wanted, 1, max(1, available_ap))


func set_ap_choice(unit: Dictionary, index: int, value: int, choices: Dictionary) -> bool:
	if unit.is_empty() or index < 0 or value < 1:
		return false
	choices[slot_key(unit, index)] = value
	return true


func mark_used(unit: Dictionary, index: int, spent_ap: int = 1) -> bool:
	if unit.is_empty() or index < 0:
		return false
	var used := Dictionary(unit.get("action_slots_used", {}))
	used[str(index)] = true
	unit["action_slots_used"] = used
	unit["action_ap_spent"] = int(unit.get("action_ap_spent", 0)) + max(1, spent_ap)
	return true


func next_available_index(slots: Array) -> int:
	for value in slots:
		var slot := Dictionary(value)
		if not bool(slot.get("used", false)):
			return int(slot.get("index", 0))
	return 0


func has_available(slots: Array) -> bool:
	for value in slots:
		if not bool(Dictionary(value).get("used", false)):
			return true
	return false


func has_used(unit: Dictionary) -> bool:
	for value in Dictionary(unit.get("action_slots_used", {})).values():
		if bool(value):
			return true
	return false


func clear_unit(unit: Dictionary, choices: Dictionary, slot_count: int) -> bool:
	if unit.is_empty():
		return false
	unit["action_slots_used"] = {}
	unit["action_ap_spent"] = 0
	for index in range(max(1, slot_count)):
		choices.erase(slot_key(unit, index))
	return true
