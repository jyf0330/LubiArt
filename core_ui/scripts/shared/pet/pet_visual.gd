extends Control

const SOURCE_PSD := "battle_creature_prefab_source.psd"
const SOURCE_CANVAS_SIZE := Vector2(180.0, 180.0)
const AUTHORED_CREATURE_TEXTURE := preload("res://art/images/shared/pets/battle_complete/creature_art_gold.png")
const BATTLE_FOOTLINE_BOTTOM_INSET := 15.0
const BATTLE_SHADOW_CENTER_Y_OFFSET := -3.0
const BATTLE_VISUAL_METRICS_PATH := "res://art/manifests/shared/pets/sheets/pet_battle_visual_metrics.json"
const PLAYER_HORIZONTAL_FACING := 1.0
const ENEMY_HORIZONTAL_FACING := -1.0
const DEFAULT_AUTHORED_HORIZONTAL_FACING := 1.0
const TRANSFORM_IDLE_TEXTURE_PATHS := {
	"res://art/images/shared/pets/sheets/slices/pet_style_001_gold_mascot.png": true,
}
const DAMAGE_PREVIEW_INITIAL_HOLD := 1.0
const DAMAGE_PREVIEW_VISIBLE_HOLD := 1.0
const DAMAGE_PREVIEW_HIDDEN_HOLD := 1.0
const DAMAGE_PREVIEW_FADE_DURATION := 0.12
const HEALTH_PREFIX := "HP:"
const SHIELD_PREFIX := "SHLD:"
const DAMAGE_PREVIEW_COLOR := Color("ff5a4f")
const DAMAGE_PREVIEW_HEALTH_SCALE := 1.45
const DAMAGE_PREVIEW_LETHAL_DIM_ALPHA := 0.32
const DAMAGE_PREVIEW_LETHAL_FLASH_HALF_DURATION := 0.24
const STAT_COLUMN_GAP := 1.0
const STAT_COLUMN_RIGHT_INSET := 4.0
const HEALTH_BAR_HEAD_GAP := 14.0
const DAMAGE_PREVIEW_BADGE_RIGHT_OVERHANG_RATIO := 0.25
const DAMAGE_PREVIEW_BADGE_BOTTOM_INSET := 4.0
const DAMAGE_HEALTH_BAR_DURATION := 0.32
static var _texture_used_rect_cache: Dictionary = {}
static var _battle_texture_cache: Dictionary = {}
static var _battle_visual_metrics_by_path: Dictionary = {}
static var _battle_visual_metrics_loaded := false
static var _missing_authored_facing_paths: Dictionary = {}

@onready var psd_root: Control = $CompleteBattleCreaturePrefab
@onready var status_view: PetStatusView = $"CompleteBattleCreaturePrefab/01_UnitVisual"
@onready var frame_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/SelectionFrame"
@onready var sprite_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt"
@onready var shadow_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/Shadow"
@onready var stats_root: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats"
@onready var enemy_marker_group: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/EnemyMarker_Optional"
@onready var front_target_cell: Control = $"CompleteBattleCreaturePrefab/02_FrontTargetCell"
@onready var attack_actions: Control = $"CompleteBattleCreaturePrefab/03_AttackActions"
@onready var health_group: ProgressBar = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health"
@onready var health_frame_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/Icon"
@onready var shield_group: ProgressBar = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield"
@onready var attack_group: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Attack"
@onready var damage_cap_group: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/DamageCap"
@onready var psd_health_value: Label = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/Value_Text"
@onready var psd_shield_value: Label = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield/Value_Text"
@onready var psd_attack_value: Label = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Attack/Value_Text"
@onready var psd_damage_cap_value: Label = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/DamageCap/Value_Text"
@onready var incoming_damage_preview: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/IncomingDamagePreview"
@onready var incoming_damage_separator: ColorRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/IncomingDamagePreview/Background"
@onready var incoming_damage_value: Label = $"CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health/IncomingDamagePreview/Value"
@onready var death_mark_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/DeathMark"
@onready var animation: PetAnimation = $"CompleteBattleCreaturePrefab/03_AttackActions"
@onready var hit_reaction: PetHitReaction = $"CompleteBattleCreaturePrefab/01_UnitVisual/HitReactionPlayer"
@onready var shield_hit_effect: PetShieldHitEffect = $"CompleteBattleCreaturePrefab/01_UnitVisual/ShieldHitEffectPlayer"

@export var ally_health_fill_style: StyleBoxFlat
@export var enemy_health_fill_style: StyleBoxFlat
@export var shield_fill_style: StyleBoxFlat
@export var bronze_health_frame: Texture2D
@export var silver_health_frame: Texture2D
@export var gold_health_frame: Texture2D
@export var diamond_health_frame: Texture2D

var cell_data: Dictionary = {}
var side := ""
var _assets: RefCounted = null
var _missing_mapping: Dictionary = {}
var _health_bar_tier_override := ""
var _health_bar_max_hp := 0
var _health_bar_max_shield := 0
var _health_bar_tween: Tween = null
var _display_mode := &"battle"
var _battle_sprite_visible_rect := Rect2()
var _battle_removed_bottom_pixels := 0
var _battle_footline_bottom_inset := BATTLE_FOOTLINE_BOTTOM_INSET
var _battle_stat_layout_scale := 1.0
var _battle_stat_layout_corners := PackedVector2Array()
var _authored_stat_layout: Dictionary = {}
var _death_tween: Tween = null
var _attack_translation_tween: Tween = null
var _damage_preview_tween: Tween = null
var _damage_preview_flash_tween: Tween = null
var _damage_preview_active := false
var _damage_preview_lethal := false
var _damage_preview_current_hp := 0
var _damage_preview_projected_hp := 0
var _damage_preview_current_shield := -1
var _damage_preview_projected_shield := -1
var _damage_preview_damage := 0
var _damage_preview_max_hp := 0
var _damage_preview_pinned := false
var _damage_preview_state := &""
var _damage_preview_value_base_modulate := Color.WHITE
var _damage_preview_value_base_self_modulate := Color.WHITE
var _damage_preview_sync_epoch_msec := -1
var _damage_preview_schedule_token := 0
var _damage_preview_deadline_msec := 0
var _damage_preview_revealed_stats := false
var _damage_preview_presentation_active := false
var _damage_preview_health_base_position := Vector2.ZERO
var _damage_preview_health_base_scale := Vector2.ONE
var _damage_preview_health_base_z_index := 0
var _damage_preview_health_base_group_modulate := Color.WHITE
var _damage_preview_attack_was_visible := false
var _damage_preview_shield_was_visible := false
var _damage_preview_cap_was_visible := false
var _damage_preview_uses_badge := false
var _damage_preview_badge_base_modulate := Color.WHITE
var _cursor_hit_texture: Texture2D = null
var _cursor_hit_image: Image = null
var _display_texture_source: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation.configure(self)
	_capture_authored_stat_layout()
	_layout_children()


func _process(_delta: float) -> void:
	if _display_mode == &"battle":
		_position_health_bar_above_sprite()
		if _damage_preview_active:
			_layout_damage_preview_in_health_bar()


