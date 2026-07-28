extends Control
class_name PetAnimation

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
const LANDING_RECTS := {
	"fire": Rect2(164.0, 24.0, 85.0, 105.0),
	"water": Rect2(156.0, 25.0, 101.0, 102.0),
	"earth": Rect2(155.0, 23.0, 102.0, 103.0),
	"wind": Rect2(157.0, 27.0, 99.0, 91.0),
}

var _view: Control = null
var _base_position := Vector2.ZERO
var _shake_tween: Tween = null
var _move_tween: Tween = null
var _attack_tween: Tween = null
var _bite_frames: Array[TextureRect] = []
var _projectiles: Dictionary = {}
var _landings: Dictionary = {}
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
	for element_id in ELEMENT_IDS:
		_apply_authored_rect(
			_projectiles.get(element_id, null) as TextureRect,
			PROJECTILE_RECTS[element_id],
			authored_scale
		)
		_apply_authored_rect(
			_landings.get(element_id, null) as TextureRect,
			LANDING_RECTS[element_id],
			authored_scale
		)


func reset() -> void:
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
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = _view.create_tween()
	_move_tween.tween_property(_view, "position", target_position, maxf(duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func play_attack_action(attack_type: String, element_id: String = "fire") -> void:
	if _view == null:
		return
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
		_play_bite()
	else:
		_play_element_projectile(normalized_element)


func get_last_attack_snapshot() -> Dictionary:
	return _last_attack_snapshot.duplicate(true)


func _resolve_psd_action_nodes() -> void:
	_bite_frames.clear()
	_projectiles.clear()
	_landings.clear()
	if _view == null:
		return
	for path in BITE_FRAME_PATHS:
		var frame := get_node_or_null(path) as TextureRect
		if frame != null:
			_bite_frames.append(frame)
	for element_id in ELEMENT_IDS:
		_projectiles[element_id] = get_node_or_null(
			"element_projectile/ProjectileVariants/%s/ProjectileArt" % element_id
		) as TextureRect
		_landings[element_id] = get_node_or_null(
			"element_projectile/LandingTileVariants/%s/TileArt" % element_id
		) as TextureRect


func _play_bite() -> void:
	if _bite_frames.is_empty():
		return
	_show_bite_frame(_bite_frames[0])
	_attack_tween = _view.create_tween()
	for frame in _bite_frames.slice(1):
		_attack_tween.tween_interval(0.055)
		_attack_tween.tween_callback(_show_bite_frame.bind(frame))
	_attack_tween.tween_interval(0.055)
	_attack_tween.tween_callback(_hide_all_action_art)


func _play_element_projectile(element_id: String) -> void:
	var projectile := _projectiles.get(element_id, null) as TextureRect
	var landing := _landings.get(element_id, null) as TextureRect
	if projectile == null or landing == null:
		return
	_last_attack_snapshot["projectile_node_path"] = String(_view.get_path_to(projectile))
	var authored_rect: Rect2 = PROJECTILE_RECTS[element_id]
	var authored_scale := Vector2(_view.size.x / PSD_CANVAS_SIZE.x, _view.size.y / PSD_CANVAS_SIZE.y)
	projectile.position = Vector2(_view.size.x * 0.46, authored_rect.position.y * authored_scale.y)
	projectile.modulate.a = 1.0
	projectile.visible = true
	landing.visible = false
	_attack_tween = _view.create_tween()
	_attack_tween.tween_property(projectile, "position:x", _view.size.x * 0.82, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_attack_tween.parallel().tween_property(projectile, "modulate:a", 0.35, 0.18)
	_attack_tween.tween_callback(_show_landing.bind(projectile, landing))
	_attack_tween.tween_interval(0.11)
	_attack_tween.tween_callback(_hide_rect.bind(landing))


func _show_bite_frame(frame: TextureRect) -> void:
	for current in _bite_frames:
		current.visible = current == frame
	_last_attack_snapshot["frame_node_path"] = String(_view.get_path_to(frame))


func _show_landing(projectile: TextureRect, landing: TextureRect) -> void:
	projectile.visible = false
	landing.visible = true
	_last_attack_snapshot["landing_node_path"] = String(_view.get_path_to(landing))


func _hide_rect(rect: TextureRect) -> void:
	if rect != null:
		rect.visible = false


func _hide_all_action_art() -> void:
	for rect in _all_action_art():
		rect.visible = false
		rect.modulate = Color.WHITE


func _all_action_art() -> Array[TextureRect]:
	var result: Array[TextureRect] = []
	result.append_array(_bite_frames)
	for element_id in ELEMENT_IDS:
		var projectile := _projectiles.get(element_id, null) as TextureRect
		var landing := _landings.get(element_id, null) as TextureRect
		if projectile != null:
			result.append(projectile)
		if landing != null:
			result.append(landing)
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
