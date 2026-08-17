extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const ReadPortScript := preload("res://core/battle/auto_position/auto_position_read_port.gd")
const TurnOptimizerScript := preload("res://core/battle/auto_position/auto_position_turn_optimizer.gd")
const AutoPositionTestContextScript := preload("res://tests/helpers/auto_position_test_context.gd")

var failed := false


func _initialize() -> void:
	var state := StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var templates := _enemy_templates(state)
	var tank := Dictionary(templates[0]).duplicate(true)
	var finisher_target := Dictionary(templates[1]).duplicate(true)
	_prepare_enemy(tank, "tank_target", 100)
	_prepare_enemy(finisher_target, "finisher_target", 1)
	state.units = [tank, finisher_target]
	var expensive := _choice("a_expensive", "tank_target", 2, 30)
	var finisher := _choice("z_finisher", "finisher_target", 1, 1)
	var optimizer := TurnOptimizerScript.new()
	var read_port := ReadPortScript.new(
		AutoPositionTestContextScript.build(state),
		AutoPositionTestContextScript.evaluator(state)
	)
	var context := Dictionary(read_port.optimization_context())
	var forward := Dictionary(optimizer.optimize([expensive, finisher], 2, context))
	var reverse := Dictionary(optimizer.optimize([finisher, expensive], 2, context))
	_expect(int(forward.get("kills", 0)) == 1, "AP optimizer skips an earlier expensive nonlethal action for a later kill")
	_expect(int(reverse.get("kills", 0)) == 1, "reversing unit traversal keeps the same kill outcome")
	_expect(_selected_unit_ids([expensive, finisher], forward) == ["z_finisher"], "forward order selects only the one-AP finisher")
	_expect(_selected_unit_ids([finisher, expensive], reverse) == ["z_finisher"], "reverse order selects the same finisher")
	var planned := Array(optimizer.selected_actions([expensive, finisher], forward))
	_expect(_unit_ids(planned) == ["z_finisher"], "execution actions reuse the exact optimized subset")
	if failed:
		quit(1)
		return
	print("SMOKE_AUTO_POSITION_TURN_OPTIMIZER_OK selected=%s kills=%d ap=%d" % [
		JSON.stringify(_selected_unit_ids([expensive, finisher], forward)),
		int(forward.get("kills", 0)),
		int(forward.get("apSpent", 0))
	])
	quit(0)


func _choice(unit_id: String, target_id: String, action_ap: int, damage: int) -> Dictionary:
	return {
		"unitId": unit_id,
		"from": {"x": 0, "y": 0},
		"to": {"x": 0, "y": 0},
		"slotIndex": 0,
		"dir": "right",
		"ap": action_ap,
		"rawDamage": damage,
		"damageByTarget": {target_id: damage},
		"targets": [target_id],
		"cells": []
	}


func _selected_unit_ids(choices: Array, evaluation: Dictionary) -> Array:
	var selected: Array = []
	for index_value in Array(evaluation.get("selectedChoiceIndices", [])):
		var index := int(index_value)
		if index >= 0 and index < choices.size():
			selected.append(String(Dictionary(choices[index]).get("unitId", "")))
	selected.sort()
	return selected


func _unit_ids(choices: Array) -> Array:
	var ids: Array = []
	for choice_value in choices:
		ids.append(String(Dictionary(choice_value).get("unitId", "")))
	ids.sort()
	return ids


func _enemy_templates(state: RefCounted) -> Array:
	var enemies: Array = []
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			enemies.append(unit)
			if enemies.size() == 2:
				return enemies
	return enemies


func _prepare_enemy(enemy: Dictionary, unit_id: String, hp: int) -> void:
	enemy["id"] = unit_id
	enemy["name"] = unit_id
	enemy["side"] = StateScript.ENEMY
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["shield"] = 0
	enemy["def"] = 0
	enemy.erase("is_boss")
	enemy.erase("isBoss")
	enemy.erase("boss")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_AUTO_POSITION_TURN_OPTIMIZER_FAIL: %s" % message)
