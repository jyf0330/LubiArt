extends Control
class_name PetStatusView

## Battle stat semantics:
## - DamageCap (grey lock) is the maximum damage the unit may receive from one hit.
## - Shield (yellow shield) is the remaining shield consumed before HP by authoritative trace data.

const DAMAGE_CAP_KEYS := [
	"damage_cap",
	"damageCap",
	"incoming_damage_cap",
	"incomingDamageCap",
	"max_damage_per_hit",
	"maxDamagePerHit",
]
const HEALTH_PREFIX := "HP:"
const SHIELD_PREFIX := "SHLD:"
const ATTACK_PREFIX := "ATK:"
const DAMAGE_CAP_PREFIX := "CAP:"
const HEALTH_COLOR := Color("ffffff")
const ATTACK_COLOR := Color("ffffff")
const SHIELD_COLOR := Color("ffffff")
const DAMAGE_CAP_COLOR := Color("ffffff")

@export var psd_health_value_path: NodePath
@export var psd_shield_value_path: NodePath
@export var psd_attack_value_path: NodePath
@export var psd_damage_cap_value_path: NodePath

@onready var psd_health_value: Label = get_node_or_null(psd_health_value_path) as Label
@onready var psd_shield_value: Label = get_node_or_null(psd_shield_value_path) as Label
@onready var psd_attack_value: Label = get_node_or_null(psd_attack_value_path) as Label
@onready var psd_damage_cap_value: Label = get_node_or_null(psd_damage_cap_value_path) as Label
@onready var health_bar: ProgressBar = psd_health_value.get_parent() as ProgressBar \
	if psd_health_value != null else null

var _data: Dictionary = {}
var _battle_mode_enabled := false


func _ready() -> void:
	reset()


func reset() -> void:
	_data = {}
	_apply_stat_colors()
	for label in _psd_value_labels():
		label.text = ""
	set_mode(&"none")


func bind_battle_data(data: Dictionary) -> void:
	_data = data.duplicate(true)
	set_mode(&"battle")
	refresh()


func set_mode(mode: StringName) -> void:
	var battle_visible := mode == &"battle"
	_battle_mode_enabled = battle_visible
	for label in _psd_value_labels():
		label.visible = battle_visible
	# Battle health and shield are communicated by the shared composite bar.
	# Keep their authored labels available for data binding, but never render
	# duplicate numeric text over the unit.
	if psd_health_value != null:
		psd_health_value.visible = false
	if psd_shield_value != null:
		psd_shield_value.visible = false
	_set_damage_cap_visible(battle_visible and _damage_cap(_data) >= 0)


func refresh() -> void:
	_refresh_psd_values()


func update_hp(value: int) -> void:
	_data["hp"] = value
	if psd_health_value != null:
		psd_health_value.text = _stat_text(HEALTH_PREFIX, value)
	_refresh_health_bar()


func update_shield(value: int) -> void:
	_data["shield"] = max(0, value)
	if psd_shield_value != null:
		psd_shield_value.text = _stat_text(SHIELD_PREFIX, value)


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func _refresh_psd_values() -> void:
	if psd_health_value != null:
		psd_health_value.text = _stat_text(HEALTH_PREFIX, int(_data.get("hp", 0)))
	if psd_shield_value != null:
		psd_shield_value.text = _stat_text(SHIELD_PREFIX, int(_data.get("shield", 0)))
	if psd_attack_value != null:
		psd_attack_value.text = _stat_text(
			ATTACK_PREFIX,
			int(_data.get("atk", _data.get("attack", 0)))
		)
	if psd_damage_cap_value != null:
		var cap := _damage_cap(_data)
		psd_damage_cap_value.text = _stat_text(DAMAGE_CAP_PREFIX, cap) if cap >= 0 else ""
		_set_damage_cap_visible(_battle_mode_enabled and cap >= 0)
	_refresh_health_bar()


func _refresh_health_bar() -> void:
	if health_bar == null:
		return
	var current_hp := maxi(0, int(_data.get("hp", 0)))
	var max_hp := current_hp
	for key in ["max_hp", "maxHp", "hp_max", "hpMax"]:
		if _data.has(key):
			max_hp = maxi(0, int(_data.get(key, current_hp)))
			break
	max_hp = maxi(current_hp, max_hp)
	health_bar.min_value = 0.0
	health_bar.max_value = float(maxi(1, max_hp))
	health_bar.value = float(mini(current_hp, max_hp))


func _stat_text(prefix: String, value: int) -> String:
	return "%s%d" % [prefix, max(0, value)]


func _apply_stat_colors() -> void:
	if psd_health_value != null:
		psd_health_value.self_modulate = HEALTH_COLOR
	if psd_attack_value != null:
		psd_attack_value.self_modulate = ATTACK_COLOR
	if psd_shield_value != null:
		psd_shield_value.self_modulate = SHIELD_COLOR
	if psd_damage_cap_value != null:
		psd_damage_cap_value.self_modulate = DAMAGE_CAP_COLOR


func _damage_cap(data: Dictionary) -> int:
	for key in DAMAGE_CAP_KEYS:
		if data.has(key):
			return max(0, int(data.get(key, 0)))
	for buff_value in Array(data.get("buffs", [])):
		if not buff_value is Dictionary:
			continue
		var buff := Dictionary(buff_value)
		if not bool(buff.get("active", true)):
			continue
		for key in DAMAGE_CAP_KEYS:
			if buff.has(key):
				return max(0, int(buff.get(key, 0)))
	return -1


func _set_damage_cap_visible(visible_value: bool) -> void:
	if psd_damage_cap_value == null:
		return
	var group := psd_damage_cap_value.get_parent() as Control
	if group != null:
		group.visible = visible_value


func _psd_value_labels() -> Array[Label]:
	var labels: Array[Label] = []
	for label in [psd_health_value, psd_shield_value, psd_attack_value, psd_damage_cap_value]:
		if label != null:
			labels.append(label)
	return labels
