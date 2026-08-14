extends SceneTree

const PetAnimationScript := preload("res://core_ui/scripts/shared/pet/pet_animation.gd")
const SOURCE_PATH := "res://art/images/shared/pets/sheets/slices/pet_style_014_horned_wing_dragon.png"
const FRAME_ROOT := "res://art/images/shared/pets/animations/spr_014_horned_wing_dragon/anim_001_idle/frames"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view := Control.new()
	view.size = Vector2(200.0, 200.0)
	root.add_child(view)
	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = view.size
	sprite.texture = load(SOURCE_PATH) as Texture2D
	view.add_child(sprite)
	var animation = PetAnimationScript.new()
	view.add_child(animation)
	animation.configure(view)
	animation.play_sprite_idle(sprite, sprite.texture, Vector2(100.0, 190.0), SOURCE_PATH)
	await process_frame
	await process_frame
	var snapshot := Dictionary(animation.get_frame_animation_snapshot())
	var actions := Dictionary(snapshot.get("actions", {}))
	if actions.size() != 1 or int(actions.get("idle", 0)) != 4:
		_fail("idle action must contain exactly four frames")
		return
	if not is_equal_approx(float(animation.call("_frame_action_duration", &"idle")), 1.6):
		_fail("idle loop must last 1.6 seconds")
		return
	if not String(sprite.texture.resource_path).begins_with(FRAME_ROOT):
		_fail("approved idle frames did not start")
		return
	if not sprite.scale.is_equal_approx(Vector2.ONE):
		_fail("idle render scale changed")
		return
	var expected_y := 190.0 - 200.0 * 0.828125
	if not is_equal_approx(sprite.position.y, expected_y):
		_fail("idle footline is not stable")
		return
	print("SMOKE_HORNED_WING_DRAGON_IDLE_PASS frames=4 loop_seconds=1.6")
	quit(0)


func _fail(message: String) -> void:
	push_error("SMOKE_HORNED_WING_DRAGON_IDLE_FAIL: %s" % message)
	quit(1)