func set_unit_data(data: Dictionary, unit_side: String, assets: RefCounted) -> void:
	reset_pet_view()
	cell_data = data.duplicate(true)
	_health_bar_max_hp = maxi(
		maxi(0, int(cell_data.get("hp", 0))),
		_max_hp(cell_data, 0)
	)
	_health_bar_max_shield = maxi(0, int(cell_data.get("shield", 0)))
	side = unit_side
	_assets = assets
	_set_battle_presentation()
	_layout_children()
	frame_rect.texture = null
	frame_rect.visible = false
	if assets != null and assets.has_method("texture_for_unit"):
		var result := Dictionary(assets.call("texture_for_unit", cell_data, side))
		sprite_rect.texture = result.get("texture", null) as Texture2D
		_missing_mapping = Dictionary(result.get("missing", {}))
	if sprite_rect.texture == null:
		sprite_rect.texture = AUTHORED_CREATURE_TEXTURE
	_display_texture_source = sprite_rect.texture
	var animation_texture_path := _display_texture_source.resource_path
	_layout_children()
	var visible_foot_pivot := Vector2(
		_battle_sprite_visible_rect.get_center().x,
		_battle_sprite_visible_rect.end.y
	) - sprite_rect.position
	animation.play_sprite_idle(
		sprite_rect,
		sprite_rect.texture,
		visible_foot_pivot,
		animation_texture_path,
		not TRANSFORM_IDLE_TEXTURE_PATHS.has(animation_texture_path),
		TRANSFORM_IDLE_TEXTURE_PATHS.has(animation_texture_path),
		_battle_horizontal_facing(side),
		true,
		_authored_horizontal_facing(_display_texture_source)
	)
	enemy_marker_group.visible = false
	status_view.bind_battle_data(cell_data)
	_refresh_battle_health_bar()
	clear_dead_mark()


func reconcile_unit_data(data: Dictionary, unit_side: String, assets: RefCounted) -> void:
	var incoming := data.duplicate(true)
	if _requires_full_unit_rebind(incoming, unit_side, assets):
		set_unit_data(incoming, unit_side, assets)
		return
	# Snapshot reconciliation is a presentation-cache commit, not a second
	# gameplay write. Keep the existing prefab and its animation lifecycle alive;
	# only refresh data-driven labels and stable side markers.
	cell_data = incoming
	var incoming_hp := maxi(0, int(cell_data.get("hp", 0)))
	var incoming_shield := maxi(0, int(cell_data.get("shield", 0)))
	_health_bar_max_hp = maxi(incoming_hp, _max_hp(cell_data, incoming_hp)) \
		if _has_max_hp(cell_data) else maxi(_health_bar_max_hp, incoming_hp)
	_health_bar_max_shield = maxi(_health_bar_max_shield, incoming_shield)
	side = unit_side
	_assets = assets
	status_view.bind_battle_data(cell_data)
	enemy_marker_group.visible = false
	_refresh_battle_health_bar()


func initialize_drag_preview_from(source: Control) -> void:
	if source == null or not (source.get("cell_data") is Dictionary):
		return
	# A duplicated Node keeps the already-resolved child textures and geometry,
	# but ordinary script state starts from defaults. Copy only stable presentation
	# state so a drag clone can show the same health/facing without asset rebinding.
	cell_data = Dictionary(source.get("cell_data")).duplicate(true)
	side = String(source.get("side"))
	_assets = source.get("_assets") as RefCounted
	_missing_mapping = Dictionary(source.get("_missing_mapping")).duplicate(true)
	_health_bar_tier_override = String(source.get("_health_bar_tier_override"))
	_health_bar_max_hp = int(source.get("_health_bar_max_hp"))
	_health_bar_max_shield = int(source.get("_health_bar_max_shield"))
	_display_mode = StringName(source.get("_display_mode"))
	_battle_sprite_visible_rect = source.get("_battle_sprite_visible_rect") as Rect2
	_battle_removed_bottom_pixels = int(source.get("_battle_removed_bottom_pixels"))
	_battle_footline_bottom_inset = float(source.get("_battle_footline_bottom_inset"))
	_display_texture_source = sprite_rect.texture
	status_view.bind_battle_data(cell_data)
	enemy_marker_group.visible = false
	_position_health_bar_above_sprite()
	_refresh_battle_health_bar()
	clear_dead_mark()


func _requires_full_unit_rebind(data: Dictionary, unit_side: String, assets: RefCounted) -> bool:
	if _display_mode != &"battle" or get_unit_id() != _unit_id(data):
		return true
	if side != unit_side or _assets != assets:
		return true
	return _visual_source_key(cell_data) != _visual_source_key(data)


func _unit_id(data: Dictionary) -> String:
	return String(data.get("unitId", data.get("unit_id", data.get("id", ""))))


func _battle_horizontal_facing(unit_side: String) -> float:
	return PLAYER_HORIZONTAL_FACING \
		if unit_side in ["player", "ally", "hero", "hero_leader", "player_leader"] \
		else ENEMY_HORIZONTAL_FACING


func _authored_horizontal_facing(texture_resource: Texture2D) -> float:
	if texture_resource == null:
		return DEFAULT_AUTHORED_HORIZONTAL_FACING
	var metrics := _battle_visual_metrics(texture_resource)
	var authored_facing := String(metrics.get("authored_horizontal_facing", "")).strip_edges().to_lower()
	match authored_facing:
		"left":
			return -1.0
		"right":
			return 1.0
		"neutral", "front":
			return 0.0
	var path := texture_resource.resource_path
	if path != "" and not _missing_authored_facing_paths.has(path):
		_missing_authored_facing_paths[path] = true
		push_warning(
			"Battle sprite is missing authored_horizontal_facing metadata; " \
			+ "using the project default 'right': %s" % path
		)
	return DEFAULT_AUTHORED_HORIZONTAL_FACING


func _visual_source_key(data: Dictionary) -> String:
	for key in ["image", "image_path", "sprite", "sprite_path", "icon", "icon_path"]:
		var path := String(data.get(key, "")).strip_edges()
		if path != "":
			return "path:%s" % path
	for key in ["pet_id", "petId", "source_pet_id", "sourcePetId"]:
		var pet_id := String(data.get(key, "")).strip_edges()
		if pet_id != "":
			return "pet:%s" % pet_id
	for key in ["name", "displayName", "unitName"]:
		var unit_name := String(data.get(key, "")).strip_edges()
		if unit_name != "":
			return "name:%s" % unit_name
	return "unit:%s" % _unit_id(data)


func set_battle_stat_layout_scale(
	value: float,
	cell_corners: PackedVector2Array = PackedVector2Array()
) -> void:
	_battle_stat_layout_scale = clampf(value, 0.1, 1.0)
	_battle_stat_layout_corners = cell_corners.duplicate()
	_layout_stats_from_prefab()


func set_collection_data(data: Dictionary, texture_resource: Texture2D) -> void:
	reset_pet_view()
	cell_data = data.duplicate(true)
	side = "player"
	_display_mode = &"collection"
	frame_rect.visible = false
	_display_texture_source = texture_resource
	_set_collection_presentation(texture_resource)
	animation.play_sprite_idle(
		sprite_rect,
		sprite_rect.texture,
		Vector2(-1.0, -1.0),
		texture_resource.resource_path if texture_resource != null else ""
	)
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
	_stop_health_bar_tween()
	_stop_damage_preview_animation(false)
	if hit_reaction != null:
		hit_reaction.reset()
	animation.reset()
	if front_target_cell != null and front_target_cell.has_method("reset"):
		front_target_cell.call("reset")
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	if _attack_translation_tween != null and _attack_translation_tween.is_valid():
		_attack_translation_tween.kill()
	_death_tween = null
	_attack_translation_tween = null
	cell_data = {}
	side = ""
	_assets = null
	_missing_mapping = {}
	_health_bar_tier_override = ""
	_health_bar_max_hp = 0
	_health_bar_max_shield = 0
	_display_mode = &"none"
	_battle_sprite_visible_rect = Rect2()
	_battle_removed_bottom_pixels = 0
	_battle_footline_bottom_inset = BATTLE_FOOTLINE_BOTTOM_INSET
	frame_rect.texture = null
	frame_rect.visible = false
	sprite_rect.texture = null
	_display_texture_source = null
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
	return _display_texture_source if _display_texture_source != null else sprite_rect.texture


