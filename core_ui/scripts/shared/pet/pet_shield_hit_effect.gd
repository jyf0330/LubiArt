extends Node
class_name PetShieldHitEffect

const FRAME_DURATION := 0.06
const EFFECT_DISPLAY_SIZE := Vector2(180.0, 180.0)

@export var effect_path := NodePath("../ShieldHitEffectAnchor/ShieldHitEffect")
@export var frames: Array[Texture2D] = []

@onready var _effect: TextureRect = get_node_or_null(effect_path) as TextureRect

var _run_serial := 0
var _playing := false
var _frame_index := -1


func _ready() -> void:
	reset()


func play() -> void:
	reset()
	if _effect == null or frames.is_empty():
		return
	_playing = true
	_layout_effect()
	var serial := _run_serial
	_play_sequence(serial)


func reset() -> void:
	_run_serial += 1
	_playing = false
	_frame_index = -1
	if _effect != null:
		_effect.visible = false


func snapshot() -> Dictionary:
	return {
		"active": _playing,
		"frame_index": _frame_index,
		"effect_visible": _effect != null and _effect.visible,
		"effect_size": _effect.size if _effect != null else Vector2.ZERO,
	}


func _play_sequence(serial: int) -> void:
	for index in range(frames.size()):
		if serial != _run_serial or not is_inside_tree():
			return
		_frame_index = index
		_effect.texture = frames[index]
		_effect.visible = true
		await get_tree().create_timer(FRAME_DURATION, true, false, true).timeout
	if serial == _run_serial:
		reset()


func _layout_effect() -> void:
	var parent_control := _effect.get_parent() as Control
	var anchor_size := parent_control.size if parent_control != null else Vector2(171.0, 144.0)
	_effect.size = EFFECT_DISPLAY_SIZE
	_effect.position = (anchor_size - EFFECT_DISPLAY_SIZE) * 0.5
	_effect.pivot_offset = EFFECT_DISPLAY_SIZE * 0.5
