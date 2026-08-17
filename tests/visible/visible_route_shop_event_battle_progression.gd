extends "res://tests/helpers/singleplayer_smoke_suite.gd"

const OUTPUT_DIR := "res://output/validation/route-progression-20260817/after"
const BATTLE_ICON_PATH := "res://art/images/debug/artist_ui/three_fight_logo.png"

var _captures: Array[Dictionary] = []


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load("res://art/scenes/app/game.tscn") as PackedScene
	_expect(packed != null, "formal Game Scene loads")
	if packed == null:
		_finish_visible()
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.8).timeout
	var state = game.get("state")
	var three_choice := game.call("get_three_choice_view") as Control
	_expect(state != null and three_choice != null, "formal authority and three-choice presentation are available")
	if state == null or three_choice == null:
		_finish_visible()
		return

	await _capture("01_node1_route", "第一段普通路线三选", state)
	var first_shop := _find_button_with_command(game, "CHOOSE_ROUTE", "shop")
	_expect(first_shop != null, "node 1 exposes shop")
	if first_shop == null:
		_finish_visible()
		return
	first_shop.emit_signal("pressed")
	_expect(await _wait_for_phase_and_view(state, three_choice, "shop", &"shop"), "node 1 shop opens")
	await _capture("02_node1_shop", "第一段选择商店并进入", state)
	var first_exit := _find_button_with_command(game, "EXIT_SHOP")
	_expect(first_exit != null, "node 1 shop exposes exit")
	if first_exit != null:
		first_exit.emit_signal("pressed")
	_expect(await _wait_for_phase_and_view(state, three_choice, "route", &"three_option"), "node 1 shop exits to node 2")
	_expect(_visible_route_option_ids(game) == _authority_route_option_ids(state), "node 2 visible cards match authority")
	await _capture("03_node2_route_refreshed", "离店后刷新为第二段普通路线", state)

	var second_shop := _find_button_with_command(game, "CHOOSE_ROUTE", "shop")
	_expect(second_shop != null, "node 2 exposes current shop")
	if second_shop == null:
		_finish_visible()
		return
	second_shop.emit_signal("pressed")
	_expect(await _wait_for_phase_and_view(state, three_choice, "shop", &"shop"), "node 2 current shop opens")
	await _capture("04_node2_shop", "第二段选择当前商店并进入", state)
	var second_exit := _find_button_with_command(game, "EXIT_SHOP")
	_expect(second_exit != null, "node 2 shop exposes exit")
	if second_exit != null:
		second_exit.emit_signal("pressed")
	_expect(await _wait_for_phase_and_view(state, three_choice, "route", &"three_option"), "node 2 shop exits to fixed battle node 3")
	var battle_buttons := _visible_route_buttons(game, "battle")
	_expect(battle_buttons.size() == 3, "node 3 exposes three battle choices")
	_expect(_visible_route_option_ids(game) == _authority_route_option_ids(state), "node 3 battle IDs match authority")
	for button in battle_buttons:
		var icon := button.get_parent().get_node_or_null("KindIcon") as TextureRect
		_expect(icon != null and icon.texture != null and icon.texture.resource_path == BATTLE_ICON_PATH, "node 3 battle card uses red battle icon")
		_expect(icon != null and icon.size.is_equal_approx(Vector2(40, 62)), "node 3 battle icon keeps the authored 40x62 card rect")
		_expect(icon != null and icon.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "node 3 battle icon scales inside the authored rect")
	await _capture("05_node3_battle_three_red", "第三段显示三张红色小标战斗入口", state)
	if battle_buttons.is_empty():
		_finish_visible()
		return
	battle_buttons[0].emit_signal("pressed")
	_expect(await _wait_for_battle_scene(state, game), "battle choice enters and mounts BattleArtScene")
	await _capture("06_battle_scene", "选择第三段战斗后直接进入战斗场景", state)
	_finish_visible()


func _visible_route_buttons(game: Node, kind: String = "") -> Array[BaseButton]:
	var result: Array[BaseButton] = []
	for node in game.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != "CHOOSE_ROUTE":
			continue
		if kind != "" and String(button.get_meta("route_kind", "")) != kind:
			continue
		result.append(button)
	return result


func _visible_route_option_ids(game: Node) -> Array[String]:
	var result: Array[String] = []
	for button in _visible_route_buttons(game):
		var command := Dictionary(button.get_meta("command", {}))
		result.append(String(command.get("option_id", command.get("optionId", ""))))
	result.sort()
	return result


func _authority_route_option_ids(state) -> Array[String]:
	var result: Array[String] = []
	for value in Array(state.snapshot().get("route_options", [])):
		var option := Dictionary(value)
		result.append(String(option.get("id", option.get("optionId", ""))))
	result.sort()
	return result


func _wait_for_phase_and_view(state, three_choice: Control, phase: String, view: StringName, max_frames: int = 240) -> bool:
	for _frame in range(max_frames):
		if String(state.get("phase")) == phase and StringName(three_choice.get("_current_view")) == view:
			await process_frame
			await process_frame
			return true
		await process_frame
	return false


func _wait_for_battle_scene(state, game: Node, max_frames: int = 600) -> bool:
	for _frame in range(max_frames):
		var battle_scene := game.find_child("BattleArtScene", true, false) as Control
		if String(state.get("phase")) == "battle" and battle_scene != null and battle_scene.visible:
			await process_frame
			await process_frame
			return true
		await process_frame
	return false


func _capture(name: String, operation: String, state) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := OUTPUT_DIR.path_join(name + ".png")
	_expect(image != null and not image.is_empty() and image.save_png(path) == OK, "capture writes %s" % path)
	_captures.append({
		"name": name,
		"operation": operation,
		"file": path,
		"phase": String(state.get("phase")),
		"nodeIndex": int(state.get("node_index")),
		"stateVersion": int(state.get("state_version")),
	})


func _finish_visible() -> void:
	var report_path := OUTPUT_DIR.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"captures": _captures}, "  "))
	_finish("VISIBLE_ROUTE_SHOP_EVENT_BATTLE_PROGRESSION_OK captures=%d" % _captures.size())
