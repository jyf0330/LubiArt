extends Control

const SOURCE_CANVAS_SIZE := Vector2(380.0, 820.0)
const COMPONENT_SOURCE := "res://art/prefabs/pet/battle_pet_info_card.tscn"
const TRAIT_MANIFEST_PATH := "res://art/manifests/shared/pets/info_panel/battle_trait_icons.json"
const TRAIT_SLOT_TIERS := ["silver", "gold", "diamond"]
const ATTACK_GRID_COLUMNS := 7
const ATTACK_GRID_ROWS := 3
const ATTACK_ORIGIN_INDEX := 9
const ATTACK_ICON_CELL_SIZE := Vector2(10.0, 10.0)
const ATTACK_ICON_ORIGIN_COLOR := Color("#72d7e7")
const ATTACK_ICON_TARGET_COLOR := Color("#ef6e52")
const ATTACK_ICON_EMPTY_COLOR := Color(0.0, 0.0, 0.0, 0.0)

# One continuous path owns the full visible frame. The nested strokes follow the
# same points so the body, shoulder and trapezoid cannot develop stitched seams.
const FRAME_BASELINE_Y := 46.0
const FRAME_TOP_Y := 18.0
const FRAME_LEFT_X := 9.0
const FRAME_BOTTOM_Y := 811.0
const FRAME_SHOULDER_LEFT_X := 110.0
const FRAME_TOP_LEFT_X := 126.0
const FRAME_TOP_RIGHT_X := 254.0
const FRAME_SHOULDER_RIGHT_X := 270.0
const FRAME_OUTER_WIDTH := 18.0
const FRAME_GOLD_WIDTH := 14.0
const FRAME_DIVIDER_WIDTH := 8.0
const FRAME_TEAL_WIDTH := 5.0
const FRAME_INNER_WIDTH := 2.0
const FRAME_FILL_COLOR := Color("#131e1a")
const FRAME_OUTER_COLOR := Color("#050706")
const FRAME_GOLD_COLOR := Color("#746338")
const FRAME_DIVIDER_COLOR := Color("#0b141d")
const FRAME_TEAL_COLOR := Color("#2f4f4e")
const FRAME_INNER_COLOR := Color("#122424")

const ELEMENT_TEXTURES := {
	"dark": preload("res://art/images/shared/pets/info_panel/element_dark.png"),
	"dragon": preload("res://art/images/shared/pets/info_panel/element_dragon.png"),
	"earth": preload("res://art/images/shared/pets/info_panel/element_earth.png"),
	"electric": preload("res://art/images/shared/pets/info_panel/element_electric.png"),
	"fire": preload("res://art/images/shared/pets/info_panel/element_fire.png"),
	"grass": preload("res://art/images/shared/pets/info_panel/element_grass.png"),
	"ice": preload("res://art/images/shared/pets/info_panel/element_ice.png"),
	"water": preload("res://art/images/shared/pets/info_panel/element_water.png"),
	"wind": preload("res://art/images/shared/pets/info_panel/element_wind.png"),
}

const QUALITY_DATA := {
	"bronze": {"stars": 1, "name": "青铜", "color": Color("#c88748"), "price_base": 2},
	"silver": {"stars": 2, "name": "白银", "color": Color("#e8f1f5"), "price_base": 4},
	"gold": {"stars": 3, "name": "黄金", "color": Color("#ffd45a"), "price_base": 8},
	"diamond": {"stars": 4, "name": "钻石", "color": Color("#79e8ff"), "price_base": 16},
}

const ATTACK_CELL_TIER_DATA := {
	1: {"color": Color("#2f6faf"), "border": Color("#112e50")},
	2: {"color": Color("#7848a8"), "border": Color("#382052")},
	3: {"color": Color("#bc6b2f"), "border": Color("#603415")},
}

