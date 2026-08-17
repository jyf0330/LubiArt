extends SceneTree

const GameScene := preload("res://art/scenes/app/game.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := GameScene.instantiate() as Control
	root.add_child(scene)
	await process_frame
	await process_frame
	var middle := scene
	if middle == null:
		push_error("Load battle roster smoke requires the artist middle controller.")
		quit(1)
		return
	var seed_pet := Dictionary(middle.state.roster[0]).duplicate(true)
	for fixture_id in ["load_visible_roster_002", "load_visible_roster_003", "load_visible_roster_004"]:
		var fixture_pet := seed_pet.duplicate(true)
		fixture_pet["id"] = fixture_id
		fixture_pet["pet_id"] = fixture_id
		fixture_pet["name"] = fixture_id
		middle.state.call("_add_pet_to_roster", fixture_pet, "smoke")
	middle.state.dispatch({"type": "START_BATTLE"})
	middle.call("render_current_view")
	await process_frame
	var battle_flow := scene.find_child("BattleArtScene", true, false) as Control
	if battle_flow == null:
		push_error("Load battle roster smoke requires BattleArtScene.")
		quit(1)
		return
	var probe := BattleSceneProbe.new(battle_flow)
	var board_grid := battle_flow.get_node_or_null("Board/CellHost") as Control
	if board_grid == null:
		push_error("Load battle roster smoke requires Board/CellHost.")
		quit(1)
		return
	if board_grid.get_child_count() != 56:
		push_error("Load battle roster smoke requires the default 56-cell presentation pool, got %d cells." % board_grid.get_child_count())
		quit(1)
		return
	var dimensions := Dictionary(probe.board_summary())
	if int(dimensions.get("width", 0)) != 8 or int(dimensions.get("height", 0)) != 7 or int(dimensions.get("activeCellCount", 0)) != 56:
		push_error("Load battle roster smoke requires the default 8x7 board, got %s." % dimensions)
		quit(1)
		return
	var visible_players := _visible_player_cell_count(board_grid)
	if visible_players != 4:
		push_error("All four explicit smoke-fixture pets must remain visible on the real default board; expected 4, got %d." % visible_players)
		quit(1)
		return
	print("SMOKE_LOAD_BATTLE_VISIBLE_ROSTER_OK")
	quit(0)


func _visible_player_cell_count(board_grid: Control) -> int:
	var count := 0
	for cell_value in board_grid.get_children():
		var cell := cell_value as Control
		if cell == null:
			continue
		var cell_data: Variant = cell.get("cell_data")
		if cell_data is Dictionary and String(Dictionary(cell_data).get("side", "")) == "player":
			count += 1
	return count
