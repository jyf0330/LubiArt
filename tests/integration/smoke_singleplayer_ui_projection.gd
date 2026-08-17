extends "res://tests/helpers/singleplayer_smoke_suite.gd"


func _run() -> void:
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	_expect(packed != null, "main scene loads")
	var scene: Node = packed.instantiate()
	_expect(scene != null, "main scene instantiates")
	root.add_child(scene)
	await process_frame
	await create_timer(0.8).timeout
	_expect(scene.get_node_or_null("ThreeChoiceScene") != null, "three-choice presentation scene enters the Game shell")
	var artist_middle := scene
	_expect(artist_middle != null, "main scene exposes the formal artist flow controller")
	if artist_middle == null:
		_finish("SMOKE_SINGLEPLAYER_UI_PROJECTION_OK")
		return
	_expect(artist_middle.get("state") != null, "main artist UI exposes runtime state")
	_expect(not scene.has_method("_render"), "main artist UI does not depend on legacy debug render API")
	_expect(scene.find_child("SeedInput", true, false) == null, "main artist UI no longer renders legacy seed input")
	_expect(scene.find_child("StartSeedButton", true, false) == null, "main artist UI no longer renders legacy seed start button")
	var artist_three_grid := scene.find_child("Middle_Three_Option", true, false)
	_expect(artist_three_grid != null and _command_button_count(artist_three_grid, "CHOOSE_ROUTE") == 3, "main artist UI renders three authored route choices")
	artist_middle.call("set_developer_tools_enabled", true)
	await process_frame
	await process_frame
	var artist_run_tools := scene.find_child("RunTools", true, false) as Control
	_expect(artist_run_tools != null, "developer mode creates RunTools under the presentation Scene")
	if artist_run_tools != null:
		for button_name in ["SaveButton", "LoadButton", "ExportReplayButton", "ExportBattleTraceButton"]:
			_expect(artist_run_tools.find_child(button_name, true, false) != null, "RunTools exposes %s" % button_name)
	var artist_shop_route_button := _find_button_with_command(scene, "CHOOSE_ROUTE", "shop")
	_expect(artist_shop_route_button != null, "main artist UI binds shop route button through command metadata")
	if artist_shop_route_button != null:
		artist_shop_route_button.emit_signal("pressed")
		await create_timer(1.5).timeout
		_expect(String(artist_middle.state.snapshot().get("phase", "")) == "shop", "artist shop route reaches shop phase through ysbzs-style command response")
		var artist_shop_grid := scene.find_child("Middle_Shop", true, false) as Control
		_expect(artist_shop_grid != null and artist_shop_grid.visible, "artist shop route shows original shop panel")
		_expect(_command_button_count(scene, "BUY_OFFER") >= 1, "artist shop renders buy-offer command buttons")
	var artist_save_button := artist_run_tools.find_child("SaveButton", true, false) as BaseButton if artist_run_tools != null else null
	var artist_status_label := artist_run_tools.find_child("RunToolsStatus", true, false) as Label if artist_run_tools != null else null
	if artist_save_button != null and artist_status_label != null:
		artist_save_button.emit_signal("pressed")
		await create_timer(0.2).timeout
		_expect(String(artist_status_label.text).contains("保存"), "artist RunTools save uses the core save path")
	_expect(artist_middle.state.dispatch({"type": "EXIT_SHOP"}), "fixture leaves shop through the public command")
	artist_middle.call("render_current_view")
	await create_timer(0.3).timeout
	_expect(String(artist_middle.state.snapshot().get("phase", "")) == "route", "public shop exit returns to route")
	var artist_battle_response: Dictionary = artist_middle.state.run_command({"type": "START_BATTLE"})
	_expect(bool(artist_battle_response.get("accepted", false)), "main artist UI can enter battle through core run_command envelope")
	artist_middle.call("render_current_view")
	await create_timer(0.5).timeout
	var artist_battle_view := scene.find_child("BattleArtScene", true, false) as Control
	_expect(artist_battle_view != null and artist_battle_view.visible, "main artist UI mounts BattleArtScene for battle phase")
	var artist_auto_arrange_button := scene.find_child("AutoArrangeButton", true, false) as BaseButton
	_expect(artist_auto_arrange_button != null, "BattleArtScene exposes auto-arrange button")
	if artist_auto_arrange_button != null:
		artist_auto_arrange_button.emit_signal("pressed")
		await create_timer(1.0).timeout
		_expect(_command_log_contains_type(Array(artist_middle.state.snapshot().get("command_log", [])), "AUTO_POSITION_HEROES"), "BattleArtScene auto-arrange submits through run_command")
	var artist_begin_turn_button := scene.find_child("BeginTurnButton", true, false) as BaseButton
	_expect(artist_begin_turn_button != null, "BattleArtScene exposes all-out begin-turn button")
	if artist_begin_turn_button != null:
		var begin_turn_requests: Array = []
		artist_battle_view.command_requested.connect(func(command: Dictionary): begin_turn_requests.append(command.duplicate(true)), CONNECT_ONE_SHOT)
		artist_begin_turn_button.emit_signal("pressed")
		await process_frame
		_expect(begin_turn_requests.size() == 1 and String(Dictionary(begin_turn_requests[0]).get("type", "")) == "RUN_COMBAT_ROUND", "BattleArtScene begin-turn requests exactly one complete combat round")
	_finish("SMOKE_SINGLEPLAYER_UI_PROJECTION_OK")
