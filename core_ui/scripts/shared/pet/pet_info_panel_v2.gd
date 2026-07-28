extends Control
class_name PetInfoPanelV2

signal info_updated(snapshot: Dictionary)
signal confirm_requested(command: Dictionary)

const SOURCE_PSD := "/Users/ywh/Downloads/宠物信息栏实装.psd"
const SOURCE_CANVAS_SIZE := Vector2(476.0, 539.0)
const COMPONENT_SOURCE := "res://art/prefabs/pet/pet_detail.tscn"
const ATTACK_COLUMNS := 7
const ATTACK_ROWS := 3
const ATTACK_ORIGIN_INDEX := 10
const ATTACK_CELL_SIZE := Vector2(383.0 / 7.0, 152.0 / 3.0)
const ATTACK_CELL_INSET := Vector2.ZERO
const TARGET_MARKER_SIZE := Vector2(54.0, 48.0)
const ELEMENT_TEXTURES := {
	"water": preload("res://art/images/shared/pets/info_panel/element_water.png"),
	"fire": preload("res://art/images/shared/pets/info_panel/element_fire.png"),
	"wind": preload("res://art/images/shared/pets/info_panel/element_wind.png"),
	"earth": preload("res://art/images/shared/pets/info_panel/element_earth.png"),
}
const QUALITY_LAYERS := {
	"bronze": {
		"base": preload("res://art/images/shared/pets/info_panel/panel_base_bronze.png"),
		"attack": preload("res://art/images/shared/pets/info_panel/attack_grid_bronze.png"),
		"stats": preload("res://art/images/shared/pets/info_panel/stat_slots_bronze.png"),
		"frame": preload("res://art/images/shared/pets/info_panel/frame_bronze.png"),
		"attack_position": Vector2(46.0, 145.0),
		"frame_position": Vector2(11.0, 14.0),
	},
	"silver": {
		"base": preload("res://art/images/shared/pets/info_panel/panel_base_silver.png"),
		"attack": preload("res://art/images/shared/pets/info_panel/attack_grid_silver.png"),
		"stats": preload("res://art/images/shared/pets/info_panel/stat_slots_silver.png"),
		"frame": preload("res://art/images/shared/pets/info_panel/frame_silver.png"),
		"attack_position": Vector2(46.0, 145.0),
		"frame_position": Vector2(4.0, 5.0),
	},
	"gold": {
		"base": preload("res://art/images/shared/pets/info_panel/panel_base_gold.png"),
		"attack": preload("res://art/images/shared/pets/info_panel/attack_grid_gold.png"),
		"stats": preload("res://art/images/shared/pets/info_panel/stat_slots_gold.png"),
		"frame": preload("res://art/images/shared/pets/info_panel/frame_gold.png"),
		"attack_position": Vector2(46.0, 146.0),
		"frame_position": Vector2(7.0, 14.0),
	},
	"crystal": {
		"base": preload("res://art/images/shared/pets/info_panel/panel_base_crystal.png"),
		"attack": preload("res://art/images/shared/pets/info_panel/attack_grid_crystal.png"),
		"stats": preload("res://art/images/shared/pets/info_panel/stat_slots_crystal.png"),
		"frame": preload("res://art/images/shared/pets/info_panel/frame_crystal.png"),
		"attack_position": Vector2(46.0, 146.0),
		"frame_position": Vector2(0.0, -7.0),
	},
}

@onready var _name_label: Label = $PetName
@onready var _element_icon: TextureRect = $ElementArt
@onready var _attack_overlay: Control = $AttackFormatPlate/AttackOverlay
@onready var _base_art: TextureRect = $BaseArt
@onready var _attack_format_plate: TextureRect = $AttackFormatPlate
@onready var _stat_slot_art: TextureRect = $StatSlotArt
@onready var _frame_art: TextureRect = $FrameArt
@onready var _hp_value: Label = $StatsUI/HpValue
@onready var _attack_value: Label = $StatsUI/AttackValue
@onready var _ap_value: Label = $StatsUI/ApValue
@onready var _defense_value: Label = $StatsUI/DefenseValue
@onready var _shield_value: Label = $StatsUI/ShieldValue
@onready var _regen_value: Label = $StatsUI/RegenValue

