extends SceneTree

const PetAnimationScript := preload("res://core_ui/scripts/shared/pet/pet_animation.gd")
const SOURCE_PATH := "res://art/images/shared/pets/animations/spr_010_void_octopus/anim_001_idle/frames/frame_001.png"
const IDLE_FRAME_ROOT := "res://art/images/shared/pets/animations/spr_010_void_octopus/anim_001_idle/frames"
const EXPECTED_FRAME_COUNT := 16
const EXPECTED_FRAME_DURATION_MS := 180
const EXPECTED_FOOTLINE_Y_RATIO := 0.85625


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_texture := load(SOURCE_PATH) as Texture2D
	if source_texture == null:
		_fail("missing source texture")
		return
	for index in range(EXPECTED_FRAME_COUNT):
		var frame_path := "%s/frame_%03d.png" % [IDLE_FRAME_ROOT, index + 1]
		var frame_texture := load(frame_path) as Texture2D
		if frame_texture == null or frame_texture.get_size() != Vector2(160.0, 160.0):
			_fail("missing or invalid idle frame %s" % frame_path)
			return

	var view := Control.new()
	view.size = Vector2(200.0, 200.0)
	root.add_child(view)
	var animation = PetAnimationScript.new()
	view.add_child(animation)
	animation.configure(view)
	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = Vector2(200.0, 200.0)
	sprite.texture = source_texture
	view.add_child(sprite)
	var authored_position := sprite.position
	animation.play_sprite_idle(sprite, source_texture, Vector2(100.0, 190.0), SOURCE_PATH)
	await process_frame
	await process_frame

	var snapshot := animation.get_frame_animation_snapshot()
	var actions := Dictionary(snapshot.get("actions", {}))
	if int(actions.get("idle", 0)) != EXPECTED_FRAME_COUNT:
		_fail("idle frame count mismatch")
		return
	if actions.size() != 1 or actions.has("move"):
		_fail("void octopus exposed a non-idle action")
		return
	if String(snapshot.get("active_action", "")) != "idle":
		_fail("idle action did not start")
		return
	if not String(sprite.texture.resource_path).begins_with(IDLE_FRAME_ROOT):
		_fail("idle frame texture was not applied")
		return
	if not sprite.scale.is_equal_approx(Vector2.ONE):
		_fail("idle render scale mismatch: %s" % sprite.scale)
		return
	var expected_position_y := authored_position.y + (
		190.0 - sprite.size.y * EXPECTED_FOOTLINE_Y_RATIO
	)
	if not is_equal_approx(sprite.position.y, expected_position_y):
		_fail("idle footline mismatch: position=%s expected=%s" % [
			sprite.position.y,
			expected_position_y,
		])
		return
	animation.play_sprite_move(Vector2.RIGHT)
	await process_frame
	await process_frame
	snapshot = animation.get_frame_animation_snapshot()
	if String(snapshot.get("active_action", "")) != "idle" \
			or not String(sprite.texture.resource_path).begins_with(IDLE_FRAME_ROOT):
		_fail("movement did not keep the idle loop")
		return
	print("SMOKE_VOID_OCTOPUS_IDLE_ANIMATION_PASS frames=%d frame_ms=%d" % [
		EXPECTED_FRAME_COUNT,
		EXPECTED_FRAME_DURATION_MS,
	])
	quit(0)


func _fail(message: String) -> void:
	push_error("SMOKE_VOID_OCTOPUS_IDLE_ANIMATION_FAIL: %s" % message)
	quit(1)
