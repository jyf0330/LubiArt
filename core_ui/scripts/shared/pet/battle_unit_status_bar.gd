extends Control
class_name BattleUnitStatusBar

const BattlePetViewModelScript := preload("res://core_ui/scripts/battle/presenters/battle_pet_view_model.gd")
const ALLY_HEALTH_COLOR := Color("23d832")
const ENEMY_HEALTH_COLOR := Color("f59314")

@onready var health: UiValueBar = $Health
@onready var shield: UiValueBar = $Shield

var _view_model: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func present(data: Dictionary, unit_side: String) -> void:
	_view_model = BattlePetViewModelScript.from_record(data, unit_side)
	health.set_fill_color(
		ENEMY_HEALTH_COLOR if bool(_view_model.get("is_enemy", false)) else ALLY_HEALTH_COLOR
	)
	health.present(int(_view_model.hp), int(_view_model.max_hp))
	shield.present(int(_view_model.shield), int(_view_model.max_shield))
	shield.visible = int(_view_model.shield) > 0
	visible = true


func update_hp(value: int) -> void:
	if _view_model.is_empty():
		return
	_view_model["hp"] = clampi(value, 0, int(_view_model.max_hp))
	health.update_value(int(_view_model.hp))


func update_shield(value: int) -> void:
	if _view_model.is_empty():
		return
	var safe_value := maxi(0, value)
	_view_model["shield"] = safe_value
	_view_model["max_shield"] = maxi(int(_view_model.max_shield), maxi(1, safe_value))
	shield.present(safe_value, int(_view_model.max_shield))
	shield.visible = safe_value > 0


func show_damage_preview(projected_hp: int) -> void:
	health.show_loss_preview(projected_hp)


func clear_damage_preview() -> void:
	health.clear_preview()


func get_data_rects() -> Array[Rect2]:
	var health_rect := health.get_data_rect()
	health_rect.position += health.position
	var rects: Array[Rect2] = [health_rect]
	if shield.visible:
		var shield_rect := shield.get_data_rect()
		shield_rect.position += shield.position
		rects.append(shield_rect)
	return rects


func get_view_snapshot() -> Dictionary:
	return _view_model.duplicate(true)


func reset() -> void:
	_view_model.clear()
	visible = false
	health.clear_preview()
