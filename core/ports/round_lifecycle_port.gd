extends RefCounted

const SkillEffectPortScript := preload("res://core/ports/skill_effect_port.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")

## Versioned adapter between RoundLifecycleService and the legacy authoritative
## facade. Dynamic compatibility access is confined to this file.

const CONTRACT_ID := &"ysbzs.round-lifecycle-port.v1"
var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func units_for_side(side: String, living_only: bool) -> Array:
	var result: Array = []
	for unit_value in Array(_authority.get("units")):
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != side:
			continue
		if living_only and int(unit.get("hp", 0)) <= 0:
			continue
		result.append(unit)
	return result


func tick_skill_cooldowns(unit: Dictionary) -> void:
	var cooldowns := Dictionary(unit.get("skill_cooldowns", {}))
	for skill_id_value in cooldowns.keys():
		var skill_id := String(skill_id_value)
		var remaining: int = max(0, int(cooldowns.get(skill_id_value, 0)) - 1)
		if remaining <= 0:
			cooldowns.erase(skill_id_value)
		else:
			cooldowns[skill_id] = remaining
	unit["skill_cooldowns"] = cooldowns


func execute_attribute_hook(unit: Dictionary, hook: StringName) -> void:
	if not [EffectHookIdsScript.ROUND_START, EffectHookIdsScript.ROUND_END].has(String(hook)):
		return
	var composition := _composition()
	if composition == null:
		return
	var pipeline := composition.get("battle_hook_pipeline") as RefCounted
	if pipeline == null:
		return
	var effect_port := SkillEffectPortScript.new(_authority)
	var hook_context := effect_port.begin_hook(unit, String(hook))
	hook_context = effect_port.condition_context(hook_context, {})
	var collected := Dictionary(pipeline.call(
		&"collect",
		unit,
		Dictionary(_authority.get("game_data")),
		String(hook),
		hook_context
	))
	pipeline.call(&"execute", effect_port, hook_context, collected)
	effect_port.finish_hook(hook_context)


func mechanic_ids(unit: Dictionary) -> Array:
	return Array(_authority.call("_unit_mechanic_ids", unit))


func mechanism(mechanism_id: String) -> Dictionary:
	return Dictionary(_authority.call("_mechanism_by_id", mechanism_id))


func mechanic_param_int(unit: Dictionary, definition: Dictionary, key: String, fallback: int) -> int:
	return int(_authority.call("_mechanic_param_int", unit, definition, key, fallback))


func mechanic_param_string(unit: Dictionary, definition: Dictionary, key: String, fallback: String) -> String:
	return String(_authority.call("_mechanic_param_string", unit, definition, key, fallback))


func battle_round() -> int:
	return int(_authority.get("battle_round"))


func first_adjacent_empty_cell(unit: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("_first_adjacent_empty_cell", unit))


func first_empty_cell() -> Dictionary:
	for y in range(int(_authority.get("board_height"))):
		for x in range(int(_authority.get("board_width"))):
			if Dictionary(_authority.call("unit_at", x, y)).is_empty():
				return {"x": x, "y": y}
	return {}


func summon_unit_on_cell(
	caster: Dictionary,
	mechanism_definition: Dictionary,
	cell: Dictionary,
	default_summon_id: String,
	display_name: String,
	default_hp: int,
	default_atk: int
) -> Dictionary:
	return Dictionary(_authority.call(
		"_summon_unit_on_cell",
		caster,
		mechanism_definition,
		cell,
		default_summon_id,
		display_name,
		default_hp,
		default_atk
	))


func apply_cross_damage(
	unit: Dictionary,
	source: Dictionary,
	damage: int,
	element: String,
	label: String,
	trace_context: Dictionary
) -> Dictionary:
	return Dictionary(_authority.call(
		"_apply_cross_damage_from_unit",
		unit,
		source,
		damage,
		element,
		label,
		trace_context
	))


func advance_status_round(unit: Dictionary) -> void:
	var composition := _composition()
	if composition == null:
		return
	var status_service := composition.get("status_service") as RefCounted
	if status_service == null:
		return
	var status_catalog := Dictionary(Dictionary(_authority.get("game_data")).get("status_catalog", {}))
	status_service.call(&"advance_round", unit, status_catalog)


func log_lines(lines: Array) -> void:
	for line in lines:
		_authority.call("_log", String(line))


func _composition() -> RefCounted:
	return _authority.get("_core_composition") as RefCounted