func get_battle_sprite_visible_rect() -> Rect2:
	return _battle_sprite_visible_rect


func get_battle_sprite_actual_top_y() -> float:
	return _battle_sprite_actual_top_y()


func get_battle_footline_bottom_inset() -> float:
	return _battle_footline_bottom_inset


func get_battle_removed_bottom_pixels() -> int:
	return _battle_removed_bottom_pixels


func _set_battle_presentation() -> void:
	_display_mode = &"battle"
	frame_rect.visible = false
	sprite_rect.visible = true
	_set_authored_root_visible(true)
	shadow_rect.visible = true
	shadow_rect.z_index = 0
	sprite_rect.z_index = 1
	_refresh_battle_health_bar()
	front_target_cell.visible = false
	attack_actions.visible = true
	enemy_marker_group.visible = false
	status_view.set_mode(&"battle")


func get_unit_id() -> String:
	return String(cell_data.get("unitId", cell_data.get("unit_id", cell_data.get("id", ""))))


func get_missing_mapping() -> Dictionary:
	return _missing_mapping


func get_source_psd() -> String:
	return SOURCE_PSD


func get_source_canvas_size() -> Vector2:
	return SOURCE_CANVAS_SIZE


func get_dynamic_stat_snapshot() -> Dictionary:
	return status_view.snapshot()


func update_hp(value: int) -> void:
	_stop_health_bar_tween()
	cell_data["hp"] = value
	var safe_value := maxi(0, value)
	_health_bar_max_hp = maxi(safe_value, _max_hp(cell_data, safe_value)) \
		if _has_max_hp(cell_data) else maxi(_health_bar_max_hp, safe_value)
	status_view.update_hp(value)
	_refresh_battle_health_bar()
	if _damage_preview_active:
		_damage_preview_current_hp = maxi(0, value)
		if _damage_preview_projected_hp >= _damage_preview_current_hp:
			stop_damage_preview()
		else:
			_show_damage_preview_value()


func start_damage_preview(
	current_hp: int,
	projected_hp: int,
	sync_epoch_msec: int = -1,
	predicted_damage: int = -1,
	current_shield: int = -1,
	projected_shield: int = -1,
	max_hp: int = -1,
	pinned: bool = true,
	initial_hold: float = DAMAGE_PREVIEW_INITIAL_HOLD
) -> void:
	var safe_current := maxi(0, current_hp)
	var safe_projected := maxi(0, projected_hp)
	var safe_current_shield := maxi(0, current_shield) if current_shield >= 0 else -1
	var safe_projected_shield := maxi(0, projected_shield) if projected_shield >= 0 else -1
	var safe_max_hp := maxi(safe_current, max_hp if max_hp >= 0 else safe_current)
	var fallback_damage := safe_current - safe_projected
	if safe_current_shield >= 0 and safe_projected_shield >= 0:
		fallback_damage += safe_current_shield - safe_projected_shield
	var safe_damage := maxi(0, predicted_damage if predicted_damage >= 0 else fallback_damage)
	if safe_damage <= 0:
		stop_damage_preview()
		return
	if _damage_preview_active \
			and _damage_preview_current_hp == safe_current \
			and _damage_preview_projected_hp == safe_projected \
			and _damage_preview_current_shield == safe_current_shield \
			and _damage_preview_projected_shield == safe_projected_shield \
			and _damage_preview_damage == safe_damage \
			and _damage_preview_max_hp == safe_max_hp:
		if pinned:
			pin_damage_preview()
		elif _damage_preview_pinned:
			release_damage_preview(initial_hold)
		return
	_stop_damage_preview_animation(false)
	_damage_preview_uses_badge = incoming_damage_preview != null
	_damage_preview_revealed_stats = stats_root != null and not stats_root.visible
	_refresh_battle_health_bar()
	_damage_preview_active = true
	_damage_preview_lethal = safe_current > 0 and safe_projected <= 0
	_damage_preview_current_hp = safe_current
	_damage_preview_projected_hp = safe_projected
	_damage_preview_current_shield = safe_current_shield
	_damage_preview_projected_shield = safe_projected_shield
	_damage_preview_damage = safe_damage
	_damage_preview_max_hp = safe_max_hp
	_damage_preview_pinned = pinned
	_damage_preview_value_base_modulate = psd_health_value.modulate if psd_health_value != null else Color.WHITE
	_damage_preview_value_base_self_modulate = psd_health_value.self_modulate if psd_health_value != null else Color.WHITE
	_damage_preview_badge_base_modulate = incoming_damage_preview.modulate \
		if incoming_damage_preview != null else Color.WHITE
	_damage_preview_sync_epoch_msec = sync_epoch_msec
	_show_damage_preview_value()
	_set_damage_preview_visible(true)
	if not _damage_preview_pinned:
		_schedule_damage_preview_timeout(initial_hold)


func stop_damage_preview() -> void:
	_stop_damage_preview_animation(true)


func pin_damage_preview() -> void:
	if not _damage_preview_active:
		return
	_damage_preview_pinned = true
	_damage_preview_schedule_token += 1
	_damage_preview_deadline_msec = 0
	if _damage_preview_tween != null and _damage_preview_tween.is_valid():
		_damage_preview_tween.kill()
	_damage_preview_tween = null
	_set_damage_preview_visible(true)


func release_damage_preview(hold_seconds: float = DAMAGE_PREVIEW_INITIAL_HOLD) -> void:
	if not _damage_preview_active:
		return
	_damage_preview_pinned = false
	_damage_preview_schedule_token += 1
	if _damage_preview_tween != null and _damage_preview_tween.is_valid():
		_damage_preview_tween.kill()
	_damage_preview_tween = null
	_set_damage_preview_visible(true)
	_schedule_damage_preview_timeout(hold_seconds)


func get_damage_preview_snapshot() -> Dictionary:
	return {
		"active": _damage_preview_active,
		"state": String(_damage_preview_state),
		"pinned": _damage_preview_pinned,
		"current_hp": _damage_preview_current_hp,
		"projected_hp": _damage_preview_projected_hp,
		"max_hp": _damage_preview_max_hp,
		"current_shield": _damage_preview_current_shield,
		"projected_shield": _damage_preview_projected_shield,
		"predicted_damage": _damage_preview_damage,
		"lethal": _damage_preview_lethal,
		"embedded_in_health_bar": _damage_preview_uses_badge,
		"lethal_flash_active": _damage_preview_flash_tween != null \
			and _damage_preview_flash_tween.is_valid(),
		"displayed_hp": _displayed_hp_value(),
		"displayed_damage": _displayed_damage_value(),
		"uses_badge": _damage_preview_uses_badge,
		"initial_hold": DAMAGE_PREVIEW_INITIAL_HOLD,
		"visible_hold": DAMAGE_PREVIEW_VISIBLE_HOLD,
		"hidden_hold": DAMAGE_PREVIEW_HIDDEN_HOLD,
		"sync_epoch_msec": _damage_preview_sync_epoch_msec,
		"seconds_to_switch": maxf(
			0.0,
			float(_damage_preview_deadline_msec - Time.get_ticks_msec()) / 1000.0
		) if _damage_preview_active else 0.0,
	}


func _on_damage_preview_timeout() -> void:
	if not _damage_preview_active or _damage_preview_pinned:
		return
	stop_damage_preview()


