extends SceneTree

const ART_SCENE_PATH := "res://art/scenes/battle/battle_art_scene.tscn"
const BattleAssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")


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
	var board_background := art_scene.get_node_or_null("Board/BoardBG") as TextureRect
	var board_grid := art_scene.get_node_or_null("Board/BoardGrid") as Control
	var primary_actions := art_scene.get_node_or_null("Board/BattlePrimaryActions") as Control
	var primary_actions_shadow := art_scene.get_node_or_null("Board/BattlePrimaryActions/Shadow") as TextureRect
	var auto_arrange_button := art_scene.get_node_or_null("Board/BattlePrimaryActions/AutoArrangeButton") as TextureButton
	var begin_turn_button := art_scene.get_node_or_null("Board/BattlePrimaryActions/BeginTurnButton") as TextureButton
	var direction_drawer := art_scene.get_node_or_null("Board/AttackDirectionDrawer") as Control
	var direction_rows := art_scene.get_node_or_null("Board/AttackDirectionDrawer/Rows") as Control
	var direction_background := art_scene.get_node_or_null("Board/AttackDirectionDrawer/Rows/Row1/Background") as TextureRect
	var direction_arrow := art_scene.get_node_or_null("Board/AttackDirectionDrawer/Rows/Row1/Arrow1") as TextureRect
	var direction_last_arrow := art_scene.get_node_or_null("Board/AttackDirectionDrawer/Rows/Row4/Arrow3") as TextureRect
	var direction_collapse_button := art_scene.get_node_or_null("Board/AttackDirectionDrawer/CollapseButton") as TextureButton
	var direction_collapse_triangle := art_scene.get_node_or_null("Board/AttackDirectionDrawer/CollapseButton/Triangle") as TextureRect
	var direction_scroll_hint := art_scene.get_node_or_null("Board/AttackDirectionDrawer/ScrollHint") as TextureRect
	var direction_scroll_highlight := art_scene.get_node_or_null("Board/AttackDirectionDrawer/ScrollHint/WheelHighlight") as TextureRect
	var direction_scroll_animation := art_scene.get_node_or_null("Board/AttackDirectionDrawer/ScrollHint/AnimationPlayer") as AnimationPlayer
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
	var direction_scroll_hint_works := false
	var direction_wheel_sequence := false
	var direction_hover_signal_works := false
	var asset_registry := BattleAssetRegistryScript.new()
	var background_variants_match: bool = (
		asset_registry.call("battle_background_key", {"day": 1, "battle_period": "上午"}) == "grassland_morning"
		and asset_registry.call("battle_background_key", {"day": 2, "battle_period": "下午"}) == "pond_evening"
		and asset_registry.call("battle_background_key", {"day": 5, "battle_period": "上午"}) == "lowland_morning"
		and asset_registry.call("battle_background_key", {"day": 1, "battle_map_key": "mountain_evening"}) == "mountain_evening"
		and asset_registry.call("all_declared_runtime_assets_exist")
	)
	if direction_arrow != null and direction_scroll_hint != null and direction_scroll_animation != null:
		direction_arrow.mouse_entered.emit()
		await process_frame
		var highlight_alpha_before := direction_scroll_highlight.modulate.a if direction_scroll_highlight != null else -1.0
		direction_scroll_hint_works = (
			direction_scroll_hint.visible
			and direction_scroll_animation.current_animation == &"scroll_hint_blink"
		)
		await create_timer(0.32).timeout
		var highlight_alpha_after := direction_scroll_highlight.modulate.a if direction_scroll_highlight != null else -1.0
		direction_scroll_hint_works = (
			direction_scroll_hint_works
			and not is_equal_approx(highlight_alpha_before, highlight_alpha_after)
		)
		direction_arrow.mouse_exited.emit()
		await process_frame
		direction_scroll_hint_works = direction_scroll_hint_works and not direction_scroll_hint.visible
		if direction_last_arrow != null:
			direction_last_arrow.mouse_entered.emit()
			await process_frame
			direction_scroll_hint_works = direction_scroll_hint_works and direction_scroll_hint.visible
			direction_last_arrow.mouse_exited.emit()
			await process_frame
			direction_scroll_hint_works = direction_scroll_hint_works and not direction_scroll_hint.visible
	if direction_drawer != null and direction_arrow != null:
		var direction_commands: Array[Dictionary] = []
		var direction_hover_previews: Array[Dictionary] = []
		direction_drawer.command_requested.connect(func(command: Dictionary) -> void:
			direction_commands.append(command.duplicate(true))
		)
		direction_drawer.direction_preview_changed.connect(func(preview: Dictionary) -> void:
			direction_hover_previews.append(preview.duplicate(true))
		)
		direction_drawer.call("render_snapshot", {
			"phase": "battle",
			"units": [{"id": "wheel_test", "name": "滚轮测试", "side": "player", "active": true, "slot": 1}],
			"action_dirs": {"wheel_test:slot0": "up"},
		})
		var wheel_down := InputEventMouseButton.new()
		wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel_down.pressed = true
		wheel_down.factor = 1.0
		var wheel_up := InputEventMouseButton.new()
		wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel_up.pressed = true
		wheel_up.factor = 1.0
		for _step in range(4):
			direction_arrow.gui_input.emit(wheel_down)
		for _step in range(4):
			direction_arrow.gui_input.emit(wheel_up)
		var emitted_directions: Array[String] = []
		for command in direction_commands:
			emitted_directions.append(String(command.get("dir", "")))
		direction_wheel_sequence = (
			emitted_directions == ["right", "down", "left", "up", "left", "down", "right", "up"]
			and String(direction_commands[0].get("unitId", "")) == "wheel_test"
			and int(direction_commands[0].get("slotId", -1)) == 0
			and direction_arrow.texture.resource_path.get_file() == "direction_arrow_002.png"
		)
		direction_arrow.mouse_entered.emit()
		await process_frame
		direction_arrow.mouse_exited.emit()
		await process_frame
		direction_hover_signal_works = (
			direction_hover_previews.size() >= 2
			and String(direction_hover_previews[direction_hover_previews.size() - 2].get("unit_id", "")) == "wheel_test"
			and int(direction_hover_previews[direction_hover_previews.size() - 2].get("slot_index", -1)) == 0
			and String(direction_hover_previews[direction_hover_previews.size() - 2].get("direction", "")) == "up"
			and direction_hover_previews[direction_hover_previews.size() - 1].is_empty()
		)
	if direction_drawer != null and direction_collapse_button != null and direction_rows != null:
		direction_collapse_button.pressed.emit()
		await process_frame
		drawer_collapses = not direction_rows.visible and not bool(direction_drawer.call("is_expanded"))
		direction_collapse_button.pressed.emit()
		await process_frame
	var passed: bool = (
		board != null
		and board_background != null
		and board_background.size == Vector2(1920.0, 1080.0)
		and board_background.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
		and board_background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED
		and board_background.texture != null
		and board_background.texture.get_size() == Vector2(1456.0, 816.0)
		and background_variants_match
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
		and direction_scroll_hint != null
		and direction_scroll_hint.size == Vector2(48.0, 48.0)
		and direction_scroll_hint.texture != null
		and direction_scroll_highlight != null
		and direction_scroll_highlight.size == Vector2(48.0, 48.0)
		and direction_scroll_highlight.texture != null
		and direction_scroll_animation != null
		and direction_scroll_hint_works
		and direction_wheel_sequence
		and direction_hover_signal_works
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
