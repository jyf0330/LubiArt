extends Control

signal trace_event_started(event_id: String)
signal trace_event_finished(event_id: String)
signal trace_sequence_started
signal trace_sequence_finished
signal pets_reset_reveal_requested(units: Array)
signal enemy_move_projection_requested(event: Dictionary)

const BattleProjectileScene := preload("res://features/battle/prefabs/effects/battle_projectile.tscn")
const BattleDamageNumberScene := preload("res://features/battle/prefabs/effects/battle_damage_number.tscn")
const BattleRoundBannerScene := preload("res://features/battle/prefabs/hud/battle_round_banner.tscn")
const BattleBiteVfxScene := preload("res://features/battle/prefabs/effects/battle_bite_vfx.tscn")
const BattleUnitScene := preload("res://shared/prefabs/pet/pet_visual.tscn")
const BattleVfxHandlerRegistryScript := preload("res://features/battle/controllers/battle_vfx_handler_registry.gd")
const ARTIST_ACTION_STEP_DELAY := 0.16
const ARTIST_BULLET_FLIGHT_DURATION := 0.32
const ELEMENT_LAYER_PROJECTILE_INTERVAL := 0.055
const DEATH_FADE_DURATION := 0.42
const ELEMENT_SETTLEMENT_DELAY := 1.0
const ARTIST_ROUND_BANNER_DURATION := 1.4
const ARTIST_MOVE_DURATION := 0.22
const ENEMY_ATTACK_TRANSLATION_OUT_DURATION := 0.18
const ENEMY_ATTACK_TRANSLATION_HOLD_DURATION := 0.08
const ENEMY_ATTACK_TRANSLATION_RETURN_DURATION := 0.16
const ENEMY_ATTACK_TRANSLATION_RATIO := 0.68

var board_grid: Control = null
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


func configure(grid: Control, asset_registry: RefCounted) -> void:
	board_grid = grid
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
	if bool(reset_payload.get("showNextRoundBanner", false)):
		var round_banner := play_round_banner(int(reset_payload.get("nextRound", int(event.get("round", 1)) + 1)), "player")
		if round_banner != null:
			await round_banner.tree_exited


func _sequence_enemy_move(event: Dictionary) -> void:
	enemy_move_projection_requested.emit(event.duplicate(true))
	play_event(event)
	await get_tree().create_timer(ARTIST_MOVE_DURATION + ARTIST_ACTION_STEP_DELAY).timeout


func _sequence_movement(event: Dictionary) -> void:
	play_event(event)
	await get_tree().create_timer(ARTIST_MOVE_DURATION + ARTIST_ACTION_STEP_DELAY).timeout


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
		var bite := play_bite(target_grid)
		if attack_translation != null and attack_translation.is_running():
			await attack_translation.finished
		if bite != null and bite.has_signal("finished"):
			await bite.finished
	else:
		play_projectile(element, actor_grid, target_grid)
		await get_tree().create_timer(ARTIST_BULLET_FLIGHT_DURATION).timeout
	_apply_damage_impact(event, target_visual)
	if int(payload.get("hpTo", 1)) <= 0 and target_visual != null:
		await _play_defeated_unit_fade(target_visual)
	elif is_element_trap:
		await get_tree().create_timer(0.54 + ARTIST_ACTION_STEP_DELAY).timeout
	else:
		await get_tree().create_timer(ARTIST_ACTION_STEP_DELAY).timeout
	if target_visual != null and bool(target_visual.get_meta("trace_ghost", false)):
		target_visual.queue_free()


