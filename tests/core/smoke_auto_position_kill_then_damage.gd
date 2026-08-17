extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	_test_low_hp_kill_beats_higher_nonlethal_damage()
	_test_damage_breaks_equal_kill_count()
	_test_equal_damage_has_one_stable_result()
	_test_repeated_distant_team_placement_is_idempotent()
	if failed:
		quit(1)
		return
	print("SMOKE_AUTO_POSITION_KILL_THEN_DAMAGE_OK")
	quit(0)


func _test_low_hp_kill_beats_higher_nonlethal_damage() -> void:
	var state: RefCounted = _kill_over_damage_fixture()
	var plan := Dictionary(state.call("_build_auto_position_plan"))
	var actions := Array(plan.get("actions", []))
	_expect(actions.size() == 1, "kill-first planner returns one executable team result")
	if not actions.is_empty():
		_expect(Array(Dictionary(actions[0]).get("targets", [])).has("low_hp_kill"), "a 1-damage kill beats 30 nonlethal effective damage regardless of canonical attack side")
	_expect(int(plan.get("kills", -1)) == 1, "kill-first result reports one defeated enemy")
	_expect(int(plan.get("effectiveDamage", -1)) == 1, "kill-first result accepts only 1 effective damage when it secures the kill")
	_expect(String(plan.get("objective", "")) == "max_kills_then_effective_damage", "plan declares kills first and damage second")
	_expect(int(plan.get("resultCount", 0)) == 1, "plan exposes exactly one selected result")


func _test_damage_breaks_equal_kill_count() -> void:
	var state: RefCounted = _damage_tiebreak_fixture()
	var plan := Dictionary(state.call("_build_auto_position_plan"))
	var actions := Array(plan.get("actions", []))
	_expect(int(plan.get("kills", -1)) == 0, "damage tiebreak fixture has no kill on either side")
	_expect(int(plan.get("effectiveDamage", -1)) == 36, "equal-kill plans maximize three-strike damage plus the current three-layer element settlement, got %d" % int(plan.get("effectiveDamage", -1)))
	if not actions.is_empty():
		_expect(String(Dictionary(actions[0]).get("dir", "")) == "right", "higher effective damage wins when kill counts are equal")


func _test_equal_damage_has_one_stable_result() -> void:
	var state: RefCounted = _equal_damage_fixture()
	var first_plan := Dictionary(state.call("_build_auto_position_plan"))
	var first_signature := String(first_plan.get("resultSignature", ""))
	_expect(first_signature != "", "equal-damage plan exposes a canonical result signature")
	for _index in range(10):
		var repeated_plan := Dictionary(state.call("_build_auto_position_plan"))
		_expect(String(repeated_plan.get("resultSignature", "")) == first_signature, "unchanged state always returns the same canonical result")
	_expect(state.dispatch({"type": "AUTO_POSITION_HEROES"}), "first automatic placement succeeds")
	var actor: Dictionary = state.unit_by_id("stable_actor")
	var first_cell := "%d,%d" % [int(actor.get("x", -1)), int(actor.get("y", -1))]
	var first_actions := JSON.stringify(state.auto_position_action_plan)
	_expect(state.dispatch({"type": "AUTO_POSITION_HEROES"}), "second automatic placement succeeds")
	actor = state.unit_by_id("stable_actor")
	var second_cell := "%d,%d" % [int(actor.get("x", -1)), int(actor.get("y", -1))]
	_expect(second_cell == first_cell, "repeated automatic placement does not move to another equal-damage cell")
	_expect(JSON.stringify(state.auto_position_action_plan) == first_actions, "repeated automatic placement keeps the same action result")


func _test_repeated_distant_team_placement_is_idempotent() -> void:
	var state: RefCounted = _distant_team_fixture()
	_expect(state.dispatch({"type": "AUTO_POSITION_HEROES"}), "first distant-team automatic placement succeeds")
	var first_cells := _player_cells(state)
	var first_actions := JSON.stringify(state.auto_position_action_plan)
	var first_plan := Dictionary(Dictionary(state.last_command_result).get("plan", {}))
	var first_signature := String(first_plan.get("resultSignature", ""))
	_expect(int(first_plan.get("kills", 0)) == 2, "first distant-team placement reaches the current three-strike kill maximum")
	_expect(not Array(first_plan.get("actions", [])).is_empty(), "first distant-team placement stores executable damage actions")
	_expect(state.dispatch({"type": "AUTO_POSITION_HEROES"}), "second distant-team automatic placement succeeds")
	_expect(_player_cells(state) == first_cells, "repeated distant-team placement cannot chain another movement range")
	_expect(JSON.stringify(state.auto_position_action_plan) == first_actions, "repeated distant-team placement reuses the original action plan")
	_expect(String(Dictionary(Dictionary(state.last_command_result).get("plan", {})).get("resultSignature", "")) == first_signature, "repeated distant-team placement keeps the original result signature")


