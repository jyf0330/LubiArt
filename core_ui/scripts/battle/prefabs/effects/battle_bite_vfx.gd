extends TextureRect

signal hit_frame_reached
signal finished

var _frames: Array = []
var _durations: Array = []
var _hit_frame_index := 3
var _playing := false
var _hit_emitted := false


func play(frames: Array, frame_durations: Array = [], hit_frame_index: int = 3) -> void:
	_frames = frames.duplicate()
	_durations = frame_durations.duplicate()
	_hit_frame_index = hit_frame_index
	_hit_emitted = false
	if _frames.is_empty():
		_emit_hit_if_needed()
		finished.emit()
		queue_free()
		return
	_playing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	await _play_frames()


func _play_frames() -> void:
	for index in range(_frames.size()):
		if not _playing:
			return
		texture = _frames[index] as Texture2D
		if index + 1 == _hit_frame_index and not _hit_emitted:
			_emit_hit_if_needed()
		var duration := 0.067
		if index < _durations.size():
			duration = float(_durations[index])
		await get_tree().create_timer(maxf(duration, 0.01)).timeout
	_playing = false
	_emit_hit_if_needed()
	finished.emit()
	queue_free()


func _emit_hit_if_needed() -> void:
	if _hit_emitted:
		return
	_hit_emitted = true
	hit_frame_reached.emit()
