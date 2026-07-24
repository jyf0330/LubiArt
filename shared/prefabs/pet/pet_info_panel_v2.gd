extends Control
class_name PetInfoPanelV2

signal info_updated(snapshot: Dictionary)

const SOURCE_PSD := "/Users/ywh/Downloads/宠物信息栏2.psd"
const SOURCE_CANVAS_SIZE := Vector2(476.0, 539.0)
const COMPONENT_SOURCE := "res://shared/prefabs/pet/pet_info_panel_v2.tscn"
const ATTACK_COLUMNS := 7
const ATTACK_ROWS := 3
const ATTACK_ORIGIN_INDEX := 10
const ATTACK_CELL_SIZE := Vector2(51.0, 48.0)
const ATTACK_CELL_INSET := Vector2(1.0, 2.0)

@onready var _name_label: Label = $NameLabel
@onready var _attack_overlay: Control = $AttackOverlay
@onready var _frame_bronze: TextureRect = $FrameBronze
@onready var _frame_silver: TextureRect = $FrameSilver
@onready var _hp_value: Label = $Stats/HpValue
@onready var _attack_value: Label = $Stats/AttackValue
@onready var _ap_value: Label = $Stats/ApValue
@onready var _defense_value: Label = $Stats/DefenseValue
@onready var _shield_value: Label = $Stats/ShieldValue
@onready var _regen_value: Label = $Stats/RegenValue

var _snapshot: Dictionary = {}
var _target_cell_indices: Array[int] = []
var _portrait_texture: Texture2D = null


func _ready() -> void:
	set_info({
		"name": "李元芳",
		"quality": "白银",
		"hp": 24,
		"max_hp": 24,
		"attack": 4,
		"ap": 3,
		"max_ap": 5,
		"defense": 2,
		"shield": 3,
		"regen": 1,
		"attack_shape": {
			"offsets": [
				{"dr": 0, "dc": 2},
				{"dr": 0, "dc": 3},
			]
		},
	})


func set_info(record: Dictionary, texture: Texture2D = null) -> Dictionary:
	_snapshot = _normalize_record(record)
	_portrait_texture = texture
	_name_label.text = String(_snapshot.get("name", "未知宠物"))
	_hp_value.text = "%d/%d" % [int(_snapshot.get("hp", 0)), int(_snapshot.get("max_hp", 0))]
	_attack_value.text = str(int(_snapshot.get("attack", 0)))
	_ap_value.text = "%d/%d" % [int(_snapshot.get("ap", 0)), int(_snapshot.get("max_ap", 0))]
	_defense_value.text = str(int(_snapshot.get("defense", 0)))
	_shield_value.text = str(int(_snapshot.get("shield", 0)))
	_regen_value.text = str(int(_snapshot.get("regen", 0)))
	_apply_quality(String(_snapshot.get("quality", "白银")))
	_render_attack_shape(Dictionary(_snapshot.get("attack_shape", {})))
	info_updated.emit(get_info_snapshot())
	return get_info_snapshot()


func get_info_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_attack_shape_cell_count() -> int:
	return ATTACK_COLUMNS * ATTACK_ROWS


func get_target_cell_indices() -> Array[int]:
	return _target_cell_indices.duplicate()


func get_source_canvas_size() -> Vector2:
	return SOURCE_CANVAS_SIZE


func get_source_psd() -> String:
	return SOURCE_PSD


func get_component_source() -> String:
	return COMPONENT_SOURCE


func get_display_text() -> String:
	return "\n".join([
		String(_snapshot.get("name", "未知宠物")),
		"%s · %s" % [_snapshot.get("element", "未知元素"), _snapshot.get("quality", "白银")],
		"生命 %s/%s    攻击力 %s    防御 %s" % [_snapshot.get("hp", 0), _snapshot.get("max_hp", 0), _snapshot.get("attack", 0), _snapshot.get("defense", 0)],
		"护盾 %s    AP %s/%s    再生 %s" % [_snapshot.get("shield", 0), _snapshot.get("ap", 0), _snapshot.get("max_ap", 0), _snapshot.get("regen", 0)],
	])


