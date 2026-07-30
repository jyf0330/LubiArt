extends SceneTree

const MAIN_SCENE := preload("res://art/scenes/three_choice/three_choice_scene.tscn")
const SETTLE_FRAMES := 8

var _request_path := ""
var _last_request := ""
var _pending_output := ""
var _frames_remaining := 0


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_start")


func _start() -> void:
	_request_path = OS.get_environment("UI_CAPTURE_REQUEST").strip_edges()
	if _request_path == "":
		push_error("FIVE_OPERATION_CAPTURE_FAIL: UI_CAPTURE_REQUEST is required")
		quit(1)
		return
	root.add_child(MAIN_SCENE.instantiate())
	print("FIVE_OPERATION_CAPTURE_READY")


func _process(_delta: float) -> bool:
	if _request_path == "":
		return false
	if FileAccess.file_exists(_request_path):
		var request := FileAccess.get_file_as_string(_request_path).strip_edges()
		if request == "QUIT":
			quit(0)
			return true
		if request != "" and request != _last_request:
			_last_request = request
			_pending_output = request
			_frames_remaining = SETTLE_FRAMES
	if _frames_remaining > 0:
		_frames_remaining -= 1
		if _frames_remaining == 0:
			_save_capture(_pending_output)
	return false


func _save_capture(output_path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var save_error := root.get_texture().get_image().save_png(absolute_path)
	if save_error != OK:
		push_error("FIVE_OPERATION_CAPTURE_FAIL: %s" % error_string(save_error))
		quit(1)
		return
	print("FIVE_OPERATION_CAPTURE_SAVED: %s" % absolute_path)
