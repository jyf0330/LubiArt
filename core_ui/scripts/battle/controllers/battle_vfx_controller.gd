extends Control

signal trace_event_started(event_id: String)
signal trace_event_finished(event_id: String)
signal trace_sequence_started
signal trace_sequence_finished
signal pets_reset_reveal_requested(units: Array)
signal enemy_move_projection_requested(event: Dictionary)

const BattleRoundBannerScript := preload("res://core_ui/scripts/battle/prefabs/hud/battle_round_banner.gd")
const BattleDamageNumberScript := preload("res://core_ui/scripts/battle/prefabs/effects/battle_damage_number.gd")
const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")
const BattleVfxHandlerRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_vfx_handler_registry.gd")
const ARTIST_ACTION_STEP_DELAY := 0.16
const ARTIST_BULLET_FLIGHT_DURATION := 0.32
const ELEMENT_LAYER_PROJECTILE_INTERVAL := 0.055
const DEATH_FADE_DURATION := 0.42
const DEATH_IMPACT_HOLD_DURATION := 0.10
const ELEMENT_SETTLEMENT_DELAY := 1.0
const ARTIST_ROUND_BANNER_DURATION := 1.4
const ARTIST_MOVE_DURATION := 0.22
const ENEMY_ATTACK_TRANSLATION_OUT_DURATION := 0.18
const ENEMY_ATTACK_TRANSLATION_HOLD_DURATION := 0.08
const ENEMY_ATTACK_TRANSLATION_RETURN_DURATION := 0.16
const ENEMY_ATTACK_TRANSLATION_RATIO := 0.68

var board_grid: Control = null
var unit_host: Control = null
var assets: RefCounted = null
var _trace_queue: Array[Dictionary] = []
var _trace_sequence_playing := false
var _handler_registry: RefCounted = null


func _init() -> void:
	_handler_registry = BattleVfxHandlerRegistryScript.new()
	_handler_registry.register_sequence("ELEMENT_SETTLEMENT_START", _sequence_element_settlement_start)
	_handler_registry.register_sequence("DAMAGE_APPLIED", _play_damage_trace_sequence)
	_handler_registry.register_sequence("ATTACK_STRIKE", _play_attack_strike_trace_sequence)
	_handler_registry.register_sequence("ELEMENT_APPLIED", _play_element_applied_trace_sequence)
	_handler_registry.register_sequence("PETS_RESET", _sequence_pets_reset)
	_handler_registry.register_sequence("MOVE_MONSTER", _sequence_enemy_move)
	_handler_registry.register_sequence("MOVE_HERO", _sequence_movement)
	_handler_registry.register_sequence("round_start", _sequence_round_start)
	_handler_registry.register_sequence_kind("movement", _sequence_movement)
	_handler_registry.register_instant("MOVE_HERO", play_movement)
	_handler_registry.register_instant("DAMAGE_APPLIED", play_damage_trace)
	_handler_registry.register_instant("round_start", _instant_round_start)
	_handler_registry.register_instant("shoot_projectile", _instant_projectile)
	_handler_registry.register_instant("melee_bite", _instant_bite)
	_handler_registry.register_instant("damage", _instant_damage)
	_handler_registry.register_instant("spawn_trap", _instant_spawn_trap)
	_handler_registry.register_instant("death", _instant_death)
	_handler_registry.register_instant_kind("movement", play_movement)


func configure(grid: Control, units: Control, asset_registry: RefCounted) -> void:
	board_grid = grid
	unit_host = units
	assets = asset_registry
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play_trace(events: Array) -> void:
	for event_value in events:
		_trace_queue.append(Dictionary(event_value).duplicate(true))
	if not _trace_sequence_playing and not _trace_queue.is_empty():
		_drain_trace_queue.call_deferred()


