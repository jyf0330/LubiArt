extends SceneTree

const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleCellScene := preload("res://art/prefabs/terrain/terrain.tscn")
const StateScript := preload("res://core/state/game_state.gd")

var failed := false
var projectile_count := 0
var element_impact_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_trace_particle_count()
	await _verify_persistent_marker_count()
	if failed:
		quit(1)
		return
	print("SMOKE_ELEMENT_PARTICLE_LAYER_COUNT_OK")
	quit(0)


func _verify_trace_particle_count() -> void:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	state.battle_trace = []
	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	battle_flow.call("render_snapshot", state.snapshot())
	await process_frame
	var vfx_player := battle_flow.get_node_or_null("Board/VfxHost") as Control
	_expect(vfx_player != null, "battle UI exposes VfxHost")
	if vfx_player == null:
		battle_flow.queue_free()
		await process_frame
		return
	var actor := _first_player(state)
	var actor_unit := _unit_by_id(battle_flow, String(actor.get("id", "")))
	_expect(actor_unit != null, "UnitHost exposes the authored projectile owner")
	var attack_actions := actor_unit.get_node_or_null("CompleteBattleCreaturePrefab/03_AttackActions") if actor_unit != null else null
	_expect(attack_actions != null and attack_actions.has_signal("impact_reached"), "authored attack actions expose projectile impact timing")
	if attack_actions != null and attack_actions.has_signal("impact_reached"):
		attack_actions.connect("impact_reached", _on_projectile_impact_reached)
	var targets := [Vector2i(3, 5), Vector2i(4, 5)]
	for grid in targets:
		var cell := _cell_at(battle_flow, grid)
		_expect(cell != null, "target cell exists at %s" % grid)
		var impact_layer := cell.get_node_or_null("GroundElementEffects/ImpactLayer") if cell != null else null
		if impact_layer != null:
			impact_layer.child_entered_tree.connect(_on_element_impact_entered)

	projectile_count = 0
	element_impact_count = 0
	vfx_player.call("play_trace", [_element_event("one_layer", actor, targets, 1, false)])
	await vfx_player.trace_sequence_finished
	_expect(projectile_count == 1, "one-layer trace completes one authored projectile volley (actual %d)" % projectile_count)
	_expect(element_impact_count == 2, "one-layer trace lands on both action cells (actual %d)" % element_impact_count)

	projectile_count = 0
	element_impact_count = 0
	vfx_player.call("play_trace", [_element_event("two_layers", actor, targets, 2, false)])
	await vfx_player.trace_sequence_finished
	_expect(projectile_count == 1, "multi-layer trace reuses one authored projectile node for its volley (actual %d)" % projectile_count)
	_expect(element_impact_count == 2, "multi-layer trace still lands on both action cells (actual %d)" % element_impact_count)
	if actor_unit != null and actor_unit.has_method("get_last_attack_action_snapshot"):
		var attack_snapshot := Dictionary(actor_unit.call("get_last_attack_action_snapshot"))
		_expect(String(attack_snapshot.get("attack_type", "")) == "projectile", "UnitHost records the authored projectile action")
		_expect(String(attack_snapshot.get("element_id", "")) == "fire", "authored projectile keeps the fire element")

	projectile_count = 0
	element_impact_count = 0
	vfx_player.call("play_trace", [_element_event("suppressed", actor, targets, 3, true)])
	await vfx_player.trace_sequence_finished
	_expect(projectile_count == 0, "deferred or suppressed element events do not duplicate attack-strike projectiles")
	_expect(element_impact_count == 2, "suppressed projectile trace still shows one impact on each target cell")

	battle_flow.queue_free()
	await process_frame


func _verify_persistent_marker_count() -> void:
	var cell := BattleCellScene.instantiate() as Control
	root.add_child(cell)
	cell.call("setup_grid_position", 2, 3, Vector2(104.0, 104.0), Vector2.ZERO)
	cell.call("set_cell_data", {
		"x": 2,
		"y": 3,
		"elements": {"火": 2, "水": 1}
	}, null)
	await process_frame
	_expect(cell.has_method("get_active_element_tile_variant"), "battle cell exposes its authored element tile")
	if cell.has_method("get_active_element_tile_variant"):
		_expect(String(cell.call("get_active_element_tile_variant")) == "fire", "highest-layer element selects the authored fire tile")
	cell.call("set_cell_data", {
		"x": 2,
		"y": 3,
		"elements": {"水": 1}
	}, null)
	_expect(String(cell.call("get_active_element_tile_variant")) == "water", "changing element data selects the authored water tile")
	cell.call("set_cell_data", {"x": 2, "y": 3, "elements": {}}, null)
	_expect(String(cell.call("get_active_element_tile_variant")) == "", "clearing element data clears the authored tile")
	cell.queue_free()
	await process_frame


func _element_event(event_id: String, actor: Dictionary, target_grids: Array, layers: int, suppress_projectile: bool) -> Dictionary:
	var targets: Array[Dictionary] = []
	for grid_value in target_grids:
		var grid := grid_value as Vector2i
		targets.append({"x": grid.x, "y": grid.y})
	return {
		"eventId": event_id,
		"type": "ELEMENT_APPLIED",
		"actor": actor.duplicate(true),
		"target": Dictionary(targets[0]).duplicate(true),
		"payload": {
			"element": "火",
			"layers": layers,
			"targets": targets,
			"cells": targets,
			"cellCount": targets.size(),
			"suppressProjectile": suppress_projectile,
			"deferToAttackStrike": false
		}
	}


func _first_player(state: RefCounted) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER:
			return unit
	return {}


func _unit_by_id(battle_flow: Control, unit_id: String) -> Control:
	var unit_host := battle_flow.get_node_or_null("Board/UnitHost")
	if unit_host == null:
		return null
	for child in unit_host.get_children():
		if child is Control and child.has_method("get_unit_id") and String(child.call("get_unit_id")) == unit_id:
			return child as Control
	return null


func _cell_at(battle_flow: Control, grid: Vector2i) -> Control:
	return battle_flow.get_node_or_null("Board/CellHost/BattleCell_%d_%d" % [grid.x, grid.y]) as Control


func _on_projectile_impact_reached() -> void:
	projectile_count += 1


func _on_element_impact_entered(node: Node) -> void:
	if bool(node.get_meta("element_impact", false)):
		element_impact_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_ELEMENT_PARTICLE_LAYER_COUNT_FAIL: %s" % message)
