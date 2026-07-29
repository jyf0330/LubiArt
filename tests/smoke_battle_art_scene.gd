extends SceneTree

const ART_SCENE_PATH := "res://art/scenes/battle/battle_art_scene.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(ART_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("MOCK_BATTLE_ART_SCENE_FAIL: scene did not load")
		quit(1)
		return
	var art_scene := packed.instantiate() as Control
	root.add_child(art_scene)
	await process_frame
	await process_frame
	var board := art_scene.get_node_or_null("Board") as Control
	var board_grid := art_scene.get_node_or_null("Board/BoardGrid") as Control
	var primary_actions := art_scene.get_node_or_null("Board/BattlePrimaryActions") as Control
	var primary_actions_shadow := art_scene.get_node_or_null("Board/BattlePrimaryActions/Shadow") as TextureRect
	var auto_arrange_button := art_scene.get_node_or_null("Board/BattlePrimaryActions/AutoArrangeButton") as TextureButton
	var begin_turn_button := art_scene.get_node_or_null("Board/BattlePrimaryActions/BeginTurnButton") as TextureButton
	var direction_drawer := art_scene.get_node_or_null("Board/AttackDirectionDrawer") as Control
	var direction_rows := art_scene.get_node_or_null("Board/AttackDirectionDrawer/Rows") as Control
	var direction_background := art_scene.get_node_or_null("Board/AttackDirectionDrawer/Rows/Row1/Background") as TextureRect
	var direction_arrow := art_scene.get_node_or_null("Board/AttackDirectionDrawer/Rows/Row1/Arrow1") as TextureRect
	var direction_collapse_button := art_scene.get_node_or_null("Board/AttackDirectionDrawer/CollapseButton") as TextureButton
	var direction_collapse_triangle := art_scene.get_node_or_null("Board/AttackDirectionDrawer/CollapseButton/Triangle") as TextureRect
	var top_info_bar := art_scene.get_node_or_null("TopInfoBar") as Control
	var battle_clock := art_scene.get_node_or_null("TopInfoBar/BattleClock") as Control
	var clock_dial := art_scene.get_node_or_null("TopInfoBar/BattleClock/Dial") as TextureRect
	var clock_pointer := art_scene.get_node_or_null("TopInfoBar/BattleClock/Pointer") as TextureRect
	var cell_detail := art_scene.get_node_or_null("CellDetail") as Control
	var bottom_left_cell := board_grid.get_child(48) as Control if board_grid != null else null
	var bottom_right_cell := board_grid.get_child(55) as Control if board_grid != null else null
	var pooled_eighth_row_cell := board_grid.get_child(56) as Control if board_grid != null else null
	var bottom_left_center := bottom_left_cell.position + bottom_left_cell.size * 0.5 if bottom_left_cell != null else Vector2.ZERO
	var bottom_right_center := bottom_right_cell.position + bottom_right_cell.size * 0.5 if bottom_right_cell != null else Vector2.ZERO
	var drawer_collapses := false
	if direction_drawer != null and direction_collapse_button != null and direction_rows != null:
		direction_collapse_button.pressed.emit()
		await process_frame
		drawer_collapses = not direction_rows.visible and not bool(direction_drawer.call("is_expanded"))
		direction_collapse_button.pressed.emit()
		await process_frame
	var passed: bool = (
		board != null
		and board_grid != null
		and board_grid.get_child_count() == 64
		and bottom_left_cell != null
		and bottom_left_cell.visible
		and bottom_left_cell.call("get_grid_position") == Vector2i(0, 6)
		and bottom_left_cell.call("contains_board_point", bottom_left_center)
		and is_equal_approx(bottom_left_cell.position.y + bottom_left_cell.size.y, 959.0)
		and bottom_right_cell != null
		and bottom_right_cell.visible
		and bottom_right_cell.call("get_grid_position") == Vector2i(7, 6)
		and bottom_right_cell.call("contains_board_point", bottom_right_center)
		and pooled_eighth_row_cell != null
		and not pooled_eighth_row_cell.visible
		and top_info_bar != null
		and battle_clock != null
		and clock_dial != null
		and clock_pointer != null
		and is_equal_approx(clock_dial.size.x * 1304.0 / 1448.0, 220.0)
		and clock_dial.position == clock_pointer.position
		and clock_dial.size == clock_pointer.size
		and cell_detail != null
		and art_scene.get_node_or_null("Board/BattleVfxPlayer") != null
		and art_scene.get_node_or_null("Board/BattleActionPanel") != null
		and primary_actions != null
		and primary_actions.anchor_left == 1.0
		and primary_actions.anchor_top == 1.0
		and primary_actions.size == Vector2(365.0, 415.0)
		and primary_actions_shadow != null
		and primary_actions_shadow.size == Vector2(365.0, 415.0)
		and primary_actions_shadow.texture != null
		and auto_arrange_button != null
		and auto_arrange_button.position == Vector2(25.0, 21.0)
		and auto_arrange_button.size == Vector2(149.0, 133.0)
		and auto_arrange_button.texture_normal != null
		and auto_arrange_button.texture_pressed != null
		and begin_turn_button != null
		and begin_turn_button.position == Vector2(25.0, 21.0)
		and begin_turn_button.size == Vector2(321.0, 379.0)
		and begin_turn_button.texture_normal != null
		and begin_turn_button.texture_pressed != null
		and direction_drawer != null
		and direction_drawer.anchor_left == 1.0
		and direction_drawer.position == Vector2(1538.0, 56.0)
		and direction_drawer.size == Vector2(300.0, 421.0)
		and direction_rows != null
		and direction_rows.visible
		and direction_background != null
		and direction_background.size == Vector2(300.0, 110.0)
		and direction_background.texture != null
		and direction_background.texture.get_size() == Vector2(600.0, 220.0)
		and direction_arrow != null
		and direction_arrow.size == Vector2(64.0, 64.0)
		and direction_arrow.texture != null
		and direction_arrow.texture.get_size() == Vector2(64.0, 64.0)
		and direction_collapse_button != null
		and direction_collapse_button.size == Vector2(110.0, 47.0)
		and direction_collapse_triangle != null
		and direction_collapse_triangle.size == Vector2(40.0, 40.0)
		and drawer_collapses
		and art_scene.get_node_or_null("Board/AutoArrangeButton") == null
		and art_scene.get_node_or_null("Board/BeginTurnButton") == null
		and art_scene.get_node_or_null("Runtime") == null
		and art_scene.get_node_or_null("PrefabCatalog") == null
	)
	if not passed:
		push_error("MOCK_BATTLE_ART_SCENE_FAIL: two-scene/four-prefab hierarchy mismatch")
	art_scene.queue_free()
	await process_frame
	print("MOCK_BATTLE_ART_SCENE_%s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
