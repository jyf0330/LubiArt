extends "res://tests/helpers/singleplayer_smoke_suite.gd"

const BATTLE_ICON_PATH := "res://art/images/debug/artist_ui/three_fight_logo.png"


func _run() -> void:
	var packed := load("res://art/scenes/app/game.tscn") as PackedScene
	_expect(packed != null, "formal Game Scene loads")
	if packed == null:
		_finish("SMOKE_ROUTE_SHOP_EVENT_BATTLE_PROGRESSION_FAIL")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.8).timeout

	var state = game.get("state")
	var three_choice := game.call("get_three_choice_view") as Control
	_expect(state != null, "formal Game Scene exposes authority")
	_expect(three_choice != null, "formal Game Scene exposes three-choice presentation")
	if state == null or three_choice == null:
		_finish("SMOKE_ROUTE_SHOP_EVENT_BATTLE_PROGRESSION_FAIL")
		return

	var first_shop := _find_button_with_command(game, "CHOOSE_ROUTE", "shop")
	_expect(first_shop != null, "first ordinary route exposes a shop choice")
	if first_shop == null:
		_finish("SMOKE_ROUTE_SHOP_EVENT_BATTLE_PROGRESSION_FAIL")
		return
	first_shop.emit_signal("pressed")
	_expect(await _wait_for_phase_and_view(state, three_choice, "shop", &"shop"), "first shop choice enters shop")
	var first_exit := _find_button_with_command(game, "EXIT_SHOP")
	_expect(first_exit != null, "first shop exposes exit")
	if first_exit != null:
		first_exit.emit_signal("pressed")
	_expect(await _wait_for_phase_and_view(state, three_choice, "route", &"three_option"), "first shop exit returns to route")
	_expect(int(state.get("node_index")) == 2, "first ordinary route advances authority to node 2")
	_expect(_visible_route_option_ids(game) == _authority_route_option_ids(state), "node 2 visible cards use current authority option IDs")

	var second_shop := _find_button_with_command(game, "CHOOSE_ROUTE", "shop")
	_expect(second_shop != null, "second ordinary route exposes a current shop choice")
	if second_shop == null:
		_finish("SMOKE_ROUTE_SHOP_EVENT_BATTLE_PROGRESSION_FAIL")
		return
	second_shop.emit_signal("pressed")
	_expect(await _wait_for_phase_and_view(state, three_choice, "shop", &"shop"), "second current shop choice enters shop")
	var second_exit := _find_button_with_command(game, "EXIT_SHOP")
	_expect(second_exit != null, "second shop exposes exit")
	if second_exit != null:
		second_exit.emit_signal("pressed")
	_expect(await _wait_for_phase_and_view(state, three_choice, "route", &"three_option"), "second shop exit returns to route")
	_expect(int(state.get("node_index")) == 3, "second ordinary route advances authority to fixed battle node 3")

	var battle_buttons := _visible_route_buttons(game, "battle")
	_expect(battle_buttons.size() == 3, "node 3 exposes exactly three battle choices")
	_expect(_visible_route_option_ids(game) == _authority_route_option_ids(state), "node 3 visible battle cards use current authority option IDs")
	for button in battle_buttons:
		var icon := button.get_parent().get_node_or_null("KindIcon") as TextureRect
		_expect(icon != null and icon.texture != null and icon.texture.resource_path == BATTLE_ICON_PATH, "each node 3 battle card uses the red battle icon")
		_expect(icon != null and icon.size.is_equal_approx(Vector2(40, 62)), "each node 3 battle icon keeps the authored 40x62 card rect")
		_expect(icon != null and icon.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "each node 3 battle icon scales inside the authored rect")
	if battle_buttons.is_empty():
		_finish("SMOKE_ROUTE_SHOP_EVENT_BATTLE_PROGRESSION_FAIL")
		return

	battle_buttons[0].emit_signal("pressed")
	_expect(await _wait_for_phase(state, "battle", 600), "node 3 battle choice enters authoritative battle phase")
	var battle_scene := game.find_child("BattleArtScene", true, false) as Control
	_expect(battle_scene != null and battle_scene.visible, "BattleArtScene is mounted and visible after the battle choice")
	_finish("SMOKE_ROUTE_SHOP_EVENT_BATTLE_PROGRESSION_OK nodes=1,2,3 battle_entries=3")


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
			return true
		await process_frame
	return false


func _wait_for_phase(state, phase: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		if String(state.get("phase")) == phase:
			await process_frame
			await process_frame
			return true
		await process_frame
	return false
