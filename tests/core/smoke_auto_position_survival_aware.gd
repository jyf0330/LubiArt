extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const AutoPositionPolicyScript := preload("res://core/battle/auto_position/auto_position_policy.gd")
const AutoPositionTestContextScript := preload("res://tests/helpers/auto_position_test_context.gd")

var failed := false


func _initialize() -> void:
	_test_retaliation_projection_prefers_shield_over_hp_loss()
	_test_survival_breaks_equal_kill_count_before_damage()
	_test_enemy_kill_still_dominates_survival()
	_test_pruning_preserves_positionally_distinct_finalists()
	_test_attackers_keep_safe_standby_candidates()
	_test_all_death_explosions_reject_adjacent_finisher()
	if failed:
		quit(1)
		return
	print("SMOKE_AUTO_POSITION_SURVIVAL_AWARE_OK")
	quit(0)


func _test_retaliation_projection_prefers_shield_over_hp_loss() -> void:
	var state := StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var templates := _templates(state)
	var fragile := Dictionary(templates.get("player", {})).duplicate(true)
	var tank := Dictionary(templates.get("player", {})).duplicate(true)
	var enemy := Dictionary(templates.get("enemy", {})).duplicate(true)
	_prepare_player(fragile, "fragile", 2, 2, 10, 0)
	_prepare_player(tank, "tank", 2, 3, 10, 20)
	_prepare_enemy(enemy, "retaliator", 4, 2, 6)
	state.units = [fragile, tank, enemy]
	var risky_choices := [
		{"unitId": "fragile", "to": {"x": 2, "y": 2}, "skip": true, "targets": []},
		{"unitId": "tank", "to": {"x": 2, "y": 3}, "skip": true, "targets": []}
	]
	var safe_choices := [
		{"unitId": "fragile", "to": {"x": 2, "y": 3}, "skip": true, "targets": []},
		{"unitId": "tank", "to": {"x": 2, "y": 2}, "skip": true, "targets": []}
	]
	var risky := AutoPositionTestContextScript.retaliation(state, risky_choices, {})
	var safe := AutoPositionTestContextScript.retaliation(state, safe_choices, {})
	_expect(int(risky.get("playerHpDamage", 0)) == 6, "fragile target projects six real HP damage")
	_expect(int(safe.get("playerHpDamage", -1)) == 0, "tank target absorbs retaliation without HP loss")
	_expect(int(safe.get("playerShieldDamage", 0)) == 6, "safe plan records shield absorption instead of hiding incoming damage")


func _test_survival_breaks_equal_kill_count_before_damage() -> void:
	var policy := AutoPositionPolicyScript.new()
	var risky := {
		"kills": 1,
		"playerDeaths": 0,
		"playerHpDamage": 7,
		"effectiveDamage": 16,
		"playerShieldDamage": 3,
		"overflow": 0,
		"approachGain": 0,
		"moveCost": 0,
		"signature": "risky"
	}
	var safe := {
		"kills": 1,
		"playerDeaths": 0,
		"playerHpDamage": 0,
		"effectiveDamage": 14,
		"playerShieldDamage": 10,
		"overflow": 0,
		"approachGain": 0,
		"moveCost": 0,
		"signature": "safe"
	}
	_expect(policy.evaluation_is_better(safe, risky), "same-kill plan avoids real HP loss before chasing two extra damage")
	_expect(not policy.evaluation_is_better(risky, safe), "higher damage cannot override avoidable player HP loss")


func _test_enemy_kill_still_dominates_survival() -> void:
	var policy := AutoPositionPolicyScript.new()
	var lethal := {
		"kills": 1,
		"playerDeaths": 1,
		"playerHpDamage": 10,
		"effectiveDamage": 1,
		"playerShieldDamage": 0,
		"overflow": 0,
		"approachGain": 0,
		"moveCost": 0,
		"signature": "lethal"
	}
	var nonlethal := {
		"kills": 0,
		"playerDeaths": 0,
		"playerHpDamage": 0,
		"effectiveDamage": 30,
		"playerShieldDamage": 0,
		"overflow": 0,
		"approachGain": 0,
		"moveCost": 0,
		"signature": "nonlethal"
	}
	_expect(policy.evaluation_is_better(lethal, nonlethal), "one enemy death remains the first priority")


func _test_pruning_preserves_positionally_distinct_finalists() -> void:
	var policy := AutoPositionPolicyScript.new()
	var beams: Array = []
	for slot_index in range(3):
		beams.append(_beam("same-%d" % slot_index, 2, 2, slot_index))
	beams.append(_beam("distinct", 5, 5, 0))
	var finalists := Array(policy.prune_beams(beams, 2, 4))
	var placements := {}
	for beam_value in finalists:
		var choice := Dictionary(Array(Dictionary(beam_value).get("choices", []))[0])
		placements[JSON.stringify(choice.get("to", {}))] = true
	_expect(finalists.size() == 2, "finalist pruning respects its width")
	_expect(placements.size() == 2, "duplicate slots cannot crowd out a distinct position")


