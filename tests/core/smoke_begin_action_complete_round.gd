extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false
var commands: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_button_command()
	_verify_complete_round()
	if failed:
		quit(1)
		return
	print("SMOKE_BEGIN_ACTION_COMPLETE_ROUND_OK")
	quit(0)


func _verify_button_command() -> void:
	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	battle_flow.command_requested.connect(func(command: Dictionary): commands.append(command.duplicate(true)))
	await process_frame
	var ui_state: RefCounted = StateScript.new()
	ui_state.dispatch({"type": "START_BATTLE"})
	battle_flow.call("render_snapshot", ui_state.snapshot())
	await process_frame
	var button := battle_flow.find_child("BeginTurnButton", true, false) as BaseButton
	_expect(button != null, "battle UI exposes BeginTurnButton")
	if button != null:
		button.emit_signal("pressed")
		await process_frame
	_expect(commands.size() == 1 and String(Dictionary(commands[0]).get("type", "")) == "RUN_COMBAT_ROUND", "begin action requests exactly one complete combat round")
	battle_flow.queue_free()
	await process_frame


func _verify_complete_round() -> void:
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
	enemy["x"] = 7
	enemy["y"] = 0
	state.ap = 1
	state.battle_round = 1
	state.battle_trace = []
	state.action_dirs[state._action_slot_key(actor, 0)] = "right"
	var enemy_from := Vector2i(int(enemy.get("x", -1)), int(enemy.get("y", -1)))
	_expect(state.dispatch({"type": "RUN_COMBAT_ROUND"}), "complete combat round command is accepted")
	_expect(int(state.battle_round) == 2, "complete combat round advances exactly one round")
	_expect(Vector2i(int(enemy.get("x", -1)), int(enemy.get("y", -1))) != enemy_from, "enemy pet moves during the same button action")
	var saw_area_cast := false
	var saw_enemy_move := false
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) == "ELEMENT_APPLIED":
			saw_area_cast = int(Dictionary(event.get("payload", {})).get("cellCount", 0)) >= 1
		if String(event.get("type", "")) == "MOVE_MONSTER":
			var from_pos := Dictionary(event.get("from", {}))
			var to_pos := Dictionary(event.get("to", {}))
			saw_enemy_move = from_pos != to_pos and String(Dictionary(event.get("actor", {})).get("side", "")) == StateScript.ENEMY
	_expect(saw_area_cast, "empty-cell cast emits one area application event")
	_expect(saw_enemy_move, "enemy movement emits a formal movement trace")


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
	push_error("SMOKE_BEGIN_ACTION_COMPLETE_ROUND_FAIL: %s" % message)
