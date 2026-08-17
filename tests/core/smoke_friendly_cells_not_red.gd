extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = _fixture()
	var ally: Dictionary = state.unit_by_id("preview_ally")
	var ally_hp_before := int(ally.get("hp", -1))
	var snap: Dictionary = state.snapshot()
	var ally_cell := _snapshot_cell(snap, Vector2i(4, 3))
	var enemy_cell := _snapshot_cell(snap, Vector2i(4, 4))
	var ally_preview := Dictionary(ally_cell.get("action_preview_data", {}))
	_expect(String(ally_preview.get("preview_type", "")) == "ally", "core identifies covered same-side unit as ally")
	_expect(bool(ally_preview.get("hitAlly", false)), "core keeps ally coverage metadata")
	_expect(not bool(ally_preview.get("friendlyFire", true)), "zero-damage ally coverage is not declared as friendly fire")
	_expect(int(ally_preview.get("predictedDamage", -1)) == 0, "ally preview predicts zero damage")

	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	var battle_probe := load("res://tests/helpers/battle_scene_probe.gd").new(battle_flow) as RefCounted
	battle_flow.call("render_snapshot", snap)
	await process_frame
	_expect(_highlight_mode(battle_flow, Vector2i(4, 3)) != "attack", "ally occupied cell is not red")
	var drag_started := Dictionary(battle_probe.call("start_drag", Vector2i(3, 4), Vector2i(3, 4)))
	_expect(bool(drag_started.get("started", false)), "test probe starts the real board drag path")
	await battle_probe.call("update_drag", Vector2i(3, 4), snap)
	_expect(_highlight_mode(battle_flow, Vector2i(4, 3)) != "attack", "drag preview also keeps ally occupied cell non-red")
	_expect(_highlight_mode(battle_flow, Vector2i(4, 4)) == "attack", "real drag preview marks the enemy occupied cell red")
	battle_probe.call("cancel_drag")

	_expect(state.use_selected_action_slot(1), "covered action executes")
	_expect(int(ally.get("hp", -1)) == ally_hp_before, "executed action does not damage the ally")
	_expect(int(state.unit_by_id("preview_enemy").get("hp", 99)) < 30, "executed action still damages the enemy")

	battle_flow.queue_free()
	await process_frame
	if failed:
		quit(1)
		return
	print("SMOKE_FRIENDLY_CELLS_NOT_RED_OK")
	quit(0)


func _fixture() -> RefCounted:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var actor_source := {}
	var enemy := {}
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and actor_source.is_empty():
			actor_source = unit
		elif String(unit.get("side", "")) == StateScript.ENEMY and enemy.is_empty():
			enemy = unit
	var actor := Dictionary(actor_source)
	var ally := actor.duplicate(true)
	actor["id"] = "preview_actor"
	actor["x"] = 3
	actor["y"] = 4
	actor["atk"] = 3
	actor["attack"] = 3
	actor["shape"] = "形状13"
	actor["shape_id"] = "13"
	actor["shape_name"] = "形状13"
	actor["slot_count"] = 1
	actor["slot_elements"] = ["火"]
	actor["base_layers"] = 1
	actor["action_slots_used"] = {}
	ally["id"] = "preview_ally"
	ally["x"] = 4
	ally["y"] = 3
	ally["hp"] = 20
	ally["max_hp"] = 20
	ally["elements"] = {}
	enemy["id"] = "preview_enemy"
	enemy["x"] = 4
	enemy["y"] = 4
	enemy["hp"] = 30
	enemy["max_hp"] = 30
	enemy["shield"] = 0
	enemy["def"] = 0
	state.units = [actor, ally, enemy]
	state.ap = 3
	state.selected_unit_id = "preview_actor"
	state.selected_action_slot_index = 0
	state.action_dirs[state._action_slot_key(actor, 0)] = "right"
	return state


func _snapshot_cell(snap: Dictionary, grid: Vector2i) -> Dictionary:
	for cell_value in Array(Dictionary(snap.get("board", {})).get("cells", [])):
		var cell := Dictionary(cell_value)
		if int(cell.get("x", -1)) == grid.x and int(cell.get("y", -1)) == grid.y:
			return cell
	return {}


func _highlight_mode(battle_flow: Control, grid: Vector2i) -> String:
	var cell_host := battle_flow.find_child("CellHost", true, false) as Control
	if cell_host == null:
		return "missing_board"
	for cell in cell_host.get_children():
		if cell.has_method("get_grid_position") and Vector2i(cell.call("get_grid_position")) == grid:
			return String(cell.get("_highlight_mode"))
	return "missing_cell"


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_FRIENDLY_CELLS_NOT_RED_FAIL: %s" % message)
