extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var output_dir := OS.get_environment("DEBUG_DRAWER_CAPTURE_DIR").strip_edges()
	if output_dir.is_empty():
		push_error("DEBUG_DRAWER_CAPTURE_FAIL: DEBUG_DRAWER_CAPTURE_DIR is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	battle.call(
		"render_snapshot",
		Dictionary(MockSession.new({"start_phase": "battle"}).call("current_snapshot"))
	)
	for _frame in range(4):
		await process_frame
	var hud := battle.get_node("Hud") as Control
	var panel := battle.get_node("Hud/BattleActionPanel") as Control
	var toggle := battle.get_node("Hud/DebugDrawerToggleButton") as Button
	assert(panel.get_node_or_null("Margin/Content/MapDebugButton") != null)
	assert(panel.get_node_or_null("Margin/Content/PositionDifficultyButton") != null)
	assert(battle.get_node_or_null("ShortcutHintDebugButton") == null)
	await _capture(output_dir.path_join("debug_drawer_expanded_1920x1080.png"))
	toggle.pressed.emit()
	await create_timer(0.25).timeout
	await process_frame
	assert(bool(hud.call("debug_is_action_panel_collapsed")))
	assert(panel.position == Vector2(-462.0, 150.0))
	assert(toggle.position == Vector2(0.0, 174.0))
	await _capture(output_dir.path_join("debug_drawer_collapsed_1920x1080.png"))
	toggle.pressed.emit()
	await create_timer(0.25).timeout
	assert(not bool(hud.call("debug_is_action_panel_collapsed")))
	print("VISIBLE_DEBUG_DRAWER_PASS")
	battle.queue_free()
	quit(0)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	assert(image.save_png(path) == OK)
