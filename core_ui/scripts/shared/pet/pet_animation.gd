extends Control
class_name PetAnimation

signal hit_frame_reached
signal impact_reached

const PSD_CANVAS_SIZE := Vector2(171.0, 144.0)
const BITE_FRAME_PATHS: Array[NodePath] = [
	NodePath("bite/frame_001/FrameArt"),
	NodePath("bite/frame_002/FrameArt"),
	NodePath("bite/frame_003/FrameArt"),
	NodePath("bite/frame_004/FrameArt"),
	NodePath("bite/frame_005/FrameArt"),
]
const BITE_FRAME_RECTS: Array[Rect2] = [
	Rect2(159.0, 27.0, 102.0, 110.0),
	Rect2(156.0, 5.0, 99.0, 132.0),
	Rect2(150.0, 13.0, 121.0, 128.0),
	Rect2(140.0, 22.0, 131.0, 125.0),
	Rect2(141.0, 12.0, 113.0, 138.0),
]
const ELEMENT_IDS: Array[String] = ["fire", "water", "earth", "wind"]
const PROJECTILE_RECTS := {
	"fire": Rect2(100.0, 39.0, 87.0, 54.0),
	"water": Rect2(99.0, 37.0, 88.0, 58.0),
	"earth": Rect2(100.0, 37.0, 87.0, 57.0),
	"wind": Rect2(100.0, 37.0, 87.0, 58.0),
}
const PROJECTILE_TEXTURES := {
	"fire": preload("res://art/images/shared/pets/battle_complete/projectile_fire.png"),
	"water": preload("res://art/images/shared/pets/battle_complete/projectile_water.png"),
	"earth": preload("res://art/images/shared/pets/battle_complete/projectile_earth.png"),
	"wind": preload("res://art/images/shared/pets/battle_complete/projectile_wind.png"),
}
const FRAME_ANIMATION_MANIFEST_PATH := "res://art/manifests/shared/pets/animations/pet_frame_animation_manifest.json"
const DEFAULT_AUTHORED_HORIZONTAL_FACING := 1.0
const DIRECTION_EPSILON := 0.001
const SYNCHRONIZED_IDLE_FRAME_COUNT := 4
const SYNCHRONIZED_IDLE_FRAME_DURATION_MS := 400
const SYNCHRONIZED_IDLE_LOOP_DURATION_MS := 1600
const SYNCHRONIZED_TRANSFORM_IDLE_SCALES: Array[Vector2] = [
	Vector2.ONE,
	Vector2(1.012, 0.985),
	Vector2.ONE,
	Vector2(0.992, 1.012),
]
static var _frame_profiles_loaded := false
static var _frame_profiles_by_texture_path: Dictionary = {}
static var _frame_texture_cache: Dictionary = {}
var _view: Control = null
var _base_position := Vector2.ZERO
var _shake_tween: Tween = null
var _attack_tween: Tween = null
var _idle_sprite: TextureRect = null
var _idle_base_scale := Vector2.ONE
var _idle_base_pivot := Vector2.ZERO
var _idle_base_position := Vector2.ZERO
var _idle_base_rotation := 0.0
var _idle_pivot_ratio := Vector2(0.5, 1.0)
var _base_sprite_texture: Texture2D = null
var _frame_profile: Dictionary = {}
var _frame_tween: Tween = null
var _frame_playback_token := 0
var _frame_action: StringName = &""
var _frame_index := -1
var _synchronized_idle_textures: Array[Texture2D] = []
var _synchronized_idle_durations_ms: Array[int] = []
var _synchronized_transform_idle := false
var _frame_render_scale := Vector2.ONE
var _frame_footline_y_ratio := 1.0
var _authored_horizontal_facing := DEFAULT_AUTHORED_HORIZONTAL_FACING
var _horizontal_facing := DEFAULT_AUTHORED_HORIZONTAL_FACING
var _horizontal_facing_locked := false
var _animation_texture_path := ""
var _use_transform_idle := false
var _attack_release_delay := 0.0
var _bite_frames: Array[TextureRect] = []
var _projectile: TextureRect = null
var _last_attack_snapshot: Dictionary = {}


