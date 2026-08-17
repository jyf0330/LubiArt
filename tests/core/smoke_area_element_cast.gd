extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = _three_cell_fixture()
	var ally: Dictionary = state.unit_by_id("area_ally")
	var enemy: Dictionary = state.unit_by_id("area_enemy")
	var ally_hp_before := int(ally.get("hp", -1))
	var enemy_hp_before := int(enemy.get("hp", -1))
	_expect(state.use_selected_action_slot(1), "three-cell action can be cast")
	for grid in [Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5)]:
		_expect(int(state._cell_elements_at(grid.x, grid.y).get("火", 0)) == 3, "every covered cell receives one fire layer per strike at %s" % grid)
	_expect(int(Dictionary(ally.get("elements", {})).get("火", 0)) == 3, "ally occupying a covered cell receives all three element layers")
	_expect(int(ally.get("hp", -1)) == ally_hp_before, "ally occupying a covered cell takes no action damage")
	_expect(int(enemy.get("hp", -1)) < enemy_hp_before, "enemy occupying a covered cell still takes action damage")
	var area_events: Array = []
	var attack_strike_events: Array = []
	var action_damage_events: Array = []
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) == "ELEMENT_APPLIED":
			area_events.append(event)
		elif String(event.get("type", "")) == "ATTACK_STRIKE":
			attack_strike_events.append(event)
		elif String(event.get("type", "")) == "DAMAGE_APPLIED" and String(Dictionary(event.get("payload", {})).get("sourceType", "")) == "action":
			action_damage_events.append(event)
	_expect(area_events.size() == 1, "one cast emits one area element event")
	if area_events.size() == 1:
		var payload := Dictionary(Dictionary(area_events[0]).get("payload", {}))
		_expect(int(payload.get("cellCount", 0)) == 3, "area event carries all three covered cells")
		_expect(Array(payload.get("targets", [])).size() == 3, "area event exposes three simultaneous visual targets")
		_expect(int(payload.get("layers", 0)) == 3, "area event reports the three layers applied across its strikes")
		_expect(bool(payload.get("suppressProjectile", false)), "occupied cast keeps simultaneous element impacts without adding a fourth attack projectile")
	_expect(attack_strike_events.size() == 3, "covered enemy receives three independent attack animations")
	for strike_index in range(attack_strike_events.size()):
		var payload := Dictionary(Dictionary(attack_strike_events[strike_index]).get("payload", {}))
		_expect(int(payload.get("strikeIndex", -1)) == strike_index + 1 and int(payload.get("strikeCount", -1)) == 3, "attack animation %d/3 keeps ordered trace metadata" % (strike_index + 1))
		_expect(bool(payload.get("applyElementOnImpact", false)), "attack animation %d/3 applies its own element layer" % (strike_index + 1))
	_expect(action_damage_events.size() == 3, "covered enemy receives three independent attack strikes")
	for strike_index in range(action_damage_events.size()):
		var payload := Dictionary(Dictionary(action_damage_events[strike_index]).get("payload", {}))
		_expect(bool(payload.get("suppressProjectile", false)), "strike %d reuses the one area cast instead of firing again" % (strike_index + 1))
		_expect(int(payload.get("strikeIndex", -1)) == strike_index + 1 and int(payload.get("strikeCount", -1)) == 3, "strike %d/3 keeps ordered trace metadata" % (strike_index + 1))
	await _verify_simultaneous_vfx()
	if failed:
		quit(1)
		return
	print("SMOKE_AREA_ELEMENT_CAST_OK")
	quit(0)


func _verify_simultaneous_vfx() -> void:
	var state: RefCounted = _three_cell_fixture()
	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	battle_flow.call("render_snapshot", state.snapshot())
	await process_frame
	state.use_selected_action_slot(1)
	battle_flow.call("render_snapshot", state.snapshot())
	var vfx_player := battle_flow.get_node_or_null("Board/VfxHost") as Control
	var impact_count := 0
	var impact_deadline := Time.get_ticks_msec() + 3000
	while impact_count == 0 and Time.get_ticks_msec() < impact_deadline:
		await process_frame
		impact_count = _active_area_impact_count(battle_flow)
	# The projectile duration is authored presentation data and may change. The
	# contract is that the first visible impact frame contains every covered
	# cell, not that this frame occurs at a hard-coded wall-clock offset.
	_expect(impact_count == 3, "all three covered cells show their impact in the same animation frame (actual %d)" % impact_count)
	if vfx_player != null:
		await vfx_player.trace_sequence_finished
	for grid in [Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5)]:
		var cell := battle_flow.get_node_or_null("Board/CellHost/BattleCell_%d_%d" % [grid.x, grid.y]) as Control
		_expect(cell != null, "covered cell exists at %s" % grid)
		if cell != null:
			_expect(cell.has_method("get_active_element_tile_variant"), "covered cell exposes its authored element-tile state at %s" % grid)
			if cell.has_method("get_active_element_tile_variant"):
				_expect(String(cell.call("get_active_element_tile_variant")) == "fire", "covered cell keeps the authored fire tile at %s" % grid)
	battle_flow.queue_free()
	await process_frame


func _active_area_impact_count(battle_flow: Control) -> int:
	var impact_count := 0
	for grid in [Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5)]:
		var cell := battle_flow.get_node_or_null("Board/CellHost/BattleCell_%d_%d" % [grid.x, grid.y]) as Control
		if cell == null:
			continue
		var impact_layer := cell.get_node_or_null("GroundElementEffects/ImpactLayer")
		if impact_layer == null:
			continue
		for child in impact_layer.get_children():
			if bool(child.get_meta("element_impact", false)):
				impact_count += 1
	return impact_count


func _three_cell_fixture() -> RefCounted:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var actor_source: Dictionary = {}
	var enemy: Dictionary = {}
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and actor_source.is_empty():
			actor_source = unit
		elif String(unit.get("side", "")) == StateScript.ENEMY and enemy.is_empty():
			enemy = unit
	var actor := actor_source
	var ally := actor_source.duplicate(true)
	actor["id"] = "area_actor"
	actor["x"] = 3
	actor["y"] = 4
	actor["atk"] = 3
	actor["attack"] = 3
	actor["shape"] = "形状13"
	actor["shape_id"] = "13"
	actor["shape_name"] = "形状13"
	actor["slot_count"] = 1
	actor["slot_elements"] = ["火"]
	actor["base_layers"] = 1
	actor["action_slots_used"] = {}
	ally["id"] = "area_ally"
	ally["x"] = 4
	ally["y"] = 3
	ally["hp"] = 20
	ally["max_hp"] = 20
	ally["elements"] = {}
	enemy["id"] = "area_enemy"
	enemy["x"] = 4
	enemy["y"] = 4
	enemy["hp"] = 30
	enemy["max_hp"] = 30
	enemy["shield"] = 0
	enemy["def"] = 0
	state.units = [actor, ally, enemy]
	state.ap = 3
	state.selected_unit_id = "area_actor"
	state.selected_action_slot_index = 0
	state.battle_trace = []
	state.action_dirs[state._action_slot_key(actor, 0)] = "right"
	return state


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_AREA_ELEMENT_CAST_FAIL: %s" % message)