func _drain_trace_queue() -> void:
	if _trace_sequence_playing:
		return
	_trace_sequence_playing = true
	trace_sequence_started.emit()
	while not _trace_queue.is_empty():
		var event: Dictionary = _trace_queue.pop_front()
		var event_id := String(event.get("eventId", event.get("event_id", "trace_%d" % Time.get_ticks_msec())))
		trace_event_started.emit(event_id)
		await _play_event_sequence(event)
		trace_event_finished.emit(event_id)
	_trace_sequence_playing = false
	trace_sequence_finished.emit()


func _play_event_sequence(event: Dictionary) -> void:
	var event_type := String(event.get("type", ""))
	var kind := String(event.get("kind", ""))
	var handler: Callable = _handler_registry.sequence_handler(event_type, kind)
	if handler.is_valid():
		await handler.call(event)
		return
	play_event(event)
	await get_tree().create_timer(ARTIST_ACTION_STEP_DELAY).timeout


func _sequence_element_settlement_start(event: Dictionary) -> void:
	var payload := Dictionary(event.get("payload", {}))
	var wait_seconds: float = maxf(ELEMENT_SETTLEMENT_DELAY, float(payload.get("waitSeconds", ELEMENT_SETTLEMENT_DELAY)))
	await get_tree().create_timer(wait_seconds).timeout


func _sequence_pets_reset(event: Dictionary) -> void:
	var reset_payload := Dictionary(event.get("payload", {}))
	var reset_units := Array(reset_payload.get("units", [])).duplicate(true)
	pets_reset_reveal_requested.emit(reset_units)
	await get_tree().create_timer(0.42).timeout


func _sequence_enemy_move(event: Dictionary) -> void:
	enemy_move_projection_requested.emit(event.duplicate(true))
	play_event(event)
	await get_tree().create_timer(ARTIST_MOVE_DURATION + ARTIST_ACTION_STEP_DELAY).timeout


func _sequence_movement(event: Dictionary) -> void:
	var unit := play_event(event)
	await get_tree().create_timer(_movement_duration(unit) + ARTIST_ACTION_STEP_DELAY).timeout


func _sequence_round_start(event: Dictionary) -> void:
	play_event(event)
	await get_tree().create_timer(ARTIST_ROUND_BANNER_DURATION).timeout


func _play_damage_trace_sequence(event: Dictionary) -> void:
	var actor := Dictionary(event.get("actor", {}))
	var target := Dictionary(event.get("target", {}))
	var payload := Dictionary(event.get("payload", {}))
	var actor_grid := _dict_grid(actor)
	var target_grid := _dict_grid(target)
	var element := String(payload.get("element", "fire"))
	var source_type := String(payload.get("sourceType", "action"))
	var target_visual := _prepare_damage_target_visual(event)
	var is_element_trap := source_type == "element_trap"
	if is_element_trap:
		var trap_cell := _cell_at(target_grid)
		if trap_cell != null and trap_cell.has_method("clear_element_visuals"):
			trap_cell.call("clear_element_visuals")
		play_element_impact(element, target_grid, false)
	elif source_type == "element_settlement" or bool(payload.get("suppressProjectile", false)):
		pass
	elif String(actor.get("side", "")) == "enemy":
		var attack_translation := play_enemy_attack_translation(actor, target)
		if attack_translation != null:
			await get_tree().create_timer(ENEMY_ATTACK_TRANSLATION_OUT_DURATION).timeout
		var bite := _play_bite_on_unit(target_visual)
		await _await_bite_impact(bite)
	else:
		var projectile := play_projectile(element, actor_grid, target_grid)
		await _await_projectile_impact(projectile)
	_apply_damage_impact(event, target_visual)
	if int(payload.get("hpTo", 1)) <= 0 and target_visual != null:
		await get_tree().create_timer(DEATH_IMPACT_HOLD_DURATION).timeout
		await _play_defeated_unit_fade(target_visual)
	elif is_element_trap:
		await get_tree().create_timer(0.54 + ARTIST_ACTION_STEP_DELAY).timeout
	else:
		await get_tree().create_timer(_damage_feedback_duration(target_visual)).timeout
	if target_visual != null and bool(target_visual.get_meta("trace_ghost", false)):
		target_visual.queue_free()


