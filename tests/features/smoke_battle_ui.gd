extends SceneTree

const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	if packed == null:
		push_error("Could not load ysbzs_singleplayer scene.")
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await _settle_seconds(0.8)

	var middle := scene
	if middle == null:
		push_error("Artist UI middle controller is missing.")
		quit(1)
		return
	middle.state.reset()
	middle.state.node_index = 3
	middle.state.route_options = middle.state._build_route_options()
	middle.call("render_current_view")
	await _settle_seconds(0.8)

	var battle_button := _find_route_button(scene, "battle")
	if battle_button != null:
		battle_button.emit_signal("pressed")
	else:
		push_error("Route choices must expose a battle option; START_BATTLE fallback is not valid for UI smoke.")
		quit(1)
		return

	if not await _wait_for_phase(middle, "battle", 2.0):
		push_error("Battle route did not enter battle phase.")
		quit(1)
		return
	var battle_flow := await _wait_for_battle_flow(scene, 2.0)
	if battle_flow == null:
		push_error("BattleArtScene scene is missing or hidden.")
		quit(1)
		return
	await _settle_seconds(0.2)
	var battle_probe := BattleSceneProbe.new(battle_flow)
	if not battle_probe.is_ready():
		push_error("BattleArtScene presentation responsibility roots are incomplete.")
		quit(1)
		return

	var run_tools := scene.find_child("RunTools", true, false) as Control
	if run_tools != null and run_tools.visible:
		push_error("Player battle must hide developer-only RunTools.")
		quit(1)
		return
	var toolbar_board_grid := battle_flow.get_node_or_null("Board/CellHost") as Control
	if toolbar_board_grid == null:
		push_error("Battle board should remain available when developer tools are hidden.")
		quit(1)
		return
	var command_tools := battle_flow.find_child("BattleCommandTools", true, false) as Control
	if command_tools != null and command_tools.visible:
		push_error("BattleCommandTools should not cover the imported battle UI by default.")
		quit(1)
		return
	var action_panel := battle_flow.find_child("BattleActionPanel", true, false) as Control
	if action_panel == null or not action_panel.visible:
		push_error("Battle should expose a formal action panel outside the artist board.")
		quit(1)
		return
	for button_name in ["AllOutButton", "EndTurnButton", "MonsterTurnButton"]:
		if action_panel.find_child(button_name, true, false) == null:
			push_error("Battle action panel is missing %s." % button_name)
			quit(1)
			return
	var skill_queue_grid := action_panel.find_child("SkillQueueGrid", true, false) as GridContainer
	if skill_queue_grid == null or skill_queue_grid.get_child_count() != 8:
		push_error("Battle action panel should expose eight authored skill slots.")
		quit(1)
		return
	if not battle_probe.primary_buttons_enabled():
		push_error("Battle entry should leave the artist auto-arrange and begin-turn buttons enabled.")
		quit(1)
		return
	var entry_capture_saved := await _save_capture("res://output/battle_ui_entry.png")
	if not entry_capture_saved:
		print("SMOKE_BATTLE_UI_ENTRY_CAPTURE_SKIPPED headless viewport texture unavailable")

	var board_grid := battle_flow.get_node_or_null("Board/CellHost") as Control
	if board_grid == null:
		push_error("BattleArtScene Board/CellHost is missing.")
		quit(1)
		return
	if board_grid.get_child_count() != 56:
		push_error("BattleArtScene should build the default 56-cell presentation pool, got %d." % board_grid.get_child_count())
		quit(1)
		return
	var board_dimensions := Dictionary(battle_probe.board_summary())
	if int(board_dimensions.get("width", 0)) != 8 or int(board_dimensions.get("height", 0)) != 7 or int(board_dimensions.get("activeCellCount", 0)) != 56:
		push_error("BattleArtScene default board should be 8x7 with 56 active cells, got %s." % board_dimensions)
		quit(1)
		return
	var first_cell := board_grid.get_child(0)
	if first_cell == null or not first_cell.has_method("set_cell_data"):
		push_error("BattleArtScene board cells should be battle_cell prefab instances.")
		quit(1)
		return
	if not battle_probe.required_asset_manifest_available():
		push_error("BattleArtScene should load the imported battle asset manifest.")
		quit(1)
		return
	var unit_prefab := _find_first_battle_unit(battle_flow.get_node_or_null("Board/UnitHost"))
	if unit_prefab == null or not unit_prefab.has_method("set_unit_data"):
		push_error("BattleArtScene should render units through battle_unit prefab instances.")
		quit(1)
		return
	if unit_prefab.get_node_or_null("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/Value_Text") == null:
		push_error("BattleUnit prefab should own its authored health data surface.")
		quit(1)
		return
	if not unit_prefab.has_method("update_hp") or not unit_prefab.has_method("play_shake") or not unit_prefab.has_method("set_dead_mark"):
		push_error("BattleUnit prefab should expose reusable VFX/data APIs.")
		quit(1)
		return
	if not unit_prefab.has_method("play_cross_cell_projectile") or not unit_prefab.has_method("start_damage_preview") or not unit_prefab.has_method("play_bite_impact"):
		push_error("BattleUnit prefab should own the authored projectile, damage-preview, and bite feedback APIs.")
		quit(1)
		return
	if not first_cell.has_method("set_highlight") or not first_cell.has_method("show_attack_order_marker") or not first_cell.has_method("get_unit_node"):
		push_error("BattleCell prefab should expose reusable highlight/marker/unit APIs.")
		quit(1)
		return
	first_cell.call("set_hovered", true)
	var hover_highlight := first_cell.find_child("HoverHighlight", true, false) as Polygon2D
	if hover_highlight == null or not bool(first_cell.call("is_hover_highlight_visible")):
		push_error("BattleCell hover state should use the authored perspective overlay.")
		quit(1)
		return
	if hover_highlight.polygon.size() < 4:
		push_error("BattleCell hover overlay should follow the authored cell polygon.")
		quit(1)
		return
	first_cell.call("set_hovered", false)
	first_cell.call("clear_highlight")
	if not _assert_artist_cell_style(first_cell):
		quit(1)
		return
	var prefab_reuse := Dictionary(battle_probe.spawn_prefab_samples())
	if not bool(prefab_reuse.get("banner_ok", false)) or not bool(prefab_reuse.get("trap_ok", false)):
		push_error("Scene-owned round and terrain feedback should instantiate through the shared VFX player.")
		quit(1)
		return
	await _settle_seconds(0.2)
	var vfx_player := battle_flow.get_node_or_null("Board/VfxHost") as Control
	if vfx_player == null or vfx_player.get_child_count() <= 0:
		push_error("Board/VfxHost should own spawned reusable VFX prefab instances.")
		quit(1)
		return
	var detail_open := Dictionary(battle_probe.open_first_pet_detail())
	if not bool(detail_open.get("opened", false)):
		push_error("Battle pet detail smoke could not find a visible pet cell.")
		quit(1)
		return
	await _settle_seconds(0.4)
	var detail_summary := Dictionary(battle_probe.detail_summary())
	if not bool(detail_summary.get("visible", false)):
		push_error("Clicking a battle pet should show the detail panel, got %s." % JSON.stringify(detail_summary))
		quit(1)
		return
	if not bool(detail_summary.get("usesBattlePrefab", false)):
		push_error("Battle CellDetail should use the authored battle-only detail prefab: %s." % JSON.stringify(detail_summary))
		quit(1)
		return
	var opened_unit_id := String(detail_open.get("unitId", ""))
	if opened_unit_id == "":
		push_error("Battle pet detail probe should report the clicked unit id, got %s." % JSON.stringify(detail_open))
		quit(1)
		return
	var selected_after_click := String(middle.state.snapshot().get(
		"selected_unit_id",
		middle.state.snapshot().get("selectedUnitId", "")
	))
	if selected_after_click != opened_unit_id:
		push_error("Clicking a player pet should select it through the core before opening detail, got selected=%s opened=%s." % [selected_after_click, JSON.stringify(detail_open)])
		quit(1)
		return
	await _settle_seconds(0.2)
	var selected_snapshot: Dictionary = Dictionary(middle.state.snapshot())
	var skill_control_bar := Array(selected_snapshot.get("skillControlBar", []))
	var living_player_count := 0
	for unit_value in Array(selected_snapshot.get("units", [])):
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == "player" and int(unit.get("hp", 0)) > 0:
			living_player_count += 1
	var expected_skill_count := mini(4, living_player_count) * 2
	if skill_control_bar.size() != expected_skill_count:
		push_error("Each living battle pet should contribute one A/B pair to the shared control bar, expected %d and got %d." % [expected_skill_count, skill_control_bar.size()])
		quit(1)
		return
	for index in range(skill_control_bar.size()):
		var skill_button := skill_queue_grid.get_child(index) as Button
		var entry := Dictionary(skill_control_bar[index])
		var expected_parts := [String(entry.get("unitName", "")), String(entry.get("skillSlot", "")).to_upper(), String(entry.get("label", ""))]
		if skill_button == null or not expected_parts.all(func(part): return skill_button.text.contains(part)):
			push_error("Shared skill slot %d should render pet, A/B, and catalog label %s, got %s." % [index + 1, expected_parts, skill_button.text if skill_button != null else "<missing>"])
			quit(1)
			return
	for index in range(skill_control_bar.size(), skill_queue_grid.get_child_count()):
		var empty_button := skill_queue_grid.get_child(index) as Button
		if empty_button == null or not empty_button.disabled or not empty_button.text.contains("—"):
			push_error("Unused authored shared-bar slot %d should remain visibly empty and disabled." % (index + 1))
			quit(1)
			return
	if Array(selected_snapshot.get("selectedTraits", [])).size() != 1 or not Array(selected_snapshot.get("selectedSkillCombos", [])).is_empty():
		push_error("The selected pet should project one trait while implicit ordered combos stay disabled.")
		quit(1)
		return
	var action_range_summary := Dictionary(battle_probe.selected_action_range_summary(selected_snapshot))
	if int(action_range_summary.get("actionBlockLimit", 0)) != 3:
		push_error("Selected pet should route exactly three action blocks into 02_FrontTargetCell, got %s." % JSON.stringify(action_range_summary))
		quit(1)
		return
	var range_color: Color = action_range_summary.get("color", Color.TRANSPARENT)
	if not range_color.is_equal_approx(Color("ff3b30")):
		push_error("Selected pet attack range should be red-only, got %s." % JSON.stringify(action_range_summary))
		quit(1)
		return
	if int(action_range_summary.get("visibleCellCount", 0)) <= 0:
		push_error("Clicking a player pet should display its projected action-block attack cells, got %s." % JSON.stringify(action_range_summary))
		quit(1)
		return
	if int(action_range_summary.get("overlayVisibleMarkerCount", 0)) != int(action_range_summary.get("visibleCellCount", -1)):
		push_error("02_FrontTargetCell should render every projected cell through its red board overlay, got %s." % JSON.stringify(action_range_summary))
		quit(1)
		return
	var detail_text := String(detail_summary.get("text", ""))
	if not detail_text.contains("生命") or not detail_text.contains("攻击力") or not detail_text.contains("护盾"):
		push_error("Authored pet-detail prefab should render health, attack, and shield fields, got %s." % JSON.stringify(detail_summary))
		quit(1)
		return
	var detail_capture_saved := await _save_capture("res://output/battle_ui_pet_detail.png")
	if not detail_capture_saved:
		print("SMOKE_BATTLE_UI_DETAIL_CAPTURE_SKIPPED headless viewport texture unavailable")
	var trace_count_before := Array(middle.state.snapshot().get("battleTrace", [])).size()
	var drag_start := Dictionary(battle_probe.start_first_player_drag(Dictionary(middle.state.snapshot())))
	if not bool(drag_start.get("started", false)):
		push_error("Battle drag preview should start from the first player unit, got %s." % JSON.stringify(drag_start))
		quit(1)
		return
	var selected_on_press := String(middle.state.snapshot().get(
		"selected_unit_id",
		middle.state.snapshot().get("selectedUnitId", "")
	))
	if selected_on_press != String(drag_start.get("unitId", "")):
		push_error("Pressing a player pet should select it before drag movement, got selected=%s start=%s." % [selected_on_press, JSON.stringify(drag_start)])
		quit(1)
		return
	var detail_during_drag := Dictionary(battle_probe.detail_summary())
	if bool(detail_during_drag.get("visible", false)):
		push_error("Battle drag should hide the previous pet detail panel, got %s." % JSON.stringify(detail_during_drag))
		quit(1)
		return
	if not bool(drag_start.get("preview_was_active", false)):
		push_error("Battle drag deploy should create a same-prefab drag preview before dropping.")
		quit(1)
		return
	await _settle_seconds(0.4)
	var cancel_target := _grid_from_value(drag_start.get("target", {}))
	var cancel_preview := Dictionary(await battle_probe.update_drag(cancel_target, Dictionary(middle.state.snapshot())))
	if int(cancel_preview.get("attack_highlight_count", 0)) <= 0:
		push_error("Battle drag preview should project artist attack range while dragging before cancel, got %s." % JSON.stringify(cancel_preview))
		battle_probe.cancel_drag()
		quit(1)
		return
	var cancel_origin_grid := _grid_from_value(drag_start.get("origin", {}))
	var cancel_origin := Dictionary(await battle_probe.update_drag(cancel_origin_grid, Dictionary(middle.state.snapshot())))
	if not bool(cancel_origin.get("preview_was_active", false)):
		push_error("Battle drag preview should remain active when dragged back to origin, got %s." % JSON.stringify(cancel_origin))
		quit(1)
		return
	var cancel_command := Dictionary(battle_probe.finish_drag(cancel_origin_grid))
	if not cancel_command.is_empty():
		push_error("Battle drag back to origin should cancel without MOVE_HERO, got %s." % JSON.stringify(cancel_command))
		quit(1)
		return
	await _settle_seconds(0.4)
	if Array(middle.state.snapshot().get("battleTrace", [])).size() != trace_count_before:
		push_error("Battle drag cancel should not append a movement trace.")
		quit(1)
		return
	var detail_after_cancel := Dictionary(battle_probe.detail_summary())
	if bool(detail_after_cancel.get("visible", false)):
		push_error("Battle drag cancel should not reopen pet detail, got %s." % JSON.stringify(detail_after_cancel))
		quit(1)
		return
	drag_start = Dictionary(battle_probe.start_first_player_drag(Dictionary(middle.state.snapshot())))
	if not bool(drag_start.get("started", false)):
		push_error("Battle drag preview should restart after cancel, got %s." % JSON.stringify(drag_start))
		quit(1)
		return
	var drag_target := _grid_from_value(drag_start.get("target", {}))
	var drag_preview := Dictionary(await battle_probe.update_drag(drag_target, Dictionary(middle.state.snapshot())))
	if int(drag_preview.get("attack_highlight_count", 0)) <= 0:
		push_error("Battle drag preview should project attack range while dragging, got %s." % JSON.stringify(drag_preview))
		battle_probe.cancel_drag()
		quit(1)
		return
	var drag_capture_saved := await _save_capture("res://output/battle_ui_drag_preview.png")
	if not drag_capture_saved:
		print("SMOKE_BATTLE_UI_DRAG_CAPTURE_SKIPPED headless viewport texture unavailable")
	var drag_command := Dictionary(battle_probe.finish_drag(drag_target))
	if String(drag_command.get("type", "")) != "MOVE_HERO":
		push_error("Battle drag deploy should emit MOVE_HERO, got command=%s start=%s preview=%s." % [JSON.stringify(drag_command), JSON.stringify(drag_start), JSON.stringify(drag_preview)])
		quit(1)
		return
	await _settle_seconds(0.5)
	if battle_flow.call("is_battle_input_locked"):
		await battle_flow.trace_sequence_finished
	var trace_count_after := Array(middle.state.snapshot().get("battleTrace", [])).size()
	if trace_count_after <= trace_count_before:
		push_error("Battle drag deploy should append a core movement trace, before=%d after=%d command=%s start=%s preview=%s." % [trace_count_before, trace_count_after, JSON.stringify(drag_command), JSON.stringify(drag_start), JSON.stringify(drag_preview)])
		quit(1)
		return
	var action_range_after_drag := Dictionary(battle_probe.selected_action_range_summary(Dictionary(middle.state.snapshot())))
	if int(action_range_after_drag.get("visibleCellCount", 0)) <= 0:
		push_error("Selected pet red action range should be restored after the movement trace rebuilds final cells, got %s." % JSON.stringify(action_range_after_drag))
		quit(1)
		return
	if int(action_range_after_drag.get("overlayVisibleMarkerCount", 0)) != int(action_range_after_drag.get("visibleCellCount", -1)):
		push_error("Movement trace rebuild should restore all red board-overlay markers, got %s." % JSON.stringify(action_range_after_drag))
		quit(1)
		return
	var detail_after_drag := Dictionary(battle_probe.detail_summary())
	if bool(detail_after_drag.get("visible", false)):
		push_error("Battle drag movement should not reopen a stale pet detail panel, got %s." % JSON.stringify(detail_after_drag))
		quit(1)
		return
	var complete_round_command := Dictionary(battle_probe.press_hud_command(&"RUN_COMBAT_ROUND"))
	if String(complete_round_command.get("type", "")) != "RUN_COMBAT_ROUND":
		push_error("Battle HUD command path should emit RUN_COMBAT_ROUND, got %s." % JSON.stringify(complete_round_command))
		quit(1)
		return
	await _settle_seconds(0.3)
	var phase_after_round := String(middle.state.snapshot().get("phase", ""))
	if phase_after_round != "battle" and phase_after_round != "battle_end":
		push_error("Battle RUN_COMBAT_ROUND command should keep battle playable, got phase %s." % phase_after_round)
		quit(1)
		return

	var auto_button := battle_flow.find_child("AutoArrangeButton", true, false) as TextureButton
	var begin_button := battle_flow.find_child("BeginTurnButton", true, false) as TextureButton
	if auto_button == null or auto_button.texture_normal == null:
		push_error("Battle auto-arrange TextureButton is not using imported art.")
		quit(1)
		return
	if begin_button == null or begin_button.texture_normal == null:
		push_error("Battle begin-turn TextureButton is not using imported art.")
		quit(1)
		return

	auto_button.emit_signal("pressed")
	await _settle_seconds(0.4)
	if String(middle.state.snapshot().get("phase", "")) != "battle":
		push_error("Auto arrange should keep battle phase active.")
		quit(1)
		return

	if middle.has_method("get_battle_missing_mapping_report"):
		var missing := Array(middle.call("get_battle_missing_mapping_report"))
		if _mapping_report_has_id(missing, "enemy_r01_001") or _mapping_report_has_name(missing, "棉悠悠"):
			push_error("Battle enemy image map should resolve enemy_r01_001 / 棉悠悠.")
			quit(1)
			return
		if _mapping_report_has_id(missing, "enemy_r01_002") or _mapping_report_has_name(missing, "炽焰牛"):
			push_error("Battle enemy image map should resolve enemy_r01_002 / 炽焰牛.")
			quit(1)
			return
		if not missing.is_empty():
			print("SMOKE_BATTLE_UI_MAPPING_GAPS %s" % JSON.stringify(missing))

	var capture_saved := await _save_capture("res://output/battle_ui_main.png")
	if not capture_saved:
		print("SMOKE_BATTLE_UI_CAPTURE_SKIPPED headless viewport texture unavailable")
	print("SMOKE_BATTLE_UI_OK res://art/scenes/battle/battle_art_scene.tscn")
	if _should_keep_open():
		print("SMOKE_BATTLE_UI_KEEP_OPEN")
		return
	quit(0)


