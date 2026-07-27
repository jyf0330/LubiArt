extends Sprite2D

const ARTIST_PROJECTILE_SCALE := 0.45

var _start_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _arc_height := 96.0


func play(texture_resource: Texture2D, from_position: Vector2, to_position: Vector2, duration: float = 0.32, arc_height: float = 96.0) -> void:
	texture = texture_resource
	centered = true
	scale = Vector2.ONE * ARTIST_PROJECTILE_SCALE
	_start_position = from_position
	_target_position = to_position
	_arc_height = arc_height
	position = _start_position
	var tween := create_tween()
	tween.tween_method(_set_arc_progress, 0.0, 1.0, maxf(duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)


func _set_arc_progress(progress: float) -> void:
	var base := _start_position.lerp(_target_position, progress)
	var lift := sin(progress * PI) * _arc_height
	position = base + Vector2(0.0, -lift)
	var tangent := _arc_tangent(progress)
	if tangent.length() > 0.001:
		rotation = tangent.angle()


func _arc_tangent(progress: float) -> Vector2:
	var horizontal := _target_position - _start_position
	var lift_delta := cos(progress * PI) * PI * -_arc_height
	return horizontal + Vector2(0.0, lift_delta)