func _fade_damage_preview(show: bool) -> void:
	var preview_control := incoming_damage_preview if _damage_preview_uses_badge else health_group
	if preview_control == null:
		_set_damage_preview_visible(show)
		_schedule_damage_preview_timeout(
			DAMAGE_PREVIEW_VISIBLE_HOLD if show else DAMAGE_PREVIEW_HIDDEN_HOLD
		)
		return
	if _damage_preview_tween != null and _damage_preview_tween.is_valid():
		_damage_preview_tween.kill()
	_damage_preview_tween = create_tween()
	_damage_preview_tween.set_trans(Tween.TRANS_SINE)
	_damage_preview_tween.set_ease(Tween.EASE_IN_OUT)
	_damage_preview_tween.tween_property(
		preview_control,
		"modulate:a",
		_damage_preview_badge_base_modulate.a \
			if show and _damage_preview_uses_badge \
			else (_damage_preview_health_base_group_modulate.a if show else 0.0),
		DAMAGE_PREVIEW_FADE_DURATION
	)
	_damage_preview_tween.tween_callback(
		_complete_damage_preview_fade.bind(
			show,
			DAMAGE_PREVIEW_VISIBLE_HOLD if show else DAMAGE_PREVIEW_HIDDEN_HOLD
		)
	)


func _complete_damage_preview_fade(visible_value: bool, hold_duration: float) -> void:
	if not _damage_preview_active or _damage_preview_pinned:
		return
	_damage_preview_state = &"visible" if visible_value else &"hidden"
	_schedule_damage_preview_timeout(hold_duration)


func _set_damage_preview_visible(visible_value: bool) -> void:
	if _damage_preview_uses_badge and incoming_damage_preview != null:
		incoming_damage_preview.visible = visible_value
		incoming_damage_preview.modulate.a = _damage_preview_badge_base_modulate.a \
			if visible_value else 0.0
	elif health_group != null:
		health_group.modulate.a = _damage_preview_health_base_group_modulate.a if visible_value else 0.0
	_damage_preview_state = &"visible" if visible_value else &"hidden"
	_sync_lethal_damage_preview_flash()


func _show_damage_preview_value() -> void:
	if not _damage_preview_active:
		return
	if shield_group != null:
		shield_group.visible = false
	if _damage_preview_uses_badge:
		if incoming_damage_value != null:
			incoming_damage_value.text = ""
			incoming_damage_value.self_modulate = Color.WHITE
		_layout_damage_preview_in_health_bar()
		_sync_lethal_damage_preview_flash()
		return
	if psd_health_value == null:
		return
	psd_health_value.text = HEALTH_PREFIX + str(_damage_preview_projected_hp)
	psd_health_value.self_modulate = _damage_preview_value_base_self_modulate \
		if _damage_preview_projected_hp >= _damage_preview_max_hp else DAMAGE_PREVIEW_COLOR


func _schedule_damage_preview_timeout(duration: float) -> void:
	if not _damage_preview_active:
		return
	_damage_preview_schedule_token += 1
	var scheduled_token := _damage_preview_schedule_token
	var safe_duration := maxf(duration, 0.001)
	_damage_preview_deadline_msec = Time.get_ticks_msec() + int(round(safe_duration * 1000.0))
	get_tree().create_timer(safe_duration).timeout.connect(func() -> void:
		if scheduled_token == _damage_preview_schedule_token and _damage_preview_active:
			_on_damage_preview_timeout()
	)


func _stop_damage_preview_animation(restore_current_hp: bool) -> void:
	var had_preview_animation := _damage_preview_active \
		or (_damage_preview_tween != null and _damage_preview_tween.is_valid())
	_damage_preview_schedule_token += 1
	_damage_preview_deadline_msec = 0
	if _damage_preview_tween != null and _damage_preview_tween.is_valid():
		_damage_preview_tween.kill()
	_damage_preview_tween = null
	_stop_lethal_damage_preview_flash()
	if had_preview_animation and psd_health_value != null:
		psd_health_value.modulate = _damage_preview_value_base_modulate
		psd_health_value.self_modulate = _damage_preview_value_base_self_modulate
	if incoming_damage_preview != null:
		incoming_damage_preview.visible = false
		incoming_damage_preview.modulate = _damage_preview_badge_base_modulate
	if incoming_damage_value != null:
		incoming_damage_value.text = ""
	_damage_preview_active = false
	_damage_preview_lethal = false
	_damage_preview_pinned = false
	_damage_preview_state = &""
	_damage_preview_sync_epoch_msec = -1
	_leave_damage_preview_presentation()
	_layout_shield_bar_segment()
	if not _damage_preview_uses_badge and stats_root != null:
		_refresh_battle_health_bar()
	_damage_preview_revealed_stats = false
	_damage_preview_uses_badge = false
	if restore_current_hp and psd_health_value != null:
		psd_health_value.text = HEALTH_PREFIX + str(max(0, int(cell_data.get("hp", 0))))
	if restore_current_hp and psd_shield_value != null:
		psd_shield_value.text = SHIELD_PREFIX + str(max(0, int(cell_data.get("shield", 0))))


func _enter_damage_preview_presentation() -> void:
	if _damage_preview_presentation_active or health_group == null:
		return
	_damage_preview_presentation_active = true
	_damage_preview_health_base_position = health_group.position
	_damage_preview_health_base_scale = health_group.scale
	_damage_preview_health_base_z_index = health_group.z_index
	_damage_preview_health_base_group_modulate = health_group.modulate
	_damage_preview_attack_was_visible = attack_group != null and attack_group.visible
	_damage_preview_shield_was_visible = shield_group != null and shield_group.visible
	_damage_preview_cap_was_visible = damage_cap_group != null and damage_cap_group.visible
	var extra_width := health_group.size.x * health_group.scale.x * (DAMAGE_PREVIEW_HEALTH_SCALE - 1.0)
	health_group.position.x -= extra_width
	health_group.scale *= DAMAGE_PREVIEW_HEALTH_SCALE
	health_group.z_index = 12
	_layout_shield_bar_segment()
	if attack_group != null:
		attack_group.visible = false
	if damage_cap_group != null:
		damage_cap_group.visible = false


func _leave_damage_preview_presentation() -> void:
	if not _damage_preview_presentation_active:
		return
	_damage_preview_presentation_active = false
	if health_group != null:
		health_group.position = _damage_preview_health_base_position
		health_group.scale = _damage_preview_health_base_scale
		health_group.z_index = _damage_preview_health_base_z_index
		health_group.modulate = _damage_preview_health_base_group_modulate
	if attack_group != null:
		attack_group.visible = _damage_preview_attack_was_visible
	if shield_group != null:
		shield_group.visible = _damage_preview_shield_was_visible
	_layout_shield_bar_segment()
	if damage_cap_group != null:
		damage_cap_group.visible = _damage_preview_cap_was_visible


func _displayed_hp_value() -> int:
	if psd_health_value == null:
		return -1
	var numeric_text := psd_health_value.text.trim_prefix(HEALTH_PREFIX).strip_edges()
	if numeric_text.contains(" "):
		numeric_text = numeric_text.get_slice(" ", 0)
	return int(numeric_text) if numeric_text.is_valid_int() else -1


func _displayed_damage_value() -> int:
	return _damage_preview_damage if _damage_preview_active else -1