func _find_route_button(scene: Node, kind: String) -> BaseButton:
	var buttons := scene.find_children("*", "BaseButton", true, false)
	for node in buttons:
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != "CHOOSE_ROUTE":
			continue
		if String(button.get_meta("route_kind", "")).to_lower() == kind:
			return button
	return null


func _find_first_battle_unit(root_node: Node) -> Node:
	var stack := [root_node]
	while not stack.is_empty():
		var current := stack.pop_back() as Node
		if current == null:
			continue
		if current.has_method("set_unit_data") and current.has_method("get_unit_id"):
			return current
		for child in current.get_children():
			stack.append(child)
	return null


func _grid_from_value(value: Variant) -> Vector2i:
	var grid := Dictionary(value) if value is Dictionary else {}
	return Vector2i(int(grid.get("x", -1)), int(grid.get("y", -1)))


func _mapping_report_has_id(report: Array, id: String) -> bool:
	for value in report:
		var item := Dictionary(value)
		if String(item.get("id", "")) == id:
			return true
	return false


func _mapping_report_has_name(report: Array, name: String) -> bool:
	for value in report:
		var item := Dictionary(value)
		if String(item.get("name", "")) == name:
			return true
	return false


func _assert_artist_cell_style(cell: Node) -> bool:
	var control := cell as Control
	if control == null:
		push_error("BattleCell style check needs a Control cell.")
		return false
	if control.has_method("uses_perspective_geometry") and bool(control.call("uses_perspective_geometry")):
		var perspective_style := control.get_theme_stylebox("panel")
		if not (perspective_style is StyleBoxEmpty):
			push_error("Perspective BattleCell should keep the authored polygon visible without a competing panel fill.")
			return false
		return true
	var style := control.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		push_error("BattleCell should expose a StyleBoxFlat panel style.")
		return false
	if not _color_close(style.bg_color, Color(0.48, 0.50, 0.53, 0.30)):
		push_error("BattleCell default bg should match artist BoardGrid runtime style, got %s." % [style.bg_color])
		return false
	if not _color_close(style.border_color, Color(0.78, 0.82, 0.86, 0.45)):
		push_error("BattleCell default border should match artist BoardGrid runtime style, got %s." % [style.border_color])
		return false
	if style.corner_radius_top_left != 12 or style.corner_radius_top_right != 12 or style.corner_radius_bottom_left != 12 or style.corner_radius_bottom_right != 12:
		push_error("BattleCell corner radius should match artist BoardGrid runtime style.")
		return false
	if style.shadow_size != 5 or not style.shadow_offset.is_equal_approx(Vector2(0.0, 3.0)):
		push_error("BattleCell shadow should match artist BoardGrid runtime style.")
		return false
	return true


func _color_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.001 and absf(a.g - b.g) < 0.001 and absf(a.b - b.b) < 0.001 and absf(a.a - b.a) < 0.001


func _should_keep_open() -> bool:
	if OS.get_environment("KEEP_GODOT_OPEN") == "1":
		return true
	for arg in OS.get_cmdline_args():
		if String(arg) == "--keep-open":
			return true
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "--keep-open":
			return true
	return false


func _settle_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _wait_for_phase(middle: Node, phase: String, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if String(middle.state.snapshot().get("phase", "")) == phase:
			return true
		await _settle_seconds(0.05)
		elapsed += 0.05
	return String(middle.state.snapshot().get("phase", "")) == phase


func _wait_for_battle_flow(scene: Node, timeout: float) -> Control:
	var elapsed := 0.0
	while elapsed < timeout:
		var battle_flow := scene.find_child("BattleArtScene", true, false) as Control
		if battle_flow != null and battle_flow.visible:
			return battle_flow
		await _settle_seconds(0.05)
		elapsed += 0.05
	var final_flow := scene.find_child("BattleArtScene", true, false) as Control
	if final_flow != null and final_flow.visible:
		return final_flow
	return null


func _save_capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		return false
	return image.save_png(path) == OK
