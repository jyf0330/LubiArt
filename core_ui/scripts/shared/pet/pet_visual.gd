extends Control

const SOURCE_PSD := "battle_creature_prefab_source.psd"
const SOURCE_CANVAS_SIZE := Vector2(171.0, 144.0)
const AUTHORED_CREATURE_TEXTURE := preload("res://art/images/shared/pets/battle_complete/creature_art.png")
const BattleProjectileScript := preload("res://core_ui/scripts/battle/prefabs/effects/battle_projectile.gd")
const BattleDamageNumberScript := preload("res://core_ui/scripts/battle/prefabs/effects/battle_damage_number.gd")
const BattleBiteVfxScript := preload("res://core_ui/scripts/battle/prefabs/effects/battle_bite_vfx.gd")
const BATTLE_FOOTLINE_BOTTOM_INSET := 15.0
const BATTLE_SHADOW_CENTER_Y_OFFSET := -3.0
const BATTLE_VISUAL_METRICS_PATH := "res://art/manifests/shared/pets/sheets/pet_battle_visual_metrics.json"
const STAT_HEALTH_SIZE := Vector2(38.0, 36.0)
const STAT_HEALTH_FONT_SCALE := 0.83
const STAT_SHIELD_SIZE := Vector2(35.0, 46.0)
const STAT_ATTACK_SIZE := Vector2(49.0, 51.0)
const STAT_DAMAGE_CAP_SIZE := Vector2(39.0, 47.0)
const STAT_EDGE_INSET := 10.0
const STAT_VALUE_FONT_SIZE := 20

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
@onready var death_mark_rect: TextureRect = $"CompleteBattleCreaturePrefab/01_UnitVisual/DeathMark"
@onready var animation: PetAnimation = $"CompleteBattleCreaturePrefab/03_AttackActions"
@onready var projectile_layer: Control = $"CompleteBattleCreaturePrefab/04_BattleEffects/ProjectileLayer"
@onready var hit_layer: Control = $"CompleteBattleCreaturePrefab/04_BattleEffects/HitLayer"
@onready var damage_number_layer: Control = $"CompleteBattleCreaturePrefab/04_BattleEffects/DamageNumberLayer"

var cell_data: Dictionary = {}
var side := ""
var _assets: RefCounted = null
var _missing_mapping: Dictionary = {}
var _display_mode := &"battle"
var _battle_sprite_visible_rect := Rect2()
var _battle_removed_bottom_pixels := 0
var _battle_footline_bottom_inset := BATTLE_FOOTLINE_BOTTOM_INSET
var _death_tween: Tween = null
var _attack_translation_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation.configure(self)
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
	_layout_children()
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
	_clear_runtime_battle_effects()
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


func play_cross_cell_projectile(
	element_id: String,
	from_global_center: Vector2,
	to_global_center: Vector2,
	duration: float = 0.32,
	arc_height: float = 96.0
) -> Node:
	if projectile_layer == null:
		return null
	var texture_resource: Texture2D = null
	if _assets != null and _assets.has_method("projectile_texture"):
		texture_resource = _assets.call("projectile_texture", element_id) as Texture2D
	var projectile := BattleProjectileScript.new() as Sprite2D
	if projectile == null:
		return null
	projectile.name = "CrossCellProjectile"
	projectile_layer.add_child(projectile)
	var layer_inverse := projectile_layer.get_global_transform_with_canvas().affine_inverse()
	projectile.call(
		"play",
		texture_resource,
		layer_inverse * from_global_center,
		layer_inverse * to_global_center,
		duration,
		arc_height
	)
	return projectile


func play_bite_impact() -> Node:
	if hit_layer == null:
		return null
	var bite := BattleBiteVfxScript.new() as Control
	if bite == null:
		return null
	bite.name = "BiteImpact"
	hit_layer.add_child(bite)
	var target_size := minf(size.x, size.y) * 1.55
	bite.size = Vector2(target_size, target_size)
	bite.position = size * 0.5 - bite.size * 0.5
	var frames: Array = []
	var durations: Array = []
	if _assets != null:
		if _assets.has_method("monster_bite_frames"):
			frames = Array(_assets.call("monster_bite_frames"))
		if _assets.has_method("monster_bite_frame_durations"):
			durations = Array(_assets.call("monster_bite_frame_durations"))
	bite.call("play", frames, durations, 3)
	return bite


