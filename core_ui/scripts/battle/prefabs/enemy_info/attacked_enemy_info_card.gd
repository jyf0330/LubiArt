extends Control

const HEALTH_FILL_WIDTH := 274.0
const SHIELD_FILL_WIDTH := 280.0
const ATTACKER_COUNT := 4

@export var attack_logo_01: Texture2D
@export var attack_logo_02: Texture2D

@onready var target_portrait: TextureRect = $TargetPortrait
@onready var health_fill: TextureProgressBar = $HealthBar/Fill
@onready var hp_value: Label = $HealthBar/HpValue
@onready var shield_fill: TextureProgressBar = $ShieldBar/Fill
@onready var attack_logo: TextureRect = $AttackLogo
@onready var attacker_nodes: Array[TextureRect] = [
	$Attackers/AttackerPortrait1,
	$Attackers/AttackerPortrait2,
	$Attackers/AttackerPortrait3,
	$Attackers/AttackerPortrait4,
]

var _logo_variant := 2


func _ready() -> void:
	set_logo_variant(_logo_variant)
	clear()


func set_card_data(data: Dictionary) -> void:
	visible = not data.is_empty()
	if not visible:
		clear()
		return
	target_portrait.texture = data.get("target_texture", null) as Texture2D
	var hp := maxi(0, int(data.get("hp", 0)))
	var max_hp := maxi(1, int(data.get("max_hp", hp)))
	var shield := maxi(0, int(data.get("shield", 0)))
	var max_shield := maxi(1, int(data.get("max_shield", max(shield, 1))))
	set_health(hp, max_hp)
	set_shield(shield, max_shield)
	set_attackers(Array(data.get("attacker_textures", [])))
	set_logo_variant(int(data.get("logo_variant", _logo_variant)))
	tooltip_text = String(data.get("tooltip", ""))


func set_health(value: int, maximum: int) -> void:
	var safe_max := maxi(1, maximum)
	health_fill.max_value = safe_max
	health_fill.value = clampi(value, 0, safe_max)
	hp_value.text = str(clampi(value, 0, safe_max))


func set_shield(value: int, maximum: int) -> void:
	var safe_max := maxi(1, maximum)
	shield_fill.max_value = safe_max
	shield_fill.value = clampi(value, 0, safe_max)


func set_attackers(textures: Array) -> void:
	for index in range(ATTACKER_COUNT):
		var texture := textures[index] as Texture2D if index < textures.size() else null
		attacker_nodes[index].texture = texture
		attacker_nodes[index].visible = texture != null


func set_logo_variant(variant: int) -> void:
	_logo_variant = 1 if variant == 1 else 2
	if attack_logo != null:
		attack_logo.texture = attack_logo_01 if _logo_variant == 1 else attack_logo_02


func clear() -> void:
	target_portrait.texture = null
	set_health(0, 1)
	set_shield(0, 1)
	set_attackers([])
	tooltip_text = ""
