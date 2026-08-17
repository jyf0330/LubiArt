extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false
var trace_started := false
var trace_finished := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_direct_core_trace()
	await _verify_direct_ui_trace()
	var state: RefCounted = _empty_target_fixture()
	state.battle_trace = []
	_expect(state.use_selected_action_slot(1), "selected empty-cell action succeeds")
	var element_events: Array = []
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) == "ELEMENT_APPLIED":
			element_events.append(event)
	_expect(element_events.size() == 1, "one empty action cell emits one element animation trace")
	if element_events.size() == 1:
		var event := Dictionary(element_events[0])
		var actor := Dictionary(event.get("actor", {}))
		var target := Dictionary(event.get("target", {}))
		var payload := Dictionary(event.get("payload", {}))
		_expect(String(actor.get("id", "")) != "", "element trace keeps the casting pet")
		_expect(int(target.get("x", -1)) == 1 and int(target.get("y", -1)) == state.board_height - 1, "element trace targets the actual empty action cell")
		_expect(String(payload.get("element", "")) == "火" and int(payload.get("layers", 0)) == 3, "element trace keeps the three core layers applied by the action")
		_expect(int(payload.get("cellCount", 0)) == 1, "one-cell shape emits one simultaneous area target")
		_expect(String(event.get("protocol", "")).begins_with("|ELEMENT_APPLIED|"), "element trace exposes replay protocol")
		await _verify_vfx(event)

	if failed:
		quit(1)
		return
	print("SMOKE_EMPTY_CELL_CAST_ANIMATION_OK")
	quit(0)


func _verify_direct_core_trace() -> void:
	var state: RefCounted = _empty_target_fixture()
	state.battle_trace = []
	_expect(state.use_selected_action_slot(1), "direct selected action succeeds")
	var element_count := 0
	for event_value in state.battle_trace:
		if String(Dictionary(event_value).get("type", "")) == "ELEMENT_APPLIED":
			element_count += 1
	_expect(element_count > 0, "direct begin emits empty-cell element animation traces")


func _verify_direct_ui_trace() -> void:
	var state: RefCounted = _empty_target_fixture()
	state.battle_trace = []
	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	battle_flow.call("render_snapshot", state.snapshot())
	await process_frame
	var vfx_player := battle_flow.get_node_or_null("Board/VfxHost") as Control
	trace_finished = false
	if vfx_player != null:
		vfx_player.trace_sequence_finished.connect(func(): trace_finished = true, CONNECT_ONE_SHOT)
	state.use_selected_action_slot(1)
	battle_flow.call("render_snapshot", state.snapshot())
	var event := _first_element_event(state.battle_trace)
	var expected_variant := _element_variant(String(Dictionary(event.get("payload", {})).get("element", "")))
	var target := Dictionary(event.get("target", {}))
	var cell := battle_flow.get_node_or_null("Board/CellHost/BattleCell_%d_%d" % [int(target.get("x", -1)), int(target.get("y", -1))]) as Control
	var impact: Control = null
	var impact_deadline := Time.get_ticks_msec() + 1500
	while impact == null and Time.get_ticks_msec() < impact_deadline:
		await process_frame
		impact = _first_element_impact(cell)
	_expect(impact != null, "battle UI consumes new element traces and shows the impact pulse")
	if impact != null:
		_expect(cell != null and impact.get_global_rect().intersects(cell.get_global_rect()), "element impact overlaps its real target cell")
		_expect(String(impact.get_meta("element_tile_variant", "")) == expected_variant, "element impact uses its authored tile variant")
		_expect(cell != null and String(cell.call("get_active_element_tile_variant")) == expected_variant, "target cell keeps the authored tile after impact")
	var finish_deadline := Time.get_ticks_msec() + 5000
	while not trace_finished and Time.get_ticks_msec() < finish_deadline:
		await process_frame
	_expect(trace_finished, "battle UI finishes the staged element trace")
	battle_flow.queue_free()
	await process_frame


func _first_element_event(events: Array) -> Dictionary:
	for event_value in events:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) == "ELEMENT_APPLIED":
			return event
	return {}


