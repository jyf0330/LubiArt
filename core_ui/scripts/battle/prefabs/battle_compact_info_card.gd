extends Control
class_name BattleCompactInfoCard

const BattlePetViewModelScript := preload("res://core_ui/scripts/battle/presenters/battle_pet_view_model.gd")
const ELEMENT_TEXTURES := {
	"dark": preload("res://art/images/shared/pets/info_panel/element_dark.png"),
	"water": preload("res://art/images/shared/pets/info_panel/element_water.png"),
	"ice": preload("res://art/images/shared/pets/info_panel/element_ice.png"),
	"grass": preload("res://art/images/shared/pets/info_panel/element_grass.png"),
	"electric": preload("res://art/images/shared/pets/info_panel/element_electric.png"),
	"wind": preload("res://art/images/shared/pets/info_panel/element_wind.png"),
	"fire": preload("res://art/images/shared/pets/info_panel/element_fire.png"),
	"dragon": preload("res://art/images/shared/pets/info_panel/element_dragon.png"),
	"earth": preload("res://art/images/shared/pets/info_panel/element_earth.png"),
}
const SOURCE_CANVAS_SIZE := Vector2(380.0, 820.0)
const ALLY_ACCENT := Color("47d7c4")
const ENEMY_ACCENT := Color("f47a45")
const QUALITY_LABELS := {
	"bronze": "青铜",
	"silver": "白银",
	"gold": "黄金",
	"legendary": "传说",
}

@onready var portrait: TextureRect = $Margin/Column/PortraitShell/Portrait
@onready var side_accent: ColorRect = $Margin/Column/IdentityBar/IdentityRow/SideAccent
@onready var name_label: Label = $Margin/Column/IdentityBar/IdentityRow/NameLabel
@onready var quality_label: Label = $Margin/Column/IdentityBar/IdentityRow/QualityLabel
@onready var element_icon: TextureRect = $Margin/Column/IdentityBar/IdentityRow/ElementIcon
@onready var health_bar: UiValueBar = $Margin/Column/Health
@onready var shield_bar: UiValueBar = $Margin/Column/Shield
@onready var attack_grid: BattleAttackShapeGrid = $Margin/Column/CombatPanel/CombatMargin/CombatRow/AttackShapeGrid
@onready var side_label: Label = $Margin/Column/CombatPanel/CombatMargin/CombatRow/Legend/SideLabel
@onready var stat_values := {
	"attack": $Margin/Column/StatsPanel/StatsMargin/StatGrid/Attack/Row/Value,
	"defense": $Margin/Column/StatsPanel/StatsMargin/StatGrid/Defense/Row/Value,
	"regen": $Margin/Column/StatsPanel/StatsMargin/StatGrid/Regen/Row/Value,
	"ap": $Margin/Column/StatsPanel/StatsMargin/StatGrid/Ap/Row/Value,
	"shield": $Margin/Column/StatsPanel/StatsMargin/StatGrid/Shield/Row/Value,
	"damage_cap": $Margin/Column/StatsPanel/StatsMargin/StatGrid/DamageCap/Row/Value,
}

var _snapshot: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_info(record: Dictionary, texture: Texture2D = null) -> Dictionary:
	_snapshot = BattlePetViewModelScript.from_record(record)
	portrait.texture = texture
	name_label.text = String(_snapshot.name)
	quality_label.text = _quality_display(String(_snapshot.quality))
	element_icon.texture = ELEMENT_TEXTURES.get(_element_key(String(_snapshot.element))) as Texture2D
	var accent := ENEMY_ACCENT if bool(_snapshot.is_enemy) else ALLY_ACCENT
	side_accent.color = accent
	side_label.text = "%s · %s" % [String(_snapshot.role), _element_display(String(_snapshot.element))]
	side_label.add_theme_color_override("font_color", accent)
	health_bar.set_fill_color(Color("2eaf35"))
	health_bar.present(int(_snapshot.hp), int(_snapshot.max_hp))
	shield_bar.present(int(_snapshot.shield), int(_snapshot.max_shield), "护盾 %d" % int(_snapshot.shield))
	shield_bar.visible = int(_snapshot.shield) > 0
	for key in stat_values:
		var label := stat_values[key] as Label
		if key == "ap":
			label.text = "%d/%d" % [int(_snapshot.ap), int(_snapshot.max_ap)]
		else:
			label.text = str(int(_snapshot.get(key, 0)))
	attack_grid.present(Dictionary(_snapshot.attack_shape))
	return get_info_snapshot()


func get_info_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func get_attack_shape_cell_count() -> int:
	return attack_grid.get_cell_count()


func get_target_cell_indices() -> Array[int]:
	return attack_grid.get_target_cell_indices()


func get_source_canvas_size() -> Vector2:
	return SOURCE_CANVAS_SIZE


func get_source_psd() -> String:
	return "战斗宠物详情_正式独立实现"


func get_component_source() -> String:
	return "res://art/prefabs/battle/battle_compact_info_card.tscn"


func get_display_text() -> String:
	return "\n".join([
		String(_snapshot.get("name", "未知宠物")),
		"生命 %d/%d" % [int(_snapshot.get("hp", 0)), int(_snapshot.get("max_hp", 0))],
		"攻击力 %d · 护盾 %d" % [int(_snapshot.get("attack", 0)), int(_snapshot.get("shield", 0))],
	])


func _element_key(value: String) -> String:
	var primary := value.split("/", false, 1)[0].strip_edges()
	var normalized := primary.to_lower()
	var aliases := {"暗": "dark", "水": "water", "冰": "ice", "草": "grass", "雷": "electric", "电": "electric", "风": "wind", "火": "fire", "龙": "dragon", "土": "earth"}
	return String(aliases.get(primary, normalized if ELEMENT_TEXTURES.has(normalized) else "wind"))


func _element_display(value: String) -> String:
	var labels := {"dark": "暗", "water": "水", "ice": "冰", "grass": "草", "electric": "雷", "wind": "风", "fire": "火", "dragon": "龙", "earth": "土"}
	var key := _element_key(value)
	return "%s系" % String(labels.get(key, value))


func _quality_display(value: String) -> String:
	return String(QUALITY_LABELS.get(value.strip_edges().to_lower(), value))