func configure(view: Control) -> void:
	_view = view
	_base_position = view.position if view != null else Vector2.ZERO
	_resolve_psd_action_nodes()
	if view != null:
		layout_authored(view.size, PSD_CANVAS_SIZE)
	reset()


func _process(_delta: float) -> void:
	if _frame_action == &"idle":
		_apply_synchronized_idle_phase()


func layout_authored(view_size: Vector2, canvas_size: Vector2 = PSD_CANVAS_SIZE) -> void:
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0:
		return
	var authored_scale := Vector2(view_size.x / canvas_size.x, view_size.y / canvas_size.y)
	for index in range(mini(_bite_frames.size(), BITE_FRAME_RECTS.size())):
		_apply_authored_rect(_bite_frames[index], BITE_FRAME_RECTS[index], authored_scale)
	_apply_authored_rect(_projectile, PROJECTILE_RECTS["fire"], authored_scale)


func reset() -> void:
	_stop_sprite_idle()
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	_shake_tween = null
	_attack_tween = null
	_last_attack_snapshot = {}
	_hide_all_action_art()


func play_sprite_idle(
	sprite: TextureRect,
	texture_resource: Texture2D,
	visible_foot_pivot: Vector2 = Vector2(-1.0, -1.0),
	animation_texture_path: String = "",
	allow_frame_profile: bool = true,
	use_transform_idle: bool = false,
	horizontal_facing: float = DEFAULT_AUTHORED_HORIZONTAL_FACING,
	lock_horizontal_facing: bool = false,
	authored_horizontal_facing: float = DEFAULT_AUTHORED_HORIZONTAL_FACING
) -> void:
	_stop_sprite_idle()
	if sprite == null or texture_resource == null:
		return
	_idle_sprite = sprite
	_base_sprite_texture = texture_resource
	_animation_texture_path = animation_texture_path if animation_texture_path != "" else texture_resource.resource_path
	_frame_profile = (
		_frame_profile_for_texture_path(_animation_texture_path)
		if allow_frame_profile
		else {}
	)
	_use_transform_idle = use_transform_idle
	_authored_horizontal_facing = (
		0.0
		if is_zero_approx(authored_horizontal_facing)
		else (1.0 if authored_horizontal_facing > 0.0 else -1.0)
	)
	_horizontal_facing = 1.0 if horizontal_facing > 0.0 else -1.0
	_horizontal_facing_locked = lock_horizontal_facing
	_idle_base_scale = sprite.scale
	_idle_base_pivot = sprite.pivot_offset
	_idle_base_position = sprite.position
	_idle_base_rotation = sprite.rotation
	_idle_pivot_ratio = Vector2(0.5, 1.0)
	if visible_foot_pivot.x >= 0.0 and visible_foot_pivot.y >= 0.0 \
			and sprite.size.x > 0.0 and sprite.size.y > 0.0:
		_idle_pivot_ratio = visible_foot_pivot / sprite.size
	refresh_idle_pivot()
	_apply_sprite_facing()
	_start_sprite_idle_loop()


func _start_sprite_idle_loop() -> void:
	if _idle_sprite == null:
		return
	# Idle playback is opt-in through the reviewed frame-animation manifest.
	# A specifically opted-in authored still may use a foot-anchored transform
	# idle when its available frame delivery belongs to a different identity.
	if not _play_frame_action(&"idle", true) and _use_transform_idle:
		_start_transform_idle_loop()


func _start_transform_idle_loop() -> void:
	if _idle_sprite == null:
		return
	_stop_frame_tween()
	_frame_action = &"idle"
	_frame_index = -1
	_synchronized_transform_idle = true
	_synchronized_idle_durations_ms.assign(
		[
			SYNCHRONIZED_IDLE_FRAME_DURATION_MS,
			SYNCHRONIZED_IDLE_FRAME_DURATION_MS,
			SYNCHRONIZED_IDLE_FRAME_DURATION_MS,
			SYNCHRONIZED_IDLE_FRAME_DURATION_MS,
		]
	)
	_apply_synchronized_idle_phase(true)


