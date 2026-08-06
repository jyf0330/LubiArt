extends SceneTree

const PREFAB := preload("res://art/prefabs/battle/hud/battle_map_controls.tscn")
const OUTPUT_DIR := "res://output/validation/all_out_idle_highlight"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var background := TextureRect.new()
	background.size = Vector2(1920.0, 1080.0)
	background.texture = preload(
		"res://art/images/battle/map_controls/maps/grassland_morning.png"
	)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(background)
	var prefab := PREFAB.instantiate() as Control
	prefab.position = Vector2.ZERO
	root.add_child(prefab)
	await process_frame
	await process_frame
	await _capture("01_before_idle.png")

	prefab.call("_mark_player_activity")
	var deadline := Time.get_ticks_msec() + 4000
	while not bool(prefab.get("_all_out_idle_prompt_played")) \
			and Time.get_ticks_msec() < deadline:
		await process_frame
	if not bool(prefab.get("_all_out_idle_prompt_played")):
		_fail("idle prompt did not start after three seconds")
		return
	await create_timer(0.56).timeout
	var material := (prefab.get_node("AllOutButton") as TextureButton).material as ShaderMaterial
	var progress := float(material.get_shader_parameter("sweep_progress"))
	if progress <= 0.0 or progress >= 1.0:
		_fail("idle prompt was not visible at the expected midpoint")
		return
	await _capture("02_highlight_mid_sweep.png")
	var first_tween := prefab.get("_all_out_highlight_tween") as Tween
	deadline = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		var current_tween := prefab.get("_all_out_highlight_tween") as Tween
		if current_tween != null and current_tween != first_tween:
			break
		await process_frame
	var repeated_tween := prefab.get("_all_out_highlight_tween") as Tween
	if repeated_tween == null or repeated_tween == first_tween:
		_fail("idle prompt did not repeat after another three seconds")
		return
	await create_timer(0.56).timeout
	await _capture("03_repeated_highlight_mid_sweep.png")

	var a_release := InputEventKey.new()
	a_release.keycode = KEY_A
	a_release.pressed = false
	prefab.call("_input", a_release)
	assert(is_equal_approx(float(material.get_shader_parameter("sweep_progress")), -1.0))
	await _capture("04_after_a_release.png")
	print("ALL_OUT_IDLE_HIGHLIGHT_VISIBLE_PASS")
	quit(0)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	assert(image.save_png(OUTPUT_DIR.path_join(file_name)) == OK)


func _fail(message: String) -> void:
	push_error("ALL_OUT_IDLE_HIGHLIGHT_VISIBLE_FAIL: %s" % message)
	quit(1)
