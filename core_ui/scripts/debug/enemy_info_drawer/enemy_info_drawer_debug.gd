extends Control

const MockAssetProviderScript := preload("res://session/mock_asset_provider.gd")
const PET_IDS := ["pal_001", "pal_002", "pal_003", "pal_006", "pal_011", "pal_028", "pal_030", "pal_042"]

@onready var card: Control = $PreviewArea/AttackedEnemyInfoCard
@onready var hp_slider: HSlider = $DebugPanel/Margin/Controls/HpSlider
@onready var shield_slider: HSlider = $DebugPanel/Margin/Controls/ShieldSlider
@onready var hp_readout: Label = $DebugPanel/Margin/Controls/HpReadout
@onready var shield_readout: Label = $DebugPanel/Margin/Controls/ShieldReadout
@onready var preview_state: Label = $DebugPanel/Margin/Controls/PreviewState
@onready var attacker_count: OptionButton = $DebugPanel/Margin/Controls/AttackerCount

var _assets := MockAssetProviderScript.new()
var _target_id := "pal_001"
var _attacker_ids := ["pal_002", "pal_003", "pal_006", "pal_030"]
var _logo_variant := 2
var _movement_preview_active := false
var _visible_attacker_count := 0


func _ready() -> void:
	hp_slider.value_changed.connect(_on_hp_changed)
	shield_slider.value_changed.connect(_on_shield_changed)
	$DebugPanel/Margin/Controls/ToggleMovePreview.pressed.connect(_toggle_move_preview)
	$DebugPanel/Margin/Controls/RandomOneDigit.pressed.connect(_random_hp.bind(1))
	$DebugPanel/Margin/Controls/RandomTwoDigits.pressed.connect(_random_hp.bind(2))
	$DebugPanel/Margin/Controls/RandomThreeDigits.pressed.connect(_random_hp.bind(3))
	$DebugPanel/Margin/Controls/RandomTarget.pressed.connect(_random_target)
	$DebugPanel/Margin/Controls/ToggleLogo.pressed.connect(_toggle_logo)
	attacker_count.item_selected.connect(_attacker_count_changed)
	_set_default_state()


func _on_hp_changed(value: float) -> void:
	hp_readout.text = "HP：%d / %d" % [int(value), int(hp_slider.max_value)]
	card.call("set_health", int(value), int(hp_slider.max_value))


func _on_shield_changed(value: float) -> void:
	shield_readout.text = "护盾：%d / %d" % [int(value), int(shield_slider.max_value)]
	card.call("set_shield", int(value), int(shield_slider.max_value))


func _toggle_move_preview() -> void:
	_movement_preview_active = not _movement_preview_active
	if _movement_preview_active:
		_visible_attacker_count = maxi(1, attacker_count.selected)
		attacker_count.select(_visible_attacker_count)
		hp_slider.value = maxi(0, int(hp_slider.max_value) - 28)
		shield_slider.value = maxi(0, int(shield_slider.max_value) - 36)
	else:
		_set_default_state()
	_refresh()


func _set_default_state() -> void:
	_movement_preview_active = false
	_visible_attacker_count = 0
	attacker_count.select(0)
	hp_slider.value = hp_slider.max_value
	shield_slider.value = shield_slider.max_value
	_refresh()


func _random_hp(digits: int) -> void:
	var low := 1 if digits == 1 else int(pow(10, digits - 1))
	var high := 9 if digits == 1 else int(pow(10, digits)) - 1
	var value := randi_range(low, high)
	hp_slider.max_value = high
	hp_slider.value = value
	_on_hp_changed(value)


func _random_target() -> void:
	_target_id = String(PET_IDS.pick_random())
	_refresh()


func _toggle_logo() -> void:
	_logo_variant = 1 if _logo_variant == 2 else 2
	card.call("set_logo_variant", _logo_variant)


func _attacker_count_changed(index: int) -> void:
	_visible_attacker_count = index if _movement_preview_active else 0
	_refresh()


func _refresh() -> void:
	var textures: Array = []
	for index in range(mini(_visible_attacker_count, _attacker_ids.size())):
		textures.append(_assets.texture_for_pet_id(String(_attacker_ids[index])))
	card.call("set_card_data", {
		"target_texture": _assets.texture_for_pet_id(_target_id),
		"hp": int(hp_slider.value),
		"max_hp": int(hp_slider.max_value),
		"shield": int(shield_slider.value),
		"max_shield": int(shield_slider.max_value),
		"attacker_textures": textures,
		"logo_variant": _logo_variant,
	})
	preview_state.text = (
		"状态：移动后进入攻击范围，显示行动伤害预览"
		if _movement_preview_active
		else "状态：战斗开始，满血满护盾，攻击组为空"
	)
	_on_hp_changed(hp_slider.value)
	_on_shield_changed(shield_slider.value)
