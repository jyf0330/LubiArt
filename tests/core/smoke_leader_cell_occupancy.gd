extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const AutoPositionTestContextScript := preload("res://tests/helpers/auto_position_test_context.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "leader-cell fixture can start battle")
	var player := _first_side(state, StateScript.PLAYER)
	var enemy := _first_side(state, StateScript.ENEMY)
	var player_leader := Dictionary(state.call("_leader_unit", true))
	var enemy_leader := Dictionary(state.call("_leader_unit", false))
	_expect(not player.is_empty() and not enemy.is_empty(), "fixture exposes both pet sides")
	for unit_value in [player, enemy]:
		var unit := Dictionary(unit_value)
		var candidates := AutoPositionTestContextScript.candidates(state, unit, {
			"limit": 256,
			"movementBudget": 99,
			"allowDirectionChanges": true,
			"positionIndependent": true,
		})
		_expect(not _has_destination(candidates, int(player_leader.get("x", -1)), int(player_leader.get("y", -1))), "%s candidates cannot enter the configured player leader cell" % String(unit.get("side", "pet")))
		_expect(not _has_destination(candidates, int(enemy_leader.get("x", -1)), int(enemy_leader.get("y", -1))), "%s candidates cannot enter the configured enemy leader cell" % String(unit.get("side", "pet")))

	var duck: Dictionary = {}
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY and String(unit.get("name", "")) == "冲浪鸭":
			duck = unit
			break
	if duck.is_empty():
		duck = enemy
	_expect(not duck.is_empty(), "fixture exposes a real enemy auto-position mover")
	if not duck.is_empty() and not player.is_empty():
		player["x"] = state.board_width - 2
		player["y"] = 0
		player["hp"] = max(1, int(player.get("hp", 1)))
		duck["x"] = state.board_width - 1
		duck["y"] = 1
		duck["hp"] = max(1, int(duck.get("hp", 1)))
		duck["has_attacked"] = false
		duck["action_slots_used"] = {}
		state.units = [player, duck]
		state.battle_trace = []
		state.call("_apply_enemy_auto_position_plan")
		_expect(not (int(duck.get("x", -1)) == int(enemy_leader.get("x", -1)) and int(duck.get("y", -1)) == int(enemy_leader.get("y", -1))), "enemy auto-position does not cover the configured boss cell")
		var boss_cell := _board_cell(state, int(enemy_leader.get("x", -1)), int(enemy_leader.get("y", -1)))
		_expect(String(boss_cell.get("leaderId", "")) == "enemy_boss", "configured enemy leader cell still projects the boss after enemy movement")

	if failed:
		quit(1)
		return
	print("SMOKE_LEADER_CELL_OCCUPANCY_OK")
	quit(0)


func _first_side(state: RefCounted, side: String) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == side:
			return unit
	return {}


func _has_destination(candidates: Array, x: int, y: int) -> bool:
	for candidate_value in candidates:
		var destination := Dictionary(Dictionary(candidate_value).get("to", {}))
		if int(destination.get("x", -1)) == x and int(destination.get("y", -1)) == y:
			return true
	return false


func _board_cell(state: RefCounted, x: int, y: int) -> Dictionary:
	var board := Dictionary(state.snapshot().get("board", {}))
	for cell_value in Array(board.get("cells", [])):
		var cell := Dictionary(cell_value)
		if int(cell.get("x", -1)) == x and int(cell.get("y", -1)) == y:
			return cell
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_LEADER_CELL_OCCUPANCY_FAIL: %s" % message)
