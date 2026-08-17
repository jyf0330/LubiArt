extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed := load("res://art/scenes/app/game.tscn") as PackedScene
	if packed == null:
		push_error("Could not load ysbzs_singleplayer scene.")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await create_timer(0.8).timeout
	var middle := scene
	if middle == null:
		push_error("Could not find artist UI middle controller.")
		quit(1)
		return
	middle.state.reset()
	middle.state.node_index = 3
	middle.state.route_options = middle.state._build_route_options()
	middle.call("render_current_view")
	await create_timer(1.0).timeout
	var battle_buttons := _battle_route_buttons(scene)
	if battle_buttons.size() != 3:
		push_error("Visible step-3 route should expose exactly 3 battle buttons, got %d." % battle_buttons.size())
		quit(1)
		return
	var encounter_id := String(Dictionary(battle_buttons[0].get_meta("command", {})).get("option_id", ""))
	for button in battle_buttons:
		if String(Dictionary(button.get_meta("command", {})).get("option_id", "")) != encounter_id:
			push_error("Visible battle buttons must share the same encounter target.")
			quit(1)
			return
	battle_buttons[2].emit_signal("pressed")
	await create_timer(1.8).timeout
	if String(middle.state.snapshot().get("phase", "")) != "battle":
		push_error("The third visible battle button did not enter battle.")
		quit(1)
		return
	var battle_flow := scene.find_child("BattleArtScene", true, false) as Control
	if battle_flow == null or not battle_flow.visible:
		push_error("BattleArtScene is not visible after selecting the third battle button.")
		quit(1)
		return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.save_png("res://output/fixed_battle_step3_three_entries.png") != OK:
		push_error("Could not capture the visible fixed-battle validation window.")
		quit(1)
		return
	print("VISIBLE_FIXED_BATTLE_THREE_ENTRY_OK step=3 button=3 shared_encounter=%s" % encounter_id)
	if OS.get_cmdline_user_args().has("--keep-open"):
		while true:
			await create_timer(1.0).timeout


func _battle_route_buttons(scene: Node) -> Array[BaseButton]:
	var matches: Array[BaseButton] = []
	for node in scene.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) == "CHOOSE_ROUTE" and String(button.get_meta("route_kind", "")) == "battle":
			matches.append(button)
	return matches
