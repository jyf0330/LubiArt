@tool
extends Control
class_name PetInfoPanelV2

signal info_updated(snapshot: Dictionary)
signal confirm_requested(command: Dictionary)

const SOURCE_PSD := "宠物信息栏实装(修改).psd"
const SOURCE_CANVAS_SIZE := Vector2(476.0, 539.0)
const COMPONENT_SOURCE := "res://art/prefabs/pet/sprite_info_card.tscn"
const ATTACK_COLUMNS := 7
const ATTACK_ROWS := 3
const ATTACK_ORIGIN_INDEX := 10
const ATTACK_CELL_SIZE := Vector2(383.0 / 7.0, 152.0 / 3.0)
const ATTACK_CELL_INSET := Vector2.ZERO
const ORIGIN_MARKER_SIZE := Vector2(43.0, 42.0)
const TARGET_MARKER_SIZE := Vector2(54.0, 48.0)
const ATTACK_FORMAT_ART_SIZE := Vector2(383.0, 152.0)
const BASE_ART_SIZE := Vector2(472.0, 540.0)
const STAT_SLOT_ART_SIZE := Vector2(322.0, 174.0)
const ELEMENT_ART_SIZE := Vector2(93.0, 115.0)
const SILVER_TRAIT_ART_SIZE := Vector2(48.0, 48.0)
const BASE_ART_ORDER := ["bronze", "silver", "gold", "crystal"]
const BASE_ART_NAMES := ["青铜", "白银", "黄金", "水晶"]
const ELEMENT_ORDER := ["dark", "water", "ice", "grass", "electric", "wind", "fire", "dragon", "earth"]
const ELEMENT_NAMES := ["暗", "水", "冰", "草", "电", "风", "火", "龙", "土"]
const SILVER_TRAIT_ORDER := [
	"self_heal",
	"signature_burst",
	"guard",
	"combo_multiplier",
	"finisher_crit",
	"element_echo",
	"battle_growth",
	"vitality",
]
const SILVER_TRAIT_NAMES := ["自愈", "本命爆发", "护体", "连击倍增", "收尾暴击", "元素回响", "越战越勇", "壮体"]
const SILVER_TRAIT_TEXTURES := {
	"self_heal": preload("res://art/images/shared/pets/info_panel/trait_silver_self_heal.png"),
	"signature_burst": preload("res://art/images/shared/pets/info_panel/trait_silver_signature_burst.png"),
	"guard": preload("res://art/images/shared/pets/info_panel/trait_silver.png"),
	"combo_multiplier": preload("res://art/images/shared/pets/info_panel/trait_silver_combo_multiplier.png"),
	"finisher_crit": preload("res://art/images/shared/pets/info_panel/trait_silver_finisher_crit.png"),
	"element_echo": preload("res://art/images/shared/pets/info_panel/trait_silver_element_echo.png"),
	"battle_growth": preload("res://art/images/shared/pets/info_panel/trait_silver_battle_growth.png"),
	"vitality": preload("res://art/images/shared/pets/info_panel/trait_silver_vitality.png"),
}
const ELEMENT_LAYERS := {
	"dark": {
		"texture": preload("res://art/images/shared/pets/info_panel/element_dark.png"),
	},
	"water": {
		"texture": preload("res://art/images/shared/pets/info_panel/element_water.png"),
	},
	"ice": {
		"texture": preload("res://art/images/shared/pets/info_panel/element_ice.png"),
	},
	"grass": {
		"texture": preload("res://art/images/shared/pets/info_panel/element_grass.png"),
	},
	"electric": {
		"texture": preload("res://art/images/shared/pets/info_panel/element_electric.png"),
	},
	"fire": {
		"texture": preload("res://art/images/shared/pets/info_panel/element_fire.png"),
	},
	"wind": {
		"texture": preload("res://art/images/shared/pets/info_panel/element_wind.png"),
	},
	"dragon": {
		"texture": preload("res://art/images/shared/pets/info_panel/element_dragon.png"),
	},
	"earth": {
		"texture": preload("res://art/images/shared/pets/info_panel/element_earth.png"),
	},
}
const ELEMENT_ALIASES := {
	"dark": "dark",
	"darkness": "dark",
	"shadow": "dark",
	"暗": "dark",
	"water": "water",
	"水": "water",
	"ice": "ice",
	"冰": "ice",
	"grass": "grass",
	"plant": "grass",
	"nature": "grass",
	"草": "grass",
	"木": "grass",
	"electric": "electric",
	"electricity": "electric",
	"lightning": "electric",
	"thunder": "electric",
	"电": "electric",
	"雷": "electric",
	"wind": "wind",
	"风": "wind",
	"fire": "fire",
	"火": "fire",
	"dragon": "dragon",
	"龙": "dragon",
	"earth": "earth",
	"ground": "earth",
	"soil": "earth",
	"土": "earth",
}
const QUALITY_LAYERS := {
	"bronze": {
		"base": preload("res://art/images/shared/pets/info_panel/panel_base_bronze.png"),
		"attack": preload("res://art/images/shared/pets/info_panel/attack_grid_bronze.png"),
		"stats": preload("res://art/images/shared/pets/info_panel/stat_slots_bronze.png"),
		"base_position": Vector2(14.0, 22.0),
	},
	"silver": {
		"base": preload("res://art/images/shared/pets/info_panel/panel_base_silver.png"),
		"attack": preload("res://art/images/shared/pets/info_panel/attack_grid_silver.png"),
		"stats": preload("res://art/images/shared/pets/info_panel/stat_slots_silver.png"),
		"base_position": Vector2(7.0, 11.0),
	},
	"gold": {
		"base": preload("res://art/images/shared/pets/info_panel/panel_base_gold.png"),
		"attack": preload("res://art/images/shared/pets/info_panel/attack_grid_gold.png"),
		"stats": preload("res://art/images/shared/pets/info_panel/stat_slots_gold.png"),
		"base_position": Vector2(10.0, 22.0),
	},
	"crystal": {
		"base": preload("res://art/images/shared/pets/info_panel/panel_base_crystal.png"),
		"attack": preload("res://art/images/shared/pets/info_panel/attack_grid_crystal.png"),
		"stats": preload("res://art/images/shared/pets/info_panel/stat_slots_crystal.png"),
		"base_position": Vector2(2.0, 0.0),
	},
}

