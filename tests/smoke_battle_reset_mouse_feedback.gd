extends SceneTree

const BATTLE := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")

var _reset_command_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var battle := BATTLE.instantiate() as Control
	root.add_child(battle)
	battle.command_requested.connect(_on_command_requested)
	await process_frame
	await process_frame
	var snapshot := Dictionary(MockSession.new({"start_phase": "battle"}).call("current_snapshot"))
	var reset_state := Dictionary(Dictionary(snapshot.get("pet_reset", {})).get("player", {}))
	assert(not bool(reset_state.get("eligible", false)))
	battle.call("render_snapshot", snapshot)
	await process_frame
	await process_frame
	var button := battle.get_node("MapControls/ResetButton") as TextureButton
	assert(not button.disabled)
	await _mouse_press(button)
	assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
	await _mouse_release(button)
	assert(_reset_command_count == 0)
	var release_tween := (
		(battle.get_node("MapControls").get("_button_tweens") as Dictionary).get(button) as Tween
	)
	assert(release_tween != null)
	release_tween.custom_step(0.20)
	assert(button.scale.is_equal_approx(Vector2.ONE))

	var eligible_snapshot := snapshot.duplicate(true)
	Dictionary(Dictionary(eligible_snapshot["pet_reset"])["player"])["eligible"] = true
	battle.call("render_snapshot", eligible_snapshot)
	await process_frame
	assert(not button.disabled)
	await _mouse_press(button)
	await _mouse_release(button)
	assert(_reset_command_count == 1)
	print("BATTLE_RESET_MOUSE_FEEDBACK_SMOKE_PASS")
	quit(0)


func _mouse_press(button: TextureButton) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	assert(root.gui_get_hovered_control() == button)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame


func _mouse_release(button: TextureButton) -> void:
	var point := button.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _on_command_requested(command: Dictionary) -> void:
	if String(command.get("type", "")) == "RESET_PETS":
		_reset_command_count += 1
