extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var actor := _first_side(state, StateScript.PLAYER)
	var enemy := _first_side(state, StateScript.ENEMY)
	state.units = [actor, enemy]
	actor["x"] = 0
	actor["y"] = 6
	actor["shape"] = "形状01"
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["slot_count"] = 1
	actor["slot_elements"] = ["火"]
	actor["base_layers"] = 1
	actor["action_slots_used"] = {}
	enemy["x"] = 1
	enemy["y"] = 6
	enemy["hp"] = 30
	enemy["max_hp"] = 30
	enemy["ap"] = 0
	enemy["move_range"] = 0
	enemy["moveRange"] = 0
	state.ap = 1
	state.battle_round = 1
	state.battle_trace = []
	state.action_dirs[state._action_slot_key(actor, 0)] = "right"

	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	var probe := BattleSceneProbe.new(battle_flow)
	var previous_snapshot: Dictionary = state.snapshot()
	battle_flow.call("render_snapshot", previous_snapshot)
	await process_frame
	var enemy_id := String(enemy.get("id", ""))
	_expect(_visible_unit_hp(probe, enemy_id) == 30, "pre-action board starts at enemy HP 30")

	_expect(bool(state.dispatch({"type": "RUN_COMBAT_ROUND"})), "combat round command is accepted")
	var final_snapshot: Dictionary = state.snapshot()
	var final_enemy := _snapshot_unit_by_id(final_snapshot, enemy_id)
	_expect(not final_enemy.is_empty(), "round result retains the enemy record")
	_expect(int(final_enemy.get("hp", 30)) < 30, "round result contains reduced enemy HP")
	var actor_id := String(actor.get("id", ""))
	final_snapshot["selected_unit_id"] = actor_id
	final_snapshot["action_block_ranges_by_unit"] = Dictionary(previous_snapshot.get(
		"action_block_ranges_by_unit",
		{}
	)).duplicate(true)

	battle_flow.call("render_snapshot", final_snapshot)
	_expect(bool(battle_flow.call("is_battle_input_locked")), "trace locks input while staged")
	_expect(_visible_unit_hp(probe, enemy_id) == 30, "trace begins from the pre-action HP instead of the final HP")
	_expect(int(probe.selected_action_range_summary().get("visibleCellCount", 0)) == 0, "next-round action range is hidden during trace playback")

	var vfx_player := battle_flow.get_node("Board/VfxHost")
	await vfx_player.trace_sequence_finished
	var final_enemy_hp := int(final_enemy.get("hp", -1))
	var expected_visible_hp := final_enemy_hp if final_enemy_hp > 0 else -1
	_expect(_visible_unit_hp(probe, enemy_id) == expected_visible_hp, "trace completion commits final enemy HP or removes a defeated unit")
	_expect(int(probe.selected_action_range_summary().get("visibleCellCount", 0)) > 0, "trace completion reveals the final snapshot action range")

	battle_flow.queue_free()
	await process_frame
	print("SMOKE_BATTLE_TRACE_SNAPSHOT_STAGING_%s" % ["FAIL" if failed else "OK"])
	quit(1 if failed else 0)


func _visible_unit_hp(probe: RefCounted, unit_id: String) -> int:
	for y in range(8):
		for x in range(8):
			var summary := Dictionary(probe.call("cell_summary", Vector2i(x, y)))
			if summary.is_empty():
				continue
			var data := Dictionary(summary.get("data", {}))
			if String(data.get("unitId", data.get("unit_id", ""))) == unit_id:
				return int(data.get("hp", -1))
	return -1


func _snapshot_unit_by_id(snapshot: Dictionary, unit_id: String) -> Dictionary:
	for unit_value in Array(snapshot.get("units", [])):
		var unit := Dictionary(unit_value)
		if String(unit.get("id", unit.get("unitId", ""))) == unit_id:
			return unit
	return {}


func _first_side(state: RefCounted, side: String) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == side:
			return unit
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_BATTLE_TRACE_SNAPSHOT_STAGING_FAIL: %s" % message)
