extends SceneTree

const PetAnimationScript := preload("res://core_ui/scripts/shared/pet/pet_animation.gd")
const APPROVED_MANIFEST_PATH := "res://art/manifests/shared/pets/animations/approved_sprite_animation_manifest.json"
const CASE := {
	"sprite_id": "SPR_014",
	"source": "res://art/images/shared/pets/sheets/slices/pet_style_014_horned_wing_dragon.png",
	"frame_root": "res://art/images/shared/pets/animations/spr_014_horned_wing_dragon/anim_001_idle/frames",
	"frame_count": 4,
	"loop_duration_seconds": 1.6,
	"render_scale": Vector2.ONE,
	"footline_y_ratio": 0.828125,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var approved_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(APPROVED_MANIFEST_PATH))
	if not approved_parsed is Dictionary:
		_fail("approved manifest is invalid")
		return
	var approved := Array(Dictionary(approved_parsed).get("approved_animations", []))
	if approved.size() != 1 or String(Dictionary(approved[0]).get("sprite_id", "")) != String(CASE["sprite_id"]):
		_fail("only SPR_014 should remain approved: %s" % approved)
		return

	var view := Control.new()
	view.size = Vector2(200.0, 200.0)
	root.add_child(view)
	if not await _verify_case(view):
		return
	if not await _verify_synchronized_phase(view):
		return
	print("SMOKE_PET_FRAME_ANIMATIONS_PASS approved=SPR_014 frames=4 loop_seconds=1.6 synchronized=true")
	quit(0)


func _verify_case(view: Control) -> bool:
	var source_path := String(CASE["source"])
	var frame_root := String(CASE["frame_root"])
	var source_texture := load(source_path) as Texture2D
	if source_texture == null:
		_fail("missing source texture %s" % source_path)
		return false
	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = Vector2(200.0, 200.0)
	sprite.texture = source_texture
	view.add_child(sprite)
	var authored_position := sprite.position
	var animation = PetAnimationScript.new()
	view.add_child(animation)
	animation.configure(view)
	animation.play_sprite_idle(sprite, source_texture, Vector2(100.0, 190.0), source_path)
	await process_frame
	await process_frame

	var snapshot := animation.get_frame_animation_snapshot()
	var actions := Dictionary(snapshot.get("actions", {}))
	if actions.size() != 1 or int(actions.get("idle", 0)) != int(CASE["frame_count"]):
		_fail("SPR_014 did not expose exactly one idle action: %s" % actions)
		return false
	var actual_loop_duration := float(animation.call("_frame_action_duration", &"idle"))
	if not is_equal_approx(actual_loop_duration, float(CASE["loop_duration_seconds"])):
		_fail("SPR_014 loop duration mismatch: %s" % actual_loop_duration)
		return false
	if String(snapshot.get("active_action", "")) != "idle" \
			or not String(sprite.texture.resource_path).begins_with(frame_root):
		_fail("SPR_014 idle frames did not start")
		return false
	var expected_render_scale := Vector2(CASE["render_scale"])
	if not sprite.scale.is_equal_approx(expected_render_scale):
		_fail("SPR_014 render scale mismatch: %s" % sprite.scale)
		return false
	var expected_footline_y_ratio := float(CASE["footline_y_ratio"])
	var expected_position_y := authored_position.y \
			+ (190.0 - 200.0 * expected_footline_y_ratio) * expected_render_scale.y
	if not is_equal_approx(sprite.position.y, expected_position_y):
		_fail("SPR_014 footline mismatch: position=%s expected=%s" % [sprite.position.y, expected_position_y])
		return false

	animation.reset()
	animation.queue_free()
	sprite.queue_free()
	await process_frame
	return true


func _verify_synchronized_phase(view: Control) -> bool:
	var running: Array[Dictionary] = []
	for _index in 2:
		var source_path := String(CASE["source"])
		var source_texture := load(source_path) as Texture2D
		var sprite := TextureRect.new()
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.size = Vector2(200.0, 200.0)
		sprite.texture = source_texture
		view.add_child(sprite)
		var synchronized_animation = PetAnimationScript.new()
		view.add_child(synchronized_animation)
		synchronized_animation.configure(view)
		synchronized_animation.play_sprite_idle(sprite, source_texture, Vector2(100.0, 190.0), source_path)
		running.append({"animation": synchronized_animation, "sprite": sprite})
	await process_frame
	await process_frame
	var first_index := -1
	for item in running:
		var snapshot := Dictionary(item["animation"].get_frame_animation_snapshot())
		var current_index := int(snapshot.get("frame_index", -1))
		if first_index < 0:
			first_index = current_index
		elif current_index != first_index:
			_fail("SPR_014 instances did not share the same project-clock phase")
			return false
	for item in running:
		item["animation"].reset()
		item["animation"].queue_free()
		item["sprite"].queue_free()
	return true


func _fail(message: String) -> void:
	push_error("SMOKE_PET_FRAME_ANIMATIONS_FAIL: %s" % message)
	quit(1)
