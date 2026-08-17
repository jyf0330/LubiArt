extends SceneTree

const CAPTURE_SIZE := Vector2i(480, 270)
const RMSE_TOLERANCE := 1.5
const CHANGED_PIXEL_RATIO_TOLERANCE := 0.005
const CHANGED_PIXEL_CHANNEL_THRESHOLD := 0.08
const BATTLE_IDLE_TIMEOUT := 120.0

var _failed := false
var _output_dir := ""
var _baseline_dir := ""
var _update_baselines := false
var _captures: Array[Dictionary] = []
var _scene: Node = null
var _middle: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("QA_UI_REGRESSION_FAIL: visual regression needs a real display driver")
		quit(1)
		return
	_output_dir = _argument_value("--qa-output=", OS.get_user_data_dir())
	_update_baselines = _has_argument("--qa-update-baselines")
	var platform := _platform_key()
	_baseline_dir = ProjectSettings.globalize_path("res://qa/visual_baselines/%s" % platform)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	DirAccess.make_dir_recursive_absolute(_baseline_dir)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_move_to_foreground()
	root.size = Vector2i(1920, 1080)

	var packed := load("res://art/scenes/app/game.tscn") as PackedScene
	_expect(packed != null, "formal game scene can be loaded")
	if packed == null:
		_finish()
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	await _settle(1.5)
	_middle = _scene
	_expect(_middle != null and _middle.get("state") != null, "formal Game exposes the session-backed authority boundary")
	if _middle == null or _middle.get("state") == null:
		_finish()
		return

	await _capture("01_route_ready")
	_expect(await _enter_battle_with_real_clicks(), "real UI clicks reach formal battle")
	if String(_snapshot().get("phase", "")) != "battle":
		_finish()
		return
	await _capture("02_battle_enter")

	var auto_button := _scene.find_child("AutoArrangeButton", true, false) as BaseButton
	var auto_version := int(_snapshot().get("stateVersion", -1))
	_expect(await _activate_formal_button(auto_button), "formal AutoArrangeButton emits its semantic action")
	_expect(await _wait_for_state_version_after(auto_version, 30.0), "auto-position changes the authoritative state version")
	_expect(await _wait_for_controller_idle(30.0), "auto-position presentation settles")
	await _capture("03_auto_position")

	var begin_button := _scene.find_child("AllOutButton", true, false) as BaseButton
	if begin_button == null:
		begin_button = _scene.find_child("BeginTurnButton", true, false) as BaseButton
	var previous_round := int(_snapshot().get("battle_round", 0))
	_expect(await _activate_formal_button(begin_button), "formal all-out battle button emits its semantic action")
	_expect(await _wait_for_round_change(previous_round, BATTLE_IDLE_TIMEOUT), "one visible combat round completes")
	_expect(await _wait_for_controller_idle(BATTLE_IDLE_TIMEOUT), "round presentation settles before capture")
	await _capture("04_round_complete")

	if String(_snapshot().get("phase", "")) == "battle":
		_expect(_middle.state.dispatch({"type": "RUN_BATTLE"}), "public command can fast-forward remaining rounds for settlement rendering")
		_middle.call("render_current_view")
		_expect(await _wait_for_phase("battle_end", 180.0), "fast-forward reaches settlement")
		_expect(await _wait_for_controller_idle(180.0), "settlement presentation becomes idle")
	await _capture("05_settlement")
	_finish()


func _enter_battle_with_real_clicks() -> bool:
	for _step in range(12):
		var phase := String(_snapshot().get("phase", ""))
		if phase == "battle":
			return true
		var button: BaseButton = null
		match phase:
			"route":
				button = _find_command_button("CHOOSE_ROUTE", "battle")
				if button == null:
					button = _first_route_progress_button()
			"shop":
				button = _find_any_command_button(["EXIT_SHOP", "BACK_TO_ROUTE"])
				if button == null:
					button = _scene.find_child("Shop_BackButton", true, false) as BaseButton
			"reward":
				button = _find_command_button("PICK_REWARD", "")
			_:
				return false
		if button == null:
			return false
		var previous_version := int(_snapshot().get("stateVersion", -1))
		var previous_phase := phase
		var progressed := false
		for attempt in range(3):
			print("QA_UI_CLICK phase=%s button=%s attempt=%d" % [phase, button.name, attempt + 1])
			if not await _click_button(button):
				return false
			if await _wait_for_progress(previous_phase, previous_version, 4.0):
				progressed = true
				break
		if not progressed:
			print("QA_UI_CLICK_STALLED phase=%s version=%d" % [String(_snapshot().get("phase", "")), int(_snapshot().get("stateVersion", -1))])
			return false
		await _settle(0.8)
	return String(_snapshot().get("phase", "")) == "battle"