func play_sprite_attack(direction: Vector2, _duration: float = 0.42) -> void:
	if not _begin_sprite_action():
		return
	_update_horizontal_facing(direction)
	_attack_release_delay = 0.0
	if _play_frame_action(&"attack", false):
		_attack_release_delay = _frame_action_release_delay(&"attack")
		return
	_start_sprite_idle_loop()


func _begin_sprite_action() -> bool:
	if _idle_sprite == null:
		return false
	_stop_frame_tween()
	_restore_sprite_pose()
	_restore_sprite_texture()
	refresh_idle_pivot()
	return true


func _update_horizontal_facing(direction: Vector2) -> void:
	if _horizontal_facing_locked or absf(direction.x) <= DIRECTION_EPSILON:
		return
	_horizontal_facing = signf(direction.x)
	_apply_sprite_facing(_frame_render_scale)


func _apply_sprite_facing(render_scale: Vector2 = Vector2.ONE) -> void:
	if _idle_sprite == null:
		return
	_idle_sprite.scale = _idle_base_scale * render_scale * Vector2(_facing_mirror_x(), 1.0)


func _facing_mirror_x() -> float:
	if is_zero_approx(_authored_horizontal_facing):
		return 1.0
	return 1.0 if _horizontal_facing == _authored_horizontal_facing else -1.0


func _play_frame_action(action: StringName, loop: bool) -> bool:
	if _idle_sprite == null or not _frame_profile.has(String(action)):
		return false
	var definition := Dictionary(_frame_profile.get(String(action), {}))
	var frame_paths := Array(definition.get("frames", []))
	var durations_ms := Array(definition.get("durations_ms", []))
	if frame_paths.is_empty() or frame_paths.size() != durations_ms.size():
		push_warning("Invalid pet frame animation '%s' for %s" % [action, _animation_texture_path])
		return false
	if action == &"idle" and (
			frame_paths.size() != SYNCHRONIZED_IDLE_FRAME_COUNT
			or not _has_uniform_idle_timing(durations_ms)
	):
		push_warning(
			"Pet idle animation must use the shared 4-frame / 1.6-second rhythm: %s"
			% _animation_texture_path
		)
		return false
	var frame_textures: Array[Texture2D] = []
	for frame_path_value in frame_paths:
		var frame_path := String(frame_path_value)
		var frame_texture := _cached_frame_texture(frame_path)
		if frame_texture == null:
			push_warning("Missing pet animation frame: %s" % frame_path)
			return false
		frame_textures.append(frame_texture)
	_stop_frame_tween()
	_frame_playback_token += 1
	var playback_token := _frame_playback_token
	_frame_action = action
	_frame_index = -1
	var render_scale_value = definition.get("render_scale", 1.0)
	if render_scale_value is Array and Array(render_scale_value).size() >= 2:
		_frame_render_scale = Vector2(
			float(Array(render_scale_value)[0]),
			float(Array(render_scale_value)[1])
		)
	else:
		var uniform_render_scale := maxf(float(render_scale_value), 0.01)
		_frame_render_scale = Vector2.ONE * uniform_render_scale
	_frame_footline_y_ratio = clampf(
		float(definition.get("frame_footline_y_ratio", 1.0)),
		0.0,
		1.0
	)
	if loop and action == &"idle":
		_synchronized_idle_textures.assign(frame_textures)
		_synchronized_idle_durations_ms.assign(durations_ms)
		_apply_synchronized_idle_phase(true)
		return true
	_frame_tween = _idle_sprite.create_tween()
	if loop:
		_frame_tween.set_loops()
	for index in range(frame_textures.size()):
		_frame_tween.tween_callback(
			_apply_animation_frame.bind(playback_token, index, frame_textures[index])
		)
		_frame_tween.tween_interval(maxf(float(durations_ms[index]) / 1000.0, 0.016))
	if not loop:
		_frame_tween.tween_callback(_finish_frame_action.bind(playback_token))
	return true


