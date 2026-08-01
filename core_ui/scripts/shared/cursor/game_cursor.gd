extends CanvasLayer

const STATE_POINTER := &"pointer"
const STATE_LOADING := &"loading"
const STATE_PET_HOVER := &"pet_hover"
const STATE_GRABBING := &"grabbing"

const POINTER_TEXTURE := preload("res://art/images/shared/cursors/cursor_pointer_64.png")
const HAND_OPEN_TEXTURE := preload("res://art/images/shared/cursors/hand_frames/hand_00.png")
const HAND_GRAB_TEXTURE := preload("res://art/images/shared/cursors/hand_frames/hand_02.png")
const LOADING_TEXTURES := [
	preload("res://art/images/shared/cursors/hourglass_sand_frames/sand_00.png"),
	preload("res://art/images/shared/cursors/hourglass_sand_frames/sand_01.png"),
	preload("res://art/images/shared/cursors/hourglass_sand_frames/sand_02.png"),
	preload("res://art/images/shared/cursors/hourglass_sand_frames/sand_03.png"),
	preload("res://art/images/shared/cursors/hourglass_sand_frames/sand_04.png"),
	preload("res://art/images/shared/cursors/hourglass_sand_frames/sand_05.png"),
	preload("res://art/images/shared/cursors/hourglass_frames/hourglass_01.png"),
	preload("res://art/images/shared/cursors/hourglass_frames/hourglass_02.png"),
	preload("res://art/images/shared/cursors/hourglass_frames/hourglass_03.png"),
]
const LOADING_FRAME_DURATIONS := [
	0.60, 0.35, 0.35, 0.35, 0.35, 0.45, 0.12, 0.12, 0.12,
]
const POINTER_HOTSPOT := Vector2(15.0, 8.0)
const HAND_HOTSPOT := Vector2(32.0, 34.0)
const LOADING_HOTSPOT := Vector2(32.0, 32.0)
const NATIVE_CURSOR_SHAPES := [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]

@onready var cursor_visual: TextureRect = $CursorVisual

var _state := &""
var _loading_sources: Dictionary = {}
var _pet_hovered := false
var _grabbing := false
var _loading_frame_index := 0
var _loading_elapsed := 0.0
var _hotspot := POINTER_HOTSPOT
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_mouse_mode = Input.mouse_mode
	cursor_visual.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_state()


func _exit_tree() -> void:
	_clear_native_cursors()
	Input.mouse_mode = _previous_mouse_mode


func _process(delta: float) -> void:
	if _state == STATE_LOADING:
		_advance_loading_animation(delta)


func set_loading(active: bool) -> void:
	set_loading_source(&"default", active)


func set_loading_source(source: StringName, active: bool) -> void:
	if active:
		_loading_sources[source] = true
	else:
		_loading_sources.erase(source)
	_refresh_state()


func set_pet_hover(active: bool) -> void:
	_pet_hovered = active
	_refresh_state()


func set_grabbing(active: bool) -> void:
	_grabbing = active
	_refresh_state()


func reset_interaction() -> void:
	_pet_hovered = false
	_grabbing = false
	_refresh_state()


func debug_state() -> StringName:
	return _state


func debug_loading_frame_index() -> int:
	return _loading_frame_index


func _refresh_state() -> void:
	var next_state := STATE_POINTER
	if not _loading_sources.is_empty():
		next_state = STATE_LOADING
	elif _grabbing:
		next_state = STATE_GRABBING
	elif _pet_hovered:
		next_state = STATE_PET_HOVER
	if next_state == _state:
		return
	_state = next_state
	match _state:
		STATE_LOADING:
			_loading_frame_index = 0
			_loading_elapsed = 0.0
			_hotspot = LOADING_HOTSPOT
			cursor_visual.texture = LOADING_TEXTURES[0]
		STATE_GRABBING:
			_hotspot = HAND_HOTSPOT
			cursor_visual.texture = HAND_GRAB_TEXTURE
		STATE_PET_HOVER:
			_hotspot = HAND_HOTSPOT
			cursor_visual.texture = HAND_OPEN_TEXTURE
		_:
			_hotspot = POINTER_HOTSPOT
			cursor_visual.texture = POINTER_TEXTURE
	_apply_native_cursor(cursor_visual.texture, _hotspot)
	set_process(_state == STATE_LOADING)


func _advance_loading_animation(delta: float) -> void:
	_loading_elapsed += delta
	while _loading_elapsed >= LOADING_FRAME_DURATIONS[_loading_frame_index]:
		_loading_elapsed -= LOADING_FRAME_DURATIONS[_loading_frame_index]
		_loading_frame_index = (_loading_frame_index + 1) % LOADING_TEXTURES.size()
		cursor_visual.texture = LOADING_TEXTURES[_loading_frame_index]
		_apply_native_cursor(cursor_visual.texture, _hotspot)


func _apply_native_cursor(texture: Texture2D, hotspot: Vector2) -> void:
	for cursor_shape in NATIVE_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(texture, cursor_shape, hotspot)


func _clear_native_cursors() -> void:
	for cursor_shape in NATIVE_CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(null, cursor_shape)
