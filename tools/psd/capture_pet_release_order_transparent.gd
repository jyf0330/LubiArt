extends SceneTree

const AttackTimelineScene := preload("res://art/prefabs/battle/hud/attack_timeline.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const OUTPUT_PATH := "res://art/images/battle/hud/attack_timeline/source/screen_pet_release_order_transparent_v2.png"


func _initialize() -> void:
	print("PET_RELEASE_ORDER_TRANSPARENT_CAPTURE_INIT")
	call_deferred("_run")


func _run() -> void:
	print("PET_RELEASE_ORDER_TRANSPARENT_CAPTURE_RENDERING")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1640, 778)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var timeline := AttackTimelineScene.instantiate() as Control
	viewport.add_child(timeline)
	# The root panel owns the translucent full-screen plate and its four corner
	# ornaments. Replacing only its own style keeps every authored child intact.
	timeline.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	await process_frame
	await process_frame
	var snapshot := Dictionary(MockSession.new({"start_phase": "battle"}).call("current_snapshot"))
	timeline.call("render_snapshot", snapshot)
	await process_frame
	await process_frame
	await process_frame
	RenderingServer.force_sync()
	print("PET_RELEASE_ORDER_TRANSPARENT_CAPTURE_SAVING")

	var image := viewport.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("PET_RELEASE_ORDER_TRANSPARENT_CAPTURE_FAIL: %d" % error)
		quit(1)
		return
	print("PET_RELEASE_ORDER_TRANSPARENT_CAPTURE_PASS: %s" % OUTPUT_PATH)
	viewport.queue_free()
	quit(0)
