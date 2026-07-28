extends Control

const SOURCE_PSD := "/Users/ywh/Downloads/战斗精灵完整预制体.psd"
const SOURCE_CANVAS_SIZE := Vector2(171.0, 144.0)
const AUTHORED_CREATURE_TEXTURE := preload("res://art/images/shared/pets/battle_complete/creature_art.png")
const ATTACK_RANGE_TEXTURE := preload("res://art/images/shared/pets/battle_complete/attack_range_cell.png")

@onready var psd_root: Control = $CompleteBattleCreaturePrefab
@onready var status_view: PetStatusView = $"CompleteBattleCreaturePrefab/01_UnitVisual"
@onready var frame_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/SelectionFrame"
@onready var sprite_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt"
@onready var shadow_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/Shadow"
@onready var stats_root: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats"
@onready var enemy_marker_group: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/EnemyMarker_Optional"
@onready var front_target_cell: Control = $"CompleteBattleCreaturePrefab/02_FrontTargetCell"
@onready var attack_actions: Control = $"CompleteBattleCreaturePrefab/03_AttackActions"
@onready var health_group: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health"
@onready var shield_group: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield"
@onready var attack_group: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Attack"
@onready var damage_cap_group: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/DamageCap"
@onready var psd_health_value: Label = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/Value_Text"
@onready var psd_shield_value: Label = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield/Value_Text"
@onready var psd_attack_value: Label = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Attack/Value_Text"
@onready var psd_damage_cap_value: Label = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/DamageCap/Value_Text"
@onready var death_mark_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/DeathMark"
@onready var animation: PetAnimation = $"CompleteBattleCreaturePrefab/03_AttackActions"

var cell_data: Dictionary = {}
var side := ""
var _missing_mapping: Dictionary = {}
var _display_mode := &"battle"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation.configure(self)
	_layout_children()


func set_unit_data(data: Dictionary, unit_side: String, assets: RefCounted) -> void:
	reset_pet_view()
	cell_data = data.duplicate(true)
	side = unit_side
	_set_battle_presentation()
	_layout_children()
	if assets != null and assets.has_method("frame_texture"):
		frame_rect.texture = assets.call("frame_texture", side)
	frame_rect.visible = frame_rect.texture != null
	if assets != null and assets.has_method("texture_for_unit"):
		var result := Dictionary(assets.call("texture_for_unit", cell_data, side))
		sprite_rect.texture = result.get("texture", null) as Texture2D
		_missing_mapping = Dictionary(result.get("missing", {}))
	if sprite_rect.texture == null:
		sprite_rect.texture = AUTHORED_CREATURE_TEXTURE
	enemy_marker_group.visible = side == "enemy" or side == "monster"
	status_view.bind_battle_data(cell_data)
	clear_dead_mark()


func set_collection_data(data: Dictionary, texture_resource: Texture2D) -> void:
	reset_pet_view()
	cell_data = data.duplicate(true)
	side = "player"
	_display_mode = &"collection"
	frame_rect.visible = false
	_set_collection_presentation(texture_resource)
	status_view.set_mode(&"collection")
	clear_dead_mark()


func clear_collection_data() -> void:
	reset_pet_view()
	_display_mode = &"collection"
	frame_rect.visible = false
	_set_collection_presentation(null)
	status_view.set_mode(&"collection")
	clear_dead_mark()


func reset_pet_view() -> void:
	animation.reset()
	cell_data = {}
	side = ""
	_missing_mapping = {}
	_display_mode = &"none"
	frame_rect.texture = null
	frame_rect.visible = false
	sprite_rect.texture = null
	sprite_rect.visible = false
	_set_authored_root_visible(false)
	death_mark_rect.texture = null
	clear_dead_mark()
	status_view.reset()
	_reset_interaction_state()
	scale = Vector2.ONE
	rotation = 0.0


func get_display_mode() -> StringName:
	return _display_mode


func get_display_texture() -> Texture2D:
	return sprite_rect.texture


func _set_battle_presentation() -> void:
	_display_mode = &"battle"
	frame_rect.visible = true
	sprite_rect.visible = true
	_set_authored_root_visible(true)
	shadow_rect.visible = true
	stats_root.visible = true
	front_target_cell.visible = false
	attack_actions.visible = true
	enemy_marker_group.visible = side == "enemy" or side == "monster"
	status_view.set_mode(&"battle")


func get_unit_id() -> String:
	return String(cell_data.get("unitId", cell_data.get("unit_id", cell_data.get("id", ""))))


func get_missing_mapping() -> Dictionary:
	return _missing_mapping


func get_source_psd() -> String:
	return SOURCE_PSD


func get_source_canvas_size() -> Vector2:
	return SOURCE_CANVAS_SIZE


func get_attack_range_texture() -> Texture2D:
	return ATTACK_RANGE_TEXTURE


func get_dynamic_stat_snapshot() -> Dictionary:
	return status_view.snapshot()


