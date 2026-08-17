extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false
var reset_revealed := false
var round_banner_titles: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := StateScript.new()
	state.start_battle()
	_keep_enemy_count(state, 2)
	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	var battle_probe := load("res://tests/helpers/battle_scene_probe.gd").new(battle_flow) as RefCounted
	battle_flow.call("render_snapshot", state.snapshot())
	await process_frame

	state.battle_round = 5
	state.call("_grant_pet_reset_charges_for_round", 5)
	state.call("_reset_eligible_sides_after_round")
	state.call("_start_next_battle_round")
	var final_snapshot: Dictionary = state.snapshot()
	var reset_event := _last_event(final_snapshot, "PETS_RESET")
	var reset_units := Array(Dictionary(reset_event.get("payload", {})).get("units", []))
	_expect(not reset_event.is_empty(), "enemy auto reset emits PETS_RESET")
	_expect(reset_units.size() == 4, "reset trace contains the restored fixed roster")
	_expect(_event_count(final_snapshot, "WAVE_SUMMONED") == 0, "reset flow emits no wave event")

	var vfx_player := battle_flow.get_node("Board/VfxHost")
	vfx_player.pets_reset_reveal_requested.connect(func(_units: Array): reset_revealed = true)
	vfx_player.child_entered_tree.connect(func(child: Node):
		if child.name != "RoundFeedback":
			return
		child.tree_exiting.connect(func():
			var title := child.get_node_or_null("Title") as Label
			if title != null:
				round_banner_titles.append(title.text)
		)
	)
	battle_flow.call("render_snapshot", final_snapshot)
	for unit_value in reset_units:
		var unit := Dictionary(unit_value)
		_expect(not _unit_visible_at(battle_probe, int(unit.get("x", -1)), int(unit.get("y", -1))), "reset pet stays hidden until reveal step")

	await vfx_player.trace_sequence_finished
	_expect(reset_revealed, "pet reset reveal signal runs")
	for unit_value in reset_units:
		var unit := Dictionary(unit_value)
		_expect(_unit_visible_at(battle_probe, int(unit.get("x", -1)), int(unit.get("y", -1))), "reset pet is visible after reveal")
	_expect(bool(Dictionary(reset_event.get("payload", {})).get("showNextRoundBanner", false)) and int(Dictionary(reset_event.get("payload", {})).get("nextRound", 0)) == 6, "round-5 reset requests the round-6 banner")

	battle_flow.queue_free()
	await process_frame
	print("SMOKE_PET_RESET_VFX_ORDER_%s" % ["FAIL" if failed else "OK"])
	quit(1 if failed else 0)


func _keep_enemy_count(state: RefCounted, count: int) -> void:
	var kept := 0
	for value in state.units:
		var unit := Dictionary(value)
		if String(unit.get("side", "")) != StateScript.ENEMY:
			continue
		if kept < count:
			unit["hp"] = max(1, int(unit.get("hp", 1)))
			kept += 1
		else:
			unit["hp"] = 0


func _last_event(snap: Dictionary, event_type: String) -> Dictionary:
	var found: Dictionary = {}
	for value in Array(snap.get("battleTrace", [])):
		var event := Dictionary(value)
		if String(event.get("type", "")) == event_type:
			found = event
	return found


func _event_count(snap: Dictionary, event_type: String) -> int:
	var count := 0
	for value in Array(snap.get("battleTrace", [])):
		if String(Dictionary(value).get("type", "")) == event_type:
			count += 1
	return count


func _unit_visible_at(battle_probe: RefCounted, x: int, y: int) -> bool:
	var cell := battle_probe.call("cell_at", Vector2i(x, y)) as Control
	return cell != null and cell.has_method("get_unit_node") and cell.call("get_unit_node") != null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_PET_RESET_VFX_ORDER_FAIL: %s" % message)
