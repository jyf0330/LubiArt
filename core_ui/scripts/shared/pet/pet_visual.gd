extends Control

const SOURCE_PSD := "battle_creature_prefab_source.psd"
const SOURCE_CANVAS_SIZE := Vector2(180.0, 180.0)
const AUTHORED_CREATURE_TEXTURE := preload("res://art/images/shared/pets/battle_complete/creature_art_gold.png")
const BATTLE_FOOTLINE_BOTTOM_INSET := 15.0
const BATTLE_SHADOW_CENTER_Y_OFFSET := -3.0
const BATTLE_VISUAL_METRICS_PATH := "res://art/manifests/shared/pets/sheets/pet_battle_visual_metrics.json"
const DAMAGE_PREVIEW_INITIAL_HOLD := 1.0
const DAMAGE_PREVIEW_VISIBLE_HOLD := 1.0
const DAMAGE_PREVIEW_HIDDEN_HOLD := 1.0
const DAMAGE_PREVIEW_FADE_DURATION := 0.12
const HEALTH_PREFIX := "HP:"
const SHIELD_PREFIX := "SHLD:"
const DAMAGE_PREVIEW_COLOR := Color("ff5a4f")
const DAMAGE_PREVIEW_HEALTH_SCALE := 1.45
const STAT_COLUMN_GAP := 1.0
const STAT_COLUMN_RIGHT_INSET := 4.0
const DAMAGE_PREVIEW_BADGE_RIGHT_OVERHANG_RATIO := 0.25
const DAMAGE_PREVIEW_BADGE_BOTTOM_INSET := 4.0
static var _texture_used_rect_cache: Dictionary = {}
static var _battle_texture_cache: Dictionary = {}
static var _battle_visual_metrics_by_path: Dictionary = {}
static var _battle_visual_metrics_loaded := false

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
@onready var incoming_damage_preview: Control = $"CompleteBattleCreaturePrefab/01_UnitVisual/IncomingDamagePreview"
@onready var incoming_damage_value: Label = $"CompleteBattleCreaturePrefab/01_UnitVisual/IncomingDamagePreview/Value"
@onready var death_mark_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/DeathMark"
@onready var animation: PetAnimation = $"CompleteBattleCreaturePrefab/03_AttackActions"
@onready var hit_reaction: PetHitReaction = $"CompleteBattleCreaturePrefab/01_UnitVisual/HitReactionPlayer"
@onready var shield_hit_effect: PetShieldHitEffect = $"CompleteBattleCreaturePrefab/01_UnitVisual/ShieldHitEffectPlayer"

var cell_data: Dictionary = {}
var side := ""
var _assets: RefCounted = null
var _missing_mapping: Dictionary = {}
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
var _damage_preview_active := false
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


func set_unit_data(data: Dictionary, unit_side: String, assets: RefCounted) -> void:
	reset_pet_view()
	cell_data = data.duplicate(true)
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
	animation.play_sprite_idle(
		sprite_rect,
		sprite_rect.texture,
		_battle_sprite_visible_rect.end - sprite_rect.position,
		animation_texture_path
	)
	enemy_marker_group.visible = side == "enemy" or side == "monster"
	status_view.bind_battle_data(cell_data)
	clear_dead_mark()


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


func get_dynamic_stat_snapshot() -> Dictionary:
	return status_view.snapshot()


func update_hp(value: int) -> void:
	cell_data["hp"] = value
	status_view.update_hp(value)
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
	pinned: bool = false,
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
	_damage_preview_uses_badge = side in ["player", "ally"] and incoming_damage_preview != null
	if not _damage_preview_uses_badge:
		_damage_preview_revealed_stats = stats_root != null and not stats_root.visible
		_show_battle_stats()
		_enter_damage_preview_presentation()
	_damage_preview_active = true
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
	_fade_damage_preview(_damage_preview_state == &"hidden")


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
		incoming_damage_preview.visible = true
		incoming_damage_preview.modulate.a = _damage_preview_badge_base_modulate.a \
			if visible_value else 0.0
	elif health_group != null:
		health_group.modulate.a = _damage_preview_health_base_group_modulate.a if visible_value else 0.0
	_damage_preview_state = &"visible" if visible_value else &"hidden"


func _show_damage_preview_value() -> void:
	if not _damage_preview_active:
		return
	if _damage_preview_uses_badge:
		if incoming_damage_value != null:
			incoming_damage_value.text = str(_damage_preview_damage)
			incoming_damage_value.self_modulate = Color.WHITE
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
	if had_preview_animation and psd_health_value != null:
		psd_health_value.modulate = _damage_preview_value_base_modulate
		psd_health_value.self_modulate = _damage_preview_value_base_self_modulate
	if incoming_damage_preview != null:
		incoming_damage_preview.visible = false
		incoming_damage_preview.modulate = _damage_preview_badge_base_modulate
	if incoming_damage_value != null:
		incoming_damage_value.text = ""
	_damage_preview_active = false
	_damage_preview_pinned = false
	_damage_preview_state = &""
	_damage_preview_sync_epoch_msec = -1
	_leave_damage_preview_presentation()
	if _damage_preview_revealed_stats and stats_root != null:
		stats_root.visible = _display_mode == &"battle"
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
	if attack_group != null:
		attack_group.visible = false
	if shield_group != null:
		shield_group.visible = false
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
	if incoming_damage_value == null or not incoming_damage_value.text.is_valid_int():
		return -1
	return int(incoming_damage_value.text)


func update_shield(value: int) -> void:
	cell_data["shield"] = max(0, value)
	status_view.update_shield(value)


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
	_show_battle_stats()
	visible = not is_dragging
	modulate = Color(1.0, 1.0, 1.0, 0.62) if is_dragging else Color.WHITE
	z_index = 40 if is_dragging else 0


func _show_battle_stats() -> void:
	if stats_root != null and _display_mode == &"battle":
		stats_root.visible = true


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
	else:
		play_shake()
	update_hp(int(payload.get("hpTo", int(cell_data.get("hp", 0)))))
	update_shield(int(payload.get("shieldTo", int(cell_data.get("shield", 0)))))


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
	var uniform_scale := minf(size.x / used_rect.size.x, size.y / used_rect.size.y)
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
		total_height += group.size.y * group.scale.y
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
		var scaled_size := group.size * group.scale
		group.position = Vector2(
			shared_right_edge - scaled_size.x - STAT_COLUMN_RIGHT_INSET * _battle_stat_layout_scale,
			row_y
		)
		row_y += scaled_size.y + STAT_COLUMN_GAP * _battle_stat_layout_scale


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