func _normalize_record(record: Dictionary) -> Dictionary:
	var hp := int(_first_value(record, ["hp", "current_hp", "currentHp"], 0))
	var max_hp := int(_first_value(record, ["max_hp", "maxHp", "hp_max"], hp))
	var ap := int(_first_value(record, ["ap", "available_ap", "current_ap", "currentAp"], 0))
	var max_ap := int(_first_value(record, ["max_ap", "maxAp", "ap_max"], ap))
	return {
		"id": String(_first_value(record, ["id", "pet_id", "unit_id"], "")),
		"name": String(_first_value(record, ["name", "display_name", "title"], "未知宠物")),
		"element": String(_first_value(record, ["element", "element_name"], "未知元素")),
		"quality": String(_first_value(record, ["quality", "rarity", "tier"], "白银")),
		"hp": hp,
		"max_hp": max_hp,
		"attack": int(_first_value(record, ["attack", "atk", "power"], 0)),
		"ap": ap,
		"max_ap": max_ap,
		"defense": int(_first_value(record, ["defense", "def", "resistance"], 0)),
		"shield": int(_first_value(record, ["shield", "armor"], 0)),
		"regen": int(_first_value(record, ["regen", "regeneration", "heal_per_round"], 0)),
		"attack_shape": Dictionary(record.get("attack_shape", {})).duplicate(true),
	}


func _apply_quality(quality: String) -> void:
	var normalized := quality.strip_edges().to_lower()
	var bronze := normalized.contains("bronze") or quality.contains("青铜")
	_frame_bronze.visible = bronze
	_frame_silver.visible = not bronze


func _render_attack_shape(shape: Dictionary) -> void:
	for child in _attack_overlay.get_children():
		child.free()
	_target_cell_indices.clear()

	var origin := TextureRect.new()
	origin.name = "OriginMarker"
	origin.texture = _portrait_texture if _portrait_texture != null else preload("res://assets/artist_ui/pet_info_panel_v2/attack_origin.png")
	origin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	origin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	origin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	origin.position = _marker_position(ATTACK_ORIGIN_INDEX, origin.texture.get_size())
	origin.size = origin.texture.get_size()
	_attack_overlay.add_child(origin)

	for offset_value in Array(shape.get("offsets", [])):
		var offset := Dictionary(offset_value)
		var row := int(offset.get("dr", 0)) + 1
		var column := int(offset.get("dc", 0)) + 3
		if row < 0 or row >= ATTACK_ROWS or column < 0 or column >= ATTACK_COLUMNS:
			continue
		var index := row * ATTACK_COLUMNS + column
		if index == ATTACK_ORIGIN_INDEX or _target_cell_indices.has(index):
			continue
		_target_cell_indices.append(index)

	_target_cell_indices.sort()
	for index in _target_cell_indices:
		var target := TextureRect.new()
		target.name = "TargetCell%02d" % index
		target.texture = preload("res://assets/artist_ui/pet_info_panel_v2/attack_target.png")
		target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		target.stretch_mode = TextureRect.STRETCH_SCALE
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.position = _cell_position(index)
		target.size = ATTACK_CELL_SIZE
		_attack_overlay.add_child(target)


func _cell_position(index: int) -> Vector2:
	var row := index / ATTACK_COLUMNS
	var column := index % ATTACK_COLUMNS
	return ATTACK_CELL_INSET + Vector2(column * ATTACK_CELL_SIZE.x, row * ATTACK_CELL_SIZE.y)


func _marker_position(index: int, marker_size: Vector2) -> Vector2:
	return _cell_position(index) + (ATTACK_CELL_SIZE - marker_size) * 0.5


func _first_value(record: Dictionary, keys: Array[String], fallback: Variant) -> Variant:
	for key in keys:
		if record.has(key) and record.get(key) != null:
			return record.get(key)
	return fallback
