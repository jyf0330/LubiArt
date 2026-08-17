extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false
var projectile_count := 0
var element_impact_count := 0
var vfx_order: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = _two_side_fixture()
	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	battle_flow.call("render_snapshot", state.snapshot())
	await process_frame
	var vfx_player := battle_flow.get_node_or_null("Board/VfxHost") as Control
	_expect(vfx_player != null, "battle UI exposes VfxHost")
	if vfx_player == null:
		quit(1)
		return
	state.battle_trace = []
	_expect(state.use_selected_action_slot(1), "shape09 action succeeds")
	var attack_events: Array = []
	var element_events: Array = []
	var damage_events: Array = []
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) == "ATTACK_STRIKE":
			attack_events.append(event)
		elif String(event.get("type", "")) == "ELEMENT_APPLIED":
			element_events.append(event)
		elif String(event.get("type", "")) == "DAMAGE_APPLIED" and String(Dictionary(event.get("payload", {})).get("sourceType", "")) == "action":
			damage_events.append(event)
	_expect(attack_events.size() == 3, "shape09 emits exactly three simultaneous attack volleys")
	_expect(element_events.size() == 1, "shape09 emits one area element event")
	if not element_events.is_empty():
		var element_payload := Dictionary(Dictionary(element_events[0]).get("payload", {}))
		_expect(bool(element_payload.get("deferToAttackStrike", false)), "occupied attack defers element visuals to strike impact")
		_expect(int(element_payload.get("layers", 0)) == 3, "shape09 element trace reports one layer from each of three strikes")
	for event_index in range(attack_events.size()):
		var event_value = attack_events[event_index]
		var payload := Dictionary(Dictionary(event_value).get("payload", {}))
		_expect(bool(payload.get("applyElementOnImpact", false)), "volley %d lays its own element layer" % (event_index + 1))
		var keys: Array[String] = []
		for target_value in Array(payload.get("targets", [])):
			var target := Dictionary(target_value)
			keys.append("%d,%d" % [int(target.get("x", -1)), int(target.get("y", -1))])
		keys.sort()
		_expect(keys == ["4,3", "4,5"], "each volley attacks both shape09 sides (actual %s)" % JSON.stringify(keys))
	_expect(damage_events.size() == 3, "only the occupied enemy side receives three damage settlements")
	_expect(int(state._cell_elements_at(4, 3).get("火", 0)) == 3, "enemy side receives three fire layers")
	_expect(int(state._cell_elements_at(4, 5).get("火", 0)) == 3, "empty opposite side receives three fire layers")
	for event_value in damage_events:
		_expect(String(Dictionary(Dictionary(event_value).get("target", {})).get("id", "")) == "two_side_target", "damage remains bound to the enemy-occupied side")
	var visual_events := element_events.duplicate(true)
	visual_events.append_array(attack_events)
	var actor_unit := _unit_by_id(battle_flow, "two_side_actor")
	_expect(actor_unit != null, "UnitHost exposes the shape09 attack owner")
	var attack_actions := actor_unit.get_node_or_null("CompleteBattleCreaturePrefab/03_AttackActions") if actor_unit != null else null
	_expect(attack_actions != null and attack_actions.has_signal("impact_reached"), "authored attack actions expose volley impact timing")
	if attack_actions != null and attack_actions.has_signal("impact_reached"):
		attack_actions.connect("impact_reached", _on_projectile_impact_reached)
	for grid in [Vector2i(4, 3), Vector2i(4, 5)]:
		var cell := _cell_at(battle_flow, grid)
		var impact_layer := cell.get_node_or_null("GroundElementEffects/ImpactLayer") if cell != null else null
		if impact_layer != null:
			impact_layer.child_entered_tree.connect(_on_element_impact_entered)
	vfx_player.call("play_trace", visual_events)
	await vfx_player.trace_sequence_finished
	_expect(projectile_count == 3, "shape09 completes three authored projectile volleys (actual %d)" % projectile_count)
	_expect(element_impact_count == 6, "all three volleys show the same element impact on both shape09 sides (actual %d)" % element_impact_count)
	_expect(not vfx_order.is_empty() and vfx_order[0] == "projectile", "deferred element does not appear before the first attack projectile")
	_expect(vfx_order.find("element") > vfx_order.find("projectile"), "element impact appears after projectile launch at attack landing")
	_expect(_has_effect_marker(battle_flow, Vector2i(4, 3)), "enemy side keeps an element marker from first impact")
	_expect(_has_effect_marker(battle_flow, Vector2i(4, 5)), "empty opposite side keeps an element marker from first impact")
	battle_flow.queue_free()
	await process_frame
	if failed:
		quit(1)
		return
	print("SMOKE_MULTI_CELL_STRIKE_VFX_OK projectiles=%d" % projectile_count)
	quit(0)


func _two_side_fixture() -> RefCounted:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var actor: Dictionary = {}
	var target: Dictionary = {}
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and actor.is_empty():
			actor = unit
		elif String(unit.get("side", "")) == StateScript.ENEMY and target.is_empty():
			target = unit
	state.units = [actor, target]
	actor["id"] = "two_side_actor"
	actor["name"] = "蜜蜂"
	actor["x"] = 3
	actor["y"] = 4
	actor["atk"] = 3
	actor["attack"] = 3
	actor["shape"] = "形状09"
	actor["shape_id"] = "09"
	actor["shape_name"] = "形状09"
	actor["slot_count"] = 1
	actor["slot_elements"] = ["火"]
	actor["base_layers"] = 1
	actor["action_slots_used"] = {}
	target["id"] = "two_side_target"
	target["x"] = 4
	target["y"] = 3
	target["hp"] = 99
	target["max_hp"] = 99
	target["shield"] = 0
	target["def"] = 0
	state.ap = 1
	state.selected_unit_id = "two_side_actor"
	state.selected_action_slot_index = 0
	state.action_dirs[state._action_slot_key(actor, 0)] = "right"
	return state


func _on_projectile_impact_reached() -> void:
	projectile_count += 1
	vfx_order.append("projectile")


func _on_element_impact_entered(node: Node) -> void:
	if bool(node.get_meta("element_impact", false)):
		element_impact_count += 1
		vfx_order.append("element")


func _has_effect_marker(battle_flow: Control, grid: Vector2i) -> bool:
	var cell := _cell_at(battle_flow, grid)
	return cell != null and cell.has_method("get_active_element_tile_variant") \
		and String(cell.call("get_active_element_tile_variant")) == "fire"


func _cell_at(battle_flow: Control, grid: Vector2i) -> Control:
	return battle_flow.get_node_or_null("Board/CellHost/BattleCell_%d_%d" % [grid.x, grid.y]) as Control


func _unit_by_id(battle_flow: Control, unit_id: String) -> Control:
	var unit_host := battle_flow.get_node_or_null("Board/UnitHost")
	if unit_host == null:
		return null
	for child in unit_host.get_children():
		if child is Control and child.has_method("get_unit_id") and String(child.call("get_unit_id")) == unit_id:
			return child as Control
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_MULTI_CELL_STRIKE_VFX_FAIL: %s" % message)
