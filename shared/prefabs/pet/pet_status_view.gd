extends Node
class_name PetStatusView

@export var hp_label_path: NodePath
@export var life_label_path: NodePath
@export var attack_label_path: NodePath
@export var defense_label_path: NodePath
@export var psd_health_value_path: NodePath
@export var psd_shield_value_path: NodePath
@export var psd_attack_value_path: NodePath
@export var psd_damage_cap_value_path: NodePath

@onready var hp_label: Label = get_node(hp_label_path) as Label
@onready var life_label: Label = get_node(life_label_path) as Label
@onready var attack_label: Label = get_node(attack_label_path) as Label
@onready var defense_label: Label = get_node(defense_label_path) as Label
@onready var psd_health_value: Label = get_node_or_null(psd_health_value_path) as Label
@onready var psd_shield_value: Label = get_node_or_null(psd_shield_value_path) as Label
@onready var psd_attack_value: Label = get_node_or_null(psd_attack_value_path) as Label
@onready var psd_damage_cap_value: Label = get_node_or_null(psd_damage_cap_value_path) as Label

var _data: Dictionary = {}


func _ready() -> void:
	_apply_readability_style()
	reset()


func reset() -> void:
	_data = {}
	hp_label.text = ""
	life_label.text = ""
	attack_label.text = ""
	defense_label.text = ""
	for label in _psd_value_labels():
		label.text = ""
	set_mode(&"none")


func bind_battle_data(data: Dictionary) -> void:
	_data = data.duplicate(true)
	set_mode(&"battle")
	refresh()


func set_mode(mode: StringName) -> void:
	var battle_visible := mode == &"battle"
	hp_label.visible = false
	var uses_psd_values := not _psd_value_labels().is_empty()
	life_label.visible = battle_visible and not uses_psd_values
	attack_label.visible = battle_visible and not uses_psd_values
	defense_label.visible = battle_visible and not uses_psd_values
	for label in _psd_value_labels():
		label.visible = battle_visible


func refresh() -> void:
	var hp: int = max(0, int(_data.get("hp", 0)))
	var attack: int = max(0, int(_data.get("atk", _data.get("attack", 0))))
	hp_label.text = str(hp)
	life_label.text = "生命 %d" % hp
	attack_label.text = "攻击力 %d" % attack
	_refresh_defense_label()
	_refresh_psd_values()


func update_hp(value: int) -> void:
	_data["hp"] = value
	var hp: int = max(0, value)
	hp_label.text = str(hp)
	life_label.text = "生命 %d" % hp
	if psd_health_value != null:
		psd_health_value.text = str(hp)


func update_shield(value: int) -> void:
	_data["shield"] = max(0, value)
	_refresh_defense_label()
	if psd_shield_value != null:
		psd_shield_value.text = str(max(0, value))


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func _incoming_damage(data: Dictionary) -> int:
	var threat := Dictionary(data.get("threat", {}))
	return max(0, int(threat.get("totalDamage", threat.get("damage", threat.get("threat", threat.get("atk", 0))))))


func _refresh_defense_label() -> void:
	var shield: int = max(0, int(_data.get("shield", 0)))
	var incoming_damage := _incoming_damage(_data)
	defense_label.text = "护盾 %d · 受伤 %d" % [shield, incoming_damage]
	if incoming_damage > 0:
		defense_label.add_theme_color_override("font_color", Color("ffd2cc"))
		defense_label.add_theme_stylebox_override("normal", _stat_strip(Color(0.22, 0.035, 0.025, 0.9), Color(0.95, 0.35, 0.28, 0.95)))
	elif shield > 0:
		defense_label.add_theme_color_override("font_color", Color("d8f6ff"))
		defense_label.add_theme_stylebox_override("normal", _stat_strip(Color(0.025, 0.12, 0.18, 0.9), Color(0.28, 0.73, 0.92, 0.95)))
	else:
		defense_label.add_theme_color_override("font_color", Color("e6ddd0"))
		defense_label.add_theme_stylebox_override("normal", _stat_strip(Color(0.055, 0.045, 0.04, 0.84), Color(0.38, 0.34, 0.28, 0.85)))


func _refresh_psd_values() -> void:
	if psd_health_value != null:
		psd_health_value.text = str(max(0, int(_data.get("hp", 0))))
	if psd_shield_value != null:
		psd_shield_value.text = str(max(0, int(_data.get("shield", 0))))
	if psd_attack_value != null:
		psd_attack_value.text = str(max(0, int(_data.get("atk", _data.get("attack", 0)))))
	if psd_damage_cap_value != null:
		psd_damage_cap_value.text = str(_damage_cap(_data))


func _damage_cap(data: Dictionary) -> int:
	for key in ["damage_cap", "damageCap", "incoming_damage_cap", "incomingDamageCap"]:
		if data.has(key):
			return max(0, int(data.get(key, 0)))
	return _incoming_damage(data)


func _psd_value_labels() -> Array[Label]:
	var labels: Array[Label] = []
	for label in [psd_health_value, psd_shield_value, psd_attack_value, psd_damage_cap_value]:
		if label != null:
			labels.append(label)
	return labels


func _apply_readability_style() -> void:
	for label in [life_label, attack_label, defense_label]:
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color(0.025, 0.02, 0.015, 0.98))
	life_label.add_theme_color_override("font_color", Color("e8ffe2"))
	life_label.add_theme_stylebox_override("normal", _stat_strip(Color(0.025, 0.13, 0.055, 0.9), Color(0.35, 0.82, 0.42, 0.95)))
	attack_label.add_theme_color_override("font_color", Color("fff0b8"))
	attack_label.add_theme_stylebox_override("normal", _stat_strip(Color(0.18, 0.1, 0.025, 0.9), Color(0.92, 0.63, 0.2, 0.95)))
	defense_label.add_theme_color_override("font_color", Color("e6ddd0"))
	defense_label.add_theme_stylebox_override("normal", _stat_strip(Color(0.055, 0.045, 0.04, 0.84), Color(0.38, 0.34, 0.28, 0.85)))


func _stat_strip(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	return style