func _apply_synchronized_idle_phase(force: bool = false) -> void:
	if _idle_sprite == null or _frame_action != &"idle":
		return
	var index := _synchronized_idle_frame_index(
		Time.get_ticks_msec(),
		_synchronized_idle_durations_ms
	)
	if index < 0 or (not force and index == _frame_index):
		return
	if _synchronized_transform_idle:
		_frame_index = index
		var facing_scale := _idle_base_scale * Vector2(_facing_mirror_x(), 1.0)
		_idle_sprite.scale = facing_scale * SYNCHRONIZED_TRANSFORM_IDLE_SCALES[index]
		_idle_sprite.position = _idle_base_position
		return
	if index >= _synchronized_idle_textures.size():
		return
	_apply_animation_frame(
		_frame_playback_token,
		index,
		_synchronized_idle_textures[index]
	)


static func _synchronized_idle_frame_index(clock_msec: int, durations_ms: Array) -> int:
	if durations_ms.is_empty():
		return -1
	var total_duration_ms := 0
	for duration_value in durations_ms:
		total_duration_ms += maxi(1, int(duration_value))
	if total_duration_ms <= 0:
		return -1
	var phase_msec := posmod(clock_msec, total_duration_ms)
	var elapsed_msec := 0
	for index in range(durations_ms.size()):
		elapsed_msec += maxi(1, int(durations_ms[index]))
		if phase_msec < elapsed_msec:
			return index
	return durations_ms.size() - 1


static func _has_uniform_idle_timing(durations_ms: Array) -> bool:
	if durations_ms.size() != SYNCHRONIZED_IDLE_FRAME_COUNT:
		return false
	var total_duration_ms := 0
	for duration_value in durations_ms:
		var duration_ms := int(duration_value)
		if duration_ms != SYNCHRONIZED_IDLE_FRAME_DURATION_MS:
			return false
		total_duration_ms += duration_ms
	return total_duration_ms == SYNCHRONIZED_IDLE_LOOP_DURATION_MS


static func _cached_frame_texture(frame_path: String) -> Texture2D:
	if _frame_texture_cache.has(frame_path):
		return _frame_texture_cache[frame_path] as Texture2D
	var frame_texture := load(frame_path) as Texture2D
	if frame_texture != null:
		_frame_texture_cache[frame_path] = frame_texture
	return frame_texture


func _apply_animation_frame(playback_token: int, index: int, texture_resource: Texture2D) -> void:
	if playback_token != _frame_playback_token or _idle_sprite == null:
		return
	_frame_index = index
	_idle_sprite.texture = texture_resource
	_apply_sprite_facing(_frame_render_scale)
	_idle_sprite.position = _idle_base_position + Vector2(
		0.0,
		_frame_footline_offset_y(texture_resource)
	)


func _frame_footline_offset_y(texture_resource: Texture2D) -> float:
	if _idle_sprite == null or texture_resource == null:
		return 0.0
	var texture_size := texture_resource.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return 0.0
	var fitted_scale := minf(
		_idle_sprite.size.x / texture_size.x,
		_idle_sprite.size.y / texture_size.y
	)
	var fitted_height := texture_size.y * fitted_scale
	var fitted_top := (_idle_sprite.size.y - fitted_height) * 0.5
	var frame_footline_y := fitted_top + fitted_height * _frame_footline_y_ratio
	return (_idle_sprite.pivot_offset.y - frame_footline_y) * _frame_render_scale.y


func _finish_frame_action(playback_token: int) -> void:
	if playback_token != _frame_playback_token or _idle_sprite == null:
		return
	_frame_tween = null
	_frame_action = &""
	_frame_index = -1
	_restore_sprite_pose()
	_restore_sprite_texture()
	refresh_idle_pivot()
	_start_sprite_idle_loop()


