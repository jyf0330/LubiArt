extends Node
class_name PetHitReaction

const STEP_DURATION := 0.06
const EFFECT_DISPLAY_SIZE := Vector2(145.0, 290.0)
const OFFSETS: Array[float] = [0.0, 2.0, 8.0, 11.0, 7.0, 2.0, -2.0, 1.0]
const SCALE_X: Array[float] = [1.0, 0.94, 0.86, 0.90, 0.96, 1.02, 1.01, 1.0]
const SCALE_Y: Array[float] = [1.0, 1.04, 1.09, 1.06, 1.02, 0.98, 0.99, 1.0]
const FLASH: Array[float] = [0.0, 1.0, 0.72, 0.0, 0.0, 0.0, 0.0, 0.0]

@export var sprite_path := NodePath("../CreatureArt")
@export var effect_path := NodePath("../HitEffectAnchor/BattleHitEffect")
@export var frames: Array[Texture2D] = []

@onready var _sprite: TextureRect = get_node_or_null(sprite_path) as TextureRect
@onready var _effect: TextureRect = get_node_or_null(effect_path) as TextureRect

var _run_serial := 0
var _playing := false
var _frame_index := -1
var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE
var _base_pivot := Vector2.ZERO
var _reaction_direction := Vector2.RIGHT


func _ready() -> void:
	if _sprite != null and _sprite.material != null:
		_sprite.material = _sprite.material.duplicate(true)
	reset()


func play(direction: Vector2 = Vector2.RIGHT, visible_sprite_rect: Rect2 = Rect2()) -> void:
	reset()
	if _sprite == null or _effect == null or frames.size() < 6:
		return
	_playing = true
	_base_position = _sprite.position
	_base_scale = _sprite.scale
	_base_pivot = _sprite.pivot_offset
	_reaction_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var body_rect := visible_sprite_rect
	if body_rect.size.x <= 0.0 or body_rect.size.y <= 0.0:
		body_rect = Rect2(_sprite.position, _sprite.size)
	_sprite.pivot_offset = body_rect.get_center() - _sprite.position
	_layout_effect_at_contact(body_rect)
	var serial := _run_serial
	_play_sequence(serial)


func reset() -> void:
	_run_serial += 1
	if _playing and _sprite != null:
		_sprite.position = _base_position
		_sprite.scale = _base_scale
		_sprite.pivot_offset = _base_pivot
	_playing = false
	_frame_index = -1
	_set_flash(0.0)
	if _effect != null:
		_effect.visible = false


func snapshot() -> Dictionary:
	return {
		"active": _playing,
		"frame_index": _frame_index,
		"effect_visible": _effect != null and _effect.visible,
		"effect_size": _effect.size if _effect != null else Vector2.ZERO,
		"sprite_offset": (_sprite.position - _base_position) if _playing and _sprite != null else Vector2.ZERO,
		"sprite_scale": _sprite.scale if _sprite != null else Vector2.ONE,
		"flash_amount": _flash_amount(),
	}


func _play_sequence(serial: int) -> void:
	for index in range(OFFSETS.size()):
		if serial != _run_serial or not is_inside_tree():
			return
		_apply_step(index)
		await get_tree().create_timer(STEP_DURATION, true, false, true).timeout
	if serial != _run_serial:
		return
	reset()


func _apply_step(index: int) -> void:
	_frame_index = index
	_sprite.position = _base_position + _reaction_direction * OFFSETS[index]
	_sprite.scale = Vector2(_base_scale.x * SCALE_X[index], _base_scale.y * SCALE_Y[index])
	_set_flash(FLASH[index])
	if index < frames.size() and index < 6:
		_effect.texture = frames[index]
		_effect.visible = true
	else:
		_effect.visible = false


func _layout_effect_at_contact(body_rect: Rect2) -> void:
	var body_center := body_rect.get_center()
	var contact_offset := Vector2(
		_reaction_direction.x * body_rect.size.x * 0.44,
		_reaction_direction.y * body_rect.size.y * 0.44
	)
	var contact_point := body_center - contact_offset
	_effect.size = EFFECT_DISPLAY_SIZE
	_effect.position = contact_point - EFFECT_DISPLAY_SIZE * 0.5
	_effect.pivot_offset = EFFECT_DISPLAY_SIZE * 0.5


func _set_flash(amount: float) -> void:
	if _sprite == null:
		return
	var shader_material := _sprite.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter("flash_amount", clampf(amount, 0.0, 1.0))


func _flash_amount() -> float:
	if _sprite == null:
		return 0.0
	var shader_material := _sprite.material as ShaderMaterial
	if shader_material == null:
		return 0.0
	return float(shader_material.get_shader_parameter("flash_amount"))
