extends "res://tests/helpers/singleplayer_smoke_suite.gd"

const MAX_VISIBLE_RESPONSE_MS := 150


func _run() -> void:
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	_expect(packed != null, "formal Game Scene loads")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.8).timeout

	var state = scene.get("state")
	_expect(state != null, "formal Game Scene exposes its runtime state")
	var three_choice_view := scene.call("get_three_choice_view") as Control
	_expect(three_choice_view != null, "formal Game Scene exposes its three-choice presentation")
	var shop_button := _find_button_with_command(scene, "CHOOSE_ROUTE", "shop")
	_expect(shop_button != null, "formal three-choice screen exposes the shop route button")
	var shop_ms := await _press_and_wait(shop_button, state, three_choice_view, "shop", &"shop", -1)
	_expect(shop_ms <= MAX_VISIBLE_RESPONSE_MS, "visible shop route responds within %dms (actual %dms)" % [MAX_VISIBLE_RESPONSE_MS, shop_ms])
	# Phase changes before the presentation coordinator finishes rendering the
	# returned Snapshot. Let that request fully settle before issuing the next
	# real button input so the test measures commands rather than overlap policy.
	await create_timer(0.4).timeout
	var before_rejected_version := int(state.get("state_version"))
	var rejected_started := Time.get_ticks_msec()
	var rejected_purchase := bool(await three_choice_view.call("_submit_core_command", {
		"type": "BUY_OFFER",
		"offer_id": "visible_latency_missing_offer",
	}))
	var rejected_ms := Time.get_ticks_msec() - rejected_started
	_expect(not rejected_purchase, "rejected purchase remains rejected through the immediate-feedback path")
	_expect(rejected_ms <= MAX_VISIBLE_RESPONSE_MS, "visible rejected purchase responds within %dms (actual %dms)" % [MAX_VISIBLE_RESPONSE_MS, rejected_ms])
	_expect(int(state.get("state_version")) == before_rejected_version, "rejected purchase does not advance authoritative state")
	_expect(not _tree_has_text(scene, "处理中：购买"), "rejected purchase clears provisional pending feedback")

	var before_buy_version := int(state.get("state_version"))
	var buy_button := _find_connected_command_button(scene, "BUY_OFFER")
	_expect(buy_button != null, "formal shop exposes a connected purchase button")
	var buy_ms := await _press_and_wait(buy_button, state, three_choice_view, "shop", &"shop", before_buy_version)
	_expect(buy_ms <= MAX_VISIBLE_RESPONSE_MS, "visible shop purchase responds within %dms (actual %dms)" % [MAX_VISIBLE_RESPONSE_MS, buy_ms])
	await create_timer(0.4).timeout

	var before_roll_version := int(state.get("state_version"))
	var roll_button := _find_button_with_command(scene, "ROLL_SHOP")
	_expect(roll_button != null, "formal shop exposes the refresh button")
	var roll_ms := await _press_and_wait(roll_button, state, three_choice_view, "shop", &"shop", before_roll_version)
	_expect(roll_ms <= MAX_VISIBLE_RESPONSE_MS, "visible shop refresh responds within %dms (actual %dms)" % [MAX_VISIBLE_RESPONSE_MS, roll_ms])
	await create_timer(0.4).timeout

	var exit_button := _find_button_with_command(scene, "EXIT_SHOP")
	_expect(exit_button != null, "formal shop exposes the exit button")
	var exit_ms := await _press_and_wait(exit_button, state, three_choice_view, "route", &"three_option", -1)
	_expect(exit_ms <= MAX_VISIBLE_RESPONSE_MS, "visible shop exit responds within %dms (actual %dms)" % [MAX_VISIBLE_RESPONSE_MS, exit_ms])
	_finish("VISIBLE_THREE_CHOICE_COMMAND_LATENCY_OK shop_ms=%d reject_ms=%d buy_ms=%d roll_ms=%d exit_ms=%d" % [shop_ms, rejected_ms, buy_ms, roll_ms, exit_ms])


func _find_connected_command_button(root_node: Node, command_type: String) -> BaseButton:
	for node in root_node.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null or button.disabled or button.pressed.get_connections().is_empty():
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) == command_type:
			return button
	return null


func _press_and_wait(
	button: BaseButton,
	state,
	three_choice_view: Control,
	phase: String,
	view: StringName,
	previous_version: int
) -> int:
	if button == null or state == null:
		return MAX_VISIBLE_RESPONSE_MS + 1
	var started := Time.get_ticks_msec()
	button.emit_signal("pressed")
	var cursor := button.get_tree().get_first_node_in_group(&"game_cursor")
	var cursor_state := StringName(cursor.call("debug_state")) if cursor != null and cursor.has_method("debug_state") else &""
	if cursor_state == &"loading" and String(Dictionary(button.get_meta("command", {})).get("type", "")) == "BUY_OFFER":
		_expect(_tree_has_text(button.get_tree().root, "处理中：购买"), "purchase press shows neutral pending feedback before authority confirmation")
	while Time.get_ticks_msec() - started <= MAX_VISIBLE_RESPONSE_MS:
		var phase_matches := String(state.get("phase")) == phase
		var version_matches := previous_version < 0 or int(state.get("state_version")) > previous_version
		var view_matches := three_choice_view != null and StringName(three_choice_view.get("_current_view")) == view
		if phase_matches and version_matches and view_matches:
			return Time.get_ticks_msec() - started
		await process_frame
	return Time.get_ticks_msec() - started


func _tree_has_text(root_node: Node, fragment: String) -> bool:
	for node in root_node.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text.contains(fragment):
			return true
	return false
