extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	if packed == null:
		push_error("Could not load ysbzs_singleplayer scene.")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await create_timer(0.8).timeout
	var middle := scene
	if middle == null or middle.get("state") == null:
		push_error("Battle action panel smoke could not find the live middle controller.")
		quit(1)
		return
	if not middle.state.dispatch({"type": "START_BATTLE"}):
		push_error("Battle action panel smoke could not enter battle through the core command.")
		quit(1)
		return
	middle.call("render_current_view")
	await create_timer(0.5).timeout
	var panel := scene.find_child("BattleActionPanel", true, false) as Control
	if panel == null or not panel.visible:
		push_error("Formal battle action panel is missing or hidden.")
		quit(1)
		return
	for button_name in ["ResetPetsButton", "AllOutButton", "EndTurnButton", "MonsterTurnButton"]:
		if panel.find_child(button_name, true, false) == null:
			push_error("Formal battle action panel is missing %s." % button_name)
			quit(1)
			return
	var skill_queue_grid := panel.find_child("SkillQueueGrid", true, false) as GridContainer
	if skill_queue_grid == null or skill_queue_grid.get_child_count() != 8:
		push_error("Formal battle action panel should expose eight authored skill queue slots.")
		quit(1)
		return
	var end_button := panel.find_child("EndTurnButton", true, false) as BaseButton
	if end_button == null:
		push_error("Formal battle action panel end-turn button is missing.")
		quit(1)
		return
	end_button.emit_signal("pressed")
	await create_timer(0.35).timeout
	var phase := String(middle.state.snapshot().get("phase", ""))
	if phase != "battle" and phase != "battle_end":
		push_error("Formal battle action panel end-turn should keep the battle flow playable, got %s." % phase)
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		var image := get_root().get_texture().get_image()
		if image == null or image.save_png("res://output/battle_action_panel.png") != OK:
			push_error("Could not capture formal battle action panel.")
			quit(1)
			return
	print("SMOKE_BATTLE_ACTION_PANEL_OK")
	if DisplayServer.get_name() == "headless":
		quit(0)