const ELEMENT_DATA := {
	"dark": {"name": "暗", "color": Color("#ad72e8")},
	"dragon": {"name": "龙", "color": Color("#d194ff")},
	"earth": {"name": "土", "color": Color("#c7924b")},
	"electric": {"name": "雷", "color": Color("#ffe46b")},
	"fire": {"name": "火", "color": Color("#ff785d")},
	"grass": {"name": "草", "color": Color("#70dd83")},
	"ice": {"name": "冰", "color": Color("#a7e9ff")},
	"water": {"name": "水", "color": Color("#63caff")},
	"wind": {"name": "风", "color": Color("#80e8cf")},
}

@onready var _quality_stars: Label = $QualityHeader/QualityStars
@onready var _quality_name: Label = $QualityHeader/QualityName
@onready var _portrait_backdrop: ColorRect = $PortraitPanel/PortraitBackdrop
@onready var _portrait: TextureRect = $PortraitPanel/Portrait
@onready var _pet_name: Label = $PortraitPanel/PetName
@onready var _element_icon: TextureRect = $PortraitPanel/ElementIcon
@onready var _element_name: Label = $PortraitPanel/ElementName
@onready var _health_bar: TextureProgressBar = $HealthBar
@onready var _health_value: Label = $HealthBar/HealthValue
@onready var _shield_bar: TextureProgressBar = $ShieldBar
@onready var _shield_value: Label = $ShieldBar/ShieldValue
@onready var _attack_range_panel: Panel = $AttackRangePanel
@onready var _attack_grid: GridContainer = $AttackRangePanel/AttackGrid
@onready var _trait_slots: Array[Panel] = [
	$TraitSlots/TraitSlotSilver as Panel,
	$TraitSlots/TraitSlotGold as Panel,
	$TraitSlots/TraitSlotDiamond as Panel,
]
@onready var _hp_value: Label = $StatsPanel/StatsGrid/HpStat/Value
@onready var _attack_value: Label = $StatsPanel/StatsGrid/AttackStat/Value
@onready var _ap_value: Label = $StatsPanel/StatsGrid/ApStat/Value
@onready var _defense_value: Label = $StatsPanel/StatsGrid/DefenseStat/Value
@onready var _shield_stat_value: Label = $StatsPanel/StatsGrid/ShieldStat/Value
@onready var _regen_value: Label = $StatsPanel/StatsGrid/RegenStat/Value
@onready var _attack_stat: VBoxContainer = $StatsPanel/StatsGrid/AttackStat
@onready var _defense_stat: VBoxContainer = $StatsPanel/StatsGrid/DefenseStat
@onready var _regen_stat: VBoxContainer = $StatsPanel/StatsGrid/RegenStat

var _snapshot: Dictionary = {}
var _target_cell_indices: Array[int] = []
var _quality_key := "bronze"
var _element_key := "dark"
var _attack_cell_tier := 1
var _display_price := 2
var _unlocked_trait_slot_count := 0
var _trait_empty_style: StyleBoxFlat = null
var _trait_awakened_style: StyleBoxFlat = null
var _trait_catalog: Dictionary = {}
var _trait_name_lookup: Dictionary = {}
var _legacy_first_defaults: Dictionary = {}
var _displayed_trait_ids: Array[String] = ["", "", ""]


func _draw() -> void:
	var silhouette := PackedVector2Array([
		Vector2(0.0, SOURCE_CANVAS_SIZE.y),
		Vector2(0.0, FRAME_BASELINE_Y),
		Vector2(FRAME_SHOULDER_LEFT_X, FRAME_BASELINE_Y),
		Vector2(FRAME_TOP_LEFT_X, FRAME_TOP_Y),
		Vector2(FRAME_TOP_RIGHT_X, FRAME_TOP_Y),
		Vector2(FRAME_SHOULDER_RIGHT_X, FRAME_BASELINE_Y),
		Vector2(SOURCE_CANVAS_SIZE.x, FRAME_BASELINE_Y),
		SOURCE_CANVAS_SIZE,
	])
	var outline := _frame_outline_points()
	draw_colored_polygon(silhouette, FRAME_FILL_COLOR)
	draw_polyline(outline, FRAME_OUTER_COLOR, FRAME_OUTER_WIDTH, true)
	draw_polyline(outline, FRAME_GOLD_COLOR, FRAME_GOLD_WIDTH, true)
	draw_polyline(outline, FRAME_DIVIDER_COLOR, FRAME_DIVIDER_WIDTH, true)
	draw_polyline(outline, FRAME_TEAL_COLOR, FRAME_TEAL_WIDTH, true)
	draw_polyline(outline, FRAME_INNER_COLOR, FRAME_INNER_WIDTH, true)


