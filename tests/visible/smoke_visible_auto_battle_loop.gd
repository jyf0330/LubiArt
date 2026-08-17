extends SceneTree

const MainScene := preload("res://art/scenes/app/game.tscn")
const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 20.0
	var scene := MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.1, true, false, true).timeout
	var middle := scene
	var view := middle.call("get_three_choice_view") as Control
	_expect(middle != null, "main artist UI exposes Middle controller")
	if middle == null:
		quit(1)
		return
	while bool(view.get("_is_transitioning")):
		await process_frame

	var state: RefCounted = middle.get("state")
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture enters battle")
	var actor := _first_side(state, StateScript.PLAYER)
	var enemy := _first_side(state, StateScript.ENEMY)
	_expect(not actor.is_empty() and not enemy.is_empty(), "fixture has both sides")
	state.units = [actor, enemy]
	actor["x"] = 0
	actor["y"] = 6
	actor["hp"] = 999
	actor["max_hp"] = 999
	actor["atk"] = 1
	actor["shape"] = "形状01"
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["slot_count"] = 1
	actor["action_slots_used"] = {}
	enemy["x"] = 7
	enemy["y"] = 1
	enemy["hp"] = 999
	enemy["max_hp"] = 999
	enemy["atk"] = 0
	enemy["shield"] = 0
	state.battle_round = 9
	state.battle_trace = []
	state.ap = 1
	middle.call("render_current_view")
	await process_frame
	var before_snapshot: Dictionary = state.snapshot()
	var before_round := int(before_snapshot.get("battle_round", 0))
	var before_command_log := Array(before_snapshot.get("command_log", []))
	var before_auto_count := _command_count(before_command_log, "AUTO_POSITION_HEROES")
	var before_round_count := _command_count(before_command_log, "RUN_COMBAT_ROUND")

	var begin_button := scene.find_child("BeginTurnButton", true, false) as BaseButton
	_expect(begin_button != null, "battle UI exposes BeginTurnButton")
	if begin_button != null:
		begin_button.emit_signal("pressed")
		await process_frame

	var battle_view := scene.find_child("BattleArtScene", true, false) as Control
	var timeout_at := Time.get_ticks_msec() + 15000
	while battle_view != null \
			and battle_view.has_method("is_battle_input_locked") \
			and bool(battle_view.call("is_battle_input_locked")) \
			and Time.get_ticks_msec() < timeout_at:
		await process_frame
	var final_snapshot: Dictionary = state.snapshot()
	var command_log := Array(final_snapshot.get("command_log", []))
	_expect(not bool(middle.get("_visible_auto_battle_running")), "begin action does not start the program-controlled auto-battle loop")
	_expect(String(final_snapshot.get("phase", "")) == "battle", "one begin-action click remains in battle when the fixture is not settled")
	_expect(int(final_snapshot.get("battle_round", 0)) == before_round + 1, "one begin-action click advances exactly one round")
	_expect(_command_count(command_log, "AUTO_POSITION_HEROES") == before_auto_count, "begin action does not auto-click or repeat auto positioning")
	_expect(_command_count(command_log, "RUN_COMBAT_ROUND") == before_round_count + 1, "begin action submits exactly one complete-round command")

	scene.queue_free()
	await process_frame
	print("SMOKE_VISIBLE_SINGLE_ROUND_BUTTON_%s" % ["FAIL" if failed else "OK"])
	quit(1 if failed else 0)


func _first_side(state: RefCounted, side: String) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == side:
			return unit
	return {}


func _command_count(command_log: Array, command_type: String) -> int:
	var count := 0
	for command_value in command_log:
		if String(Dictionary(command_value).get("type", "")) == command_type:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_VISIBLE_SINGLE_ROUND_BUTTON_FAIL: %s" % message)
