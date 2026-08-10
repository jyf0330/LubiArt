extends SceneTree

const ART_SCENE_PATH := "res://art/scenes/battle/battle_art_scene.tscn"
const BattleAssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(ART_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("MOCK_BATTLE_ART_SCENE_FAIL: scene did not load")
		quit(1)
		return
	var art_scene_source := FileAccess.get_file_as_string(ART_SCENE_PATH)
	var art_scene := packed.instantiate() as Control
	root.add_child(art_scene)
	await process_frame
	await process_frame
	var battle_snapshot := Dictionary(MockSession.new({"start_phase": "battle"}).call("current_snapshot"))
	var occupied_cell_count := 0
	for cell_value in Array(Dictionary(battle_snapshot.get("board", {})).get("cells", [])):
		var cell_data := Dictionary(cell_value)
		if String(cell_data.get("unitId", cell_data.get("unit_id", ""))) != "":
			occupied_cell_count += 1
	art_scene.call("render_snapshot", battle_snapshot)
	await process_frame
	await process_frame
	var board := art_scene.get_node_or_null("Board") as Control
	var board_background := art_scene.get_node_or_null("Board/Background") as TextureRect
	var board_grid := art_scene.get_node_or_null("Board/CellHost") as Control
	var unit_host := art_scene.get_node_or_null("Board/UnitHost") as Control
	var vfx_host := art_scene.get_node_or_null("Board/VfxHost") as Control
	var map_controls := art_scene.get_node_or_null("MapControls") as Control
	var map_debug_button := art_scene.get_node_or_null(
		"Hud/BattleActionPanel/Margin/Content/MapDebugButton"
	) as Button
	var map_auto_button := art_scene.get_node_or_null("MapControls/AutoArrangeButton") as TextureButton
	var map_reset_button := art_scene.get_node_or_null("MapControls/ResetButton") as TextureButton
	var map_speed_button := art_scene.get_node_or_null("MapControls/SpeedButton") as TextureButton
	var map_settings_button := art_scene.get_node_or_null("MapControls/SettingsButton") as TextureButton
	var map_attack_order_button := art_scene.get_node_or_null("MapControls/AttackOrderButton") as TextureButton
	var map_bag_button := art_scene.get_node_or_null("MapControls/BagButton") as TextureButton
	var shortcut_hints := art_scene.get_node_or_null("MapControls/ShortcutHints") as TextureRect
	var map_all_out_button := art_scene.get_node_or_null("MapControls/AllOutButton") as TextureButton
	var hud := art_scene.get_node_or_null("Hud") as Control
	var attack_timeline_layer := art_scene.get_node_or_null("Hud/AttackTimelineLayer") as CanvasLayer
	var attack_timeline := art_scene.get_node_or_null("Hud/AttackTimelineLayer/AttackTimeline") as Control
	var primary_actions := art_scene.get_node_or_null("Hud/BattlePrimaryActions") as Control
	var primary_actions_shadow := art_scene.get_node_or_null("Hud/BattlePrimaryActions/Shadow") as TextureRect
	var auto_arrange_button := art_scene.get_node_or_null("Hud/BattlePrimaryActions/AutoArrangeButton") as TextureButton
	var begin_turn_button := art_scene.get_node_or_null("Hud/BattlePrimaryActions/BeginTurnButton") as TextureButton
	var action_panel := art_scene.get_node_or_null("Hud/BattleActionPanel") as Control
	var position_difficulty_button := art_scene.get_node_or_null(
		"Hud/BattleActionPanel/Margin/Content/PositionDifficultyButton"
	) as Button
	var debug_drawer_toggle_button := art_scene.get_node_or_null(
		"Hud/DebugDrawerToggleButton"
	) as Button
	var cell_detail := art_scene.get_node_or_null("OverlayHost") as Control
	var settings_menu := art_scene.get_node_or_null("OverlayHost/SettingsMenu") as Control
	var bottom_left_cell := board_grid.get_child(48) as Control if board_grid != null else null
	var bottom_right_cell := board_grid.get_child(55) as Control if board_grid != null else null
	var bottom_left_center := bottom_left_cell.position + bottom_left_cell.size * 0.5 if bottom_left_cell != null else Vector2.ZERO
	var bottom_right_center := bottom_right_cell.position + bottom_right_cell.size * 0.5 if bottom_right_cell != null else Vector2.ZERO
	var attack_timeline_button_works := false
	var debug_drawer_works := false
	var asset_registry := BattleAssetRegistryScript.new()
	var background_variants_match: bool = (
		asset_registry.call("battle_background_key", {"day": 1, "battle_period": "上午"}) == "grassland_morning"
		and asset_registry.call("battle_background_key", {"day": 2, "battle_period": "下午"}) == "pond_evening"
		and asset_registry.call("battle_background_key", {"day": 5, "battle_period": "上午"}) == "lowland_morning"
		and asset_registry.call("battle_background_key", {"day": 1, "battle_map_key": "mountain_evening"}) == "mountain_evening"
		and asset_registry.call("all_declared_runtime_assets_exist")
	)
	var debug_map_cycle_works := false
	if map_debug_button != null and board_background != null:
		var debug_map_paths: Array[String] = []
		for _debug_step in range(8):
			map_debug_button.pressed.emit()
			await process_frame
			debug_map_paths.append(board_background.texture.resource_path)
		debug_map_cycle_works = (
			debug_map_paths.size() == 8
			and debug_map_paths.all(func(path: String) -> bool:
				return path.begins_with("res://art/images/battle/map_controls/maps/")
				)
			and debug_map_paths.duplicate().reduce(func(unique: Array, path: String) -> Array:
				if path not in unique:
					unique.append(path)
				return unique
				, []).size() == 8
		)
	if hud != null and action_panel != null and debug_drawer_toggle_button != null:
		var expanded_panel_position := action_panel.position
		var expanded_toggle_position := debug_drawer_toggle_button.position
		debug_drawer_toggle_button.pressed.emit()
		await create_timer(0.25).timeout
		var collapsed_works := (
			bool(hud.call("debug_is_action_panel_collapsed"))
			and action_panel.position == Vector2(-462.0, 150.0)
			and debug_drawer_toggle_button.position == Vector2(0.0, 174.0)
			and debug_drawer_toggle_button.text == "›"
		)
		debug_drawer_toggle_button.pressed.emit()
		await create_timer(0.25).timeout
		debug_drawer_works = (
			collapsed_works
			and not bool(hud.call("debug_is_action_panel_collapsed"))
			and action_panel.position == expanded_panel_position
			and debug_drawer_toggle_button.position == expanded_toggle_position
			and debug_drawer_toggle_button.text == "‹"
		)
	if hud != null and attack_timeline != null and map_controls != null and map_attack_order_button != null:
		var starts_closed := not attack_timeline.visible and not bool(hud.call("debug_is_attack_timeline_open"))
		var duplicate_button_removed := art_scene.get_node_or_null(
			"Hud/AttackTimelineLayer/AttackTimelineToggleButton"
		) == null
		map_attack_order_button.pressed.emit()
		await process_frame
		var opens_on_button := attack_timeline.visible and bool(hud.call("debug_is_attack_timeline_open"))
		map_attack_order_button.pressed.emit()
		await process_frame
		var closes_on_button := not attack_timeline.visible
		var tab_press := InputEventKey.new()
		tab_press.keycode = KEY_TAB
		tab_press.pressed = true
		map_controls.call("_unhandled_key_input", tab_press)
		var tab_echo := InputEventKey.new()
		tab_echo.keycode = KEY_TAB
		tab_echo.pressed = true
		tab_echo.echo = true
		map_controls.call("_unhandled_key_input", tab_echo)
		var echo_keeps_closed := not attack_timeline.visible
		var tab_release := InputEventKey.new()
		tab_release.keycode = KEY_TAB
		tab_release.pressed = false
		map_controls.call("_unhandled_key_input", tab_release)
		var opens_on_tab := attack_timeline.visible and bool(hud.call("debug_is_attack_timeline_open"))
		map_attack_order_button.pressed.emit()
		attack_timeline_button_works = (
			starts_closed
			and duplicate_button_removed
			and opens_on_button
			and closes_on_button
			and echo_keeps_closed
			and opens_on_tab
			and not attack_timeline.visible
		)
	var passed: bool = (
		art_scene_source.count("[node ") == 10
		and occupied_cell_count > 0
		and board != null
		and board_background != null
		and board_background.size == Vector2(1920.0, 1080.0)
		and board_background.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
		and board_background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED
		and board_background.texture != null
		and board_background.texture.get_size() == Vector2(1920.0, 1080.0)
		and board_background.texture.resource_path.begins_with("res://art/images/battle/map_controls/maps/")
		and background_variants_match
		and debug_map_cycle_works
		and board_grid != null
		and board_grid.get_child_count() == 56
		and unit_host != null
		and unit_host.get_child_count() == occupied_cell_count
		and unit_host.get_child_count() < board_grid.get_child_count()
		and vfx_host != null
		and hud != null
		and attack_timeline_layer != null
		and attack_timeline_layer.layer == 100
		and attack_timeline != null
		and attack_timeline.size == Vector2(1640.0, 780.0)
		and int(attack_timeline.call("debug_marker_count")) == 8
		and art_scene.get_node_or_null("Hud/AttackTimelineLayer/AttackTimelineToggleButton") == null
		and attack_timeline_button_works
		and art_scene.get_child_count() == 4
		and board.get_child_count() == 4
		and bottom_left_cell != null
		and bottom_left_cell.visible
		and bottom_left_cell.call("get_grid_position") == Vector2i(0, 6)
		and bottom_left_cell.call("contains_board_point", bottom_left_center)
		and bottom_left_cell.get_node_or_null("PrefabAnchor") == null
		and is_equal_approx(bottom_left_cell.position.y + bottom_left_cell.size.y, 959.0)
		and bottom_right_cell != null
		and bottom_right_cell.visible
		and bottom_right_cell.call("get_grid_position") == Vector2i(7, 6)
		and bottom_right_cell.call("contains_board_point", bottom_right_center)
		and art_scene.get_node_or_null("Hud/TopInfoBar") == null
		and cell_detail != null
		and settings_menu != null
		and art_scene.get_node_or_null("Board/VfxHost") != null
		and art_scene.get_node_or_null("Hud/BattleActionPanel") != null
		and position_difficulty_button != null
		and debug_drawer_toggle_button != null
		and debug_drawer_works
		and map_controls != null
		and map_controls.position == Vector2.ZERO
		and map_controls.size == Vector2(1920.0, 1080.0)
		and map_controls.get_node_or_null("MapBackground") == null
		and map_debug_button != null
		and map_debug_button.get_parent() == action_panel.get_node("Margin/Content")
		and map_debug_button.custom_minimum_size.y == 42.0
		and map_auto_button != null
		and Rect2(map_auto_button.position, map_auto_button.size) == Rect2(1772.0, 915.0, 66.0, 62.0)
		and map_reset_button != null
		and Rect2(map_reset_button.position, map_reset_button.size) == Rect2(1841.0, 915.0, 66.0, 62.0)
		and map_speed_button != null
		and Rect2(map_speed_button.position, map_speed_button.size) == Rect2(90.0, 985.0, 65.0, 62.0)
		and map_settings_button != null
		and Rect2(map_settings_button.position, map_settings_button.size) == Rect2(20.0, 985.0, 65.0, 62.0)
		and map_attack_order_button != null
		and Rect2(map_attack_order_button.position, map_attack_order_button.size) == Rect2(1704.0, 915.0, 65.0, 62.0)
		and map_bag_button != null
		and Rect2(map_bag_button.position, map_bag_button.size) == Rect2(1635.0, 915.0, 66.0, 62.0)
		and map_bag_button.disabled
		and map_bag_button.tooltip_text == "回撤：当前没有可回撤的上一回合。（快捷键 B）"
		and map_all_out_button != null
		and Rect2(map_all_out_button.position, map_all_out_button.size) == Rect2(1635.0, 983.0, 272.0, 64.0)
		and shortcut_hints != null
		and Rect2(shortcut_hints.position, shortcut_hints.size) == Rect2(0.0, 948.0, 1920.0, 99.0)
		and art_scene.get_node_or_null("ShortcutHintDebugButton") == null
		and primary_actions != null
		and not primary_actions.visible
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
		and art_scene.get_node_or_null("Hud/AttackDirectionDrawer") == null
		and art_scene.get_node_or_null("Board/AutoArrangeButton") == null
		and art_scene.get_node_or_null("Board/BeginTurnButton") == null
		and art_scene.get_node_or_null("Runtime") == null
		and art_scene.get_node_or_null("PrefabCatalog") == null
	)
	if not passed:
		print({
			"scene_nodes": art_scene_source.count("[node "),
			"occupied_cells": occupied_cell_count,
			"board_children": board.get_child_count() if board != null else -1,
			"grid_children": board_grid.get_child_count() if board_grid != null else -1,
			"unit_children": unit_host.get_child_count() if unit_host != null else -1,
			"timeline_markers": int(attack_timeline.call("debug_marker_count")) if attack_timeline != null else -1,
			"timeline_button_works": attack_timeline_button_works,
			"scene_children": art_scene.get_child_count(),
			"background_variants": background_variants_match,
			"debug_map_cycle": debug_map_cycle_works,
			"debug_drawer": debug_drawer_works,
			"action_panel_position": action_panel.position if action_panel != null else Vector2.ZERO,
			"action_panel_size": action_panel.size if action_panel != null else Vector2.ZERO,
			"drawer_toggle_position": debug_drawer_toggle_button.position if debug_drawer_toggle_button != null else Vector2.ZERO,
			"map_debug_parent": str(map_debug_button.get_parent().get_path()) if map_debug_button != null else "",
			"map_debug_minimum": map_debug_button.custom_minimum_size if map_debug_button != null else Vector2.ZERO,
			"difficulty_button": position_difficulty_button != null,
			"shortcut_hint_debug_removed": art_scene.get_node_or_null("ShortcutHintDebugButton") == null,
			"top_info_removed": art_scene.get_node_or_null("Hud/TopInfoBar") == null,
			"direction_drawer_removed": art_scene.get_node_or_null("Hud/AttackDirectionDrawer") == null,
		})
		push_error("MOCK_BATTLE_ART_SCENE_FAIL: minimal battle hierarchy mismatch")
	art_scene.queue_free()
	await process_frame
	print("MOCK_BATTLE_ART_SCENE_%s" % ("PASS" if passed else "FAIL"))
	quit(0 if passed else 1)