func update_hp(value: int) -> void:
	cell_data["hp"] = value
	status_view.update_hp(value)


func update_shield(value: int) -> void:
	cell_data["shield"] = max(0, value)
	status_view.update_shield(value)


func set_selected(selected: bool) -> void:
	if frame_rect != null:
		frame_rect.modulate = Color(1.0, 0.92, 0.45, 1.0) if selected else Color.WHITE


func set_dragging(is_dragging: bool) -> void:
	visible = not is_dragging
	modulate = Color(1.0, 1.0, 1.0, 0.62) if is_dragging else Color.WHITE
	z_index = 40 if is_dragging else 0


func set_dead_mark(texture_resource: Texture2D) -> void:
	if death_mark_rect == null:
		return
	death_mark_rect.texture = texture_resource
	death_mark_rect.visible = texture_resource != null


func clear_dead_mark() -> void:
	if death_mark_rect != null:
		death_mark_rect.visible = false


func play_shake(duration: float = 0.22, strength: float = 7.0) -> void:
	animation.play_shake(duration, strength)


func move_to_position(target_position: Vector2, duration: float = 0.22) -> void:
	animation.move_to_position(target_position, duration)


func play_attack_action(attack_type: String, element_id: String = "fire") -> void:
	animation.play_attack_action(attack_type, element_id)


func get_last_attack_action_snapshot() -> Dictionary:
	return animation.get_last_attack_snapshot()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_children()


func _layout_children() -> void:
	if frame_rect == null or sprite_rect == null:
		return
	sprite_rect.position = Vector2.ZERO
	sprite_rect.size = Vector2(size.x, size.y * 120.0 / SOURCE_CANVAS_SIZE.y)
	_set_authored_rect(shadow_rect, Rect2(45.0, 104.0, 79.0, 19.0))
	_set_authored_rect(enemy_marker_group, Rect2(65.0, -49.0, 39.0, 48.0))
	_set_authored_rect(health_group, Rect2(16.0, 7.0, 46.0, 44.0))
	_set_authored_rect(shield_group, Rect2(114.0, 5.0, 35.0, 46.0))
	_set_authored_rect(attack_group, Rect2(11.0, 93.0, 49.0, 51.0))
	_set_authored_rect(damage_cap_group, Rect2(112.0, 92.0, 39.0, 47.0))
	_set_authored_local_rect(psd_health_value, Rect2(10.0, 8.0, 26.0, 21.0))
	_set_authored_local_rect(psd_shield_value, Rect2(7.0, 12.0, 24.0, 21.0))
	_set_authored_local_rect(psd_attack_value, Rect2(17.0, 17.0, 24.0, 21.0))
	_set_authored_local_rect(psd_damage_cap_value, Rect2(8.0, 20.0, 24.0, 21.0))
	var value_font_size := maxi(9, int(round(18.0 * minf(size.x / SOURCE_CANVAS_SIZE.x, size.y / SOURCE_CANVAS_SIZE.y))))
	for label in [psd_health_value, psd_shield_value, psd_attack_value, psd_damage_cap_value]:
		label.add_theme_font_size_override("font_size", value_font_size)
	if death_mark_rect != null:
		death_mark_rect.position = Vector2(size.x * 0.32, 4.0)
		death_mark_rect.size = Vector2(size.x * 0.36, size.y * 0.36)
	if animation != null:
		animation.layout_authored(size, SOURCE_CANVAS_SIZE)


func _set_authored_rect(control: Control, authored_rect: Rect2) -> void:
	if control == null:
		return
	var authored_scale := Vector2(
		size.x / SOURCE_CANVAS_SIZE.x,
		size.y / SOURCE_CANVAS_SIZE.y
	)
	control.position = authored_rect.position * authored_scale
	control.size = authored_rect.size * authored_scale


func _set_authored_local_rect(control: Control, authored_rect: Rect2) -> void:
	if control == null:
		return
	var authored_scale := Vector2(
		size.x / SOURCE_CANVAS_SIZE.x,
		size.y / SOURCE_CANVAS_SIZE.y
	)
	control.position = authored_rect.position * authored_scale
	control.size = authored_rect.size * authored_scale


func _set_collection_presentation(texture_resource: Texture2D) -> void:
	_set_authored_root_visible(texture_resource != null)
	sprite_rect.texture = texture_resource
	sprite_rect.visible = texture_resource != null
	shadow_rect.visible = false
	stats_root.visible = false
	enemy_marker_group.visible = false
	front_target_cell.visible = false
	attack_actions.visible = false


func _set_authored_root_visible(visible_value: bool) -> void:
	if psd_root != null:
		psd_root.visible = visible_value
	if not visible_value and enemy_marker_group != null:
		enemy_marker_group.visible = false


func _reset_interaction_state() -> void:
	visible = true
	modulate = Color.WHITE
	z_index = 0
	if frame_rect != null:
		frame_rect.modulate = Color.WHITE
