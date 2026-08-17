extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	state.battle_round = 4
	state.battle_trace = []
	var current_snapshot: Dictionary = state.snapshot()

	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	battle_flow.call("render_snapshot", current_snapshot)
	await process_frame
	_expect(_action_title(battle_flow) == "行动控制 · 回合4", "initial action panel shows round 4")

	state.battle_round = 5
	state.battle_trace = [{
		"eventId": "round_label_lock_001",
		"type": "round_start",
		"kind": "round_start",
		"round": 4,
		"side": "player"
	}]
	var settled_snapshot: Dictionary = state.snapshot()
	battle_flow.call("render_snapshot", settled_snapshot)
	await process_frame
	_expect(bool(battle_flow.call("is_battle_input_locked")), "trace locks battle input")
	_expect(_action_title(battle_flow) == "行动控制 · 回合4", "trace playback keeps the visible title on round 4")

	var vfx_player := battle_flow.get_node("Board/VfxHost")
	await vfx_player.trace_sequence_finished
	_expect(not bool(battle_flow.call("is_battle_input_locked")), "trace completion unlocks battle input")
	_expect(_action_title(battle_flow) == "行动控制 · 回合5", "trace completion reveals round 5")

	battle_flow.queue_free()
	await process_frame
	print("SMOKE_ROUND_LABEL_TRACE_LOCK_%s" % ["FAIL" if failed else "OK"])
	quit(1 if failed else 0)


func _action_title(battle_flow: Control) -> String:
	var action_panel := battle_flow.get_node_or_null("Hud/BattleActionPanel") as Control
	if action_panel == null:
		return ""
	var title := action_panel.get_node_or_null("Margin/Content/Title") as Label
	return title.text if title != null else ""


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_ROUND_LABEL_TRACE_LOCK_FAIL: %s" % message)
