extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const OUTPUT_DIR := "res://output/qa/enemy_info_triangle_button"


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await _settle(8)
	var drawer := battle.get_node("EnemyInfoDrawer") as Control
	var button := drawer.get_node("ToggleButton") as TextureButton
	var arrow := drawer.get_node("ToggleButton/Arrow") as TextureRect
	if drawer == null or button == null or arrow == null:
		_fail("enemy info toggle nodes unavailable")
		return
	if button.size != Vector2(52.0, 56.0) or arrow.size != Vector2(40.0, 40.0):
		_fail("toggle geometry changed: button=%s arrow=%s" % [button.size, arrow.size])
		return
	if arrow.texture == null or arrow.texture.get_size() != Vector2(48.0, 48.0):
		_fail("triangle texture must stay on a 48x48 canvas")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	drawer.call("set_expanded", false, false)
	await _settle(4)
	_capture("closed.png")
	if not is_zero_approx(arrow.rotation):
		_fail("closed arrow must point left at zero rotation")
		return
	drawer.call("set_expanded", true, false)
	await _settle(4)
	_capture("open.png")
	if not is_equal_approx(absf(arrow.rotation), PI):
		_fail("open arrow must rotate 180 degrees")
		return
	print("VISIBLE_ENEMY_INFO_TRIANGLE_BUTTON_PASS button=%s icon=%s texture=%s" % [
		button.size,
		arrow.size,
		arrow.texture.get_size(),
	])
	quit(0)


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(file_name: String) -> void:
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name)))
	if error != OK:
		_fail("capture failed: %s" % file_name)


func _fail(message: String) -> void:
	push_error("VISIBLE_ENEMY_INFO_TRIANGLE_BUTTON_FAIL: %s" % message)
	quit(1)
