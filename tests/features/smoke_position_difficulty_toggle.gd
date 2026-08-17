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
	state.battle_round = 2
	state.battle_trace = []
	state.ap = 1
	state.pet_reset_charges = {StateScript.PLAYER: 0, StateScript.ENEMY: 0}
	state.pet_reset_eligible = {StateScript.PLAYER: false, StateScript.ENEMY: false}
	middle.call("render_current_view")
	await process_frame

	var difficulty_button := scene.find_child("PositionDifficultyButton", true, false) as Button
	var auto_arrange_button := scene.find_child("AutoArrangeButton", true, false) as BaseButton
	var begin_button := scene.find_child("BeginTurnButton", true, false) as BaseButton
	var battle_view := scene.find_child("BattleArtScene", true, false) as Control
	_expect(difficulty_button != null, "battle UI exposes PositionDifficultyButton")
	_expect(auto_arrange_button != null, "battle UI exposes AutoArrangeButton")
	_expect(begin_button != null, "battle UI exposes BeginTurnButton")
	_expect(battle_view != null, "battle UI exposes BattleArtScene")
	if difficulty_button == null or auto_arrange_button == null or begin_button == null or battle_view == null:
		quit(1)
		return
	_expect(difficulty_button.text == "摆位难度：普通", "position difficulty starts at normal")
	_expect(String(state.snapshot().get("difficulty", "")) == StateScript.DIFFICULTY_NORMAL, "core difficulty starts at normal")

	var initial_log := Array(state.snapshot().get("command_log", []))
	var initial_auto := _command_count(initial_log, "AUTO_POSITION_HEROES")
	var initial_round_commands := _command_count(initial_log, "RUN_COMBAT_ROUND")
	var initial_resets := _command_count(initial_log, "RESET_PETS")
	var initial_auto_battles := _command_count(initial_log, "RUN_BATTLE")
	var initial_difficulty_commands := _command_count(initial_log, "SET_DIFFICULTY")

	difficulty_button.set_pressed_no_signal(true)
	difficulty_button.emit_signal("toggled", true)
	await _wait_for_difficulty(state, StateScript.DIFFICULTY_EASY)
	_expect(difficulty_button.text == "摆位难度：简单", "toggle visibly reports easy positioning")
	var easy_switch_log := Array(state.snapshot().get("command_log", []))
	_expect(_command_count(easy_switch_log, "SET_DIFFICULTY") == initial_difficulty_commands + 1, "easy toggle sends one difficulty command")
	_expect(_command_count(easy_switch_log, "AUTO_POSITION_HEROES") == initial_auto, "switching difficulty does not auto-position")
	_expect(_command_count(easy_switch_log, "RUN_COMBAT_ROUND") == initial_round_commands, "switching difficulty does not start action")

	auto_arrange_button.emit_signal("pressed")
	await _wait_for_command_count(state, "AUTO_POSITION_HEROES", initial_auto + 1)
	await _wait_for_button_text(difficulty_button, "简单摆位：")
	var easy_plan := Dictionary(Dictionary(state.last_command_result).get("plan", {}))
	_expect(String(easy_plan.get("difficulty", "")) == StateScript.DIFFICULTY_EASY, "manual auto-position uses easy difficulty")
	_expect(String(easy_plan.get("directionPolicy", "")) == "optimize", "easy positioning can optimize directions")
	_expect(difficulty_button.text.begins_with("简单摆位："), "easy auto-position reports visible completion feedback")

	auto_arrange_button.emit_signal("pressed")
	await _wait_for_command_count(state, "AUTO_POSITION_HEROES", initial_auto + 2)

	difficulty_button.set_pressed_no_signal(false)
	difficulty_button.emit_signal("toggled", false)
	await _wait_for_difficulty(state, StateScript.DIFFICULTY_NORMAL)
	_expect(difficulty_button.text == "摆位难度：普通", "toggle visibly reports normal positioning")
	var normal_switch_log := Array(state.snapshot().get("command_log", []))
	_expect(_command_count(normal_switch_log, "SET_DIFFICULTY") == initial_difficulty_commands + 2, "normal toggle sends the second difficulty command")
	_expect(_command_count(normal_switch_log, "AUTO_POSITION_HEROES") == initial_auto + 2, "switching back does not auto-position")

	auto_arrange_button.emit_signal("pressed")
	await _wait_for_command_count(state, "AUTO_POSITION_HEROES", initial_auto + 3)
	var normal_plan := Dictionary(Dictionary(state.last_command_result).get("plan", {}))
	_expect(String(normal_plan.get("difficulty", "")) == StateScript.DIFFICULTY_NORMAL, "manual auto-position uses normal difficulty")
	_expect(String(normal_plan.get("directionPolicy", "")) == "preserve", "normal positioning preserves directions")

	var round_before := int(state.snapshot().get("battle_round", 0))
	begin_button.emit_signal("pressed")
	await _wait_for_round_and_unlock(state, battle_view, round_before + 1)
	await process_frame
	await process_frame
	var final_log := Array(state.snapshot().get("command_log", []))
	_expect(_command_count(final_log, "AUTO_POSITION_HEROES") == initial_auto + 3, "round completion does not auto-position again")
	_expect(_command_count(final_log, "RUN_COMBAT_ROUND") == initial_round_commands + 1, "start action remains a separate manual command")
	_expect(_command_count(final_log, "RESET_PETS") == initial_resets, "difficulty toggle never resets pets")
	_expect(_command_count(final_log, "RUN_BATTLE") == initial_auto_battles, "difficulty toggle never starts auto battle")

	scene.queue_free()
	await process_frame
	print("SMOKE_POSITION_DIFFICULTY_TOGGLE_%s" % ["FAIL" if failed else "OK"])
	quit(1 if failed else 0)


func _wait_for_command_count(state: RefCounted, command_type: String, expected: int) -> void:
	var timeout_at := Time.get_ticks_msec() + 15000
	while _command_count(Array(state.snapshot().get("command_log", [])), command_type) < expected and Time.get_ticks_msec() < timeout_at:
		await process_frame
	_expect(_command_count(Array(state.snapshot().get("command_log", [])), command_type) >= expected, "%s reaches count %d" % [command_type, expected])


func _wait_for_difficulty(state: RefCounted, expected: String) -> void:
	var timeout_at := Time.get_ticks_msec() + 5000
	while String(state.snapshot().get("difficulty", "")) != expected and Time.get_ticks_msec() < timeout_at:
		await process_frame
	_expect(String(state.snapshot().get("difficulty", "")) == expected, "difficulty becomes %s" % expected)


func _wait_for_button_text(button: Button, expected_fragment: String) -> void:
	var timeout_at := Time.get_ticks_msec() + 5000
	while not button.text.contains(expected_fragment) and Time.get_ticks_msec() < timeout_at:
		await process_frame
	_expect(button.text.contains(expected_fragment), "button text contains %s" % expected_fragment)


func _wait_for_round_and_unlock(state: RefCounted, battle_view: Control, expected_round: int) -> void:
	var timeout_at := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < timeout_at:
		var reached_round := int(state.snapshot().get("battle_round", 0)) >= expected_round
		var unlocked := not bool(battle_view.call("is_battle_input_locked"))
		if reached_round and unlocked:
			return
		await process_frame
	_expect(false, "battle reaches round %d and unlocks" % expected_round)


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
	push_error("SMOKE_POSITION_DIFFICULTY_TOGGLE_FAIL: %s" % message)
