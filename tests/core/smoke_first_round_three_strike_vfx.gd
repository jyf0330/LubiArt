extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false
var projectile_volley_count := 0
var element_impact_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = _first_round_fixture()
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
	_expect(state.use_selected_action_slot(1), "first-round player action succeeds")
	var attack_events: Array = []
	var damage_events: Array = []
	var element_events: Array = []
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		match String(event.get("type", "")):
			"ATTACK_STRIKE":
				attack_events.append(event)
			"DAMAGE_APPLIED":
				if String(Dictionary(event.get("payload", {})).get("sourceType", "")) == "action":
					damage_events.append(event)
			"ELEMENT_APPLIED":
				element_events.append(event)
	_expect(attack_events.size() == 3, "lethal first strike still emits exactly three attack animations")
	_expect(damage_events.size() == 1, "dead target is damaged only once instead of being settled repeatedly")
	_expect(element_events.size() == 1 and bool(Dictionary(Dictionary(element_events[0]).get("payload", {})).get("suppressProjectile", false)), "occupied element coverage does not add a fourth projectile")
	_expect(int(state._cell_elements_at(4, 4).get("地", 0)) == 3, "empty covered cell receives one ground layer from each strike")
	for attack_event_value in attack_events:
		_expect(bool(Dictionary(Dictionary(attack_event_value).get("payload", {})).get("applyElementOnImpact", false)), "every attack volley applies its own element layer")
	var actor_unit := _unit_by_id(battle_flow, "first_round_actor")
	_expect(actor_unit != null, "UnitHost exposes the first-round attack owner")
	var attack_actions := actor_unit.get_node_or_null("CompleteBattleCreaturePrefab/03_AttackActions") if actor_unit != null else null
	_expect(attack_actions != null and attack_actions.has_signal("impact_reached"), "authored attack actions expose volley impact timing")
	if attack_actions != null and attack_actions.has_signal("impact_reached"):
		attack_actions.connect("impact_reached", _on_projectile_impact_reached)
	var target_grids := _target_grids(attack_events)
	for grid in target_grids:
		var cell := _cell_at(battle_flow, grid)
		var impact_layer := cell.get_node_or_null("GroundElementEffects/ImpactLayer") if cell != null else null
		if impact_layer != null:
			impact_layer.child_entered_tree.connect(_on_element_impact_entered)
	vfx_player.call("play_trace", attack_events)
	await vfx_player.trace_sequence_finished
	_expect(projectile_volley_count == 3, "three strikes complete three authored projectile volleys (actual %d)" % projectile_volley_count)
	_expect(element_impact_count == 9, "three strikes land on all three covered cells (actual %d)" % element_impact_count)
	for grid in target_grids:
		var cell := _cell_at(battle_flow, grid)
		_expect(cell != null and String(cell.call("get_active_element_tile_variant")) == "earth", "covered cell keeps the authored earth tile at %s" % grid)
	battle_flow.queue_free()
	await process_frame
	if failed:
		quit(1)
		return
	print("SMOKE_FIRST_ROUND_THREE_STRIKE_VFX_OK volleys=%d impacts=%d" % [projectile_volley_count, element_impact_count])
	quit(0)


func _first_round_fixture() -> RefCounted:
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
	actor["id"] = "first_round_actor"
	actor["name"] = "第一轮宠物"
	actor["x"] = 3
	actor["y"] = 5
	actor["atk"] = 3
	actor["attack"] = 3
	actor["shape"] = "形状13"
	actor["shape_id"] = "13"
	actor["shape_name"] = "形状13"
	actor["slot_count"] = 1
	actor["slot_elements"] = ["土"]
	actor["base_layers"] = 1
	actor["action_slots_used"] = {}
	target["id"] = "first_round_target"
	target["x"] = 4
	target["y"] = 5
	target["hp"] = 1
	target["max_hp"] = 1
	target["shield"] = 0
	target["def"] = 0
	state.ap = 1
	state.selected_unit_id = "first_round_actor"
	state.selected_action_slot_index = 0
	state.action_dirs[state._action_slot_key(actor, 0)] = "right"
	return state


func _target_grids(events: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for event_value in events:
		for target_value in Array(Dictionary(event_value).get("payload", {}).get("targets", [])):
			var target := Dictionary(target_value)
			var grid := Vector2i(int(target.get("x", -1)), int(target.get("y", -1)))
			if grid.x >= 0 and grid.y >= 0 and not result.has(grid):
				result.append(grid)
	return result


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


func _on_projectile_impact_reached() -> void:
	projectile_volley_count += 1


func _on_element_impact_entered(node: Node) -> void:
	if bool(node.get_meta("element_impact", false)):
		element_impact_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_FIRST_ROUND_THREE_STRIKE_VFX_FAIL: %s" % message)
