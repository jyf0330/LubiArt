extends SceneTree

const FIXED_TEST_PLAY_SEED := "ysbzs-test-play-20260715-v1"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://art/scenes/app/game.tscn") as PackedScene
	if packed == null:
		push_error("Fixed test seed smoke could not load the main scene.")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.8).timeout
	var middle := scene
	var view := middle.call("get_three_choice_view") as Control
	if middle == null or middle.get("state") == null:
		push_error("Fixed test seed smoke could not find the artist UI runtime state.")
		quit(1)
		return
	if String(middle.state.snapshot().get("run_seed", "")) != FIXED_TEST_PLAY_SEED:
		push_error("Main test play must start with the fixed seed.")
		quit(1)
		return
	view.call("_render_terminal_choice", {"phase": "game_over"})
	var restart_button := _find_restart_button(scene)
	if restart_button == null:
		push_error("Fixed test seed smoke could not find the original restart slot button.")
		quit(1)
		return
	var command := Dictionary(restart_button.get_meta("command", {}))
	if String(command.get("type", "")) != "NEW_RUN" or String(command.get("seed", "")) != FIXED_TEST_PLAY_SEED:
		push_error("Restart must bind the same fixed test seed.")
		quit(1)
		return
	restart_button.emit_signal("pressed")
	await create_timer(0.8).timeout
	if String(middle.state.snapshot().get("run_seed", "")) != FIXED_TEST_PLAY_SEED:
		push_error("Restart did not return to the fixed test seed.")
		quit(1)
		return
	print("SMOKE_FIXED_TEST_PLAY_SEED_OK seed=%s" % FIXED_TEST_PLAY_SEED)
	quit(0)


func _find_restart_button(scene: Node) -> BaseButton:
	for node in scene.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button != null and button.has_meta("command"):
			var command := Dictionary(button.get_meta("command", {}))
			if String(command.get("type", "")) == "NEW_RUN":
				return button
	return null