var _snapshot: Dictionary = {}
var _target_cell_indices: Array[int] = []
var _portrait_texture: Texture2D = null
var _confirm_command: Dictionary = {}
var _is_context_detail := false

@onready var _close_button: Button = get_node_or_null("Actions/CloseButton") as Button
@onready var _confirm_button: Button = get_node_or_null("Actions/ConfirmButton") as Button


func _ready() -> void:
	if _close_button != null and not _close_button.pressed.is_connected(close):
		_close_button.pressed.connect(close)
	if _confirm_button != null and not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)
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


func show_detail(record: Dictionary, texture: Texture2D = null, confirm_command: Dictionary = {}) -> void:
	_is_context_detail = false
	_confirm_command = confirm_command.duplicate(true)
	set_info(record, texture)
	if _close_button != null:
		_close_button.visible = true
	if _confirm_button != null:
		_confirm_button.visible = not _confirm_command.is_empty()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	move_to_front()


func show_context_detail(record: Dictionary, texture: Texture2D = null) -> void:
	show_detail(record, texture)
	_is_context_detail = true
	if _close_button != null:
		_close_button.visible = false
	if _confirm_button != null:
		_confirm_button.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func close() -> void:
	visible = false
	_confirm_command.clear()
	_is_context_detail = false


func close_context_detail() -> void:
	if _is_context_detail:
		close()


func is_context_detail() -> bool:
	return _is_context_detail


func get_detail_snapshot() -> Dictionary:
	return get_info_snapshot()


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
	_apply_element(String(_snapshot.get("element", "")))
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


func _on_confirm_pressed() -> void:
	if _confirm_command.is_empty():
		return
	var command := _confirm_command.duplicate(true)
	close()
	confirm_requested.emit(command)


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
	var tier := "silver"
	if normalized.contains("bronze") or quality.contains("青铜"):
		tier = "bronze"
	elif normalized.contains("gold") or quality.contains("黄金"):
		tier = "gold"
	elif normalized.contains("crystal") or normalized.contains("diamond") or quality.contains("水晶"):
		tier = "crystal"
	var layers: Dictionary = QUALITY_LAYERS[tier]
	_apply_image_root(_base_art, layers["base"] as Texture2D, Vector2(28.0, 29.0))
	_apply_image_root(
		_attack_format_plate,
		layers["attack"] as Texture2D,
		layers["attack_position"] as Vector2
	)
	_apply_image_root(_stat_slot_art, layers["stats"] as Texture2D, Vector2(49.0, 308.0))
	_apply_image_root(
		_frame_art,
		layers["frame"] as Texture2D,
		layers["frame_position"] as Vector2
	)


func _apply_element(element: String) -> void:
	var normalized := element.strip_edges().to_lower()
	var texture_key := ""
	if normalized in ["water", "水"]:
		texture_key = "water"
	elif normalized in ["fire", "火"]:
		texture_key = "fire"
	elif normalized in ["wind", "风"]:
		texture_key = "wind"
	elif normalized in ["earth", "土"]:
		texture_key = "earth"
	_element_icon.visible = ELEMENT_TEXTURES.has(texture_key)
	if _element_icon.visible:
		_apply_image_root(
			_element_icon,
			ELEMENT_TEXTURES[texture_key] as Texture2D,
			Vector2(371.0, 18.0)
		)


func _apply_image_root(node: TextureRect, image: Texture2D, authored_position: Vector2) -> void:
	node.texture = image
	node.position = authored_position
	node.size = image.get_size()


func _render_attack_shape(shape: Dictionary) -> void:
	for child in _attack_overlay.get_children():
		child.free()
	_target_cell_indices.clear()

	var origin := TextureRect.new()
	origin.name = "OriginMarker"
	origin.texture = _portrait_texture if _portrait_texture != null else preload("res://art/images/shared/pets/info_panel/attack_origin.png")
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
		target.texture = preload("res://art/images/shared/pets/info_panel/attack_target.png")
		target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		target.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.position = _marker_position(index, TARGET_MARKER_SIZE)
		target.size = TARGET_MARKER_SIZE
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