@export_enum("跟随宠物品质", "青铜", "白银", "黄金", "水晶")
var base_art_selection := 0:
	set(value):
		base_art_selection = clampi(value, 0, BASE_ART_ORDER.size())
		if is_inside_tree():
			call_deferred("_apply_base_art")

@export_enum("跟随宠物属性", "暗", "水", "冰", "草", "电", "风", "火", "龙", "土")
var element_art_selection := 0:
	set(value):
		element_art_selection = clampi(value, 0, ELEMENT_ORDER.size())
		if is_inside_tree():
			call_deferred("_apply_element_art")

@export_enum("自愈", "本命爆发", "护体", "连击倍增", "收尾暴击", "元素回响", "越战越勇", "壮体")
var silver_trait_selection := 2:
	set(value):
		silver_trait_selection = clampi(value, 0, SILVER_TRAIT_ORDER.size() - 1)
		if is_inside_tree():
			call_deferred("_apply_silver_trait_art")

@onready var _name_label: Label = $PetName
@onready var _attack_overlay: Control = $AttackFormatPlate/AttackOverlay
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
var _current_quality_tier := "crystal"
var _current_element_key := "water"
var _editor_base_art_selection := -1
var _editor_element_art_selection := -1
var _editor_silver_trait_selection := -1

@onready var _close_button: Button = get_node_or_null("Actions/CloseButton") as Button
@onready var _confirm_button: Button = get_node_or_null("Actions/ConfirmButton") as Button


func _ready() -> void:
	if _close_button != null and not _close_button.pressed.is_connected(close):
		_close_button.pressed.connect(close)
	if _confirm_button != null and not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and _editor_base_art_selection != base_art_selection:
		_apply_base_art()
	if Engine.is_editor_hint() and _editor_element_art_selection != element_art_selection:
		_apply_element_art()
	if Engine.is_editor_hint() and _editor_silver_trait_selection != silver_trait_selection:
		_apply_silver_trait_art()


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
	_apply_quality(String(_snapshot.get("quality", "水晶")))
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


func set_base_art_by_index(index: int) -> bool:
	return set_quality_art_exclusive_by_index(index)


func set_quality_art_exclusive_by_index(index: int) -> bool:
	if index < 0 or index >= BASE_ART_ORDER.size():
		return false
	base_art_selection = index + 1
	if is_inside_tree():
		_apply_base_art()
	return true


func set_base_art_by_name(variant_name: String) -> bool:
	var normalized := variant_name.strip_edges().to_lower()
	for index in range(BASE_ART_ORDER.size()):
		if normalized == String(BASE_ART_ORDER[index]) or variant_name == BASE_ART_NAMES[index]:
			return set_base_art_by_index(index)
	return false


func follow_quality_base_art() -> void:
	base_art_selection = 0


func get_base_art_index() -> int:
	return BASE_ART_ORDER.find(_selected_base_art_tier())


func get_base_art_variant_names() -> PackedStringArray:
	return PackedStringArray(BASE_ART_NAMES)


func get_base_art_size() -> Vector2:
	return BASE_ART_SIZE


func set_element_art_by_index(index: int) -> bool:
	if index < 0 or index >= ELEMENT_ORDER.size():
		return false
	element_art_selection = index + 1
	return true


func set_element_art_by_name(element_name: String) -> bool:
	var key := _normalize_element_key(element_name)
	var index := ELEMENT_ORDER.find(key)
	return set_element_art_by_index(index) if index >= 0 else false


