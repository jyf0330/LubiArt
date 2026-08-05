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
const EARTH_SLIME_TEXTURE_PATH := "res://art/images/shared/pets/sheets/slices/pet_style_005_earth_slime.png"
const FRAME_ANIMATION_MANIFEST_PATH := "res://art/manifests/shared/pets/animations/pet_frame_animation_manifest.json"
const EARTH_SLIME_IDLE_SQUASH := Vector2(1.035, 0.960)
const EARTH_SLIME_IDLE_STRETCH := Vector2(0.985, 1.020)
static var _frame_profiles_loaded := false
static var _frame_profiles_by_texture_path: Dictionary = {}
var _view: Control = null
var _base_position := Vector2.ZERO
var _shake_tween: Tween = null
var _move_tween: Tween = null
var _attack_tween: Tween = null
var _idle_tween: Tween = null
var _sprite_action_tween: Tween = null
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
var _animation_texture_path := ""
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
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	_shake_tween = null
	_move_tween = null
	_attack_tween = null
	_last_attack_snapshot = {}
	_hide_all_action_art()


func play_sprite_idle(
	sprite: TextureRect,
	texture_resource: Texture2D,
	visible_foot_pivot: Vector2 = Vector2(-1.0, -1.0),
	animation_texture_path: String = ""
) -> void:
	_stop_sprite_idle()
	if sprite == null or texture_resource == null:
		return
	_idle_sprite = sprite
	_base_sprite_texture = texture_resource
	_animation_texture_path = animation_texture_path if animation_texture_path != "" else texture_resource.resource_path
	_frame_profile = _frame_profile_for_texture_path(_animation_texture_path)
	_idle_base_scale = sprite.scale
	_idle_base_pivot = sprite.pivot_offset
	_idle_base_position = sprite.position
	_idle_base_rotation = sprite.rotation
	_idle_pivot_ratio = Vector2(0.5, 1.0)
	if visible_foot_pivot.x >= 0.0 and visible_foot_pivot.y >= 0.0 \
			and sprite.size.x > 0.0 and sprite.size.y > 0.0:
		_idle_pivot_ratio = visible_foot_pivot / sprite.size
	refresh_idle_pivot()
	_start_sprite_idle_loop()


