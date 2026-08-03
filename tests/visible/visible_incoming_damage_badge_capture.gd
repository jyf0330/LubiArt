extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")
const CAPTURE := "lubi_manual_drag_incoming_damage_badge.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main_instance := MainScene.instantiate()
	root.add_child(main_instance)
	for _frame in range(12):
		await process_frame
	await create_timer(0.5).timeout
	var battle_view := main_instance.call("get_feature_controller", &"battle") as Control
	if battle_view == null:
		_fail("battle view is unavailable")
		return
	var probe := BattleSceneProbe.new(battle_view)
	var origin_cell := _first_draggable_player_cell(battle_view)
	if origin_cell == null:
		_fail("manual drag origin was unavailable before auto arrange")
		return
	var preview_pet := origin_cell.call("get_unit_node") as Control
	var preview_unit_id := String(preview_pet.call("get_unit_id"))
	var origin_grid := origin_cell.call("get_grid_position") as Vector2i
	var target_grid := _first_empty_grid(battle_view)
	if target_grid.x < 0:
		_fail("no manual drag target was available")
		return
	probe.start_drag(origin_grid, target_grid)
	await probe.update_drag(target_grid)
	var held_preview := battle_view.get_node_or_null(
		"Board/UnitHost/BattleUnitDragPreview"
	) as Control
	if held_preview == null:
		_fail("manual drag preview was unavailable")
		return
	var held_badge := held_preview.get_node(
		"CompleteBattleCreaturePrefab/01_UnitVisual/IncomingDamagePreview"
	) as Control
	var held_value := held_badge.get_node("Value") as Label
	if not held_badge.visible or held_value.text == "":
		_fail("incoming-damage badge was not visible over the manual drag target")
		return
	probe.finish_drag(target_grid)
	await create_timer(0.25).timeout
	preview_pet = _pet_by_unit_id(battle_view, preview_unit_id)
	if preview_pet == null:
		_fail("manually placed player pet was unavailable")
		return
	var badge := preview_pet.get_node(
		"CompleteBattleCreaturePrefab/01_UnitVisual/IncomingDamagePreview"
	) as Control
	var value := badge.get_node("Value") as Label
	if not badge.visible or value.text == "":
		_fail("incoming-damage badge was not visible")
		return
	await RenderingServer.frame_post_draw
	var capture_path := OS.get_environment("TEMP").path_join(CAPTURE)
	var error := root.get_texture().get_image().save_png(capture_path)
	if error != OK:
		_fail("could not save capture (error %d)" % error)
		return
	print("VISIBLE_MANUAL_DRAG_INCOMING_DAMAGE_BADGE_PASS capture=%s value=%s" % [capture_path, value.text])
	quit(0)


func _first_draggable_player_cell(battle_view: Control) -> Control:
	var board_grid := battle_view.get_node("Board/CellHost") as Control
	for cell in board_grid.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var data := Dictionary(cell.get("cell_data"))
		var unit_id := String(data.get("unitId", data.get("unit_id", "")))
		var side := String(data.get("side", data.get("unitSide", "")))
		if unit_id != "" and side in ["player", "ally"] and unit_id != "player_hero":
			return cell as Control
	return null


func _first_empty_grid(battle_view: Control) -> Vector2i:
	var board_grid := battle_view.get_node("Board/CellHost") as Control
	for cell in board_grid.get_children():
		if not cell.has_method("get_grid_position") or not cell.has_method("get_unit_node"):
			continue
		if cell.call("get_unit_node") == null:
			return cell.call("get_grid_position") as Vector2i
	return Vector2i(-1, -1)


func _pet_by_unit_id(battle_view: Control, unit_id: String) -> Control:
	var board_grid := battle_view.get_node("Board/CellHost") as Control
	for cell in board_grid.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var pet := cell.call("get_unit_node") as Control
		if pet != null and pet.has_method("get_unit_id") \
				and String(pet.call("get_unit_id")) == unit_id:
			return pet
	return null
func _fail(message: String) -> void:
	push_error("VISIBLE_INCOMING_DAMAGE_BADGE_FAIL: %s" % message)
	quit(1)
