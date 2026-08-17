extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_any_enemy_triggers_trap_on_move()
	_verify_enemy_spawn_avoids_all_traps()
	if failed:
		quit(1)
		return
	print("SMOKE_ENEMY_ELEMENT_TRAP_RULES_OK")
	quit(0)


func _verify_any_enemy_triggers_trap_on_move() -> void:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var enemy := _first_enemy(state)
	var player := _first_player(state)
	state.units = [player, enemy]
	player["x"] = 0
	player["y"] = 0
	player["hp"] = 80
	player["max_hp"] = 80
	enemy["x"] = 7
	enemy["y"] = 5
	enemy["hp"] = 80
	enemy["max_hp"] = 80
	enemy["shield"] = 0
	enemy["def"] = 0
	enemy["atk"] = 0
	enemy["mechanics"] = []
	var plan := Dictionary(state.call("_build_auto_position_plan", StateScript.ENEMY, 3, true))
	var destination := _planned_destination(plan, String(enemy.get("id", "")))
	_expect(not destination.is_empty(), "enemy planner exposes a movement destination")
	if destination.is_empty():
		return
	var x := int(destination.get("x", -1))
	var y := int(destination.get("y", -1))
	state._apply_element_to_cell(x, y, "火", 2)
	state._apply_element_to_cell(x, y, "水", 1)
	state.battle_trace = []
	state.call("_apply_enemy_auto_position_plan")
	_expect(int(enemy.get("x", -1)) == x and int(enemy.get("y", -1)) == y, "enemy moves onto the trapped destination")
	_expect(int(enemy.get("hp", 0)) == 76, "ordinary enemy takes all trap damage without a special mechanic")
	_expect(not bool(state.call("_cell_has_element_trap", x, y)), "triggered trap layers are consumed")
	_expect(_has_trap_damage_trace(state, String(enemy.get("id", ""))), "trap trigger is preserved as visible damage trace")


func _verify_enemy_spawn_avoids_all_traps() -> void:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var safe := Vector2i(state.board_width - 2, 1)
	for y in range(state.board_height):
		for x in range(state.board_width):
			if Vector2i(x, y) != safe:
				state._apply_element_to_cell(x, y, "土", 1)
	for value in state.units:
		if String(Dictionary(value).get("side", "")) == StateScript.ENEMY:
			Dictionary(value)["hp"] = 0
	var candidates: Array = state.call("_side_reset_cells", StateScript.ENEMY, 1)
	_expect(candidates == [safe], "reset expansion finds the only safe cell in the enemy 5x5 area")
	state._apply_element_to_cell(safe.x, safe.y, "土", 1)
	var blocked: Array = state.call("_side_reset_cells", StateScript.ENEMY, 1)
	_expect(blocked.is_empty(), "reset refuses to fall back onto an element trap")


func _planned_destination(plan: Dictionary, unit_id: String) -> Dictionary:
	for move_value in Array(plan.get("moves", [])):
		var move := Dictionary(move_value)
		if String(move.get("unitId", "")) == unit_id:
			return Dictionary(move.get("to", {}))
	return {}


func _has_trap_damage_trace(state: RefCounted, unit_id: String) -> bool:
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) != "DAMAGE_APPLIED":
			continue
		if String(Dictionary(event.get("target", {})).get("id", "")) != unit_id:
			continue
		if String(Dictionary(event.get("payload", {})).get("sourceType", "")) == "element_trap":
			return true
	return false


func _first_enemy(state: RefCounted) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			return unit
	return {}


func _first_player(state: RefCounted) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER:
			return unit
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_ENEMY_ELEMENT_TRAP_RULES_FAIL: %s" % message)