func _verify_vfx(event: Dictionary) -> void:
	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	var fixture: RefCounted = _empty_target_fixture()
	fixture.battle_trace = []
	battle_flow.call("render_snapshot", fixture.snapshot())
	await process_frame
	var vfx_player := battle_flow.get_node_or_null("Board/VfxHost") as Control
	_expect(vfx_player != null, "battle UI exposes VFX player")
	if vfx_player == null:
		return
	vfx_player.trace_event_started.connect(func(_event_id: String): trace_started = true)
	vfx_player.trace_event_finished.connect(func(_event_id: String): trace_finished = true)
	trace_started = false
	trace_finished = false
	vfx_player.call("play_trace", [event])
	await process_frame
	var actor := Dictionary(event.get("actor", {}))
	var actor_unit := _unit_by_id(battle_flow, String(actor.get("id", "")))
	_expect(trace_started, "element trace starts playback")
	_expect(actor_unit != null, "UnitHost exposes the authored projectile owner")
	if actor_unit != null and actor_unit.has_method("get_last_attack_action_snapshot"):
		var attack_snapshot := Dictionary(actor_unit.call("get_last_attack_action_snapshot"))
		_expect(String(attack_snapshot.get("attack_type", "")) == "projectile", "element trace plays the authored projectile action")
		_expect(String(attack_snapshot.get("element_id", "")) == "fire", "element projectile keeps the authored fire element")
		_expect(String(attack_snapshot.get("projectile_node_path", "")).ends_with("element_projectile/ProjectileArt"), "projectile stays under the pet attack-action responsibility node")
	var target := Dictionary(event.get("target", {}))
	var cell := battle_flow.get_node_or_null("Board/CellHost/BattleCell_%d_%d" % [int(target.get("x", -1)), int(target.get("y", -1))]) as Control
	var impact: Control = null
	var impact_deadline := Time.get_ticks_msec() + 3000
	while impact == null and Time.get_ticks_msec() < impact_deadline:
		await process_frame
		impact = _first_element_impact(cell)
	_expect(impact != null, "element trace shows a visible pulse on the empty target cell")
	if impact != null:
		_expect(String(impact.get_meta("element_tile_variant", "")) == "fire", "element impact keeps the authored fire variant")
	var deadline := Time.get_ticks_msec() + 5000
	while not trace_finished and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(trace_finished, "simultaneous area projectile sequence finishes after flight and impact")
	battle_flow.queue_free()
	await process_frame


func _first_element_impact(cell: Control) -> Control:
	if cell == null:
		return null
	var impact_layer := cell.get_node_or_null("GroundElementEffects/ImpactLayer")
	if impact_layer == null:
		return null
	for child in impact_layer.get_children():
		if child is Control and not child.is_queued_for_deletion() and bool(child.get_meta("element_impact", false)):
			return child as Control
	return null


func _unit_by_id(battle_flow: Control, unit_id: String) -> Control:
	var unit_host := battle_flow.get_node_or_null("Board/UnitHost")
	if unit_host == null:
		return null
	for child in unit_host.get_children():
		if child is Control and child.has_method("get_unit_id") and String(child.call("get_unit_id")) == unit_id:
			return child as Control
	return null


func _element_variant(element: String) -> String:
	match element:
		"火", "fire", "龙", "dragon":
			return "fire"
		"水", "water", "冰", "ice":
			return "water"
		"地", "earth", "ground", "暗", "dark":
			return "earth"
		_:
			return "wind"


func _empty_target_fixture() -> RefCounted:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var actor := _first_player(state)
	var enemy := _first_enemy(state)
	state.units = [actor, enemy]
	actor["x"] = 0
	actor["y"] = state.board_height - 1
	actor["shape"] = "形状01"
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["slot_count"] = 1
	actor["slot_elements"] = ["火"]
	actor["base_layers"] = 1
	actor["has_attacked"] = false
	actor["action_slots_used"] = {}
	enemy["x"] = 7
	enemy["y"] = 0
	state.ap = 1
	state.selected_unit_id = String(actor.get("id", ""))
	state.selected_action_slot_index = 0
	state.action_dirs[state._action_slot_key(actor, 0)] = "right"
	return state


func _first_player(state: RefCounted) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER:
			return unit
	return {}


func _first_enemy(state: RefCounted) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			return unit
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