func _play_defeated_unit_fade(unit: Control) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if unit.has_method("play_death_fade"):
		await unit.call("play_death_fade", DEATH_FADE_DURATION)


func _damage_feedback_duration(unit: Control) -> float:
	if unit != null and unit.has_method("get_damage_feedback_duration"):
		return maxf(ARTIST_ACTION_STEP_DELAY, float(unit.call("get_damage_feedback_duration")))
	return ARTIST_ACTION_STEP_DELAY


func _play_attack_strike_trace_sequence(event: Dictionary) -> void:
	var actor := Dictionary(event.get("actor", {}))
	var target := Dictionary(event.get("target", {}))
	var payload := Dictionary(event.get("payload", {}))
	var actor_grid := _dict_grid(actor)
	var element := String(payload.get("element", "fire"))
	var target_values: Array = Array(payload.get("targets", []))
	if target_values.is_empty():
		target_values = [target]
	var target_grids: Array[Vector2i] = []
	for target_value in target_values:
		var target_grid := _dict_grid(Dictionary(target_value))
		if target_grid.x >= 0 and target_grid.y >= 0:
			target_grids.append(target_grid)
	if String(actor.get("side", "")) == "enemy":
		if play_enemy_attack_translation(actor, target) != null:
			await get_tree().create_timer(ENEMY_ATTACK_TRANSLATION_OUT_DURATION).timeout
		var bite := play_bite(target_grids[0]) if not target_grids.is_empty() else null
		await _await_bite_impact(bite)
	else:
		var projectiles: Array[Node] = []
		for target_grid in target_grids:
			var projectile := play_projectile(element, actor_grid, target_grid)
			if projectile != null:
				projectiles.append(projectile)
		if not projectiles.is_empty():
			await _await_projectile_impact(projectiles[0])
	var apply_element_on_impact := bool(payload.get("applyElementOnImpact", false))
	for target_grid in target_grids:
		play_element_impact(element, target_grid, apply_element_on_impact)


func _play_element_applied_trace_sequence(event: Dictionary) -> void:
	var actor := Dictionary(event.get("actor", {}))
	var target := Dictionary(event.get("target", {}))
	var payload := Dictionary(event.get("payload", {}))
	var actor_grid := _dict_grid(actor)
	var element := _visual_element_id(String(payload.get("element", "fire")))
	var suppress_projectile := bool(payload.get("suppressProjectile", false))
	if bool(payload.get("deferToAttackStrike", false)):
		return
	var target_values: Array = Array(payload.get("targets", []))
	if target_values.is_empty():
		target_values = [target]
	var target_grids: Array[Vector2i] = []
	for target_value in target_values:
		var target_grid := _dict_grid(Dictionary(target_value))
		if target_grid.x < 0 or target_grid.y < 0:
			continue
		target_grids.append(target_grid)
	if not suppress_projectile:
		var layer_count: int = max(1, int(payload.get("layers", 1)))
		var last_projectile: Node = null
		for layer_index in range(layer_count):
			for target_grid in target_grids:
				last_projectile = play_projectile(element, actor_grid, target_grid)
			if layer_index + 1 < layer_count:
				await get_tree().create_timer(ELEMENT_LAYER_PROJECTILE_INTERVAL).timeout
		await _await_projectile_impact(last_projectile)
	for target_grid in target_grids:
		play_element_impact(element, target_grid)
	await get_tree().create_timer(0.54 + ARTIST_ACTION_STEP_DELAY).timeout