func _click_button(button: BaseButton) -> bool:
	if button == null or not button.is_inside_tree() or not button.is_visible_in_tree() or button.disabled:
		return false
	var center := button.get_global_rect().get_center()
	DisplayServer.window_move_to_foreground()
	button.grab_focus()
	Input.warp_mouse(center)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.global_position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle(0.15)
	return true


func _activate_formal_button(button: BaseButton) -> bool:
	if button == null or not button.is_inside_tree() or not button.is_visible_in_tree() or button.disabled:
		return false
	button.emit_signal("pressed")
	await process_frame
	await _settle(0.15)
	return true


func _capture(name: String) -> void:
	await _settle(0.75)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s viewport capture is available" % name)
	if image == null or image.is_empty():
		return
	image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var actual_path := _output_dir.path_join(name + ".actual.png")
	_expect(image.save_png(actual_path) == OK, "%s actual capture can be saved" % name)
	var baseline_path := _baseline_dir.path_join(name + ".png")
	if _update_baselines:
		_expect(image.save_png(baseline_path) == OK, "%s baseline can be updated explicitly" % name)
		_captures.append({
			"name": name,
			"status": "baseline_updated",
			"actual": actual_path,
			"baseline": baseline_path
		})
		return
	if not FileAccess.file_exists(baseline_path):
		_failed = true
		push_error("QA_UI_REGRESSION_FAIL: missing baseline %s" % baseline_path)
		_captures.append({
			"name": name,
			"status": "missing_baseline",
			"actual": actual_path,
			"baseline": baseline_path
		})
		return
	var baseline := Image.load_from_file(baseline_path)
	if baseline == null or baseline.is_empty() or baseline.get_size() != image.get_size():
		_failed = true
		push_error("QA_UI_REGRESSION_FAIL: invalid baseline %s" % baseline_path)
		return
	var metrics := image.compute_image_metrics(baseline, true)
	var rmse := float(metrics.get("root_mean_squared", 1.0))
	var maximum := float(metrics.get("max", 1.0))
	var changed_pixel_ratio := _changed_pixel_ratio(image, baseline)
	var passed := rmse <= RMSE_TOLERANCE and changed_pixel_ratio <= CHANGED_PIXEL_RATIO_TOLERANCE
	var row := {
		"name": name,
		"status": "passed" if passed else "failed",
		"actual": actual_path,
		"baseline": baseline_path,
		"rootMeanSquared": rmse,
		"maxDelta": maximum,
		"changedPixelRatio": changed_pixel_ratio,
		"rmseTolerance": RMSE_TOLERANCE,
		"changedPixelRatioTolerance": CHANGED_PIXEL_RATIO_TOLERANCE,
		"changedPixelChannelThreshold": CHANGED_PIXEL_CHANNEL_THRESHOLD
	}
	if not passed:
		_failed = true
		var diff_path := _output_dir.path_join(name + ".diff.png")
		var diff := _difference_image(image, baseline)
		diff.save_png(diff_path)
		row["diff"] = diff_path
		push_error("QA_UI_REGRESSION_FAIL: %s rmse=%.5f changed=%.5f max=%.5f" % [name, rmse, changed_pixel_ratio, maximum])
	_captures.append(row)


func _changed_pixel_ratio(actual: Image, baseline: Image) -> float:
	var changed := 0
	var pixel_count := actual.get_width() * actual.get_height()
	for y in range(actual.get_height()):
		for x in range(actual.get_width()):
			var left := actual.get_pixel(x, y)
			var right := baseline.get_pixel(x, y)
			if maxf(abs(left.r - right.r), maxf(abs(left.g - right.g), abs(left.b - right.b))) > CHANGED_PIXEL_CHANNEL_THRESHOLD:
				changed += 1
	return float(changed) / float(maxi(1, pixel_count))