func _stop_frame_tween() -> void:
	_frame_playback_token += 1
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	_frame_tween = null
	_frame_action = &""
	_frame_index = -1
	_synchronized_idle_textures.clear()
	_synchronized_idle_durations_ms.clear()
	_synchronized_transform_idle = false
	_frame_render_scale = Vector2.ONE
	_frame_footline_y_ratio = 1.0


func _restore_sprite_texture() -> void:
	if _idle_sprite != null and _base_sprite_texture != null:
		_idle_sprite.texture = _base_sprite_texture


func _frame_profile_for_texture_path(texture_path: String) -> Dictionary:
	_ensure_frame_profiles_loaded()
	if texture_path == "" or not _frame_profiles_by_texture_path.has(texture_path):
		return {}
	return Dictionary(_frame_profiles_by_texture_path[texture_path]).duplicate(true)


func _frame_action_duration(action: StringName, fallback: float = 0.0) -> float:
	if not _frame_profile.has(String(action)):
		return fallback
	var definition := Dictionary(_frame_profile.get(String(action), {}))
	var durations_ms := Array(definition.get("durations_ms", []))
	if durations_ms.is_empty():
		return fallback
	var total_ms := 0.0
	for duration_value in durations_ms:
		total_ms += maxf(float(duration_value), 0.0)
	return total_ms / 1000.0


func _frame_action_release_delay(action: StringName) -> float:
	if not _frame_profile.has(String(action)):
		return 0.0
	var definition := Dictionary(_frame_profile.get(String(action), {}))
	var durations_ms := Array(definition.get("durations_ms", []))
	var release_frame := clampi(int(definition.get("release_frame", 1)), 1, durations_ms.size())
	var total_ms := 0.0
	for index in range(release_frame - 1):
		total_ms += maxf(float(durations_ms[index]), 0.0)
	return total_ms / 1000.0


static func _ensure_frame_profiles_loaded() -> void:
	if _frame_profiles_loaded:
		return
	_frame_profiles_loaded = true
	_frame_profiles_by_texture_path = {}
	if not FileAccess.file_exists(FRAME_ANIMATION_MANIFEST_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FRAME_ANIMATION_MANIFEST_PATH))
	if not (parsed is Dictionary):
		push_warning("Could not parse pet frame animation manifest")
		return
	var manifest := Dictionary(parsed)
	_frame_profiles_by_texture_path = Dictionary(manifest.get("by_texture_path", {})).duplicate(true)
	for alias_path_value in Dictionary(manifest.get("aliases", {})).keys():
		var alias_path := String(alias_path_value)
		var source_path := String(Dictionary(manifest.get("aliases", {}))[alias_path_value])
		if alias_path == "" or not _frame_profiles_by_texture_path.has(source_path):
			push_warning("Invalid pet frame animation alias: %s -> %s" % [alias_path, source_path])
			continue
		_frame_profiles_by_texture_path[alias_path] = Dictionary(
			_frame_profiles_by_texture_path[source_path]
		).duplicate(true)


func get_frame_animation_snapshot() -> Dictionary:
	var actions: Dictionary = {}
	for action_name in _frame_profile.keys():
		var definition := Dictionary(_frame_profile[action_name])
		actions[String(action_name)] = Array(definition.get("frames", [])).size()
	return {
		"source_texture_path": _animation_texture_path,
		"actions": actions,
		"active_action": String(_frame_action),
		"frame_index": _frame_index,
		"render_scale": _frame_render_scale,
		"authored_horizontal_facing": int(_authored_horizontal_facing),
		"horizontal_facing": int(_horizontal_facing),
		"horizontal_facing_locked": _horizontal_facing_locked,
		"uses_transform_idle": _use_transform_idle and _frame_profile.is_empty(),
	}


func _restore_sprite_pose() -> void:
	if _idle_sprite == null:
		return
	_apply_sprite_facing()
	_idle_sprite.pivot_offset = _idle_base_pivot
	_idle_sprite.position = _idle_base_position
	_idle_sprite.rotation = _idle_base_rotation


func refresh_idle_pivot() -> void:
	if _idle_sprite != null:
		_idle_sprite.pivot_offset = _idle_sprite.size * _idle_pivot_ratio


