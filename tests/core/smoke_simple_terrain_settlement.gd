extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = StateScript.new()
	state.phase = "battle"
	state.battle_round = 1
	state.cell_elements = {}
	state.units = [
		_unit("enemy", StateScript.ENEMY, 1, 1),
		_unit("player", StateScript.PLAYER, 2, 2),
	]
	state.call("_apply_element_to_cell", 1, 1, "火", 2)
	state.call("_apply_element_to_cell", 1, 1, "水", 1)
	state.call("_apply_element_to_cell", 4, 4, "火", 3)
	state.call("_apply_element_to_cell", 4, 4, "水", 2)
	state.call("_apply_element_to_cell", 2, 2, "地", 3)

	_expect(bool(state.call("_settle_threshold_elements")), "occupied enemy terrain settles")
	_expect(int(state.unit_by_id("enemy").get("hp", -1)) == 6, "every coexisting element damages the enemy")
	_expect(int(state.call("_cell_elements_at", 1, 1).get("火", -1)) == 0, "occupied fire terrain clears")
	_expect(int(state.call("_cell_elements_at", 1, 1).get("水", -1)) == 0, "occupied water terrain clears")
	_expect(int(state.call("_cell_elements_at", 4, 4).get("火", -1)) == 3, "empty fire terrain remains")
	_expect(int(state.call("_cell_elements_at", 4, 4).get("水", -1)) == 2, "empty water terrain remains")
	_expect(int(state.unit_by_id("player").get("hp", -1)) == 10, "player on terrain takes no settlement damage")
	state.call("_apply_trap_stack_on_enter", state.unit_by_id("player"))
	_expect(int(state.unit_by_id("player").get("hp", -1)) == 10, "player cannot trigger terrain damage on entry")
	_expect(int(state.call("_cell_elements_at", 2, 2).get("地", -1)) == 3, "player cannot consume terrain")

	if failed:
		quit(1)
		return
	print("SMOKE_SIMPLE_TERRAIN_SETTLEMENT_OK")
	quit(0)


func _unit(unit_id: String, side: String, x: int, y: int) -> Dictionary:
	return {
		"id": unit_id,
		"name": unit_id,
		"side": side,
		"x": x,
		"y": y,
		"hp": 10,
		"max_hp": 10,
		"shield": 0,
		"def": 0,
		"atk": 1,
		"active": true,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Simple terrain settlement failed: %s" % message)