func _layout_damage_preview_in_health_bar() -> void:
	if not _damage_preview_active or not _damage_preview_uses_badge \
			or incoming_damage_preview == null or health_group == null:
		return
	var safe_max_hp := maxi(1, _damage_preview_max_hp)
	var current_shield := _damage_preview_current_shield \
		if _damage_preview_current_shield >= 0 else maxi(0, int(cell_data.get("shield", 0)))
	var projected_shield := _damage_preview_projected_shield \
		if _damage_preview_projected_shield >= 0 else current_shield
	var bar_capacity := maxi(
		1,
		safe_max_hp + maxi(_health_bar_max_shield, current_shield)
	)
	var current_effective := mini(
		bar_capacity,
		maxi(0, _damage_preview_current_hp) + current_shield
	)
	var projected_effective := mini(
		current_effective,
		maxi(0, _damage_preview_projected_hp) + projected_shield
	)
	var current_ratio := clampf(float(current_effective) / float(bar_capacity), 0.0, 1.0)
	var projected_ratio := clampf(
		float(projected_effective) / float(bar_capacity),
		0.0,
		current_ratio
	)
	var current_fill_width := health_group.size.x * current_ratio
	var projected_fill_width := health_group.size.x * projected_ratio
	var damage_fill_width := maxf(0.0, current_fill_width - projected_fill_width)
	if damage_fill_width <= 0.0:
		incoming_damage_preview.visible = false
		return
	var preview_height := health_group.size.y
	incoming_damage_preview.position = Vector2(projected_fill_width, 0.0)
	incoming_damage_preview.size = Vector2(
		damage_fill_width,
		preview_height
	)
	incoming_damage_preview.scale = Vector2.ONE
	incoming_damage_preview.visible = _damage_preview_state != &"hidden"
	if incoming_damage_separator != null:
		incoming_damage_separator.position = Vector2.ZERO
		incoming_damage_separator.size = Vector2(damage_fill_width, preview_height)
	if incoming_damage_value != null:
		incoming_damage_value.position = Vector2.ZERO
		incoming_damage_value.size = Vector2(
			damage_fill_width,
			preview_height
		)