func _difference_image(actual: Image, baseline: Image) -> Image:
	var diff := Image.create_empty(actual.get_width(), actual.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(actual.get_height()):
		for x in range(actual.get_width()):
			var left := actual.get_pixel(x, y)
			var right := baseline.get_pixel(x, y)
			diff.set_pixel(x, y, Color(
				min(1.0, abs(left.r - right.r) * 4.0),
				min(1.0, abs(left.g - right.g) * 4.0),
				min(1.0, abs(left.b - right.b) * 4.0),
				1.0
			))
	return diff


func _snapshot() -> Dictionary:
	return Dictionary(_middle.state.snapshot()) if _middle != null and _middle.get("state") != null else {}


func _wait_for_state_version_after(previous: int, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if int(_snapshot().get("stateVersion", -1)) > previous:
			return true
		await _settle(0.1)
		elapsed += 0.1
	return int(_snapshot().get("stateVersion", -1)) > previous


func _wait_for_progress(previous_phase: String, previous_version: int, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		var snapshot := _snapshot()
		if String(snapshot.get("phase", "")) != previous_phase or int(snapshot.get("stateVersion", -1)) > previous_version:
			return true
		await _settle(0.1)
		elapsed += 0.1
	var final_snapshot := _snapshot()
	return String(final_snapshot.get("phase", "")) != previous_phase or int(final_snapshot.get("stateVersion", -1)) > previous_version


func _wait_for_round_change(previous: int, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		var snapshot := _snapshot()
		if String(snapshot.get("phase", "")) == "battle_end" or int(snapshot.get("battle_round", 0)) > previous:
			return true
		await _settle(0.2)
		elapsed += 0.2
	return false


func _wait_for_phase(expected: String, timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if String(_snapshot().get("phase", "")) == expected:
			return true
		await _settle(0.2)
		elapsed += 0.2
	return false


func _wait_for_controller_idle(timeout_seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout_seconds:
		if _controller_is_idle():
			return true
		await _settle(0.2)
		elapsed += 0.2
	return _controller_is_idle()


func _controller_is_idle() -> bool:
	if _middle == null:
		return false
	var route_view := _middle.call("get_three_choice_view") as Node if _middle.has_method("get_three_choice_view") else null
	if (route_view != null and bool(route_view.get("_is_transitioning"))) or bool(_middle.get("_visible_auto_battle_running")):
		return false
	var battle: Variant = _middle.call("get_feature_controller", &"battle") if _middle.has_method("get_feature_controller") else null
	return battle == null or not battle.has_method("is_battle_input_locked") or not bool(battle.call("is_battle_input_locked"))


func _find_command_button(command_type: String, kind: String) -> BaseButton:
	for node in _scene.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != command_type:
			continue
		if kind == "" or String(button.get_meta("route_kind", "")).to_lower() == kind:
			return button
	return null


func _find_any_command_button(command_types: Array[String]) -> BaseButton:
	for command_type in command_types:
		var button := _find_command_button(command_type, "")
		if button != null:
			return button
	return null


func _first_route_progress_button() -> BaseButton:
	var fallback: BaseButton = null
	for node in _scene.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != "CHOOSE_ROUTE":
			continue
		var kind := String(button.get_meta("route_kind", "")).to_lower()
		if kind == "battle":
			continue
		if kind == "reward":
			if fallback == null:
				fallback = button
			continue
		return button
	return fallback


func _settle(seconds: float) -> void:
	await create_timer(seconds).timeout


func _argument_value(prefix: String, fallback: String) -> String:
	for value in OS.get_cmdline_user_args():
		var argument := String(value)
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _has_argument(value: String) -> bool:
	return value in OS.get_cmdline_user_args()


func _platform_key() -> String:
	match OS.get_name().to_lower():
		"macos":
			return "macos"
		"windows":
			return "windows"
		_:
			return "linux"


func _write_report() -> bool:
	var report := {
		"schema": "ysbzs.qa.visual-regression.v1",
		"status": "failed" if _failed else "passed",
		"platform": _platform_key(),
		"updatedBaselines": _update_baselines,
		"captures": _captures
	}
	var file := FileAccess.open(_output_dir.path_join("visual_regression_results.json"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "\t", false))
	file.flush()
	return true


func _finish() -> void:
	_expect(_write_report(), "visual regression report can be written")
	if _failed:
		print("QA_UI_REGRESSION_FAIL output=%s" % _output_dir)
		quit(1)
		return
	print("QA_UI_REGRESSION_OK captures=%d output=%s" % [_captures.size(), _output_dir])
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("QA_UI_REGRESSION_FAIL: %s" % message)