func _ready() -> void:
	_trait_awakened_style = _trait_slots[0].get_theme_stylebox("panel") as StyleBoxFlat
	_trait_empty_style = _trait_slots[1].get_theme_stylebox("panel") as StyleBoxFlat
	_load_trait_catalog()
	if _snapshot.is_empty():
		set_info({
			"name": "影焰幼龙",
			"element": "fire",
			"quality": "gold",
			"hp": 850,
			"max_hp": 850,
			"ap": 30,
			"max_ap": 30,
			"attack": 148,
			"defense": 55,
			"shield": 40,
			"max_shield": 40,
			"regen": 12,
			"attack_shape": [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)],
		}, null)


func set_info(record: Dictionary, portrait_texture: Texture2D = null) -> Dictionary:
	_snapshot = record.duplicate(true)
	_quality_key = _normalize_quality(str(_first_value(record, ["quality", "rank", "tier"], "bronze")))
	_element_key = _normalize_element(str(_first_value(record, ["element", "element_type"], "dark")))

	var quality: Dictionary = QUALITY_DATA[_quality_key]
	var element: Dictionary = ELEMENT_DATA[_element_key]
	var star_count := int(quality["stars"])
	_quality_stars.text = "★".repeat(star_count)
	_quality_stars.add_theme_color_override("font_color", quality["color"])
	_quality_name.text = "%s级" % str(quality["name"])
	_quality_name.add_theme_color_override("font_color", quality["color"])
	_apply_trait_slot_state(star_count - 1, record)

	_pet_name.text = str(_first_value(record, ["name", "display_name", "pet_name"], "未命名宠物"))
	_portrait.texture = portrait_texture
	_element_icon.texture = ELEMENT_TEXTURES[_element_key]
	_portrait_backdrop.color = Color("#24451d").lerp(Color(element["color"]), 0.16)

	var attack_shape: Variant = _first_value(record, ["attack_shape", "attack_range"], [])
	_attack_cell_tier = _attack_cell_count(attack_shape)
	_display_price = int(quality["price_base"]) * _attack_cell_tier
	_element_name.text = str(_display_price)
	_apply_name_price_bar_style()

	var maximum_hp := maxf(1.0, float(_first_value(record, ["max_hp", "hp_max"], 1.0)))
	var current_hp := clampf(float(_first_value(record, ["hp", "current_hp"], maximum_hp)), 0.0, maximum_hp)
	_health_bar.max_value = maximum_hp
	_health_bar.value = current_hp
	_health_value.text = "%d / %d" % [roundi(current_hp), roundi(maximum_hp)]

	var current_shield := maxi(0, int(_first_value(record, ["shield", "current_shield"], 0)))
	var maximum_shield := 0
	if current_shield > 0:
		maximum_shield = maxi(
			current_shield,
			int(_first_value(record, ["max_shield", "shield_max"], current_shield))
		)
	_shield_bar.max_value = maxf(1.0, float(maximum_shield))
	_shield_bar.value = float(current_shield)
	_shield_value.text = "%d / %d" % [current_shield, maximum_shield]

	var current_ap := int(_first_value(record, ["ap", "current_ap"], 0))
	var maximum_ap := int(_first_value(record, ["max_ap", "ap_max"], current_ap))
	_hp_value.text = "%d / %d" % [roundi(current_hp), roundi(maximum_hp)]
	_attack_value.text = str(int(_first_value(record, ["attack", "atk"], 0)))
	_ap_value.text = "%d / %d" % [current_ap, maximum_ap]
	_defense_value.text = str(int(_first_value(record, ["defense", "def"], 0)))
	_shield_stat_value.text = str(current_shield)
	_regen_value.text = str(int(_first_value(record, ["regen", "recovery"], 0)))
	_update_hover_tooltips(
		str(element["name"]),
		roundi(current_hp),
		roundi(maximum_hp),
		current_shield,
		maximum_shield,
		int(_attack_value.text),
		int(_defense_value.text),
		int(_regen_value.text)
	)

	_render_attack_shape(attack_shape)
	return get_info_snapshot()


