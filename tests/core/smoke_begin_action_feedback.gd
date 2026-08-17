extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var empty_selection_state: RefCounted = _out_of_range_fixture()
	empty_selection_state.selected_unit_id = ""
	empty_selection_state.selected_action_slot_index = 0
	var enemy_before := _first_enemy(empty_selection_state)
	var enemy_hp_before := int(enemy_before.get("hp", -1))
	empty_selection_state.dispatch({"type": "RUN_PLAYER_ALL_OUT"})
	_expect(String(empty_selection_state.selected_unit_id) == "", "begin action must not leak the last internally tested pet into UI selection")
	_expect(int(empty_selection_state.selected_action_slot_index) == 0, "begin action must restore the previous action-slot selection")
	_expect(int(enemy_before.get("hp", -1)) == enemy_hp_before, "all-out must not auto-move or damage an out-of-range target")
	_expect(int(empty_selection_state.ap) == 0, "begin action must spend available AP on empty-cell element casts")
	_expect(_has_board_element(empty_selection_state), "begin action must lay elements even when no enemy is in the action cells")

	var preserved_selection_state: RefCounted = _out_of_range_fixture()
	var player := _first_player(preserved_selection_state)
	preserved_selection_state.selected_unit_id = String(player.get("id", ""))
	preserved_selection_state.selected_action_slot_index = 1
	preserved_selection_state.dispatch({"type": "RUN_PLAYER_ALL_OUT"})
	_expect(String(preserved_selection_state.selected_unit_id) == String(player.get("id", "")), "begin action must preserve the player's existing pet selection")
	_expect(int(preserved_selection_state.selected_action_slot_index) == 1, "begin action must preserve the player's existing slot selection")

	if failed:
		quit(1)
		return
	print("SMOKE_BEGIN_ACTION_FEEDBACK_OK")
	quit(0)


func _out_of_range_fixture() -> RefCounted:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var player := _first_player(state)
	var enemy := _first_enemy(state)
	state.units = [player, enemy]
	player["x"] = 0
	player["y"] = state.board_height - 1
	player["shape"] = "形状01"
	player["shape_id"] = "01"
	player["shape_name"] = "形状01"
	player["slot_count"] = 3
	player["has_attacked"] = false
	player["action_slots_used"] = {}
	enemy["x"] = state.board_width - 1
	enemy["y"] = 0
	state.ap = 3
	state.log_lines.clear()
	return state


func _first_player(state: RefCounted) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER:
			return unit
	return {}


func _first_enemy(state: RefCounted) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			return unit
	return {}


func _log_contains(state: RefCounted, needle: String) -> bool:
	for line in state.log_lines:
		if String(line).contains(needle):
			return true
	return false


func _has_board_element(state: RefCounted) -> bool:
	for y in range(state.board_height):
		for x in range(state.board_width):
			for value in Dictionary(state._cell_elements_at(x, y)).values():
				if int(value) > 0:
					return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
