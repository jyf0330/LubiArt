extends RefCounted

const SkillEffectPortScript := preload("res://core/ports/skill_effect_port.gd")
const SkillActionPlanServiceScript := preload("res://core/battle/skills/skill_action_plan_service.gd")
const SkillActionRulesScript := preload("res://core/battle/skills/skill_action_rules.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const PLAYER := "player"

## Narrow adapter used by PlayerTurnService. It builds stable skill-plan steps,
## then re-resolves live authority objects immediately before execution.

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func phase() -> String:
	return String(_authority.get("phase"))


func action_points() -> int:
	return int(_authority.get("ap"))


func set_resolving(value: bool) -> void:
	_authority.set("_player_all_out_resolving", value)


func selected_unit_id() -> String:
	return String(_authority.get("selected_unit_id"))


func selected_slot_index() -> int:
	return int(_authority.get("selected_action_slot_index"))


func set_selection(unit_id: String, slot_index: int) -> void:
	_authority.set("selected_unit_id", unit_id)
	_authority.set("selected_action_slot_index", slot_index)


func skill_action_plan() -> Array:
	var catalog := Dictionary(Dictionary(_authority.get("game_data")).get("skill_catalog", {}))
	return SkillActionPlanServiceScript.new().build(
		Array(_authority.call("_skill_control_entries", PLAYER)),
		catalog,
		Dictionary(_authority.get("action_dirs"))
	)


func unit_for_step(step: Dictionary) -> Dictionary:
	var unit := Dictionary(_authority.call("unit_by_id", String(step.get("unitId", ""))))
	if unit.is_empty() or String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
		return {}
	return unit


func execute_skill_step(unit: Dictionary, step: Dictionary) -> bool:
	var skill_id := String(step.get("skillId", ""))
	var order_index := int(step.get("orderIndex", 0))
	var catalog := Dictionary(Dictionary(_authority.get("game_data")).get("skill_catalog", {}))
	var definition := Dictionary(catalog.get(skill_id, {}))
	if definition.is_empty():
		self.log("技能定义不存在：%s。" % skill_id)
		return false
	var slot_index := SkillActionRulesScript.action_slot_index(definition)
	var directions := Dictionary(_authority.get("action_dirs"))
	directions[String(_authority.call("_action_slot_key", unit, slot_index))] = String(step.get("direction", "right"))
	_authority.set("action_dirs", directions)
	var composition: RefCounted = _authority.get("_core_composition")
	var trait_catalog := Dictionary(Dictionary(_authority.get("game_data")).get("trait_catalog", {}))
	var modifiers := Dictionary(composition.trait_service.modifiers(unit, trait_catalog, EffectHookIdsScript.SKILL))
	return bool(composition.skill_execution_service.execute(
		SkillEffectPortScript.new(_authority),
		unit,
		definition,
		order_index,
		modifiers,
		EffectHookIdsScript.SKILL
	))


func skill_combos(queue: Array[String], order_index: int, already_triggered: Dictionary) -> Array:
	var data := Dictionary(_authority.get("game_data"))
	var composition: RefCounted = _authority.get("_core_composition")
	return Array(composition.skill_combo_service.matches_at(
		queue,
		order_index,
		Dictionary(data.get("skill_catalog", {})),
		Dictionary(data.get("skill_combo_catalog", {})),
		already_triggered
	))


func execute_combo(unit: Dictionary, definition: Dictionary) -> bool:
	var data := Dictionary(_authority.get("game_data"))
	var composition: RefCounted = _authority.get("_core_composition")
	var modifiers := Dictionary(composition.trait_service.modifiers(unit, Dictionary(data.get("trait_catalog", {})), EffectHookIdsScript.COMBO))
	return bool(composition.skill_execution_service.execute(
		SkillEffectPortScript.new(_authority),
		unit,
		definition,
		int(definition.get("end_index", 0)),
		modifiers,
		EffectHookIdsScript.COMBO
	))


func finish_skill_phase() -> void:
	_authority.set("ap", 0)
	_authority.set("auto_position_action_plan", [])


func settle_elements() -> void:
	_authority.call("_settle_player_elements_after_all_out")


func log(message: String) -> void:
	_authority.call("_log", message)
