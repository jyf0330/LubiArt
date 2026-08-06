extends SceneTree

const BATTLE_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MOCK_SESSION := preload("res://session/mock_game_session.gd")
const OUTPUT_DIR := "res://output/validation/battle_map_controls"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var battle_view := BATTLE_SCENE.instantiate() as Control
	root.add_child(battle_view)
	await process_frame
	battle_view.call("render_snapshot", Dictionary(MOCK_SESSION.new({"start_phase": "battle"}).call("current_snapshot")))
	for _frame in range(4):
		await process_frame
	var debug_button := battle_view.get_node("ShortcutHintDebugButton") as Button
	var hints := battle_view.get_node("MapControls/ShortcutHints") as TextureRect
	assert(debug_button != null)
	assert(hints != null)
	assert(hints.visible)
	await _capture("formal_shortcut_hints_visible.png")
	debug_button.pressed.emit()
	await process_frame
	assert(not hints.visible)
	await _capture("formal_shortcut_hints_hidden.png")
	debug_button.pressed.emit()
	await process_frame
	assert(hints.visible)
	await _capture("formal_shortcut_hints_restored.png")
	print("BATTLE_SHORTCUT_HINTS_DEBUG_VISIBLE_PASS")
	quit(0)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	assert(image.save_png(OUTPUT_DIR.path_join(file_name)) == OK)