func _stop_sprite_idle() -> void:
	_stop_frame_tween()
	if _idle_sprite != null:
		_horizontal_facing = _authored_horizontal_facing \
			if not is_zero_approx(_authored_horizontal_facing) \
			else DEFAULT_AUTHORED_HORIZONTAL_FACING
		_restore_sprite_pose()
		_restore_sprite_texture()
	_idle_sprite = null
	_base_sprite_texture = null
	_frame_profile = {}
	_use_transform_idle = false
	_animation_texture_path = ""
	_frame_render_scale = Vector2.ONE
	_frame_footline_y_ratio = 1.0
	_authored_horizontal_facing = DEFAULT_AUTHORED_HORIZONTAL_FACING
	_horizontal_facing = DEFAULT_AUTHORED_HORIZONTAL_FACING
	_horizontal_facing_locked = false
	_attack_release_delay = 0.0
	_idle_base_scale = Vector2.ONE
	_idle_base_pivot = Vector2.ZERO
	_idle_base_position = Vector2.ZERO
	_idle_base_rotation = 0.0
	_idle_pivot_ratio = Vector2(0.5, 1.0)


func play_shake(duration: float = 0.22, strength: float = 7.0) -> void:
	if _view == null:
		return
	_base_position = _view.position
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = _view.create_tween()
	_shake_tween.tween_property(_view, "position:x", _base_position.x + strength, duration * 0.18)
	_shake_tween.tween_property(_view, "position:x", _base_position.x - strength, duration * 0.18)
	_shake_tween.tween_property(_view, "position:x", _base_position.x + strength * 0.55, duration * 0.18)
	_shake_tween.tween_property(_view, "position:x", _base_position.x, duration * 0.18)


func play_attack_action(attack_type: String, element_id: String = "fire") -> Node:
	if _view == null:
		return null
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	_hide_all_action_art()
	var normalized_type := attack_type.strip_edges().to_lower()
	var normalized_element := _normalized_element(element_id)
	_last_attack_snapshot = {
		"attack_type": normalized_type,
		"element_id": normalized_element,
		"hit_frame": 4 if normalized_type == "bite" else 1,
	}
	if normalized_type == "bite":
		return _play_bite()
	return _play_element_projectile(normalized_element)


func play_projectile_between(
	element_id: String,
	from_global_center: Vector2,
	to_global_center: Vector2,
	duration: float = 0.32,
	arc_height: float = 96.0
) -> Node:
	if _view == null:
		return null
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	_hide_all_action_art()
	var normalized_element := _normalized_element(element_id)
	_last_attack_snapshot = {
		"attack_type": "projectile",
		"element_id": normalized_element,
		"hit_frame": 1,
	}
	return _play_element_projectile_between(
		normalized_element,
		from_global_center,
		to_global_center,
		duration,
		arc_height
	)


func get_last_attack_snapshot() -> Dictionary:
	return _last_attack_snapshot.duplicate(true)


func _resolve_psd_action_nodes() -> void:
	_bite_frames.clear()
	_projectile = null
	if _view == null:
		return
	for path in BITE_FRAME_PATHS:
		var frame := get_node_or_null(path) as TextureRect
		if frame != null:
			_bite_frames.append(frame)
	_projectile = get_node_or_null("element_projectile/ProjectileArt") as TextureRect


func _play_bite() -> Node:
	if _bite_frames.is_empty():
		return null
	_show_bite_frame(_bite_frames[0])
	_attack_tween = _view.create_tween()
	for index in range(1, _bite_frames.size()):
		_attack_tween.tween_interval(0.055)
		_attack_tween.tween_callback(_show_bite_frame.bind(_bite_frames[index]))
		if index == 3:
			_attack_tween.tween_callback(hit_frame_reached.emit)
	_attack_tween.tween_interval(0.055)
	_attack_tween.tween_callback(_hide_all_action_art)
	return self


