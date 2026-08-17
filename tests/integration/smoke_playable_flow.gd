extends SceneTree

const BATTLE_COMPLETION_TIMEOUT := 180.0
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")


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
	await _settle_seconds(0.8)

	var middle := scene
	if middle == null or middle.get("state") == null:
		push_error("Playable flow smoke could not find the artist UI controller.")
		quit(1)
		return
	middle.state.node_index = 3
	middle.state.route_options = middle.state._build_route_options()
	middle.call("render_current_view")
	await _settle_seconds(0.4)

	var battle_route := await _advance_to_first_battle_route(scene, middle)
	if battle_route == null:
		push_error("Playable flow needs a fixed battle route button after ordinary route nodes.")
		quit(1)
		return
	battle_route.emit_signal("pressed")
	await _settle_seconds(1.8)
	if String(middle.state.snapshot().get("phase", "")) != "battle":
		push_error("Playable flow did not enter battle from the real route button.")
		quit(1)
		return

	var battle_flow := scene.find_child("BattleArtScene", true, false) as Control
	if battle_flow == null or not battle_flow.visible:
		push_error("Playable flow did not show BattleArtScene.")
		quit(1)
		return
	if not await _wait_for_controller_idle(middle, 5.0):
		push_error("Playable flow controller did not become idle before battle command.")
		quit(1)
		return
	var battle_probe := BattleSceneProbe.new(battle_flow)
	if not battle_probe.is_ready():
		push_error("Playable flow needs all BattleArtScene presentation responsibility roots.")
		quit(1)
		return
	var run_battle_command := Dictionary(battle_probe.emit_command_request({"type": "RUN_BATTLE"}))
	if String(run_battle_command.get("type", "")) != "RUN_BATTLE":
		push_error("BattleSceneProbe should emit RUN_BATTLE through BattleArtScene.command_requested.")
		quit(1)
		return
	if not await _wait_for_phase(middle, "battle_end", BATTLE_COMPLETION_TIMEOUT):
		push_error("BattleArtScene RUN_BATTLE request should drive core battle to battle_end, got %s." % String(middle.state.snapshot().get("phase", "")))
		quit(1)
		return
	if not await _wait_for_controller_idle(middle, 120.0):
		push_error("Playable flow controller did not finish the final battle trace.")
		quit(1)
		return

	var continue_button := _find_button_with_command(scene, "CONTINUE_AFTER_BATTLE", "")
	if continue_button == null:
		push_error("Playable flow needs a continue-after-battle command on the original route slot.")
		quit(1)
		return
	continue_button.emit_signal("pressed")
	await _wait_for_phase_change(middle, "battle_end", 5.0)

	var phase_after_continue := String(middle.state.snapshot().get("phase", ""))
	if phase_after_continue == "reward":
		await process_frame
		if not await _wait_for_controller_idle(middle, 5.0):
			push_error("Playable flow controller did not finish the reward transition.")
			quit(1)
			return
		var reward_button := _find_button_with_command(scene, "PICK_REWARD", "")
		if reward_button == null:
			push_error("Playable flow reached reward phase but no original reward slot is clickable.")
			quit(1)
			return
		reward_button.emit_signal("pressed")
		await process_frame
		var reward_detail := scene.find_child("ArtistPetDetailPanel", true, false)
		var confirm_button := reward_detail.get_node_or_null("Panel/Actions/ConfirmButton") as Button if reward_detail != null else null
		if confirm_button != null and confirm_button.visible:
			confirm_button.emit_signal("pressed")
		await _settle_seconds(1.0)
		phase_after_continue = String(middle.state.snapshot().get("phase", ""))

	if not ["route", "day_end", "game_over"].has(phase_after_continue):
		push_error("Playable flow should return to route/day_end/game_over after battle reward, got %s." % phase_after_continue)
		quit(1)
		return

	if phase_after_continue == "day_end":
		var next_day_button := _find_button_with_command(scene, "START_NEXT_DAY", "")
		if next_day_button != null:
			next_day_button.emit_signal("pressed")
			await _settle_seconds(1.0)
			if String(middle.state.snapshot().get("phase", "")) != "route":
				push_error("Playable flow START_NEXT_DAY should return to route phase.")
				quit(1)
				return

	if not await _assert_save_load_round_trip(scene, middle):
		quit(1)
		return

	var capture_saved := await _save_capture("res://output/playable_flow_main.png")
	if not capture_saved:
		print("SMOKE_PLAYABLE_FLOW_CAPTURE_SKIPPED headless viewport texture unavailable")
	print("SMOKE_PLAYABLE_FLOW_OK route->battle->battle_end->reward/route with save-load")
	if _should_keep_open():
		print("SMOKE_PLAYABLE_FLOW_KEEP_OPEN")
		return
	quit(0)


