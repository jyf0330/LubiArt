extends SceneTree

const GAME_SCENE := preload("res://art/scenes/app/game.tscn")
const OUTPUT_DIR := "res://output/validation/2026-08-05_battle_art_round_trip/formal_visible"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await _settle(0.8)
	game.state.reset()
	if not _prepare_four_active_roster(game):
		_fail("could not prepare four active pets")
		return
	game.state.node_index = 3
	game.state.route_options = game.state._build_route_options()
	game.call("render_current_view")
	await _settle(0.8)
	var battle_route := _find_battle_route(game)
	if battle_route == null:
		_fail("formal route has no battle entry")
		return
	battle_route.pressed.emit()
	var battle := await _wait_for_battle(game, 3.0)
	if battle == null:
		_fail("formal battle scene did not mount")
		return

	var map_controls := battle.get_node("MapControls") as Control
	var timeline := battle.get_node("Hud/AttackTimelineLayer/AttackTimeline") as Control
	var settings := battle.get_node("OverlayHost/SettingsMenu") as Control
	var speed_button := map_controls.get_node("SpeedButton") as TextureButton
	var bag_button := map_controls.get_node("BagButton") as TextureButton
	if not speed_button.disabled or not bag_button.disabled:
		_fail("unsupported formal speed and bag actions must be disabled")
		return
	if (battle.get_node("MapDebugButton") as Button).visible:
		_fail("formal map debug button must be hidden by default")
		return
	if (battle.get_node("ShortcutHintDebugButton") as Button).visible:
		_fail("formal shortcut debug button must be hidden by default")
		return

	(map_controls.get_node("AttackOrderButton") as TextureButton).pressed.emit()
	await _settle(0.25)
	if not timeline.visible or int(timeline.call("debug_marker_count")) != 8:
		_fail("formal attack timeline must show eight authoritative A/B entries")
		return
	if not await _capture("attack_timeline.png"):
		_fail("could not capture attack timeline")
		return
	(map_controls.get_node("AttackOrderButton") as TextureButton).pressed.emit()
	await process_frame

	(map_controls.get_node("SettingsButton") as TextureButton).pressed.emit()
	await _settle(0.25)
	if not settings.visible:
		_fail("formal settings menu did not open")
		return
	var buttons_root := "CompleteUISettingsButtonPrefab/01_UISettingsButtonVisual/Menu/VBoxContainer/"
	if not (settings.get_node(buttons_root + "MainMenu") as Button).disabled:
		_fail("unrouted formal main-menu action must be disabled")
		return
	if not (settings.get_node(buttons_root + "Resign") as Button).disabled:
		_fail("unrouted formal resign action must be disabled")
		return
	if (settings.get_node(buttons_root + "SaveGame") as Button).disabled:
		_fail("formal save entry must stay available")
		return
	if (settings.get_node(buttons_root + "LoadGame") as Button).disabled:
		_fail("formal load entry must stay available")
		return
	if not await _capture("settings_menu.png"):
		_fail("could not capture settings menu")
		return
	(settings.get_node(buttons_root + "Continue") as Button).pressed.emit()
	await process_frame
	if settings.visible:
		_fail("formal settings menu did not close")
		return
	print("SMOKE_BATTLE_ART_CONTROLS_VISIBLE_OK")
	quit(0)


func _prepare_four_active_roster(game: Node) -> bool:
	var existing_pet_ids := {}
	for value in Array(game.state.snapshot().get("roster", [])):
		var row := Dictionary(value)
		existing_pet_ids[String(row.get("pet_id", row.get("id", "")))] = true
	for value in Array(game.state.game_data.get("shop_offers", [])):
		if _active_roster_count(game) >= 4:
			break
		var offer := Dictionary(value).duplicate(true)
		var pet_id := String(offer.get("pet_id", offer.get("id", "")))
		if pet_id == "" or existing_pet_ids.has(pet_id):
			continue
		game.state.call("_add_pet_to_roster", offer, "battle_art_visible_fixture", "party")
		existing_pet_ids[pet_id] = true
	return _active_roster_count(game) == 4


func _active_roster_count(game: Node) -> int:
	var count := 0
	for value in Array(game.state.snapshot().get("roster", [])):
		if bool(Dictionary(value).get("active", false)):
			count += 1
	return count


func _find_battle_route(game: Node) -> BaseButton:
	for node in game.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) == "CHOOSE_ROUTE" \
				and String(button.get_meta("route_kind", "")).to_lower() == "battle":
			return button
	return null


func _wait_for_battle(game: Node, timeout_seconds: float) -> Control:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var battle := game.find_child("BattleArtScene", true, false) as Control
		if battle != null and battle.visible:
			return battle
		await process_frame
	return null


func _settle(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame


func _capture(file_name: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	return image != null \
		and image.get_size() == Vector2i(1920, 1080) \
		and image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))) == OK


func _fail(message: String) -> void:
	push_error("SMOKE_BATTLE_ART_CONTROLS_VISIBLE_FAIL: %s" % message)
	quit(1)