func get_info_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_attack_shape_cell_count() -> int:
	return ATTACK_GRID_COLUMNS * ATTACK_GRID_ROWS


func get_attack_grid_size() -> Vector2i:
	return Vector2i(ATTACK_GRID_COLUMNS, ATTACK_GRID_ROWS)


func get_attack_origin_index() -> int:
	return ATTACK_ORIGIN_INDEX


func get_attack_icon_cell_size() -> Vector2:
	return ATTACK_ICON_CELL_SIZE


func get_target_cell_indices() -> Array[int]:
	return _target_cell_indices.duplicate()


func get_source_canvas_size() -> Vector2:
	return SOURCE_CANVAS_SIZE


func get_source_psd() -> String:
	return ""


func get_component_source() -> String:
	return COMPONENT_SOURCE


func get_display_text() -> String:
	return "%s · %s · %s级 · 价格%d" % [
		_pet_name.text,
		ELEMENT_DATA[_element_key]["name"],
		QUALITY_DATA[_quality_key]["name"],
		_display_price,
	]


func get_quality_star_count() -> int:
	return int(QUALITY_DATA[_quality_key]["stars"])


func get_quality_key() -> String:
	return _quality_key


func get_element_key() -> String:
	return _element_key


func get_attack_cell_tier() -> int:
	return _attack_cell_tier


func get_display_price() -> int:
	return _display_price


func get_trait_slot_count() -> int:
	return _trait_slots.size()


func get_unlocked_trait_slot_count() -> int:
	return _unlocked_trait_slot_count


func is_trait_slot_awakened(index: int) -> bool:
	return index >= 0 and index < _unlocked_trait_slot_count


func get_displayed_trait_ids() -> Array[String]:
	return _displayed_trait_ids.duplicate()


func get_trait_catalog_count() -> int:
	return _trait_catalog.size()


func get_trait_display_name(trait_id: String) -> String:
	var normalized_id := _resolve_trait_id(trait_id)
	if normalized_id == "":
		return ""
	return str(Dictionary(_trait_catalog[normalized_id]).get("name", ""))


func set_hover_tooltip_input_enabled(enabled: bool) -> void:
	var mouse_mode := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for control in _hover_tooltip_controls():
		control.mouse_filter = mouse_mode


func get_name_price_bar_color() -> Color:
	return Color(ATTACK_CELL_TIER_DATA[_attack_cell_tier]["color"])


