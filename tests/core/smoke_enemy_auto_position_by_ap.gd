extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var player := _first_side(state, StateScript.PLAYER).duplicate(true)
	var enemy_fast := _first_side(state, StateScript.ENEMY).duplicate(true)
	var enemy_slow := enemy_fast.duplicate(true)
	_prepare_unit(player, "player_target", StateScript.PLAYER, 0, 7, 3)
	_prepare_unit(enemy_fast, "enemy_fast", StateScript.ENEMY, 7, 0, 3)
	_prepare_unit(enemy_slow, "enemy_slow", StateScript.ENEMY, 7, 2, 1)
	state.units = [player, enemy_fast, enemy_slow]
	state.battle_trace = []

	var plan := Dictionary(state.call("_build_auto_position_plan", StateScript.ENEMY, 4, true))
	var planned_by_id := {}
	for move_value in Array(plan.get("moves", [])):
		var move := Dictionary(move_value)
		planned_by_id[String(move.get("unitId", ""))] = move
	_expect(planned_by_id.has("enemy_fast"), "move-range-3 enemy receives a shared auto-position move")
	_expect(planned_by_id.has("enemy_slow"), "move-range-1 enemy receives a shared auto-position move")
	if planned_by_id.has("enemy_fast"):
		_expect(_move_distance(Dictionary(planned_by_id["enemy_fast"])) > 1 and _move_distance(Dictionary(planned_by_id["enemy_fast"])) <= 3, "move-range-3 enemy can move farther than the legacy one-cell step")
	if planned_by_id.has("enemy_slow"):
		_expect(_move_distance(Dictionary(planned_by_id["enemy_slow"])) <= 1, "move-range-1 enemy remains limited to one cell")

	state.call("_enemy_turn")
	for unit_id in planned_by_id.keys():
		var move := Dictionary(planned_by_id[unit_id])
		var destination := Dictionary(move.get("to", {}))
		var moved_unit: Dictionary = state.unit_by_id(String(unit_id))
		_expect(int(moved_unit.get("x", -1)) == int(destination.get("x", -2)) and int(moved_unit.get("y", -1)) == int(destination.get("y", -2)), "enemy turn applies the same auto-position plan for %s" % unit_id)

	var move_ranges := {}
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) != "MOVE_MONSTER":
			continue
		move_ranges[String(event.get("unitId", ""))] = int(event.get("moveRange", -1))
	_expect(int(move_ranges.get("enemy_fast", -1)) == 3, "fast enemy movement trace records its AP3 range")
	_expect(int(move_ranges.get("enemy_slow", -1)) == 1, "slow enemy movement trace records its AP1 range")

	if failed:
		quit(1)
		return
	print("SMOKE_ENEMY_AUTO_POSITION_BY_AP_OK fast_distance=%d slow_distance=%d" % [
		_move_distance(Dictionary(planned_by_id.get("enemy_fast", {}))),
		_move_distance(Dictionary(planned_by_id.get("enemy_slow", {})))
	])
	quit(0)


func _prepare_unit(unit: Dictionary, unit_id: String, side: String, x: int, y: int, unit_ap: int) -> void:
	unit["id"] = unit_id
	unit["name"] = unit_id
	unit["side"] = side
	unit["x"] = x
	unit["y"] = y
	unit["hp"] = 50
	unit["max_hp"] = 50
	unit["atk"] = 2
	unit["ap"] = unit_ap
	unit["attack_count"] = 1
	unit["move_range"] = unit_ap
	unit["moveRange"] = unit_ap
	unit["shape"] = "形状01"
	unit["shape_id"] = "01"
	unit["shape_name"] = "形状01"
	unit["slot_count"] = 1
	unit["slot_elements"] = ["风"]
	unit["base_layers"] = 1
	unit["action_slots_used"] = {}
	unit["has_attacked"] = false


func _move_distance(move: Dictionary) -> int:
	var from := Dictionary(move.get("from", {}))
	var to := Dictionary(move.get("to", {}))
	return abs(int(from.get("x", -1)) - int(to.get("x", -1))) + abs(int(from.get("y", -1)) - int(to.get("y", -1)))


func _first_side(state: RefCounted, side: String) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == side:
			return unit
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_ENEMY_AUTO_POSITION_BY_AP_FAIL: %s" % message)