func _play_defeated_unit_fade(unit: Control) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if unit.has_method("clear_dead_mark"):
		unit.call("clear_dead_mark")
	unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := unit.create_tween()
	fade.tween_property(unit, "modulate:a", 0.0, DEATH_FADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade.finished
	if is_instance_valid(unit):
		unit.visible = false


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
		var attack_translation := play_enemy_attack_translation(actor, target)
		if attack_translation != null:
			await get_tree().create_timer(ENEMY_ATTACK_TRANSLATION_OUT_DURATION).timeout
		var bite := play_bite(target_grids[0]) if not target_grids.is_empty() else null
		if attack_translation != null and attack_translation.is_running():
			await attack_translation.finished
		if bite != null and bite.has_signal("finished"):
			await bite.finished
	else:
		for target_grid in target_grids:
			play_projectile(element, actor_grid, target_grid)
		await get_tree().create_timer(ARTIST_BULLET_FLIGHT_DURATION).timeout
	var apply_element_on_impact := bool(payload.get("applyElementOnImpact", false))
	for target_grid in target_grids:
		play_element_impact(element, target_grid, apply_element_on_impact)
	await get_tree().create_timer(ARTIST_ACTION_STEP_DELAY).timeout


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
		for layer_index in range(layer_count):
			for target_grid in target_grids:
				play_projectile(element, actor_grid, target_grid)
			if layer_index + 1 < layer_count:
				await get_tree().create_timer(ELEMENT_LAYER_PROJECTILE_INTERVAL).timeout
		await get_tree().create_timer(ARTIST_BULLET_FLIGHT_DURATION).timeout
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
	ghost.position = get_global_transform_with_canvas().affine_inverse() * cell.global_position
	add_child(ghost)
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
	var target_grid := _dict_grid(target)
	var final_damage: int = max(0, int(payload.get("finalDamage", 0)))
	var shield_damage: int = max(0, int(payload.get("shieldDamage", 0)))
	var hp_damage: int = max(0, int(payload.get("hpDamage", final_damage - shield_damage)))
	if shield_damage > 0:
		play_damage_number(target_grid, shield_damage, "shield", -13.0 if hp_damage > 0 else 0.0)
	if hp_damage > 0:
		play_damage_number(target_grid, hp_damage, "hp", 13.0 if shield_damage > 0 else 0.0)
	if shield_damage <= 0 and hp_damage <= 0 and final_damage > 0:
		play_damage_number(target_grid, final_damage)
	var unit := target_visual if target_visual != null else _unit_by_id(String(target.get("id", "")))
	if unit != null:
		if unit.has_method("play_shake"):
			unit.call("play_shake")
		if unit.has_method("update_hp"):
			unit.call("update_hp", int(payload.get("hpTo", 0)))
		if unit.has_method("update_shield"):
			unit.call("update_shield", int(payload.get("shieldTo", 0)))
	return unit


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


func _instant_damage(event: Dictionary) -> Node:
	return play_damage_number(_event_grid(event, "at"), int(event.get("amount", 0)))


func _instant_spawn_trap(event: Dictionary) -> Node:
	return play_spawn_trap(String(event.get("element", "fire")), _event_grid(event, "at"))


func _instant_death(event: Dictionary) -> Node:
	var unit := _unit_by_id(String(event.get("unit_id", "")))
	if unit != null and unit.has_method("set_dead_mark") and assets != null:
		var side := String(unit.get("side"))
		unit.call("set_dead_mark", assets.call("death_mark_texture", side))
	return unit


func play_movement(event: Dictionary) -> Node:
	var unit_id := String(event.get("unitId", Dictionary(event.get("actor", {})).get("id", "")))
	var unit := _unit_by_id(unit_id)
	if unit == null:
		return null
	var from_grid := _dict_grid(Dictionary(event.get("from", {})))
	var to_grid := _dict_grid(Dictionary(event.get("to", {})))
	var target_parent := unit.get_parent() as Control
	if target_parent != null:
		var from_cell := _cell_at(from_grid)
		var to_cell := _cell_at(to_grid)
		if from_cell != null and to_cell != null:
			unit.position = from_cell.position - to_cell.position
	if unit.has_method("move_to_position"):
		unit.call("move_to_position", Vector2.ZERO, 0.22)
	return unit


func play_damage_trace(event: Dictionary) -> Node:
	var actor := Dictionary(event.get("actor", {}))
	var target := Dictionary(event.get("target", {}))
	var payload := Dictionary(event.get("payload", {}))
	var actor_grid := _dict_grid(actor)
	var target_grid := _dict_grid(target)
	var element := String(payload.get("element", "fire"))
	if String(actor.get("side", "")) == "enemy":
		play_enemy_attack_translation(actor, target)
		play_bite(target_grid)
	elif actor_grid.x >= 0 and target_grid.x >= 0:
		play_projectile(element, actor_grid, target_grid)
	return _apply_damage_impact(event)


func play_enemy_attack_translation(actor: Dictionary, target: Dictionary) -> Tween:
	var actor_id := String(actor.get("id", ""))
	var actor_grid := _dict_grid(actor)
	var target_grid := _dict_grid(target)
	var actor_visual := _unit_by_id(actor_id)
	var actor_cell := _cell_at(actor_grid)
	var target_cell := _cell_at(target_grid)
	if actor_visual == null or actor_cell == null or target_cell == null or actor_grid == target_grid:
		return null
	var parent := actor_visual.get_parent() as Control
	if parent == null:
		return null
	var parent_inverse := parent.get_global_transform_with_canvas().affine_inverse()
	var actor_center_global := actor_cell.global_position + actor_cell.size * 0.5
	var target_center_global := target_cell.global_position + target_cell.size * 0.5
	var travel_delta := (parent_inverse * target_center_global) - (parent_inverse * actor_center_global)
	if travel_delta.length_squared() <= 0.01:
		return null
	var origin := actor_visual.position
	var original_z_index := actor_visual.z_index
	actor_visual.z_index = max(actor_visual.z_index, 86)
	var tween := actor_visual.create_tween()
	tween.tween_property(actor_visual, "position", origin + travel_delta * ENEMY_ATTACK_TRANSLATION_RATIO, ENEMY_ATTACK_TRANSLATION_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(ENEMY_ATTACK_TRANSLATION_HOLD_DURATION)
	tween.tween_property(actor_visual, "position", origin, ENEMY_ATTACK_TRANSLATION_RETURN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		if is_instance_valid(actor_visual):
			actor_visual.position = origin
			actor_visual.z_index = original_z_index
	)
	return tween


func play_projectile(element: String, from_grid: Vector2i, to_grid: Vector2i) -> Node:
	var projectile := BattleProjectileScene.instantiate()
	add_child(projectile)
	projectile.z_index = 80
	var texture_resource: Texture2D = null
	if assets != null and assets.has_method("projectile_texture"):
		texture_resource = assets.call("projectile_texture", _visual_element_id(element)) as Texture2D
	if projectile.has_method("play"):
		projectile.call("play", texture_resource, _cell_center(from_grid), _cell_center(to_grid), 0.32, _arc_height(from_grid, to_grid))
	return projectile


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
	var bite := BattleBiteVfxScene.instantiate() as Control
	add_child(bite)
	bite.z_index = 85
	bite.size = _monster_bite_size()
	bite.position = _cell_center(grid) - bite.size * 0.5
	var frames: Array = []
	var durations: Array = []
	if assets != null:
		if assets.has_method("monster_bite_frames"):
			frames = Array(assets.call("monster_bite_frames"))
		if assets.has_method("monster_bite_frame_durations"):
			durations = Array(assets.call("monster_bite_frame_durations"))
	if bite.has_method("play"):
		bite.call("play", frames, durations, 3)
	return bite


func play_damage_number(grid: Vector2i, amount: int, damage_kind: String = "hp", y_offset: float = 0.0) -> Node:
	var number := BattleDamageNumberScene.instantiate() as Control
	add_child(number)
	number.name = "ShieldDamageNumber" if damage_kind == "shield" else "HpDamageNumber"
	number.z_index = 90
	number.position = _cell_center(grid) - Vector2(70.0, 24.0) + Vector2(0.0, y_offset)
	number.size = Vector2(140.0, 40.0)
	if number.has_method("show_damage"):
		if damage_kind == "shield":
			number.call("show_damage", amount, Color(0.18, 0.68, 1.0), 0.55, "护盾")
		else:
			number.call("show_damage", amount, Color(1.0, 0.22, 0.14), 0.55, "生命")
	return number


func play_spawn_trap(element: String, grid: Vector2i, transient: bool = false) -> Node:
	var cell := _cell_at(grid)
	if cell == null or assets == null or not assets.has_method("buff_ring_texture"):
		return cell
	var marker_texture = assets.call("buff_ring_texture", element)
	if transient and cell.has_method("show_transient_element_marker"):
		cell.call("show_transient_element_marker", marker_texture)
	elif cell.has_method("show_effect_marker"):
		cell.call("show_effect_marker", marker_texture)
	return cell


func play_element_impact(element: String, grid: Vector2i, persist_marker: bool = true) -> Node:
	var cell := _cell_at(grid)
	if cell == null:
		return null
	if persist_marker:
		play_spawn_trap(_visual_element_id(element), grid, true)
	var pulse := ColorRect.new()
	pulse.name = "ElementImpact"
	pulse.set_meta("element_impact", true)
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.z_index = 82
	pulse.color = _element_impact_color(_visual_element_id(element))
	pulse.size = cell.size * 0.82
	pulse.pivot_offset = pulse.size * 0.5
	var global_center := cell.global_position + cell.size * 0.5
	pulse.position = get_global_transform_with_canvas().affine_inverse() * global_center - pulse.size * 0.5
	pulse.scale = Vector2.ONE * 0.62
	add_child(pulse)
	var original_cell_modulate := cell.modulate
	var cell_tint := _element_impact_color(_visual_element_id(element))
	cell_tint.a = 1.0
	var tween := pulse.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector2.ONE * 1.12, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "modulate", cell_tint, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.08)
	tween.set_parallel(true)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(cell, "modulate", original_cell_modulate, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		if is_instance_valid(cell):
			cell.modulate = original_cell_modulate
		pulse.queue_free()
	)
	return pulse


func _element_impact_color(element: String) -> Color:
	match element:
		"neutral":
			return Color(0.84, 0.84, 0.78, 0.72)
		"water":
			return Color(0.18, 0.68, 1.0, 0.72)
		"grass":
			return Color(0.3, 0.8, 0.28, 0.72)
		"electric":
			return Color(1.0, 0.84, 0.12, 0.76)
		"ice":
			return Color(0.56, 0.9, 1.0, 0.74)
		"ground":
			return Color(0.78, 0.58, 0.22, 0.72)
		"dark":
			return Color(0.5, 0.28, 0.7, 0.74)
		"dragon":
			return Color(0.9, 0.32, 0.6, 0.76)
		_:
			return Color(1.0, 0.28, 0.08, 0.76)


func play_round_banner(round_number: int, side: String) -> Node:
	var banner := BattleRoundBannerScene.instantiate() as Control
	add_child(banner)
	banner.z_index = 100
	banner.anchor_left = 0.0
	banner.anchor_top = 0.0
	banner.anchor_right = 1.0
	banner.anchor_bottom = 1.0
	banner.offset_left = 0.0
	banner.offset_top = 0.0
	banner.offset_right = 0.0
	banner.offset_bottom = 0.0
	var texture_resource: Texture2D = null
	if assets != null and assets.has_method("round_banner_texture"):
		texture_resource = assets.call("round_banner_texture") as Texture2D
	if banner.has_method("show_round"):
		banner.call("show_round", round_number, side, texture_resource, 1.4)
	return banner


func debug_spawn_prefab_samples() -> Dictionary:
	var before := get_child_count()
	var projectile := play_projectile("fire", Vector2i(1, 6), Vector2i(5, 2))
	var damage := play_damage_number(Vector2i(5, 2), 7)
	var banner := play_round_banner(1, "player")
	var bite := play_bite(Vector2i(5, 2))
	var trap := play_spawn_trap("fire", Vector2i(2, 6))
	return {
		"before": before,
		"after": get_child_count(),
		"projectile_ok": projectile != null and projectile.has_method("play"),
		"damage_ok": damage != null and damage.has_method("show_damage"),
		"banner_ok": banner != null and banner.has_method("show_round"),
		"bite_ok": bite != null and bite.has_method("play"),
		"trap_ok": trap != null and trap.has_method("show_effect_marker")
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


func _cell_center(grid: Vector2i) -> Vector2:
	var cell := _cell_at(grid)
	if cell == null:
		return Vector2.ZERO
	var global_center := cell.global_position + cell.size * 0.5
	return get_global_transform_with_canvas().affine_inverse() * global_center


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


func _arc_height(from_grid: Vector2i, to_grid: Vector2i) -> float:
	var distance: int = abs(from_grid.x - to_grid.x) + abs(from_grid.y - to_grid.y)
	return 72.0 + float(distance) * 18.0


func _monster_bite_size() -> Vector2:
	var cell := _cell_at(Vector2i.ZERO)
	if cell == null:
		return Vector2(180.0, 180.0)
	var target := minf(cell.size.x, cell.size.y) * 1.55
	return Vector2(target, target)


func _dict_grid(value: Dictionary) -> Vector2i:
	return Vector2i(int(value.get("x", value.get("c", -1))), int(value.get("y", value.get("r", -1))))