func play_damage_number(
	amount: int,
	damage_kind: String = "hp",
	y_offset: float = 0.0,
	x_offset: float = 0.0
) -> Node:
	if damage_number_layer == null:
		return null
	var number := BattleDamageNumberScript.new() as Control
	if number == null:
		return null
	number.name = "ShieldDamageNumber" if damage_kind == "shield" else "HpDamageNumber"
	damage_number_layer.add_child(number)
	number.position = size * 0.5 - Vector2(70.0, 24.0) + Vector2(x_offset, y_offset)
	number.size = Vector2(140.0, 40.0)
	if damage_kind == "shield":
		number.call("show_damage", amount, Color(0.18, 0.68, 1.0), 0.55, "护盾")
	else:
		number.call("show_damage", amount, Color(1.0, 0.22, 0.14), 0.55, "生命")
	return number


func play_damage_feedback(payload: Dictionary) -> void:
	var final_damage: int = max(0, int(payload.get("finalDamage", 0)))
	var shield_damage: int = max(0, int(payload.get("shieldDamage", 0)))
	var hp_damage: int = max(0, int(payload.get("hpDamage", final_damage - shield_damage)))
	var strike_index: int = max(1, int(payload.get("strikeIndex", 1)))
	var strike_count: int = max(1, int(payload.get("strikeCount", 1)))
	var strike_x_offset := 0.0
	if strike_count > 1:
		strike_x_offset = float(strike_index - 1) * 10.0 - float(strike_count - 1) * 5.0
	if shield_damage > 0:
		play_damage_number(shield_damage, "shield", -13.0 if hp_damage > 0 else 0.0, strike_x_offset)
	if hp_damage > 0:
		play_damage_number(hp_damage, "hp", 13.0 if shield_damage > 0 else 0.0, strike_x_offset)
	if shield_damage <= 0 and hp_damage <= 0 and final_damage > 0:
		play_damage_number(final_damage, "hp", 0.0, strike_x_offset)
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


func _clear_runtime_battle_effects() -> void:
	for layer in [projectile_layer, hit_layer, damage_number_layer]:
		if layer == null:
			continue
		for child in layer.get_children():
			child.queue_free()


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
	_set_authored_rect(enemy_marker_group, Rect2(65.0, -49.0, 39.0, 48.0))
	# Scale all four badges uniformly with the perspective cell and keep every
	# badge inside its own cell at every depth. This prevents neighboring cells'
	# badges from covering one another on both narrow back rows and large front rows.
	var stat_scale := minf(size.x / SOURCE_CANVAS_SIZE.x, size.y / SOURCE_CANVAS_SIZE.y)
	var edge_inset := STAT_EDGE_INSET * stat_scale
	var health_position := Vector2(edge_inset, edge_inset)
	_set_fixed_rect(health_group, Rect2(health_position, STAT_HEALTH_SIZE * stat_scale))
	var shield_position := Vector2(
		size.x - STAT_SHIELD_SIZE.x * stat_scale - edge_inset,
		edge_inset
	)
	_set_fixed_rect(shield_group, Rect2(
		shield_position,
		STAT_SHIELD_SIZE * stat_scale
	))
	var attack_position := Vector2(
		edge_inset,
		size.y - STAT_ATTACK_SIZE.y * stat_scale - edge_inset
	)
	_set_fixed_rect(attack_group, Rect2(
		attack_position,
		STAT_ATTACK_SIZE * stat_scale
	))
	var damage_cap_position := Vector2(
		size.x - STAT_DAMAGE_CAP_SIZE.x * stat_scale - edge_inset,
		size.y - STAT_DAMAGE_CAP_SIZE.y * stat_scale - edge_inset
	)
	_set_fixed_rect(damage_cap_group, Rect2(
		damage_cap_position,
		STAT_DAMAGE_CAP_SIZE * stat_scale
	))
	_center_stat_value(psd_health_value, health_group, stat_scale * STAT_HEALTH_FONT_SCALE)
	_center_stat_value(psd_shield_value, shield_group, stat_scale)
	_center_stat_value(psd_attack_value, attack_group, stat_scale)
	_center_stat_value(psd_damage_cap_value, damage_cap_group, stat_scale)
	if death_mark_rect != null:
		death_mark_rect.position = Vector2(size.x * 0.32, 4.0)
		death_mark_rect.size = Vector2(size.x * 0.36, size.y * 0.36)
	if animation != null:
		animation.layout_authored(size, SOURCE_CANVAS_SIZE)


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


func _set_fixed_rect(control: Control, fixed_rect: Rect2) -> void:
	if control == null:
		return
	control.scale = Vector2.ONE
	control.position = fixed_rect.position
	control.size = fixed_rect.size


func _center_stat_value(label: Label, group: Control, stat_scale: float) -> void:
	if label == null or group == null:
		return
	_set_fixed_rect(label, Rect2(Vector2.ZERO, group.size))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(
		"font_size",
		maxi(9, int(round(float(STAT_VALUE_FONT_SIZE) * stat_scale)))
	)


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
	if frame_rect != null:
		frame_rect.modulate = Color.WHITE
