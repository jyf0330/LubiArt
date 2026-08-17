extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_element_execution_query_parity()
	_test_trap_execution()
	_test_taunt_query_and_authority_execution()
	if failed:
		quit(1)
		return
	print("SMOKE_MECHANIC_PROJECTION_PRODUCTION_CALLERS_OK")
	quit(0)


func _test_element_execution_query_parity() -> void:
	var state: RefCounted = StateScript.new()
	state.phase = "battle"
	state.battle_round = 1
	state.cell_elements = {}
	var ignite := _player("ignite", "点燃来源", 0, 0)
	ignite["mechanics"] = ["mech_fire_ignite_bonus"]
	ignite["mechanic_params"] = {"per_layer": 2}
	var multi := _player("multi", "共鸣来源", 0, 1)
	multi["mechanics"] = ["mech_multi_element_bonus"]
	multi["mechanic_params"] = {"bonus": 3}
	var cross := _player("cross", "十字来源", 0, 2)
	cross["element"] = "火"
	cross["quality"] = "钻石"
	cross["mechanics"] = ["mech_fire_cross_detonate_diamond"]
	var center := _enemy("center", "中心目标", 4, 4)
	center["hp"] = 100
	center["max_hp"] = 100
	var adjacent := _enemy("adjacent", "相邻目标", 5, 4)
	adjacent["hp"] = 100
	adjacent["max_hp"] = 100
	state.units = [ignite, multi, cross, center, adjacent]
	state.call("_apply_element_to_cell", 4, 4, "火", 4)
	state.call("_apply_element_to_cell", 4, 4, "水", 1)
	state.call("_apply_element_to_cell", 6, 6, "火", 2)
	state.call("_apply_element_to_cell", 6, 6, "水", 1)

	var context := Dictionary(state.call("_battle_query_context"))
	var context_before := context.duplicate(true)
	var projector: RefCounted = state.get("_core_composition").battle_query_projector
	var query_settlement := Dictionary(projector.project_settlement(context, {"火": 4, "水": 1}, "火", {}))
	_expect(int(query_settlement.get("rawDamage", -1)) == 21, "query settlement uses triangular 10 plus ignite 8 and multi-element 3")
	_expect(context == context_before, "query settlement leaves its context unchanged")

	state.battle_trace = []
	_expect(bool(state.call("_settle_threshold_elements")), "state executes the projected threshold settlement")
	_expect(int(state.unit_by_id("center").get("hp", -1)) == 78, "state settles fire4 and water1 on the occupied cell for 22 total damage")
	_expect(int(state.unit_by_id("adjacent").get("hp", -1)) == 79, "cross execution applies the same projected 21 damage to the adjacent target")
	_expect(int(state.call("_cell_elements_at", 4, 4).get("火", -1)) == 0, "state clears the settled fire layers after execution")
	_expect(int(state.call("_cell_elements_at", 4, 4).get("水", -1)) == 0, "state also settles and clears the second element on the same occupied cell")
	_expect(int(state.call("_cell_elements_at", 6, 6).get("火", -1)) == 2, "empty cell preserves its fire terrain")
	_expect(int(state.call("_cell_elements_at", 6, 6).get("水", -1)) == 1, "empty cell preserves every coexisting element terrain")
	var settlement_hits := 0
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		var payload := Dictionary(event.get("payload", {}))
		if String(event.get("type", "")) != "DAMAGE_APPLIED" or String(payload.get("sourceType", "")) != "element_settlement":
			continue
		settlement_hits += 1
	_expect(settlement_hits == 3, "occupied multi-element cell emits two fire hits and one water hit")