func _sync_lethal_damage_preview_flash() -> void:
	if not _damage_preview_active or not _damage_preview_lethal \
			or incoming_damage_value == null or not incoming_damage_preview.visible:
		_stop_lethal_damage_preview_flash()
		return
	if _damage_preview_flash_tween != null and _damage_preview_flash_tween.is_valid():
		return
	incoming_damage_value.modulate.a = 1.0
	_damage_preview_flash_tween = create_tween().set_loops()
	_damage_preview_flash_tween.tween_property(
		incoming_damage_value,
		"modulate:a",
		DAMAGE_PREVIEW_LETHAL_DIM_ALPHA,
		DAMAGE_PREVIEW_LETHAL_FLASH_HALF_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_damage_preview_flash_tween.tween_property(
		incoming_damage_value,
		"modulate:a",
		1.0,
		DAMAGE_PREVIEW_LETHAL_FLASH_HALF_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_lethal_damage_preview_flash() -> void:
	if _damage_preview_flash_tween != null and _damage_preview_flash_tween.is_valid():
		_damage_preview_flash_tween.kill()
	_damage_preview_flash_tween = null
	if incoming_damage_value != null:
		incoming_damage_value.modulate.a = 1.0


func update_shield(value: int) -> void:
	var safe_value := maxi(0, value)
	cell_data["shield"] = safe_value
	_health_bar_max_shield = maxi(_health_bar_max_shield, safe_value)
	status_view.update_shield(value)
	_refresh_battle_health_bar()


func set_selected(selected: bool) -> void:
	if frame_rect != null:
		frame_rect.modulate = Color(1.0, 0.92, 0.45, 1.0) if selected else Color.WHITE


func show_action_block_attack_ranges(
	ranges: Array,
	grid_cell_size: Vector2 = Vector2.ZERO,
	origin_grid: Vector2i = Vector2i(-1, -1),
	board_size: Vector2 = Vector2.ZERO,
	board_global_position: Vector2 = Vector2.ZERO,
	board_geometry: Dictionary = {}
) -> void:
	if front_target_cell == null or not front_target_cell.has_method("show_action_block_ranges"):
		return
	front_target_cell.call(
		"show_action_block_ranges",
		ranges,
		grid_cell_size,
		origin_grid,
		board_size,
		board_global_position,
		board_geometry
	)


func hide_action_block_attack_ranges() -> void:
	if front_target_cell != null and front_target_cell.has_method("reset"):
		front_target_cell.call("reset")


func get_action_block_attack_range_snapshot() -> Dictionary:
	if front_target_cell == null or not front_target_cell.has_method("snapshot"):
		return {}
	return Dictionary(front_target_cell.call("snapshot"))


func set_dragging(is_dragging: bool) -> void:
	_refresh_battle_health_bar()
	visible = not is_dragging
	modulate = Color(1.0, 1.0, 1.0, 0.62) if is_dragging else Color.WHITE
	z_index = 40 if is_dragging else 0


func set_battle_stats_pointer_hovered(_hovered: bool) -> void:
	_refresh_battle_health_bar()


func _hide_battle_stats() -> void:
	if stats_root != null:
		stats_root.visible = false


func _refresh_battle_health_bar() -> void:
	if stats_root == null or health_group == null:
		return
	var battle_visible := _display_mode == &"battle" and not cell_data.is_empty()
	stats_root.visible = battle_visible
	health_group.visible = battle_visible
	psd_health_value.visible = false
	psd_shield_value.visible = false
	if health_frame_rect != null:
		health_frame_rect.visible = battle_visible
	if attack_group != null:
		attack_group.visible = false
	if shield_group != null:
		shield_group.visible = false
	if damage_cap_group != null:
		damage_cap_group.visible = false
	if not battle_visible:
		return
	var current_hp := maxi(0, int(cell_data.get("hp", 0)))
	var current_shield := maxi(0, int(cell_data.get("shield", 0)))
	_health_bar_max_shield = maxi(_health_bar_max_shield, current_shield)
	_health_bar_max_hp = maxi(current_hp, _max_hp(cell_data, current_hp)) \
		if _has_max_hp(cell_data) else maxi(_health_bar_max_hp, current_hp)
	var max_hp := maxi(1, _health_bar_max_hp)
	var bar_capacity := maxi(1, max_hp + _health_bar_max_shield)
	health_group.min_value = 0.0
	health_group.max_value = float(bar_capacity)
	health_group.value = float(mini(current_hp, bar_capacity))
	if shield_group != null:
		shield_group.min_value = 0.0
		shield_group.max_value = 1.0
		shield_group.value = 1.0
		if shield_fill_style != null:
			shield_group.add_theme_stylebox_override("fill", shield_fill_style)
		_layout_shield_bar_segment(current_hp, current_shield, bar_capacity)
	var fill_style := ally_health_fill_style if _is_player_side(side) else enemy_health_fill_style
	if fill_style != null:
		health_group.add_theme_stylebox_override("fill", fill_style)
	_apply_health_bar_frame(_effective_health_bar_tier())


func set_health_bar_tier(tier: String) -> void:
	_health_bar_tier_override = _normalize_health_bar_tier(tier)
	_refresh_battle_health_bar()


func clear_health_bar_tier_override() -> void:
	_health_bar_tier_override = ""
	_refresh_battle_health_bar()


func get_health_bar_tier() -> String:
	return _effective_health_bar_tier()


func _effective_health_bar_tier() -> String:
	if _health_bar_tier_override != "":
		return _health_bar_tier_override
	for key in ["rank", "quality", "rarity", "tier"]:
		if cell_data.has(key):
			return _normalize_health_bar_tier(String(cell_data.get(key, "")))
	return "bronze"


func _normalize_health_bar_tier(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	if normalized.contains("diamond") or normalized.contains("crystal") \
			or value.contains("钻石") or value.contains("水晶"):
		return "diamond"
	if normalized.contains("gold") or value.contains("黄金"):
		return "gold"
	if normalized.contains("silver") or value.contains("白银"):
		return "silver"
	return "bronze"


func _apply_health_bar_frame(tier: String) -> void:
	if health_frame_rect == null:
		return
	match tier:
		"silver":
			health_frame_rect.texture = silver_health_frame
		"gold":
			health_frame_rect.texture = gold_health_frame
		"diamond":
			health_frame_rect.texture = diamond_health_frame
		_:
			health_frame_rect.texture = bronze_health_frame


func _max_hp(data: Dictionary, fallback: int) -> int:
	for key in ["max_hp", "maxHp", "hp_max", "hpMax"]:
		if data.has(key):
			return maxi(0, int(data.get(key, fallback)))
	return maxi(0, fallback)


func _has_max_hp(data: Dictionary) -> bool:
	for key in ["max_hp", "maxHp", "hp_max", "hpMax"]:
		if data.has(key):
			return true
	return false


func _is_player_side(unit_side: String) -> bool:
	return unit_side.strip_edges().to_lower() in [
		"player", "ally", "hero", "hero_leader", "player_leader",
	]


func contains_art_point(viewport_point: Vector2, alpha_threshold: float = 0.08) -> bool:
	if sprite_rect == null or sprite_rect.texture == null:
		return false
	var local_point := sprite_rect.get_global_transform_with_canvas().affine_inverse() * viewport_point
	var texture_size := sprite_rect.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or sprite_rect.size.x <= 0.0 or sprite_rect.size.y <= 0.0:
		return false
	var fit_scale := minf(sprite_rect.size.x / texture_size.x, sprite_rect.size.y / texture_size.y)
	var drawn_size := texture_size * fit_scale
	var drawn_origin := (sprite_rect.size - drawn_size) * 0.5
	var drawn_rect := Rect2(drawn_origin, drawn_size)
	if not drawn_rect.has_point(local_point):
		return false
	if _cursor_hit_texture != sprite_rect.texture:
		_cursor_hit_texture = sprite_rect.texture
		_cursor_hit_image = sprite_rect.texture.get_image()
	var image := _cursor_hit_image
	if image == null or image.is_empty():
		return true
	var uv := (local_point - drawn_origin) / drawn_size
	var pixel := Vector2i(
		clampi(int(floor(uv.x * float(image.get_width()))), 0, image.get_width() - 1),
		clampi(int(floor(uv.y * float(image.get_height()))), 0, image.get_height() - 1)
	)
	return image.get_pixelv(pixel).a >= alpha_threshold


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


func get_move_animation_duration(fallback: float = 0.22) -> float:
	return animation.get_move_animation_duration(fallback)


func play_attack_action(attack_type: String, element_id: String = "fire") -> void:
	animation.play_sprite_attack(Vector2.RIGHT)
	animation.play_attack_action(attack_type, element_id)


func get_last_attack_action_snapshot() -> Dictionary:
	return animation.get_last_attack_snapshot()


func play_cross_cell_projectile(
	element_id: String,
	from_global_center: Vector2,
	to_global_center: Vector2,
	duration: float = 0.32,
	arc_height: float = 96.0
) -> Node:
	animation.play_sprite_attack(to_global_center - from_global_center, duration)
	return animation.play_projectile_between(
		element_id,
		from_global_center,
		to_global_center,
		duration,
		arc_height
	)


func play_bite_impact() -> Node:
	return animation.play_attack_action("bite")


func play_damage_feedback(payload: Dictionary, reaction_direction: Vector2 = Vector2.RIGHT) -> void:
	var shield_damage: int = max(0, int(payload.get("shieldDamage", 0)))
	var final_damage: int = max(0, int(payload.get("finalDamage", 0)))
	var hp_damage: int = max(0, int(payload.get("hpDamage", final_damage - shield_damage)))
	var shield_before: int = max(0, int(payload.get("shieldFrom", cell_data.get("shield", 0))))
	if shield_before > 0 and shield_hit_effect != null:
		shield_hit_effect.play()
	if shield_before <= 0 and hp_damage > 0 and hit_reaction != null:
		hit_reaction.play(reaction_direction, _battle_sprite_visible_rect)
	var hp_from := maxi(0, int(payload.get("hpFrom", cell_data.get("hp", 0))))
	var hp_to := maxi(0, int(payload.get("hpTo", hp_from - hp_damage)))
	update_shield(int(payload.get("shieldTo", int(cell_data.get("shield", 0)))))
	_animate_health_bar_damage(hp_from, hp_to)


func get_damage_feedback_duration() -> float:
	return DAMAGE_HEALTH_BAR_DURATION


func _animate_health_bar_damage(hp_from: int, hp_to: int) -> void:
	_stop_health_bar_tween()
	_health_bar_max_hp = maxi(hp_from, _max_hp(cell_data, hp_from)) \
		if _has_max_hp(cell_data) else maxi(_health_bar_max_hp, hp_from)
	cell_data["hp"] = hp_to
	status_view.update_hp(hp_to)
	_refresh_battle_health_bar()
	if health_group == null or hp_from <= hp_to:
		return
	var safe_from := mini(hp_from, int(health_group.max_value))
	var safe_to := mini(hp_to, int(health_group.max_value))
	health_group.value = float(safe_from)
	_health_bar_tween = create_tween()
	_health_bar_tween.tween_property(
		health_group,
		"value",
		float(safe_to),
		DAMAGE_HEALTH_BAR_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_health_bar_tween.finished.connect(func():
		_health_bar_tween = null
	)


func _stop_health_bar_tween() -> void:
	if _health_bar_tween != null and _health_bar_tween.is_valid():
		_health_bar_tween.kill()
	_health_bar_tween = null


func play_attack_translation(
	target_global_center: Vector2,
	translation_ratio: float = 0.68,
	out_duration: float = 0.18,
	hold_duration: float = 0.08,
	return_duration: float = 0.16
) -> Tween:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return null
	if _attack_translation_tween != null and _attack_translation_tween.is_valid():
		_attack_translation_tween.kill()
	var parent_inverse := parent_control.get_global_transform_with_canvas().affine_inverse()
	var actor_global_center := get_global_transform_with_canvas() * (size * 0.5)
	var travel_delta := (parent_inverse * target_global_center) - (parent_inverse * actor_global_center)
	if travel_delta.length_squared() <= 0.01:
		return null
	animation.play_sprite_attack(
		travel_delta,
		out_duration + hold_duration + return_duration
	)
	var origin := position
	var original_z_index := z_index
	z_index = max(z_index, 26)
	_attack_translation_tween = create_tween()
	_attack_translation_tween.tween_property(self, "position", origin + travel_delta * translation_ratio, out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_attack_translation_tween.tween_interval(hold_duration)
	_attack_translation_tween.tween_property(self, "position", origin, return_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_attack_translation_tween.finished.connect(func():
		if is_instance_valid(self):
			position = origin
			z_index = original_z_index
		_attack_translation_tween = null
	)
	return _attack_translation_tween


func play_grid_movement(
	from_global_position: Vector2,
	to_global_position: Vector2,
	duration: float = 0.22
) -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var parent_inverse := parent_control.get_global_transform_with_canvas().affine_inverse()
	position = parent_inverse * from_global_position
	animation.move_to_position(parent_inverse * to_global_position, duration)


func play_death_fade(duration: float = 0.42) -> void:
	clear_dead_mark()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _death_tween.finished
	_death_tween = null
	if is_instance_valid(self):
		visible = false


func show_death_mark_from_assets() -> void:
	if _assets == null or not _assets.has_method("death_mark_texture"):
		return
	set_dead_mark(_assets.call("death_mark_texture", side) as Texture2D)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_children()


func _layout_children() -> void:
	if frame_rect == null or sprite_rect == null:
		return
	if _display_mode == &"battle":
		_layout_battle_sprite()
	else:
		_layout_collection_sprite()
	_layout_battle_shadow()
	_layout_incoming_damage_preview()
	_set_authored_rect(enemy_marker_group, Rect2(65.0, -49.0, 39.0, 48.0))
	_layout_stats_from_prefab()
	if death_mark_rect != null:
		death_mark_rect.position = Vector2(size.x * 0.32, 4.0)
		death_mark_rect.size = Vector2(size.x * 0.36, size.y * 0.36)
	if animation != null:
		animation.layout_authored(size, SOURCE_CANVAS_SIZE)
		animation.refresh_idle_pivot()


func _layout_battle_sprite() -> void:
	var texture_resource := _prepare_battle_texture(sprite_rect.texture)
	if texture_resource == null:
		_battle_sprite_visible_rect = Rect2()
		return
	if sprite_rect.texture != texture_resource:
		sprite_rect.texture = texture_resource
	var texture_size := texture_resource.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		_battle_sprite_visible_rect = Rect2()
		return
	var used_rect := _texture_used_rect(texture_resource)
	if used_rect.size.x <= 0.0 or used_rect.size.y <= 0.0:
		used_rect = Rect2(Vector2.ZERO, texture_size)
	var display_scale := clampf(
		float(_battle_visual_metrics(texture_resource).get("display_scale", 1.0)),
		0.5,
		1.25
	)
	var uniform_scale := minf(size.x / used_rect.size.x, size.y / used_rect.size.y) * display_scale
	var rendered_size := texture_size * uniform_scale
	var visible_center_x := (used_rect.position.x + used_rect.size.x * 0.5) * uniform_scale
	var visible_bottom_y := (used_rect.position.y + used_rect.size.y) * uniform_scale
	sprite_rect.position = Vector2(
		size.x * 0.5 - visible_center_x,
		size.y - _battle_footline_bottom_inset - visible_bottom_y
	)
	sprite_rect.size = rendered_size
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_battle_sprite_visible_rect = Rect2(
		sprite_rect.position + used_rect.position * uniform_scale,
		used_rect.size * uniform_scale
	)


func _layout_battle_shadow() -> void:
	if shadow_rect == null:
		return
	if _display_mode != &"battle":
		return
	var visible_width := _battle_sprite_visible_rect.size.x
	if visible_width <= 0.0:
		visible_width = size.x * 0.72
	var shadow_size := Vector2(
		clampf(visible_width * 0.72, size.x * 0.44, size.x * 0.70),
		clampf(size.y * 0.105, 8.0, 18.0)
	)
	var shadow_center_y := size.y - _battle_footline_bottom_inset + BATTLE_SHADOW_CENTER_Y_OFFSET
	shadow_rect.position = Vector2(
		size.x * 0.5 - shadow_size.x * 0.5,
		shadow_center_y - shadow_size.y * 0.5
	)
	shadow_rect.size = shadow_size


func _layout_incoming_damage_preview() -> void:
	if incoming_damage_preview == null:
		return
	var badge_size := clampf(minf(size.x, size.y) * 0.34, 40.0, 48.0)
	incoming_damage_preview.size = Vector2(badge_size, badge_size)
	incoming_damage_preview.position = Vector2(
		size.x - badge_size * (1.0 - DAMAGE_PREVIEW_BADGE_RIGHT_OVERHANG_RATIO),
		DAMAGE_PREVIEW_BADGE_BOTTOM_INSET - badge_size
	)


func _layout_collection_sprite() -> void:
	sprite_rect.position = Vector2.ZERO
	sprite_rect.size = Vector2(size.x, size.y * 120.0 / SOURCE_CANVAS_SIZE.y)
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_battle_sprite_visible_rect = Rect2()


func _texture_used_rect(texture_resource: Texture2D) -> Rect2:
	var cache_key := texture_resource.resource_path
	if cache_key == "":
		cache_key = str(texture_resource.get_instance_id())
	if _texture_used_rect_cache.has(cache_key):
		return Rect2(_texture_used_rect_cache[cache_key])
	var used_rect := Rect2(Vector2.ZERO, texture_resource.get_size())
	var metrics := _battle_visual_metrics(texture_resource)
	var declared_rect := Array(metrics.get("used_rect", []))
	if declared_rect.size() == 4:
		var texture_size := texture_resource.get_size()
		var declared_position := Vector2(float(declared_rect[0]), float(declared_rect[1]))
		var declared_size := Vector2(float(declared_rect[2]), float(declared_rect[3]))
		var texture_bounds := Rect2(Vector2.ZERO, texture_size)
		var clipped_rect := Rect2(declared_position, declared_size).intersection(texture_bounds)
		if clipped_rect.size.x > 0.0 and clipped_rect.size.y > 0.0:
			used_rect = clipped_rect
	else:
		var image := texture_resource.get_image()
		if image != null and not image.is_empty():
			var detected_rect := image.get_used_rect()
			if detected_rect.size.x > 0 and detected_rect.size.y > 0:
				used_rect = Rect2(detected_rect)
	_texture_used_rect_cache[cache_key] = used_rect
	return used_rect


func _prepare_battle_texture(texture_resource: Texture2D) -> Texture2D:
	if texture_resource == null:
		_battle_removed_bottom_pixels = 0
		return null
	var cache_key := _texture_cache_key(texture_resource)
	if _battle_texture_cache.has(cache_key):
		var cached := Dictionary(_battle_texture_cache[cache_key])
		_battle_removed_bottom_pixels = int(cached.get("removed_bottom_pixels", 0))
		_battle_footline_bottom_inset = float(cached.get("footline_bottom_inset", BATTLE_FOOTLINE_BOTTOM_INSET))
		return cached.get("texture", texture_resource) as Texture2D
	var texture_size := texture_resource.get_size()
	var metrics := _battle_visual_metrics(texture_resource)
	var crop_height := clampi(int(metrics.get("crop_bottom", int(texture_size.y))), 1, int(texture_size.y))
	var trim_bottom := maxi(0, int(texture_size.y) - crop_height)
	_battle_footline_bottom_inset = maxf(0.0, float(metrics.get("footline_bottom_inset", BATTLE_FOOTLINE_BOTTOM_INSET)))
	var prepared_texture := texture_resource
	if trim_bottom > 0:
		var cropped := AtlasTexture.new()
		cropped.atlas = texture_resource
		cropped.region = Rect2(0.0, 0.0, texture_size.x, float(crop_height))
		prepared_texture = cropped
	_battle_removed_bottom_pixels = trim_bottom
	var cache_entry := {
		"texture": prepared_texture,
		"removed_bottom_pixels": trim_bottom,
		"footline_bottom_inset": _battle_footline_bottom_inset,
	}
	_battle_texture_cache[cache_key] = cache_entry
	if prepared_texture != texture_resource:
		_battle_texture_cache[_texture_cache_key(prepared_texture)] = cache_entry
	return prepared_texture


func _battle_visual_metrics(texture_resource: Texture2D) -> Dictionary:
	_ensure_battle_visual_metrics_loaded()
	var path := texture_resource.resource_path
	if path == "" or not _battle_visual_metrics_by_path.has(path):
		return {}
	return Dictionary(_battle_visual_metrics_by_path[path])


func _ensure_battle_visual_metrics_loaded() -> void:
	if _battle_visual_metrics_loaded:
		return
	_battle_visual_metrics_loaded = true
	_battle_visual_metrics_by_path = {}
	if not FileAccess.file_exists(BATTLE_VISUAL_METRICS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BATTLE_VISUAL_METRICS_PATH))
	if not (parsed is Dictionary):
		return
	_battle_visual_metrics_by_path = Dictionary(parsed).get("by_texture_path", {})


func _texture_cache_key(texture_resource: Texture2D) -> String:
	var cache_key := texture_resource.resource_path
	if cache_key == "":
		cache_key = str(texture_resource.get_instance_id())
	return cache_key


func _set_authored_rect(control: Control, authored_rect: Rect2) -> void:
	if control == null:
		return
	var authored_scale := Vector2(
		size.x / SOURCE_CANVAS_SIZE.x,
		size.y / SOURCE_CANVAS_SIZE.y
	)
	control.position = authored_rect.position * authored_scale
	control.size = authored_rect.size * authored_scale


func _capture_authored_stat_layout() -> void:
	_authored_stat_layout.clear()
	for group in [health_group, shield_group, attack_group, damage_cap_group]:
		if group == null:
			continue
		_authored_stat_layout[group.name] = {
			"position": group.position,
			"size": group.size,
			"scale": group.scale,
		}


func _layout_stats_from_prefab() -> void:
	if _authored_stat_layout.is_empty():
		return
	# Keep all stat rows in one readable column along the cell's right edge.
	var corners := _battle_stat_layout_corners
	if corners.size() != 4:
		corners = PackedVector2Array([
			Vector2.ZERO,
			Vector2(size.x, 0.0),
			size,
			Vector2(0.0, size.y),
		])
	var groups: Array[Control] = [health_group, attack_group, shield_group, damage_cap_group]
	var total_height := 0.0
	for group in groups:
		if group == null or not _authored_stat_layout.has(group.name):
			continue
		var authored := Dictionary(_authored_stat_layout[group.name])
		group.size = Vector2(authored.get("size", Vector2.ZERO))
		group.scale = Vector2(authored.get("scale", Vector2.ONE)) * _battle_stat_layout_scale
		group.rotation = 0.0
		if group != health_group and group != shield_group:
			total_height += group.size.y * group.scale.y
	if health_group != null:
		var health_size := health_group.size * health_group.scale
		var health_top := minf(corners[0].y, corners[1].y)
		var health_center_y := health_top + health_size.y * 0.5
		var top_left_x := _edge_x_at_y(corners[0], corners[3], health_center_y)
		var top_right_x := _edge_x_at_y(corners[1], corners[2], health_center_y)
		health_group.position = Vector2(
			(top_left_x + top_right_x - health_size.x) * 0.5,
			health_top
		)
		_position_health_bar_above_sprite()
	total_height += STAT_COLUMN_GAP * _battle_stat_layout_scale * maxf(0.0, groups.size() - 1.0)
	var top_y := minf(corners[0].y, corners[1].y)
	var row_y := top_y
	var column_bottom_y := row_y + total_height
	var shared_right_edge := minf(
		_edge_x_at_y(corners[1], corners[2], row_y),
		_edge_x_at_y(corners[1], corners[2], column_bottom_y)
	)
	for group in groups:
		if group == null or not _authored_stat_layout.has(group.name):
			continue
		if group == health_group or group == shield_group:
			continue
		var scaled_size := group.size * group.scale
		group.position = Vector2(
			shared_right_edge - scaled_size.x - STAT_COLUMN_RIGHT_INSET * _battle_stat_layout_scale,
			row_y
		)
		row_y += scaled_size.y + STAT_COLUMN_GAP * _battle_stat_layout_scale


func _battle_sprite_actual_top_y() -> float:
	if sprite_rect == null or sprite_rect.texture == null:
		return INF
	var texture_size := sprite_rect.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or sprite_rect.size.y <= 0.0:
		return INF
	# Use the same declared visible bounds that position the battle sprite. Some
	# source textures contain faint pixels outside the authored creature bounds;
	# those pixels must not push the health slot away from the visible body.
	var used_rect := _texture_used_rect(sprite_rect.texture)
	if used_rect.size.y <= 0.0:
		return INF
	var drawn_scale := minf(
		sprite_rect.size.x / texture_size.x,
		sprite_rect.size.y / texture_size.y
	)
	var drawn_size := texture_size * drawn_scale
	var drawn_origin := (sprite_rect.size - drawn_size) * 0.5
	var visible_rect := Rect2(
		drawn_origin + used_rect.position * drawn_scale,
		used_rect.size * drawn_scale
	)
	var sprite_transform := sprite_rect.get_transform()
	var top_y := INF
	for corner in [
		visible_rect.position,
		Vector2(visible_rect.end.x, visible_rect.position.y),
		visible_rect.end,
		Vector2(visible_rect.position.x, visible_rect.end.y),
	]:
		top_y = minf(top_y, (sprite_transform * corner).y)
	return top_y


func _position_health_bar_above_sprite() -> void:
	if health_group == null:
		return
	var sprite_top := _battle_sprite_actual_top_y()
	if not is_finite(sprite_top):
		return
	health_group.position.y = sprite_top \
		- HEALTH_BAR_HEAD_GAP * _battle_stat_layout_scale \
		- health_group.size.y * health_group.scale.y
	_layout_shield_bar_segment()


func _layout_shield_bar_segment(
	current_hp: int = -1,
	current_shield: int = -1,
	bar_capacity: int = -1
) -> void:
	if health_group == null or shield_group == null:
		return
	var safe_hp := maxi(0, current_hp) \
		if current_hp >= 0 else maxi(0, int(cell_data.get("hp", 0)))
	var safe_shield := maxi(0, current_shield) \
		if current_shield >= 0 else maxi(0, int(cell_data.get("shield", 0)))
	var safe_capacity := maxi(1, bar_capacity) if bar_capacity > 0 else maxi(
		1,
		maxi(1, _health_bar_max_hp) + maxi(_health_bar_max_shield, safe_shield)
	)
	var hp_ratio := clampf(float(safe_hp) / float(safe_capacity), 0.0, 1.0)
	var shield_ratio := clampf(
		float(safe_shield) / float(safe_capacity),
		0.0,
		1.0 - hp_ratio
	)
	shield_group.position = health_group.position + Vector2(
		health_group.size.x * hp_ratio,
		0.0
	)
	shield_group.size = Vector2(
		health_group.size.x * shield_ratio,
		health_group.size.y
	)
	shield_group.scale = health_group.scale
	shield_group.rotation = health_group.rotation
	shield_group.visible = _display_mode == &"battle" \
		and not cell_data.is_empty() \
		and not _damage_preview_active \
		and safe_shield > 0 \
		and shield_group.size.x > 0.0
func _edge_x_at_y(edge_start: Vector2, edge_end: Vector2, y: float) -> float:
	if is_zero_approx(edge_end.y - edge_start.y):
		return edge_start.x
	var weight := clampf((y - edge_start.y) / (edge_end.y - edge_start.y), 0.0, 1.0)
	return lerpf(edge_start.x, edge_end.x, weight)


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
	_layout_children()


func _set_authored_root_visible(visible_value: bool) -> void:
	if psd_root != null:
		psd_root.visible = visible_value
	if not visible_value and enemy_marker_group != null:
		enemy_marker_group.visible = false


func _reset_interaction_state() -> void:
	visible = true
	modulate = Color.WHITE
	z_index = 0
	if stats_root != null:
		stats_root.visible = false
	if frame_rect != null:
		frame_rect.modulate = Color.WHITE