func _apply_trait_slot_state(unlocked_count: int, record: Dictionary = {}) -> void:
	_unlocked_trait_slot_count = clampi(unlocked_count, 0, _trait_slots.size())
	var explicit_traits := _extract_trait_assignments(record)
	for index in range(_trait_slots.size()):
		var tier := str(TRAIT_SLOT_TIERS[index])
		if index >= _unlocked_trait_slot_count:
			_displayed_trait_ids[index] = ""
			var locked_tier_label := _trait_tier_label(tier)
			_trait_slots[index].tooltip_text = (
				"%s特性槽 · 空\n精灵达到%s品质后解锁。"
				% [locked_tier_label, locked_tier_label]
			)
			_trait_slots[index].add_theme_stylebox_override("panel", _trait_empty_style)
			continue

		var trait_id := str(explicit_traits.get(tier, "")).to_upper()
		if not _trait_catalog.has(trait_id) and _uses_legacy_first_trait_defaults(record):
			trait_id = str(_legacy_first_defaults.get(tier, "")).to_upper()
		var entry := Dictionary(_trait_catalog.get(trait_id, {}))
		var icon_path := str(entry.get("icon", ""))
		if entry.is_empty() or not _apply_trait_icon(_trait_slots[index], icon_path):
			_displayed_trait_ids[index] = ""
			_trait_slots[index].tooltip_text = (
				"%s特性槽 · 空\n该槽已解锁，当前没有可显示的特性。"
				% _trait_tier_label(tier)
			)
			_trait_slots[index].add_theme_stylebox_override("panel", _trait_awakened_style)
			continue

		_displayed_trait_ids[index] = trait_id
		var tooltip_lines := ["%s · %s" % [trait_id, str(entry.get("name", ""))]]
		var description := str(entry.get("description", "")).strip_edges()
		var eligibility := str(entry.get("eligibility", "")).strip_edges()
		if description != "":
			tooltip_lines.append(description)
		if eligibility != "":
			tooltip_lines.append(eligibility)
		_trait_slots[index].tooltip_text = "\n".join(tooltip_lines)


func _uses_legacy_first_trait_defaults(record: Dictionary) -> bool:
	for key in ["quality_progression", "qualityProgression"]:
		if not record.has(key) or not record[key] is Dictionary:
			continue
		var progression := Dictionary(record[key])
		var selection := str(progression.get(
			"upgrade_selection",
			progression.get("upgradeSelection", "")
		)).strip_edges().to_lower()
		if selection == "legacy_first":
			return true
	return false