func _test_trap_execution() -> void:
	var state: RefCounted = StateScript.new()
	state.phase = "battle"
	state.battle_round = 1
	state.cell_elements = {}
	var enemy := _enemy("trap_enemy", "默认敌人", 1, 1)
	var plain_player := _player("plain_player", "普通我方", 2, 2)
	var opted_player := _player("opted_player", "陷阱我方", 3, 3)
	opted_player["mechanics"] = ["mech_trap_stack_trigger"]
	state.units = [enemy, plain_player, opted_player]
	state.call("_apply_element_to_cell", 1, 1, "火", 3)
	state.call("_apply_element_to_cell", 2, 2, "水", 3)
	state.call("_apply_element_to_cell", 3, 3, "地", 3)

	state.call("_apply_trap_stack_on_enter", enemy)
	state.call("_apply_trap_stack_on_enter", plain_player)
	state.call("_apply_trap_stack_on_enter", opted_player)
	_expect(int(state.unit_by_id("trap_enemy").get("hp", -1)) == 4, "enemy keeps the default triangular trap trigger")
	_expect(int(state.unit_by_id("plain_player").get("hp", -1)) == 10, "player without capability does not trigger the trap")
	_expect(int(state.unit_by_id("opted_player").get("hp", -1)) == 10, "authority keeps terrain damage enemy-only even when player data carries a trap mechanic")
	_expect(int(state.call("_cell_elements_at", 1, 1).get("火", -1)) == 0, "enemy-triggered trap clears after execution")
	_expect(int(state.call("_cell_elements_at", 2, 2).get("水", -1)) == 3, "disallowed player leaves trap layers intact")
	_expect(int(state.call("_cell_elements_at", 3, 3).get("地", -1)) == 3, "player movement cannot consume or clear enemy-only terrain")


func _test_taunt_query_and_authority_execution() -> void:
	var state: RefCounted = StateScript.new()
	state.phase = "battle"
	state.battle_round = 1
	state.ap = 3
	state.units = [
		_player("ordinary", "普通目标", 2, 0),
		_guard("guard", "守护目标", 0, 2),
		_enemy("enemy", "测试敌人", 0, 0),
	]
	state.battle_roster_templates[StateScript.PLAYER] = [
		Dictionary(state.unit_by_id("ordinary")).duplicate(true),
		Dictionary(state.unit_by_id("guard")).duplicate(true),
	]
	state.battle_roster_templates[StateScript.ENEMY] = [Dictionary(state.unit_by_id("enemy")).duplicate(true)]
	state.call("_normalize_skill_control_orders")
	var enemy := Dictionary(state.unit_by_id("enemy"))
	var authority_guard := Dictionary(state.unit_by_id("guard"))
	var selected := Dictionary(state.call("_nearest_player", enemy))
	_expect(String(selected.get("id", "")) == "guard", "state taunt selects the in-range guard over the ordinary tied target")
	selected["hp"] = 9
	_expect(int(state.unit_by_id("guard").get("hp", -1)) == 9, "state resolves the projected guard id back to the authority-owned unit")
	selected["hp"] = 10
	enemy.erase("target_select_redirect")

	var context := Dictionary(state.call("_battle_query_context"))
	var context_before := context.duplicate(true)
	var projector: RefCounted = state.get("_core_composition").battle_query_projector
	var projected_target := Dictionary(projector.call("_nearest_player", context, enemy.duplicate(true)))
	_expect(String(projected_target.get("id", "")) == "guard", "query projection selects the same guard target")
	projected_target["hp"] = 1
	_expect(int(authority_guard.get("hp", -1)) == 10 and context == context_before, "query target remains detached and leaves authority/context unchanged")

	state.call("_enemy_turn")
	_expect(int(state.unit_by_id("ordinary").get("hp", -1)) == 10, "real enemy execution leaves the ordinary tied target untouched")
	_expect(int(state.unit_by_id("guard").get("hp", -1)) == 2, "real enemy execution applies both planned skills to the authoritative guard")


func _player(unit_id: String, display_name: String, x: int, y: int) -> Dictionary:
	return {
		"id": unit_id,
		"name": display_name,
		"side": StateScript.PLAYER,
		"x": x,
		"y": y,
		"hp": 10,
		"max_hp": 10,
		"shield": 0,
		"def": 0,
		"atk": 1,
		"ap": 3,
		"active": true,
	}


func _guard(unit_id: String, display_name: String, x: int, y: int) -> Dictionary:
	var unit := _player(unit_id, display_name, x, y)
	unit["mechanics"] = ["mech_guard_taunt"]
	unit["mechanic_params"] = {"range": 2}
	return unit


func _enemy(unit_id: String, display_name: String, x: int, y: int) -> Dictionary:
	return {
		"id": unit_id,
		"name": display_name,
		"side": StateScript.ENEMY,
		"x": x,
		"y": y,
		"hp": 10,
		"max_hp": 10,
		"shield": 0,
		"def": 0,
		"atk": 4,
		"ap": 3,
		"attack_count": 1,
		"move_range": 0,
		"shape_id": "05",
		"shape_name": "形状05",
		"slot_count": 1,
		"slot_elements": ["火"],
		"base_layers": 1,
		"action_slots_used": {},
		"active": true,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Mechanic projection production caller failed: %s" % message)