func _beam(signature: String, x: int, y: int, slot_index: int) -> Dictionary:
	return {
		"choices": [{"unitId": "player", "to": {"x": x, "y": y}, "slotIndex": slot_index, "targets": ["enemy"]}],
		"evaluation": {
			"kills": 1,
			"playerDeaths": 0,
			"playerHpDamage": 0,
			"effectiveDamage": 10,
			"playerShieldDamage": 0,
			"overflow": 0,
			"approachGain": 0,
			"moveCost": 0,
			"actionsUsed": 1,
			"signature": signature
		}
	}


func _test_attackers_keep_safe_standby_candidates() -> void:
	var state := StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var templates := _templates(state)
	var player := Dictionary(templates.get("player", {})).duplicate(true)
	var enemy := Dictionary(templates.get("enemy", {})).duplicate(true)
	_prepare_player(player, "standby_player", 0, 7, 20, 3)
	_prepare_enemy(enemy, "standby_enemy", 7, 0, 4)
	state.units = [player, enemy]
	var candidates := AutoPositionTestContextScript.candidates(state, player, {"limit": 32, "movementBudget": -1})
	var standby_found := false
	for candidate_value in candidates:
		var candidate := Dictionary(candidate_value)
		var to := Dictionary(candidate.get("to", {}))
		if bool(candidate.get("standby", false)) and Array(candidate.get("targets", [])).is_empty() and (int(to.get("x", 0)) != 0 or int(to.get("y", 7)) != 7) and int(candidate.get("approachGain", 0)) > 0:
			standby_found = true
			break
	_expect(standby_found, "a unit with attack options also keeps a closer non-attacking standby position")


func _test_all_death_explosions_reject_adjacent_finisher() -> void:
	for case_value in [
		{"mechanism_id": "mech_death_explosion", "damage": 6, "hp_damage": 3},
		{"mechanism_id": "mech_self_destruct", "damage": 8, "hp_damage": 5},
		{"mechanism_id": "mech_shield_break_explosion", "damage": 5, "hp_damage": 2},
	]:
		_test_death_explosion_rejects_adjacent_finisher(Dictionary(case_value))


func _test_death_explosion_rejects_adjacent_finisher(case: Dictionary) -> void:
	var state := StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var templates := _templates(state)
	var player := Dictionary(templates.get("player", {})).duplicate(true)
	var enemy := Dictionary(templates.get("enemy", {})).duplicate(true)
	_prepare_player(player, "explosion_target", 4, 3, 20, 3)
	_prepare_enemy(enemy, "exploding_enemy", 4, 2, 2)
	enemy["hp"] = 1
	enemy["max_hp"] = 1
	enemy["mechanism_id"] = String(case.get("mechanism_id", ""))
	enemy["mechanic_params"] = {"damage": int(case.get("damage", 0))}
	state.units = [player, enemy]
	var adjacent := AutoPositionTestContextScript.retaliation(state, [{"unitId": "explosion_target", "to": {"x": 4, "y": 3}, "targets": []}], {"exploding_enemy": 1})
	var distant := AutoPositionTestContextScript.retaliation(state, [{"unitId": "explosion_target", "to": {"x": 0, "y": 7}, "targets": []}], {"exploding_enemy": 1})
	_expect(
		int(adjacent.get("playerHpDamage", -1)) == int(case.get("hp_damage", -1)),
		"adjacent finisher projects %s through the generic death-preview capability" % String(case.get("mechanism_id", ""))
	)
	_expect(
		int(distant.get("playerHpDamage", -1)) == 0,
		"distant player avoids %s death-preview damage" % String(case.get("mechanism_id", ""))
	)


func _templates(state: RefCounted) -> Dictionary:
	var player := {}
	var enemy := {}
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and player.is_empty():
			player = unit
		elif String(unit.get("side", "")) == StateScript.ENEMY and enemy.is_empty():
			enemy = unit
	return {"player": player, "enemy": enemy}


func _prepare_player(unit: Dictionary, unit_id: String, x: int, y: int, hp: int, shield: int) -> void:
	unit["id"] = unit_id
	unit["name"] = unit_id
	unit["side"] = StateScript.PLAYER
	unit["x"] = x
	unit["y"] = y
	unit["hp"] = hp
	unit["max_hp"] = hp
	unit["shield"] = shield
	unit["def"] = 0
	unit["has_attacked"] = false


func _prepare_enemy(unit: Dictionary, unit_id: String, x: int, y: int, atk: int) -> void:
	unit["id"] = unit_id
	unit["name"] = unit_id
	unit["side"] = StateScript.ENEMY
	unit["x"] = x
	unit["y"] = y
	unit["hp"] = 100
	unit["max_hp"] = 100
	unit["shield"] = 0
	unit["atk"] = atk
	unit["attack"] = atk
	unit["ap"] = 1
	unit["move_range"] = 0
	unit["moveRange"] = 0
	unit["shape_id"] = "02"
	unit["shape_name"] = "形状02"
	unit["slot_count"] = 1
	unit["slot_elements"] = ["火"]
	unit["action_slots_used"] = {}
	unit["has_attacked"] = false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
