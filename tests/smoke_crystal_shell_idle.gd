extends SceneTree


const STATIC_TEXTURE := "res://art/images/shared/pets/sheets/slices/pet_style_999_crystal_shell.png"
const MANIFEST_PATH := "res://art/manifests/shared/pets/animations/pet_frame_animation_manifest.json"


func _initialize() -> void:
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest_file == null:
		_fail("cannot open runtime manifest")
		return

	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	if not parsed is Dictionary:
		_fail("runtime manifest is not a dictionary")
		return

	var manifest: Dictionary = parsed
	var by_texture_path: Dictionary = manifest.get("by_texture_path", {})
	var animations: Dictionary = by_texture_path.get(STATIC_TEXTURE, {})
	var idle: Dictionary = animations.get("idle", {})
	var frames: Array = idle.get("frames", [])
	var durations: Array = idle.get("durations_ms", [])

	if idle.get("animation_id", "") != "ANIM_SPR_999_IDLE_001":
		_fail("animation id mismatch")
		return
	if frames.size() != 16 or durations.size() != 16:
		_fail("expected 16 frames and durations")
		return
	if float(idle.get("render_scale", 0.0)) != 1.0:
		_fail("render scale mismatch")
		return
	if not is_equal_approx(float(idle.get("frame_footline_y_ratio", 0.0)), 0.9140625):
		_fail("footline ratio mismatch")
		return

	for index in frames.size():
		if int(durations[index]) != 240:
			_fail("frame duration mismatch at %d" % index)
			return
		var texture_path := str(frames[index])
		var texture := load(texture_path) as Texture2D
		if texture == null:
			_fail("cannot load frame: %s" % texture_path)
			return
		if texture.get_width() != 128 or texture.get_height() != 128:
			_fail("frame canvas mismatch: %s" % texture_path)
			return

	var static_texture := load(STATIC_TEXTURE) as Texture2D
	if static_texture == null:
		_fail("cannot load static texture")
		return
	if static_texture.get_width() != 128 or static_texture.get_height() != 128:
		_fail("static texture canvas mismatch")
		return

	print("SMOKE_CRYSTAL_SHELL_IDLE_PASS frames=16 duration_ms=240 canvas=128x128")
	quit(0)


func _fail(message: String) -> void:
	push_error("SMOKE_CRYSTAL_SHELL_IDLE_FAIL: %s" % message)
	quit(1)