func _load_trait_catalog() -> void:
	if not FileAccess.file_exists(TRAIT_MANIFEST_PATH):
		return
	var file := FileAccess.open(TRAIT_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var manifest := Dictionary(parsed)
	_legacy_first_defaults = Dictionary(manifest.get("legacy_first_defaults", {})).duplicate(true)
	for value in Array(manifest.get("traits", [])):
		if not value is Dictionary:
			continue
		var entry := Dictionary(value).duplicate(true)
		var trait_id := str(entry.get("id", "")).strip_edges().to_upper()
		var trait_name := str(entry.get("name", "")).strip_edges()
		if trait_id == "" or trait_name == "":
			continue
		entry["id"] = trait_id
		_trait_catalog[trait_id] = entry
		_trait_name_lookup[trait_name] = trait_id


func _extract_trait_assignments(record: Dictionary) -> Dictionary:
	var result := {}
	for key in [
		"traits", "trait_ids", "traitIds",
		"quality_traits", "qualityTraits",
		"quality_upgrades", "qualityUpgrades",
	]:
		if record.has(key):
			_collect_trait_assignments(record[key], result)

	for key in ["quality_upgrade", "qualityUpgrade", "quality_progression", "qualityProgression"]:
		if record.has(key):
			_collect_trait_assignments(record[key], result)
	return result


func _collect_trait_assignments(value: Variant, result: Dictionary) -> void:
	if value is Array:
		for item in Array(value):
			_collect_trait_assignments(item, result)
		return
	if value is String or value is StringName:
		_store_trait_assignment(str(value), result)
		return
	if not value is Dictionary:
		return

	var entry := Dictionary(value)
	for key in ["id", "trait_id", "traitId", "upgrade_id", "upgradeId", "name", "upgrade_name", "upgradeName"]:
		if entry.has(key) and _store_trait_assignment(str(entry[key]), result):
			return
	for key in ["silver", "白银", "gold", "黄金", "diamond", "crystal", "钻石", "水晶"]:
		if entry.has(key):
			_collect_trait_assignments(entry[key], result)
	for key in ["items", "traits", "upgrades", "selected"]:
		if entry.has(key):
			_collect_trait_assignments(entry[key], result)


func _store_trait_assignment(value: String, result: Dictionary) -> bool:
	var trait_id := _resolve_trait_id(value)
	if trait_id == "":
		return false
	var tier := str(Dictionary(_trait_catalog[trait_id]).get("tier", ""))
	if not tier in TRAIT_SLOT_TIERS:
		return false
	result[tier] = trait_id
	return true


func _resolve_trait_id(value: String) -> String:
	var candidate := value.strip_edges()
	var uppercase := candidate.to_upper()
	if _trait_catalog.has(uppercase):
		return uppercase
	return str(_trait_name_lookup.get(candidate, ""))


func _apply_trait_icon(slot: Panel, icon_path: String) -> bool:
	if icon_path == "" or not ResourceLoader.exists(icon_path, "Texture2D"):
		return false
	var texture := load(icon_path) as Texture2D
	if texture == null:
		return false
	var style := StyleBoxTexture.new()
	style.texture = texture
	slot.add_theme_stylebox_override("panel", style)
	return true


func _trait_tier_label(tier: String) -> String:
	if tier == "silver":
		return "白银"
	if tier == "gold":
		return "黄金"
	return "钻石"


func _update_hover_tooltips(
	element_name: String,
	current_hp: int,
	maximum_hp: int,
	current_shield: int,
	maximum_shield: int,
	attack: int,
	defense: int,
	regen: int
) -> void:
	_element_icon.tooltip_text = "%s属性\n该精灵当前的元素属性。" % element_name
	_health_bar.tooltip_text = (
		"生命值\n当前生命 / 最大生命：%d / %d" % [current_hp, maximum_hp]
	)
	_shield_bar.tooltip_text = (
		"护盾\n当前护盾 / 最大护盾：%d / %d" % [current_shield, maximum_shield]
	)
	_attack_range_panel.tooltip_text = (
		"攻击范围\n青色格代表精灵位置，橙红格代表攻击可覆盖的位置。"
	)
	_attack_stat.tooltip_text = "攻击力：%d\n该精灵当前的攻击属性数值。" % attack
	_defense_stat.tooltip_text = "防御力：%d\n该精灵当前的防御属性数值。" % defense
	_regen_stat.tooltip_text = "生命回复：%d\n该精灵当前的生命回复属性数值。" % regen


func _hover_tooltip_controls() -> Array[Control]:
	var controls: Array[Control] = [
		_element_icon,
		_health_bar,
		_shield_bar,
		_attack_range_panel,
		_attack_stat,
		_defense_stat,
		_regen_stat,
	]
	for slot in _trait_slots:
		controls.append(slot)
	return controls


func get_panel_size() -> Vector2:
	return size


func get_frame_draw_spec() -> Dictionary:
	return {
		"points": _frame_outline_points(),
		"widths": PackedFloat32Array([
			FRAME_OUTER_WIDTH,
			FRAME_GOLD_WIDTH,
			FRAME_DIVIDER_WIDTH,
			FRAME_TEAL_WIDTH,
			FRAME_INNER_WIDTH,
		]),
		"fill_color": FRAME_FILL_COLOR,
		"right_border": false,
	}


func _frame_outline_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(SOURCE_CANVAS_SIZE.x, FRAME_BOTTOM_Y),
		Vector2(FRAME_LEFT_X, FRAME_BOTTOM_Y),
		Vector2(FRAME_LEFT_X, FRAME_BASELINE_Y),
		Vector2(FRAME_SHOULDER_LEFT_X, FRAME_BASELINE_Y),
		Vector2(FRAME_TOP_LEFT_X, FRAME_TOP_Y),
		Vector2(FRAME_TOP_RIGHT_X, FRAME_TOP_Y),
		Vector2(FRAME_SHOULDER_RIGHT_X, FRAME_BASELINE_Y),
		Vector2(SOURCE_CANVAS_SIZE.x, FRAME_BASELINE_Y),
	])