func _start_sprite_idle_loop() -> void:
	if _idle_sprite == null:
		return
	if _play_frame_action(&"idle", true):
		return
	if _animation_texture_path != EARTH_SLIME_TEXTURE_PATH:
		return
	var sprite := _idle_sprite
	_idle_tween = sprite.create_tween().set_loops()
	_idle_tween.tween_interval(0.55)
	_idle_tween.tween_property(
		sprite,
		"scale",
		_idle_base_scale * EARTH_SLIME_IDLE_SQUASH,
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_idle_tween.tween_property(
		sprite,
		"scale",
		_idle_base_scale * EARTH_SLIME_IDLE_STRETCH,
		0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_idle_tween.tween_property(
		sprite,
		"scale",
		_idle_base_scale * Vector2(1.005, 0.995),
		0.16
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(sprite, "scale", _idle_base_scale, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_idle_tween.tween_interval(0.70)


func play_sprite_attack(direction: Vector2, duration: float = 0.42) -> void:
	if not _begin_sprite_action():
		return
	_attack_release_delay = 0.0
	if _play_frame_action(&"attack", false):
		_attack_release_delay = _frame_action_release_delay(&"attack")
		return
	var sprite := _idle_sprite
	var direction_sign := -1.0 if direction.x < 0.0 else 1.0
	var safe_duration := maxf(duration, 0.18)
	var charge_duration := safe_duration * 0.34
	var release_duration := safe_duration * 0.20
	var recover_duration := safe_duration - charge_duration - release_duration
	_sprite_action_tween = sprite.create_tween()
	_sprite_action_tween.tween_property(
		sprite,
		"scale",
		_idle_base_scale * Vector2(1.06, 0.94),
		charge_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_sprite_action_tween.parallel().tween_property(
		sprite,
		"rotation",
		_idle_base_rotation - direction_sign * 0.025,
		charge_duration
	)
	_sprite_action_tween.tween_property(
		sprite,
		"scale",
		_idle_base_scale * Vector2(1.02, 0.98),
		release_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sprite_action_tween.parallel().tween_property(
		sprite,
		"rotation",
		_idle_base_rotation - direction_sign * 0.045,
		release_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sprite_action_tween.parallel().tween_property(
		sprite,
		"position:x",
		_idle_base_position.x - direction_sign * 5.0,
		release_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sprite_action_tween.tween_property(
		sprite,
		"scale",
		_idle_base_scale,
		recover_duration
	).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_sprite_action_tween.parallel().tween_property(
		sprite,
		"rotation",
		_idle_base_rotation,
		recover_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sprite_action_tween.parallel().tween_property(
		sprite,
		"position:x",
		_idle_base_position.x,
		recover_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sprite_action_tween.finished.connect(_finish_sprite_action.bind(sprite))


func play_sprite_move(direction: Vector2, duration: float = 0.36) -> void:
	if not _begin_sprite_action():
		return
	if _play_frame_action(&"move", false):
		return
	var sprite := _idle_sprite
	var direction_sign := -1.0 if direction.x < 0.0 else 1.0
	var safe_duration := maxf(duration, 0.18)
	var lift_duration := safe_duration * 0.38
	var land_duration := safe_duration * 0.27
	var settle_duration := safe_duration - lift_duration - land_duration
	var hop_height := clampf(sprite.size.y * 0.055, 4.0, 9.0)
	_sprite_action_tween = sprite.create_tween()
	_sprite_action_tween.tween_property(
		sprite,
		"position:y",
		_idle_base_position.y - hop_height,
		lift_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sprite_action_tween.parallel().tween_property(
		sprite,
		"scale",
		_idle_base_scale * Vector2(0.96, 1.06),
		lift_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sprite_action_tween.parallel().tween_property(
		sprite,
		"rotation",
		_idle_base_rotation + direction_sign * 0.035,
		lift_duration
	)
	_sprite_action_tween.tween_property(
		sprite,
		"position:y",
		_idle_base_position.y,
		land_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_sprite_action_tween.parallel().tween_property(
		sprite,
		"scale",
		_idle_base_scale * Vector2(1.08, 0.92),
		land_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_sprite_action_tween.tween_property(
		sprite,
		"scale",
		_idle_base_scale,
		settle_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sprite_action_tween.parallel().tween_property(
		sprite,
		"rotation",
		_idle_base_rotation,
		settle_duration
	)
	_sprite_action_tween.finished.connect(_finish_sprite_action.bind(sprite))


func _begin_sprite_action() -> bool:
	if _idle_sprite == null:
		return false
	_stop_frame_tween()
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	if _sprite_action_tween != null and _sprite_action_tween.is_valid():
		_sprite_action_tween.kill()
	_sprite_action_tween = null
	_restore_sprite_pose()
	_restore_sprite_texture()
	refresh_idle_pivot()
	return true


func _finish_sprite_action(sprite: TextureRect) -> void:
	if sprite != _idle_sprite:
		return
	_sprite_action_tween = null
	_restore_sprite_pose()
	_restore_sprite_texture()
	refresh_idle_pivot()
	_start_sprite_idle_loop()


func _play_frame_action(action: StringName, loop: bool) -> bool:
	if _idle_sprite == null or not _frame_profile.has(String(action)):
		return false
	var definition := Dictionary(_frame_profile.get(String(action), {}))
	var frame_paths := Array(definition.get("frames", []))
	var durations_ms := Array(definition.get("durations_ms", []))
	if frame_paths.is_empty() or frame_paths.size() != durations_ms.size():
		push_warning("Invalid pet frame animation '%s' for %s" % [action, _animation_texture_path])
		return false
	var frame_textures: Array = []
	for frame_path_value in frame_paths:
		var frame_path := String(frame_path_value)
		var frame_texture := load(frame_path) as Texture2D
		if frame_texture == null:
			push_warning("Missing pet animation frame: %s" % frame_path)
			return false
		frame_textures.append(frame_texture)
	_stop_frame_tween()
	_frame_playback_token += 1
	var playback_token := _frame_playback_token
	_frame_action = action
	_frame_index = -1
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


func _apply_animation_frame(playback_token: int, index: int, texture_resource: Texture2D) -> void:
	if playback_token != _frame_playback_token or _idle_sprite == null:
		return
	_frame_index = index
	_idle_sprite.texture = texture_resource


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


func get_move_animation_duration(fallback: float = 0.22) -> float:
	return _frame_action_duration(&"move", fallback)


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
	_frame_profiles_by_texture_path = Dictionary(parsed).get("by_texture_path", {})


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
	}


func _restore_sprite_pose() -> void:
	if _idle_sprite == null:
		return
	_idle_sprite.scale = _idle_base_scale
	_idle_sprite.pivot_offset = _idle_base_pivot
	_idle_sprite.position = _idle_base_position
	_idle_sprite.rotation = _idle_base_rotation


func refresh_idle_pivot() -> void:
	if _idle_sprite != null:
		_idle_sprite.pivot_offset = _idle_sprite.size * _idle_pivot_ratio


func _stop_sprite_idle() -> void:
	_stop_frame_tween()
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	if _sprite_action_tween != null and _sprite_action_tween.is_valid():
		_sprite_action_tween.kill()
	_sprite_action_tween = null
	if _idle_sprite != null:
		_restore_sprite_pose()
		_restore_sprite_texture()
	_idle_sprite = null
	_base_sprite_texture = null
	_frame_profile = {}
	_animation_texture_path = ""
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


func move_to_position(target_position: Vector2, duration: float = 0.22) -> void:
	if _view == null:
		return
	play_sprite_move(target_position - _view.position, duration)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = _view.create_tween()
	_move_tween.tween_property(_view, "position", target_position, maxf(duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
