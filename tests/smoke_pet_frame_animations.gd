extends SceneTree

const PetAnimationScript := preload("res://core_ui/scripts/shared/pet/pet_animation.gd")
const CASES := [
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_005_earth_slime.png",
		"counts": {"idle": 8, "attack": 6, "move": 4},
	},
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_006_shadow_rock_wolf.png",
		"counts": {"idle": 8, "attack": 6, "move": 4},
	},
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_007_rock_claw.png",
		"counts": {"idle": 7, "attack": 9},
		"render_scale": Vector2(1.56, 1.56),
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var view := Control.new()
	view.size = Vector2(200.0, 200.0)
	root.add_child(view)
	var animation = PetAnimationScript.new()
	view.add_child(animation)
	animation.configure(view)
	for test_case in CASES:
		var source_path := String(test_case["source"])
		var source_texture := load(source_path) as Texture2D
		if source_texture == null:
			_fail("missing source texture %s" % source_path)
			return
		var sprite := TextureRect.new()
		sprite.size = Vector2(200.0, 200.0)
		sprite.texture = source_texture
		view.add_child(sprite)
		animation.play_sprite_idle(sprite, source_texture, Vector2(100.0, 190.0), source_path)
		await process_frame
		await process_frame
		var snapshot := animation.get_frame_animation_snapshot()
		var actual_actions := Dictionary(snapshot.get("actions", {}))
		for action_name in Dictionary(test_case["counts"]).keys():
			var expected_count := int(Dictionary(test_case["counts"])[action_name])
			if int(actual_actions.get(action_name, 0)) != expected_count:
				_fail("%s %s frame count mismatch" % [source_path, action_name])
				return
		if not String(sprite.texture.resource_path).contains("/animations/"):
			_fail("idle frames did not start for %s" % source_path)
			return
		var expected_render_scale := Vector2(test_case.get("render_scale", Vector2.ONE))
		if not sprite.scale.is_equal_approx(expected_render_scale):
			_fail("%s idle render scale mismatch: %s" % [source_path, sprite.scale])
			return
		animation.play_sprite_attack(Vector2.RIGHT)
		await process_frame
		await process_frame
		snapshot = animation.get_frame_animation_snapshot()
		if String(snapshot.get("active_action", "")) != "attack":
			_fail("attack frames did not start for %s" % source_path)
			return
		if not sprite.scale.is_equal_approx(expected_render_scale):
			_fail("%s attack render scale mismatch: %s" % [source_path, sprite.scale])
			return
		animation.reset()
		sprite.queue_free()
		await process_frame
	print("SMOKE_PET_FRAME_ANIMATIONS_PASS cases=%d" % CASES.size())
	quit(0)


func _fail(message: String) -> void:
	push_error("SMOKE_PET_FRAME_ANIMATIONS_FAIL: %s" % message)
	quit(1)
