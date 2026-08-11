extends SceneTree

const PetAnimationScript := preload("res://core_ui/scripts/shared/pet/pet_animation.gd")
const CASES := [
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_001_gold_mascot.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_001_gold_mascot/anim_001_idle/frames",
		"frame_count": 16,
		"render_scale": Vector2(0.82, 0.82),
		"footline_y_ratio": 0.9453125,
	},
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_002_gold_shell.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_002_gold_shell/anim_001_idle/frames",
		"frame_count": 16,
		"render_scale": Vector2.ONE,
		"footline_y_ratio": 0.828125,
	},
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_005_earth_slime.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_005_earth_slime/anim_001_idle/frames",
		"frame_count": 16,
		"loop_duration_seconds": 3.84,
		"render_scale": Vector2.ONE,
		"footline_y_ratio": 0.9765625,
	},
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_007_rock_claw.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_007_rock_claw/anim_001_idle/frames",
		"frame_count": 16,
		"loop_duration_seconds": 2.4,
		"render_scale": Vector2(1.56, 1.56),
		"footline_y_ratio": 0.8515625,
	},
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_008_volcanic_dijiang.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_008_volcanic_dijiang/anim_001_idle/frames",
		"frame_count": 16,
		"render_scale": Vector2.ONE,
		"footline_y_ratio": 0.9609375,
	},
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_003_blue_electric_shell.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_009_azure_thunder_owl/anim_001_idle/frames",
		"frame_count": 16,
		"render_scale": Vector2.ONE,
		"footline_y_ratio": 0.859375,
	},
	{
		"source": "res://art/images/shared/pets/animations/spr_010_void_octopus/anim_001_idle/frames/frame_001.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_010_void_octopus/anim_001_idle/frames",
		"frame_count": 16,
		"render_scale": Vector2.ONE,
		"footline_y_ratio": 0.85625,
	},
	{
		"source": "res://art/images/shared/pets/animations/spr_012_azure_wind_feather/anim_001_idle/frames/frame_001.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_012_azure_wind_feather/anim_001_idle/frames",
		"frame_count": 16,
		"loop_duration_seconds": 2.4,
		"render_scale": Vector2.ONE,
		"footline_y_ratio": 0.9453125,
	},
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_901_aqua_crystal_frog.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_901_aqua_crystal_frog/anim_001_idle/frames",
		"frame_count": 16,
		"render_scale": Vector2.ONE,
		"footline_y_ratio": 0.925,
	},
	{
		"source": "res://art/images/shared/pets/animations/spr_057_frost_fox/anim_001_idle/frames/frame_001.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_057_frost_fox/anim_001_idle/frames",
		"frame_count": 12,
		"loop_duration_seconds": 2.88,
		"render_scale": Vector2.ONE,
		"footline_y_ratio": 0.921875,
	},
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_014_horned_wing_dragon.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_014_horned_wing_dragon/anim_001_idle/frames",
		"frame_count": 16,
		"render_scale": Vector2.ONE,
		"footline_y_ratio": 0.828125,
	},
	{
		"source": "res://art/images/shared/pets/sheets/slices/pet_style_999_crystal_shell.png",
		"frame_root": "res://art/images/shared/pets/animations/spr_999_crystal_shell/anim_001_idle/frames",
		"frame_count": 16,
		"loop_duration_seconds": 3.84,
		"render_scale": Vector2.ONE,
		"footline_y_ratio": 0.9140625,
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
		var frame_root := String(test_case["frame_root"])
		var source_texture := load(source_path) as Texture2D
		if source_texture == null:
			_fail("missing source texture %s" % source_path)
			return
		var sprite := TextureRect.new()
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.size = Vector2(200.0, 200.0)
		sprite.texture = source_texture
		view.add_child(sprite)
		var authored_position := sprite.position
		animation.play_sprite_idle(sprite, source_texture, Vector2(100.0, 190.0), source_path)
		await process_frame
		await process_frame

		var snapshot := animation.get_frame_animation_snapshot()
		var actions := Dictionary(snapshot.get("actions", {}))
		if actions.size() != 1 or int(actions.get("idle", 0)) != int(test_case["frame_count"]):
			_fail("%s did not expose exactly one idle action: %s" % [source_path, actions])
			return
		if test_case.has("loop_duration_seconds"):
			var actual_loop_duration := float(animation.call("_frame_action_duration", &"idle"))
			var expected_loop_duration := float(test_case["loop_duration_seconds"])
			if not is_equal_approx(actual_loop_duration, expected_loop_duration):
				_fail("%s idle loop duration mismatch: %s expected=%s" % [
					source_path,
					actual_loop_duration,
					expected_loop_duration,
				])
				return
		if String(snapshot.get("active_action", "")) != "idle" \
				or not String(sprite.texture.resource_path).begins_with(frame_root):
			_fail("idle frames did not start for %s" % source_path)
			return
		var expected_render_scale := Vector2(test_case["render_scale"])
		if not sprite.scale.is_equal_approx(expected_render_scale):
			_fail("%s idle render scale mismatch: %s" % [source_path, sprite.scale])
			return
		var expected_footline_y_ratio := float(test_case["footline_y_ratio"])
		var expected_position_y := authored_position.y \
				+ (190.0 - 200.0 * expected_footline_y_ratio) * expected_render_scale.y
		if not is_equal_approx(sprite.position.y, expected_position_y):
			_fail("%s idle footline mismatch: position=%s expected=%s" % [
				source_path,
				sprite.position.y,
				expected_position_y,
			])
			return

		animation.play_sprite_move(Vector2.RIGHT)
		await process_frame
		await process_frame
		snapshot = animation.get_frame_animation_snapshot()
		if String(snapshot.get("active_action", "")) != "idle" \
				or not String(sprite.texture.resource_path).begins_with(frame_root):
			_fail("%s left the idle loop during movement" % source_path)
			return
		if not sprite.scale.is_equal_approx(expected_render_scale):
			_fail("%s movement facing did not preserve idle scale" % source_path)
			return

		animation.reset()
		sprite.queue_free()
		await process_frame
	print("SMOKE_PET_FRAME_ANIMATIONS_PASS idle_only=%d" % CASES.size())
	quit(0)


func _fail(message: String) -> void:
	push_error("SMOKE_PET_FRAME_ANIMATIONS_FAIL: %s" % message)
	quit(1)