func _prepare_damage_target_visual(event: Dictionary) -> Control:
	var target := Dictionary(event.get("target", {}))
	var payload := Dictionary(event.get("payload", {}))
	var target_visual := _unit_by_id(String(target.get("id", "")))
	var hp_to := int(payload.get("hpTo", 0))
	var hp_from := int(payload.get("hpFrom", hp_to + int(payload.get("hpDamage", payload.get("finalDamage", 0)))))
	var shield_to := int(payload.get("shieldTo", 0))
	var shield_from := int(payload.get("shieldFrom", shield_to + int(payload.get("shieldDamage", 0))))
	if target_visual != null:
		if target_visual.has_method("update_hp"):
			target_visual.call("update_hp", hp_from)
		if target_visual.has_method("update_shield"):
			target_visual.call("update_shield", shield_from)
		return target_visual
	var target_grid := _dict_grid(target)
	var cell := _cell_at(target_grid)
	if cell == null:
		return null
	var ghost := BattleUnitScene.instantiate() as Control
	if ghost == null:
		return null
	ghost.name = "BattleTraceTargetGhost_%s" % String(target.get("id", "unit"))
	ghost.set_meta("trace_ghost", true)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 70
	ghost.size = cell.size
	var host := unit_host if unit_host != null else cell
	host.add_child(ghost)
	ghost.position = host.get_global_transform_with_canvas().affine_inverse() * cell.global_position
	ghost.size = cell.size
	var cell_data := target.duplicate(true)
	cell_data["unitId"] = String(target.get("id", ""))
	cell_data["unitName"] = String(target.get("name", target.get("id", "")))
	cell_data["hp"] = hp_from
	cell_data["shield"] = shield_from
	cell_data["atk"] = int(target.get("atk", target.get("attack", 0)))
	if ghost.has_method("set_unit_data"):
		ghost.call("set_unit_data", cell_data, String(target.get("side", "enemy")), assets)
	return ghost


func _apply_damage_impact(event: Dictionary, target_visual: Control = null) -> Node:
	var target := Dictionary(event.get("target", {}))
	var payload := Dictionary(event.get("payload", {}))
	var unit := target_visual if target_visual != null else _unit_by_id(String(target.get("id", "")))
	if unit == null:
		unit = _unit_at(_dict_grid(target))
	if unit != null and unit.has_method("play_damage_feedback"):
		unit.call("play_damage_feedback", payload, _damage_reaction_direction(event))
	_show_damage_number(unit, target, payload)
	return unit


func _show_damage_number(unit: Control, target: Dictionary, payload: Dictionary) -> void:
	var amount := _damage_amount(payload)
	if amount <= 0:
		return
	var feedback := BattleDamageNumberScript.new() as Label
	if feedback == null:
		return
	feedback.name = "DamageNumber_%d" % Time.get_ticks_usec()
	feedback.size = Vector2(120.0, 48.0)
	feedback.z_index = 210
	feedback.z_as_relative = false
	feedback.set_meta("damage_amount", amount)
	feedback.set_meta("target_unit_id", String(target.get("id", "")))
	add_child(feedback)
	var anchor_global := _damage_number_anchor_global(unit, target)
	feedback.position = get_global_transform_with_canvas().affine_inverse() * anchor_global \
		- feedback.size * 0.5
	feedback.call("show_damage", amount)


func _damage_number_anchor_global(unit: Control, target: Dictionary) -> Vector2:
	if unit != null and is_instance_valid(unit):
		var local_y := unit.size.y * 0.32
		if unit.has_method("get_battle_sprite_actual_top_y"):
			var sprite_top := float(unit.call("get_battle_sprite_actual_top_y"))
			if is_finite(sprite_top):
				local_y = maxf(8.0, sprite_top + 10.0)
		return unit.get_global_transform_with_canvas() * Vector2(unit.size.x * 0.5, local_y)
	var cell := _cell_at(_dict_grid(target))
	if cell != null:
		return cell.global_position + Vector2(cell.size.x * 0.5, cell.size.y * 0.3)
	return get_global_transform_with_canvas() * (size * 0.5)