func follow_pet_element_art() -> void:
	element_art_selection = 0


func get_element_art_index() -> int:
	return ELEMENT_ORDER.find(_selected_element_key())


func get_element_art_variant_names() -> PackedStringArray:
	return PackedStringArray(ELEMENT_NAMES)


func get_element_art_size() -> Vector2:
	return ELEMENT_ART_SIZE


func set_silver_trait_by_index(index: int) -> bool:
	if index < 0 or index >= SILVER_TRAIT_ORDER.size():
		return false
	silver_trait_selection = index
	return true


func set_silver_trait_by_name(trait_name: String) -> bool:
	var normalized := trait_name.strip_edges().to_lower()
	for index in range(SILVER_TRAIT_ORDER.size()):
		if normalized == String(SILVER_TRAIT_ORDER[index]) or trait_name == SILVER_TRAIT_NAMES[index]:
			return set_silver_trait_by_index(index)
	return false


func get_silver_trait_index() -> int:
	return silver_trait_selection


func get_silver_trait_variant_names() -> PackedStringArray:
	return PackedStringArray(SILVER_TRAIT_NAMES)


func get_silver_trait_art_size() -> Vector2:
	return SILVER_TRAIT_ART_SIZE


func get_display_text() -> String:
	return "\n".join([
		String(_snapshot.get("name", "未知宠物")),
		"%s · %s" % [_snapshot.get("element", "未知元素"), _snapshot.get("quality", "水晶")],
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
		"quality": String(_first_value(record, ["quality", "rarity", "tier"], "水晶")),
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
	elif (
		normalized.contains("crystal")
		or normalized.contains("diamond")
		or quality.contains("水晶")
		or quality.contains("钻石")
	):
		tier = "crystal"
	_current_quality_tier = tier
	_apply_base_art()


func _apply_base_art() -> void:
	var base_art := get_node_or_null("BaseArt") as TextureRect
	var attack_format_plate := get_node_or_null("AttackFormatPlate") as TextureRect
	var stat_slot_art := get_node_or_null("StatSlotArt") as TextureRect
	if base_art == null or attack_format_plate == null or stat_slot_art == null:
		return
	var tier := _selected_base_art_tier()
	var layers: Dictionary = QUALITY_LAYERS[tier]
	base_art.texture = layers["base"] as Texture2D
	base_art.visible = true
	base_art.position = Vector2(2.0, 0.0)
	base_art.size = BASE_ART_SIZE
	attack_format_plate.texture = layers["attack"] as Texture2D
	attack_format_plate.visible = true
	attack_format_plate.position = Vector2(46.0, 145.0)
	attack_format_plate.size = ATTACK_FORMAT_ART_SIZE
	stat_slot_art.texture = layers["stats"] as Texture2D
	stat_slot_art.visible = true
	stat_slot_art.position = Vector2(49.0, 308.0)
	stat_slot_art.size = STAT_SLOT_ART_SIZE
	base_art.set_meta("quality_tier", tier)
	attack_format_plate.set_meta("quality_tier", tier)
	stat_slot_art.set_meta("quality_tier", tier)
	_editor_base_art_selection = base_art_selection


func _selected_base_art_tier() -> String:
	if base_art_selection <= 0:
		return _current_quality_tier
	return String(BASE_ART_ORDER[base_art_selection - 1])


func _apply_element(element: String) -> void:
	_current_element_key = _normalize_element_key(element)
	_apply_element_art()


func _apply_element_art() -> void:
	var element_art := get_node_or_null("ElementArt") as TextureRect
	if element_art == null:
		return
	var key := _selected_element_key()
	element_art.visible = ELEMENT_LAYERS.has(key)
	if element_art.visible:
		var layer: Dictionary = ELEMENT_LAYERS[key]
		element_art.texture = layer["texture"] as Texture2D
		element_art.position = Vector2(370.0, 20.0)
		element_art.size = ELEMENT_ART_SIZE
	_editor_element_art_selection = element_art_selection


func _selected_element_key() -> String:
	if element_art_selection <= 0:
		return _current_element_key
	return String(ELEMENT_ORDER[element_art_selection - 1])


func _apply_silver_trait_art() -> void:
	var trait_art := get_node_or_null("TraitArt") as TextureRect
	if trait_art == null:
		return
	var key := String(SILVER_TRAIT_ORDER[silver_trait_selection])
	trait_art.texture = SILVER_TRAIT_TEXTURES[key] as Texture2D
	trait_art.position = Vector2(378.0, 315.0)
	trait_art.size = SILVER_TRAIT_ART_SIZE
	_editor_silver_trait_selection = silver_trait_selection


func _normalize_element_key(element: String) -> String:
	return String(ELEMENT_ALIASES.get(element.strip_edges().to_lower(), ""))


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
	origin.position = _marker_position(ATTACK_ORIGIN_INDEX, ORIGIN_MARKER_SIZE)
	origin.size = ORIGIN_MARKER_SIZE
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
