extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleCellScene := preload("res://art/prefabs/terrain/terrain.tscn")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = _direct_begin_fixture()
	var actor := _first_player(state)
	var enemy := _first_enemy(state)
	var enemy_hp_before := int(enemy.get("hp", -1))
	var accepted: bool = state.dispatch({"type": "RUN_PLAYER_ALL_OUT"})
	_expect(accepted, "direct begin action command is accepted")
	_expect(int(state.ap) == 0, "all-out action phase consumes the shared AP budget")
	_expect(int(enemy.get("hp", -1)) == enemy_hp_before, "out-of-shape enemy is not damaged")

	var element_cell := _first_element_cell(state)
	_expect(not element_cell.is_empty(), "direct begin action lays an element on an empty board cell")
	if not element_cell.is_empty():
		var cell := BattleCellScene.instantiate() as Control
		root.add_child(cell)
		await process_frame
		cell.call("setup_grid_position", int(element_cell.get("x", -1)), int(element_cell.get("y", -1)), Vector2(96, 96), Vector2.ZERO)
		cell.call("set_cell_data", {
			"x": int(element_cell.get("x", -1)),
			"y": int(element_cell.get("y", -1)),
			"unitId": "",
			"elements": Dictionary(element_cell.get("elements", {}))
		}, null)
		await process_frame
		var landing_tile := cell.find_child("LandingTileArt", true, false) as TextureRect
		_expect(landing_tile != null and landing_tile.visible, "Chinese core key 火 renders the formal landing tile")
		_expect(String(cell.call("get_active_element_tile_variant")) == "fire", "Chinese core key 火 maps to the fire landing-tile variant")
		cell.queue_free()

	if failed:
		quit(1)
		return
	print("SMOKE_READ2_DIRECT_BEGIN_ACTION_FEEDBACK_OK")
	quit(0)


func _direct_begin_fixture() -> RefCounted:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var actor := _first_player(state)
	var enemy := _first_enemy(state)
	state.units = [actor, enemy]
	actor["x"] = 0
	actor["y"] = state.board_height - 1
	actor["shape"] = "形状01"
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["slot_count"] = 1
	actor["element"] = "火"
	actor["element_types"] = ["火"]
	actor["secondary_elements"] = []
	actor["slot_elements"] = ["火"]
	actor["base_layers"] = 1
	actor["skill"] = "skill_vanguard"
	actor["has_attacked"] = false
	actor["action_slots_used"] = {}
	enemy["x"] = state.board_width - 1
	enemy["y"] = 0
	state.ap = 3
	state.battle_roster_templates[StateScript.PLAYER] = [actor.duplicate(true)]
	state._initialize_skill_control_orders()
	state.selected_unit_id = ""
	state.selected_action_slot_index = 0
	state.action_dirs[state._action_slot_key(actor, 0)] = "right"
	return state


func _first_element_cell(state: RefCounted) -> Dictionary:
	for y in range(state.board_height):
		for x in range(state.board_width):
			var elements: Dictionary = state._cell_elements_at(x, y)
			if int(elements.get("火", 0)) > 0 and state.unit_at(x, y).is_empty():
				return {"x": x, "y": y, "elements": elements.duplicate(true)}
	return {}


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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