func _kill_over_damage_fixture() -> RefCounted:
	var state := StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var templates := _templates(state)
	var actor := Dictionary(templates.get("actor", {})).duplicate(true)
	var enemy_a := Dictionary(templates.get("enemy_a", {})).duplicate(true)
	var enemy_b := Dictionary(templates.get("enemy_b", {})).duplicate(true)
	_prepare_actor(actor, "kill_priority_actor", 3, 5, 0)
	_prepare_enemy(enemy_a, "low_hp_kill", 2, 5, 1)
	_prepare_enemy(enemy_b, "high_hp_damage", 4, 5, 60)
	state.units = [actor, enemy_a, enemy_b]
	state.ap = 1
	return state


func _damage_tiebreak_fixture() -> RefCounted:
	var state := StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var templates := _templates(state)
	var actor := Dictionary(templates.get("actor", {})).duplicate(true)
	var enemy_a := Dictionary(templates.get("enemy_a", {})).duplicate(true)
	var enemy_b := Dictionary(templates.get("enemy_b", {})).duplicate(true)
	_prepare_actor(actor, "damage_tiebreak_actor", 3, 5, 0)
	_prepare_enemy(enemy_a, "reduced_damage_target", 2, 5, 60)
	enemy_a["def"] = 5
	_prepare_enemy(enemy_b, "full_damage_target", 4, 5, 60)
	state.units = [actor, enemy_a, enemy_b]
	state.ap = 1
	return state


func _equal_damage_fixture() -> RefCounted:
	var state := StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var templates := _templates(state)
	var actor := Dictionary(templates.get("actor", {})).duplicate(true)
	var enemy := Dictionary(templates.get("enemy_a", {})).duplicate(true)
	_prepare_actor(actor, "stable_actor", 3, 3, 3)
	_prepare_enemy(enemy, "stable_enemy", 5, 5, 30)
	state.units = [actor, enemy]
	state.ap = 1
	return state


func _distant_team_fixture() -> RefCounted:
	var state := StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var templates := _templates(state)
	var actor_template := Dictionary(templates.get("actor", {}))
	var actor_a := actor_template.duplicate(true)
	var actor_b := actor_template.duplicate(true)
	var actor_c := actor_template.duplicate(true)
	var enemy_a := Dictionary(templates.get("enemy_a", {})).duplicate(true)
	var enemy_b := Dictionary(templates.get("enemy_b", {})).duplicate(true)
	_prepare_actor(actor_a, "distant_actor_a", 1, 5, 2)
	_prepare_actor(actor_b, "distant_actor_b", 0, 6, 2)
	_prepare_actor(actor_c, "distant_actor_c", 2, 6, 2)
	_prepare_enemy(enemy_a, "distant_enemy_a", 5, 1, 21)
	_prepare_enemy(enemy_b, "distant_enemy_b", 6, 2, 10)
	state.units = [actor_a, actor_b, actor_c, enemy_a, enemy_b]
	state.ap = 3
	return state


func _player_cells(state: RefCounted) -> String:
	var rows := PackedStringArray()
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != StateScript.PLAYER:
			continue
		rows.append("%s@%d,%d" % [String(unit.get("id", "")), int(unit.get("x", -1)), int(unit.get("y", -1))])
	rows.sort()
	return "|".join(rows)


func _templates(state: RefCounted) -> Dictionary:
	var actor := {}
	var enemies: Array = []
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and actor.is_empty():
			actor = unit
		elif String(unit.get("side", "")) == StateScript.ENEMY and enemies.size() < 2:
			enemies.append(unit)
	return {
		"actor": actor,
		"enemy_a": enemies[0] if enemies.size() > 0 else {},
		"enemy_b": enemies[1] if enemies.size() > 1 else (enemies[0] if enemies.size() > 0 else {})
	}


func _prepare_actor(actor: Dictionary, unit_id: String, x: int, y: int, move_range: int) -> void:
	actor["id"] = unit_id
	actor["name"] = unit_id
	actor["side"] = StateScript.PLAYER
	actor["x"] = x
	actor["y"] = y
	actor["hp"] = 30
	actor["max_hp"] = 30
	actor["atk"] = 10
	actor["attack"] = 10
	actor["skill"] = ""
	actor["quality_upgrade"] = {}
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["slot_count"] = 1
	actor["slot_elements"] = [String(actor.get("element", "土"))]
	actor["base_layers"] = 1
	actor["move_range"] = move_range
	actor["moveRange"] = move_range
	actor["has_attacked"] = false
	actor["hasAttacked"] = false
	actor["action_slots_used"] = {}
	actor["action_ap_spent"] = 0


func _prepare_enemy(enemy: Dictionary, unit_id: String, x: int, y: int, hp: int) -> void:
	enemy["id"] = unit_id
	enemy["name"] = unit_id
	enemy["side"] = StateScript.ENEMY
	enemy["x"] = x
	enemy["y"] = y
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["shield"] = 0
	enemy["def"] = 0
	enemy["atk"] = 0
	enemy["attack"] = 0
	enemy["ap"] = 1
	enemy["move_range"] = 0
	enemy["moveRange"] = 0
	enemy["role"] = "minion"
	enemy["type"] = "pet"
	enemy.erase("is_boss")
	enemy.erase("isBoss")
	enemy.erase("boss")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