func _damage_amount(payload: Dictionary) -> int:
	if payload.has("finalDamage"):
		return maxi(0, int(payload.get("finalDamage", 0)))
	if payload.has("final_damage"):
		return maxi(0, int(payload.get("final_damage", 0)))
	var split_damage := int(payload.get("hpDamage", payload.get("hp_damage", 0))) \
		+ int(payload.get("shieldDamage", payload.get("shield_damage", 0)))
	if split_damage > 0:
		return split_damage
	var hp_from := int(payload.get("hpFrom", payload.get("hp_from", 0)))
	var hp_to := int(payload.get("hpTo", payload.get("hp_to", hp_from)))
	var shield_from := int(payload.get("shieldFrom", payload.get("shield_from", 0)))
	var shield_to := int(payload.get("shieldTo", payload.get("shield_to", shield_from)))
	return maxi(0, hp_from - hp_to + shield_from - shield_to)


func _damage_reaction_direction(event: Dictionary) -> Vector2:
	var actor_grid := _dict_grid(Dictionary(event.get("actor", {})))
	var target_grid := _dict_grid(Dictionary(event.get("target", {})))
	var actor_cell := _cell_at(actor_grid)
	var target_cell := _cell_at(target_grid)
	if actor_cell == null or target_cell == null:
		return Vector2.RIGHT
	var direction := (
		target_cell.global_position + target_cell.size * 0.5
		- actor_cell.global_position - actor_cell.size * 0.5
	)
	return direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT


func play_event(event: Dictionary) -> Node:
	var event_type := String(event.get("type", ""))
	var kind := String(event.get("kind", ""))
	var handler: Callable = _handler_registry.instant_handler(event_type, kind)
	return handler.call(event) as Node if handler.is_valid() else null


func vfx_handler_registry() -> RefCounted:
	return _handler_registry


func _instant_round_start(event: Dictionary) -> Node:
	return play_round_banner(int(event.get("round", 1)), String(event.get("side", "player")))


func _instant_projectile(event: Dictionary) -> Node:
	return play_projectile(String(event.get("element", "fire")), _event_grid(event, "from"), _event_grid(event, "to"))


func _instant_bite(event: Dictionary) -> Node:
	return play_bite(_event_grid(event, "at"))


func _instant_damage(_event: Dictionary) -> Node:
	return null


func _instant_spawn_trap(event: Dictionary) -> Node:
	return play_spawn_trap(String(event.get("element", "fire")), _event_grid(event, "at"))


func _instant_death(event: Dictionary) -> Node:
	var unit := _unit_by_id(String(event.get("unit_id", "")))
	if unit != null and unit.has_method("show_death_mark_from_assets"):
		unit.call("show_death_mark_from_assets")
	return unit


func play_movement(event: Dictionary) -> Node:
	var unit_id := String(event.get("unitId", Dictionary(event.get("actor", {})).get("id", "")))
	var unit := _unit_by_id(unit_id)
	if unit == null:
		return null
	var from_grid := _dict_grid(Dictionary(event.get("from", {})))
	var to_grid := _dict_grid(Dictionary(event.get("to", {})))
	var from_cell := _cell_at(from_grid)
	var to_cell := _cell_at(to_grid)
	if from_cell != null and to_cell != null and unit.has_method("play_grid_movement"):
		unit.call(
			"play_grid_movement",
			from_cell.global_position,
			to_cell.global_position,
			_movement_duration(unit)
		)
	return unit


func _movement_duration(unit: Node) -> float:
	if unit != null and unit.has_method("get_move_animation_duration"):
		return maxf(float(unit.call("get_move_animation_duration", ARTIST_MOVE_DURATION)), ARTIST_MOVE_DURATION)
	return ARTIST_MOVE_DURATION


