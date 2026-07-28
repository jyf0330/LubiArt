extends Control
class_name PetStatusView

@export var psd_health_value_path: NodePath
@export var psd_shield_value_path: NodePath
@export var psd_attack_value_path: NodePath
@export var psd_damage_cap_value_path: NodePath

@onready var psd_health_value: Label = get_node_or_null(psd_health_value_path) as Label
@onready var psd_shield_value: Label = get_node_or_null(psd_shield_value_path) as Label
@onready var psd_attack_value: Label = get_node_or_null(psd_attack_value_path) as Label
@onready var psd_damage_cap_value: Label = get_node_or_null(psd_damage_cap_value_path) as Label

var _data: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	_data = {}
	for label in _psd_value_labels():
		label.text = ""
	set_mode(&"none")


func bind_battle_data(data: Dictionary) -> void:
	_data = data.duplicate(true)
	set_mode(&"battle")
	refresh()


func set_mode(mode: StringName) -> void:
	var battle_visible := mode == &"battle"
	for label in _psd_value_labels():
		label.visible = battle_visible


func refresh() -> void:
	_refresh_psd_values()


func update_hp(value: int) -> void:
	_data["hp"] = value
	if psd_health_value != null:
		psd_health_value.text = str(max(0, value))


func update_shield(value: int) -> void:
	_data["shield"] = max(0, value)
	if psd_shield_value != null:
		psd_shield_value.text = str(max(0, value))


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func _incoming_damage(data: Dictionary) -> int:
	var threat := Dictionary(data.get("threat", {}))
	return max(0, int(threat.get("totalDamage", threat.get("damage", threat.get("threat", threat.get("atk", 0))))))


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