func _assert_save_load_round_trip(scene: Node, middle: Node) -> bool:
	middle.call("set_developer_tools_enabled", true)
	await process_frame
	await process_frame
	var run_tools := scene.find_child("RunTools", true, false) as Control
	if run_tools == null:
		push_error("Playable flow needs RunTools for save/load.")
		return false
	var save_button := run_tools.find_child("SaveButton", true, false) as BaseButton
	var load_button := run_tools.find_child("LoadButton", true, false) as BaseButton
	if save_button == null or load_button == null:
		push_error("Playable flow save/load buttons are missing.")
		return false
	var saved_phase := String(middle.state.snapshot().get("phase", ""))
	save_button.emit_signal("pressed")
	await _settle_seconds(0.2)
	if saved_phase == "game_over":
		middle.state.dispatch({"type": "NEW_RUN"})
	middle.state.dispatch({"type": "START_BATTLE"})
	middle.call("render_current_view")
	await _settle_seconds(0.5)
	if String(middle.state.snapshot().get("phase", "")) != "battle":
		push_error("Playable flow save/load setup could not enter a temporary battle phase.")
		return false
	load_button.emit_signal("pressed")
	await _settle_seconds(1.0)
	if String(middle.state.snapshot().get("phase", "")) != saved_phase:
		push_error("Playable flow load should restore phase %s, got %s." % [saved_phase, String(middle.state.snapshot().get("phase", ""))])
		return false
	return true


func _advance_to_first_battle_route(scene: Node, middle: Node) -> BaseButton:
	for _attempt in range(6):
		var battle_route := _find_button_with_command(scene, "CHOOSE_ROUTE", "battle")
		if battle_route != null:
			return battle_route
		if String(middle.state.snapshot().get("phase", "")) != "route":
			if not await _settle_intermediate_route_phase(scene, middle):
				return null
			continue
		var route_button := _find_first_route_progress_button(scene)
		if route_button == null:
			return null
		route_button.emit_signal("pressed")
		await _settle_seconds(1.8)
		if not await _settle_intermediate_route_phase(scene, middle):
			return null
	return _find_button_with_command(scene, "CHOOSE_ROUTE", "battle")


func _settle_intermediate_route_phase(scene: Node, middle: Node) -> bool:
	var phase := String(middle.state.snapshot().get("phase", ""))
	if phase == "route" or phase == "battle":
		return true
	if phase == "shop":
		var back_button := scene.find_child("Shop_BackButton", true, false) as BaseButton
		if back_button == null:
			return false
		back_button.emit_signal("pressed")
		await _settle_seconds(1.8)
		return String(middle.state.snapshot().get("phase", "")) == "route"
	if phase == "reward":
		var reward_button := _find_button_with_command(scene, "PICK_REWARD", "")
		if reward_button == null:
			return false
		reward_button.emit_signal("pressed")
		await _settle_seconds(1.8)
		return String(middle.state.snapshot().get("phase", "")) == "route"
	return false


func _find_first_route_progress_button(scene: Node) -> BaseButton:
	var buttons := scene.find_children("*", "BaseButton", true, false)
	var fallback: BaseButton = null
	for node in buttons:
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != "CHOOSE_ROUTE":
			continue
		if String(button.get_meta("route_kind", "")).to_lower() == "battle":
			continue
		if String(button.get_meta("route_kind", "")).to_lower() == "reward":
			if fallback == null:
				fallback = button
			continue
		return button
	return fallback


func _find_button_with_command(scene: Node, command_type: String, kind: String) -> BaseButton:
	var buttons := scene.find_children("*", "BaseButton", true, false)
	for node in buttons:
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != command_type:
			continue
		if kind == "":
			return button
		if String(button.get_meta("route_kind", "")).to_lower() == kind:
			return button
	return null


func _settle_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _wait_for_phase(middle: Node, expected_phase: String, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if String(middle.state.snapshot().get("phase", "")) == expected_phase:
			return true
		await _settle_seconds(0.2)
		elapsed += 0.2
	return String(middle.state.snapshot().get("phase", "")) == expected_phase


func _wait_for_phase_change(middle: Node, previous_phase: String, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if String(middle.state.snapshot().get("phase", "")) != previous_phase:
			return true
		await _settle_seconds(0.2)
		elapsed += 0.2
	return String(middle.state.snapshot().get("phase", "")) != previous_phase


func _wait_for_controller_idle(middle: Node, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if _controller_is_idle(middle):
			return true
		await _settle_seconds(0.2)
		elapsed += 0.2
	return _controller_is_idle(middle)


func _controller_is_idle(middle: Node) -> bool:
	var route_view := middle.call("get_three_choice_view") as Node if middle.has_method("get_three_choice_view") else null
	if (route_view != null and bool(route_view.get("_is_transitioning"))) \
			or bool(middle.get("_visible_auto_battle_running")):
		return false
	var battle_view: Variant = middle.call("get_feature_controller", &"battle") if middle.has_method("get_feature_controller") else null
	return battle_view == null or not battle_view.has_method("is_battle_input_locked") or not bool(battle_view.call("is_battle_input_locked"))


func _save_capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		return false
	return image.save_png(path) == OK


func _should_keep_open() -> bool:
	if OS.get_environment("KEEP_GODOT_OPEN") == "1":
		return true
	for arg in OS.get_cmdline_args():
		if String(arg) == "--keep-open":
			return true
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "--keep-open":
			return true
	return false