func play_damage_trace(event: Dictionary) -> Node:
	var actor := Dictionary(event.get("actor", {}))
	var target := Dictionary(event.get("target", {}))
	var payload := Dictionary(event.get("payload", {}))
	var actor_grid := _dict_grid(actor)
	var target_grid := _dict_grid(target)
	var element := String(payload.get("element", "fire"))
	if actor_grid.x >= 0 and target_grid.x >= 0:
		play_projectile(element, actor_grid, target_grid)
	return _apply_damage_impact(event)


func play_enemy_attack_translation(actor: Dictionary, target: Dictionary) -> Tween:
	var actor_id := String(actor.get("id", ""))
	var target_grid := _dict_grid(target)
	var actor_visual := _unit_by_id(actor_id)
	var target_cell := _cell_at(target_grid)
	if actor_visual == null or target_cell == null or not actor_visual.has_method("play_attack_translation"):
		return null
	var target_center_global := target_cell.global_position + target_cell.size * 0.5
	return actor_visual.call(
		"play_attack_translation",
		target_center_global,
		ENEMY_ATTACK_TRANSLATION_RATIO,
		ENEMY_ATTACK_TRANSLATION_OUT_DURATION,
		ENEMY_ATTACK_TRANSLATION_HOLD_DURATION,
		ENEMY_ATTACK_TRANSLATION_RETURN_DURATION
	) as Tween


func play_projectile(element: String, from_grid: Vector2i, to_grid: Vector2i) -> Node:
	var owner := _unit_at(from_grid)
	if owner == null:
		owner = _unit_at(to_grid)
	if owner == null or not owner.has_method("play_cross_cell_projectile"):
		return null
	return owner.call(
		"play_cross_cell_projectile",
		_visual_element_id(element),
		_cell_center_global(from_grid),
		_cell_center_global(to_grid),
		ARTIST_BULLET_FLIGHT_DURATION,
		_arc_height(from_grid, to_grid)
	) as Node


func _visual_element_id(element: String) -> String:
	match element:
		"无":
			return "neutral"
		"火":
			return "fire"
		"水":
			return "water"
		"草":
			return "grass"
		"雷":
			return "electric"
		"冰":
			return "ice"
		"地":
			return "ground"
		"暗":
			return "dark"
		"龙":
			return "dragon"
		_:
			return element


func play_bite(grid: Vector2i) -> Node:
	return _play_bite_on_unit(_unit_at(grid))


func _play_bite_on_unit(unit: Control) -> Node:
	if unit == null or not unit.has_method("play_bite_impact"):
		return null
	return unit.call("play_bite_impact") as Node


func _await_projectile_impact(projectile: Node) -> void:
	if projectile != null and projectile.has_signal("impact_reached"):
		await projectile.impact_reached
		return
	await get_tree().create_timer(ARTIST_BULLET_FLIGHT_DURATION).timeout


func _await_bite_impact(bite: Node) -> void:
	if bite != null and not bite.is_queued_for_deletion() and bite.has_signal("hit_frame_reached"):
		await bite.hit_frame_reached


func play_spawn_trap(element: String, grid: Vector2i, transient: bool = false) -> Node:
	var cell := _cell_at(grid)
	if cell == null:
		return cell
	if transient and cell.has_method("show_transient_element_tile"):
		cell.call("show_transient_element_tile", _visual_element_id(element))
	elif cell.has_method("show_element_tile"):
		cell.call("show_element_tile", _visual_element_id(element))
	return cell


func play_element_impact(element: String, grid: Vector2i, persist_tile: bool = true) -> Node:
	var cell := _cell_at(grid)
	if cell == null or not cell.has_method("play_element_impact"):
		return null
	var visual_element := _visual_element_id(element)
	return cell.call("play_element_impact", visual_element, persist_tile) as Node