func _render_attack_shape(shape_value: Variant) -> void:
	for child in _attack_grid.get_children():
		child.free()
	_target_cell_indices.clear()

	var offsets := _normalize_attack_shape(shape_value)
	for offset in offsets:
		var column := ATTACK_ORIGIN_INDEX % ATTACK_GRID_COLUMNS + offset.x
		var row := ATTACK_ORIGIN_INDEX / ATTACK_GRID_COLUMNS + offset.y
		if column < 0 or column >= ATTACK_GRID_COLUMNS or row < 0 or row >= ATTACK_GRID_ROWS:
			continue
		var index := int(row) * ATTACK_GRID_COLUMNS + int(column)
		if index != ATTACK_ORIGIN_INDEX and not _target_cell_indices.has(index):
			_target_cell_indices.append(index)

	for index in range(get_attack_shape_cell_count()):
		var cell := ColorRect.new()
		cell.name = "AttackCell%02d" % index
		cell.custom_minimum_size = ATTACK_ICON_CELL_SIZE
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if index == ATTACK_ORIGIN_INDEX:
			cell.color = ATTACK_ICON_ORIGIN_COLOR
		elif _target_cell_indices.has(index):
			cell.color = ATTACK_ICON_TARGET_COLOR
		else:
			cell.color = ATTACK_ICON_EMPTY_COLOR
		_attack_grid.add_child(cell)


func _normalize_attack_shape(shape_value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var values: Array = []
	if shape_value is Dictionary:
		values = Array(Dictionary(shape_value).get("offsets", []))
	elif shape_value is Array:
		values = shape_value
	for value in values:
		if value is Vector2i:
			result.append(value)
		elif value is Vector2:
			result.append(Vector2i(roundi(value.x), roundi(value.y)))
		elif value is Dictionary:
			var entry := Dictionary(value)
			result.append(Vector2i(
				int(entry.get("x", entry.get("dc", 0))),
				int(entry.get("y", entry.get("dr", 0)))
			))
	return result


func _attack_cell_count(shape_value: Variant) -> int:
	if shape_value is Dictionary:
		var shape := Dictionary(shape_value)
		for key in ["cell_count", "cellCount", "hit_cells", "hitCells"]:
			if shape.has(key):
				return clampi(int(shape[key]), 1, 3)
	return clampi(_normalize_attack_shape(shape_value).size(), 1, 3)


func _apply_name_price_bar_style() -> void:
	var source := _pet_name.get_theme_stylebox("normal") as StyleBoxFlat
	if source == null:
		return
	var style := source.duplicate() as StyleBoxFlat
	var tier: Dictionary = ATTACK_CELL_TIER_DATA[_attack_cell_tier]
	style.bg_color = Color(tier["color"])
	style.border_color = Color(tier["border"])
	_pet_name.add_theme_stylebox_override("normal", style)


func _normalize_quality(value: String) -> String:
	var key := value.strip_edges().to_lower()
	if key in ["silver", "白银", "2", "tier_2"]:
		return "silver"
	if key in ["gold", "黄金", "3", "tier_3"]:
		return "gold"
	if key in ["diamond", "crystal", "钻石", "水晶", "4", "tier_4"]:
		return "diamond"
	return "bronze"


func _normalize_element(value: String) -> String:
	var key := value.strip_edges().to_lower()
	var aliases := {
		"暗": "dark", "shadow": "dark",
		"龙": "dragon",
		"土": "earth", "ground": "earth",
		"雷": "electric", "lightning": "electric",
		"火": "fire",
		"草": "grass", "nature": "grass",
		"冰": "ice",
		"水": "water",
		"风": "wind", "air": "wind",
	}
	key = str(aliases.get(key, key))
	return key if ELEMENT_DATA.has(key) else "dark"


func _first_value(record: Dictionary, keys: Array, fallback: Variant) -> Variant:
	for key in keys:
		if record.has(key):
			return record[key]
	return fallback