func _play_element_projectile(element_id: String) -> Node:
	var projectile := _projectile
	if projectile == null:
		return null
	projectile.texture = PROJECTILE_TEXTURES[element_id]
	_last_attack_snapshot["projectile_node_path"] = String(_view.get_path_to(projectile))
	var authored_rect: Rect2 = PROJECTILE_RECTS[element_id]
	var authored_scale := Vector2(_view.size.x / PSD_CANVAS_SIZE.x, _view.size.y / PSD_CANVAS_SIZE.y)
	projectile.position = Vector2(_view.size.x * 0.46, authored_rect.position.y * authored_scale.y)
	projectile.modulate.a = 1.0
	projectile.visible = false
	_attack_tween = _view.create_tween()
	_attack_tween.tween_interval(_attack_release_delay)
	_attack_tween.tween_callback(_show_projectile.bind(projectile))
	_attack_tween.tween_property(projectile, "position:x", _view.size.x * 0.82, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(projectile, "modulate:a", 0.35, 0.18)
	_attack_tween.tween_callback(_hide_rect.bind(projectile))
	_attack_tween.tween_callback(impact_reached.emit)
	return self


func _play_element_projectile_between(
	element_id: String,
	from_global_center: Vector2,
	to_global_center: Vector2,
	duration: float,
	arc_height: float
) -> Node:
	var projectile := _projectile
	var projectile_parent := projectile.get_parent() as Control if projectile != null else null
	if projectile == null or projectile_parent == null:
		return null
	projectile.texture = PROJECTILE_TEXTURES[element_id]
	_last_attack_snapshot["projectile_node_path"] = String(_view.get_path_to(projectile))
	var parent_inverse := projectile_parent.get_global_transform_with_canvas().affine_inverse()
	var start_center := parent_inverse * from_global_center
	var end_center := parent_inverse * to_global_center
	var arc_offset := (parent_inverse * (from_global_center + Vector2(0.0, -arc_height))) - start_center
	projectile.position = start_center - projectile.size * 0.5
	projectile.modulate.a = 1.0
	projectile.visible = false
	_attack_tween = _view.create_tween()
	_attack_tween.tween_interval(_attack_release_delay)
	_attack_tween.tween_callback(_show_projectile.bind(projectile))
	_attack_tween.tween_method(
		func(weight: float) -> void:
			var center := start_center.lerp(end_center, weight) + arc_offset * (4.0 * weight * (1.0 - weight))
			projectile.position = center - projectile.size * 0.5,
		0.0,
		1.0,
		maxf(duration, 0.01)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_attack_tween.parallel().tween_property(
		projectile,
		"modulate:a",
		0.55,
		maxf(duration, 0.01)
	)
	_attack_tween.tween_callback(_hide_rect.bind(projectile))
	_attack_tween.tween_callback(impact_reached.emit)
	return self


func _show_bite_frame(frame: TextureRect) -> void:
	for current in _bite_frames:
		current.visible = current == frame
	_last_attack_snapshot["frame_node_path"] = String(_view.get_path_to(frame))


func _hide_rect(rect: TextureRect) -> void:
	if rect != null:
		rect.visible = false


func _show_projectile(rect: TextureRect) -> void:
	if rect != null:
		rect.modulate.a = 1.0
		rect.visible = true


func _hide_all_action_art() -> void:
	for rect in _all_action_art():
		rect.visible = false
		rect.modulate = Color.WHITE


func _all_action_art() -> Array[TextureRect]:
	var result: Array[TextureRect] = []
	result.append_array(_bite_frames)
	if _projectile != null:
		result.append(_projectile)
	return result


func _apply_authored_rect(rect: TextureRect, authored_rect: Rect2, authored_scale: Vector2) -> void:
	if rect == null:
		return
	rect.position = authored_rect.position * authored_scale
	rect.size = authored_rect.size * authored_scale


func _normalized_element(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized in ELEMENT_IDS:
		return normalized
	var aliases := {
		"火": "fire",
		"水": "water",
		"地": "earth",
		"土": "earth",
		"风": "wind",
	}
	return String(aliases.get(value, "fire"))
