extends RefCounted

const SkillActionRulesScript := preload("res://core/battle/skills/skill_action_rules.gd")
const SkillActionPlanServiceScript := preload("res://core/battle/skills/skill_action_plan_service.gd")

const SkillEffectPortScript := preload("res://core/ports/skill_effect_port.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")

## Narrow adapter used by EnemyTurnService.

var _authority: Object
var _enemy_side: String


func _init(authority: Object, enemy_side: String) -> void:
	_authority = authority
	_enemy_side = enemy_side


func reset_action_slots() -> void:
	_authority.call("_reset_action_slots", _enemy_side)


func phase() -> String:
	return String(_authority.get("phase"))


func begin_round() -> void:
	_authority.call("_apply_mechanic_round_start", _enemy_side)


func auto_position() -> void:
	_authority.call("_apply_enemy_auto_position_plan")


func skill_action_plan() -> Array:
	var catalog := Dictionary(Dictionary(_authority.get("game_data")).get("skill_catalog", {}))
	return SkillActionPlanServiceScript.new().build(
		Array(_authority.call("_skill_control_entries", _enemy_side)),
		catalog,
		Dictionary(_authority.get("action_dirs"))
	)


func nearest_player(enemy: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("_nearest_player", enemy))


func best_action(enemy: Dictionary, required_target: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("_best_enemy_shape_action", enemy, required_target))

func attack_count(enemy: Dictionary) -> int:
	return int(_authority.call("_enemy_attack_count", enemy))


func execute_action(enemy: Dictionary, action: Dictionary) -> int:
	return int(_authority.call("_execute_enemy_shape_action", enemy, action))


func unit_for_step(step: Dictionary) -> Dictionary:
	var unit := Dictionary(_authority.call("unit_by_id", String(step.get("unitId", ""))))
	if unit.is_empty() or String(unit.get("side", "")) != _enemy_side or int(unit.get("hp", 0)) <= 0:
		return {}
	return unit


func execute_skill_step(enemy: Dictionary, step: Dictionary, required_target: Dictionary) -> bool:
	var skill_id := String(step.get("skillId", ""))
	var order_index := int(step.get("orderIndex", 0))
	var catalog := Dictionary(Dictionary(_authority.get("game_data")).get("skill_catalog", {}))
	var definition := Dictionary(catalog.get(skill_id, {}))
	if definition.is_empty():
		self.log("敌方技能定义不存在：%s。" % skill_id)
		return false
	var planned_action := best_action(enemy, required_target)
	if planned_action.is_empty():
		return false
	var option := Dictionary(planned_action.get("option", {}))
	var composition: RefCounted = _authority.get("_core_composition")
	var slot_index: int = clampi(SkillActionRulesScript.action_slot_index(definition), 0, max(0, Array(_authority.call("_action_slots_for_unit", enemy)).size() - 1))
	var directions := Dictionary(_authority.get("action_dirs"))
	directions[String(_authority.call("_action_slot_key", enemy, slot_index))] = String(option.get("direction", "left"))
	_authority.set("action_dirs", directions)
	var trait_catalog := Dictionary(Dictionary(_authority.get("game_data")).get("trait_catalog", {}))
	var modifiers := Dictionary(composition.trait_service.modifiers(enemy, trait_catalog, EffectHookIdsScript.SKILL))
	return bool(composition.skill_execution_service.execute(
		SkillEffectPortScript.new(_authority),
		enemy,
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


func execute_combo(enemy: Dictionary, definition: Dictionary, required_target: Dictionary) -> bool:
	var planned_action := best_action(enemy, required_target)
	if planned_action.is_empty():
		return false
	var option := Dictionary(planned_action.get("option", {}))
	var composition: RefCounted = _authority.get("_core_composition")
	var slot_index: int = clampi(SkillActionRulesScript.action_slot_index(definition), 0, max(0, Array(_authority.call("_action_slots_for_unit", enemy)).size() - 1))
	var directions := Dictionary(_authority.get("action_dirs"))
	directions[String(_authority.call("_action_slot_key", enemy, slot_index))] = String(option.get("direction", "left"))
	_authority.set("action_dirs", directions)
	var trait_catalog := Dictionary(Dictionary(_authority.get("game_data")).get("trait_catalog", {}))
	var modifiers := Dictionary(composition.trait_service.modifiers(enemy, trait_catalog, EffectHookIdsScript.COMBO))
	return bool(composition.skill_execution_service.execute(
		SkillEffectPortScript.new(_authority),
		enemy,
		definition,
		int(definition.get("end_index", 0)),
		modifiers,
		EffectHookIdsScript.COMBO
	))


func hero_hp() -> int:
	return int(_authority.get("hero_hp"))


func log(message: String) -> void:
	_authority.call("_log", message)