func play_round_banner(round_number: int, side: String) -> Node:
	for child in get_children():
		if child.name != &"RoundFeedback":
			continue
		if int(child.get_meta("round_number", -1)) == round_number:
			return child
		child.free()
	var banner := _new_round_banner()
	banner.set_meta("round_number", round_number)
	add_child(banner)
	banner.z_index = 100
	var texture_resource: Texture2D = null
	if assets != null and assets.has_method("round_banner_texture"):
		texture_resource = assets.call("round_banner_texture") as Texture2D
	if banner.has_method("show_round"):
		banner.call("show_round", round_number, side, texture_resource, 1.4)
	return banner


func _new_round_banner() -> Control:
	var banner := BattleRoundBannerScript.new() as TextureRect
	banner.name = "RoundFeedback"
	banner.layout_mode = 1
	banner.anchor_left = 0.265167
	banner.anchor_top = 0.400734
	banner.anchor_right = 0.734833
	banner.anchor_bottom = 0.635502
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var title := Label.new()
	title.name = "Title"
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.anchor_top = 0.0820652
	title.anchor_bottom = 0.550611
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0.3, 0.1, 0.02, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_font_size_override("font_size", 62)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.set_anchors_preset(Control.PRESET_FULL_RECT)
	subtitle.anchor_top = 0.635802
	subtitle.anchor_bottom = 0.933967
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	subtitle.add_theme_color_override("font_shadow_color", Color(0.3, 0.1, 0.02, 0.9))
	subtitle.add_theme_constant_override("shadow_offset_x", 3)
	subtitle.add_theme_constant_override("shadow_offset_y", 4)
	subtitle.add_theme_font_size_override("font_size", 34)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(subtitle)
	return banner


func debug_spawn_prefab_samples() -> Dictionary:
	var before := get_child_count()
	var projectile := play_projectile("fire", Vector2i(1, 6), Vector2i(5, 2))
	var banner := play_round_banner(1, "player")
	var bite := play_bite(Vector2i(5, 2))
	var trap := play_spawn_trap("fire", Vector2i(2, 6))
	return {
		"before": before,
		"after": get_child_count(),
		"projectile_ok": projectile != null and String(projectile.get_path()).ends_with("/03_AttackActions"),
		"damage_ok": false,
		"banner_ok": banner != null and banner.has_method("show_round"),
		"bite_ok": bite != null and String(bite.get_path()).ends_with("/03_AttackActions"),
		"trap_ok": trap != null and trap.has_method("show_element_tile")
	}


func _event_grid(event: Dictionary, key: String) -> Vector2i:
	var value = event.get(key, [0, 0])
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _cell_center_global(grid: Vector2i) -> Vector2:
	var cell := _cell_at(grid)
	if cell == null:
		return Vector2.ZERO
	return cell.global_position + cell.size * 0.5


func _cell_at(grid: Vector2i) -> Control:
	if board_grid == null:
		return null
	var name := "BattleCell_%d_%d" % [grid.x, grid.y]
	return board_grid.get_node_or_null(name) as Control


func _unit_by_id(unit_id: String) -> Control:
	if board_grid == null or unit_id == "":
		return null
	for cell in board_grid.get_children():
		if cell.has_method("get_unit_node"):
			var unit := cell.call("get_unit_node") as Control
			if unit != null and unit.has_method("get_unit_id") and String(unit.call("get_unit_id")) == unit_id:
				return unit
	return null


func _unit_at(grid: Vector2i) -> Control:
	var cell := _cell_at(grid)
	if cell == null or not cell.has_method("get_unit_node"):
		return null
	return cell.call("get_unit_node") as Control


func _arc_height(from_grid: Vector2i, to_grid: Vector2i) -> float:
	var distance: int = abs(from_grid.x - to_grid.x) + abs(from_grid.y - to_grid.y)
	return 72.0 + float(distance) * 18.0


func _dict_grid(value: Dictionary) -> Vector2i:
	return Vector2i(int(value.get("x", value.get("c", -1))), int(value.get("y", value.get("r", -1))))
