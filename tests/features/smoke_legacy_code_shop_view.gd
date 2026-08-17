extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	if packed == null:
		_fail("Could not load the formal Game Scene.")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await create_timer(0.8).timeout
	if game.get("state") == null:
		_fail("Legacy shop smoke requires the formal state fixture.")
		return
	if not game.state.dispatch({"type": "ENTER_SHOP", "poolId": "night_base", "slots": 5}):
		_fail("Could not enter shop through the public core command.")
		return
	game.call("render_current_view")
	await create_timer(0.8).timeout

	var view := game.find_child("LegacyCodeShopView", true, false) as Control
	if view == null or not view.visible:
		_fail("The code-built legacy shop should cover the unfinished authored shop in shop phase.")
		return
	if not _label_contains(view, "元素背包史 · 商店") or not _label_contains(view, "本次可购买"):
		_fail("The legacy shop should restore the old title and shop summary hierarchy.")
		return
	if _command_button_count(view, "BUY_OFFER") < 1:
		_fail("The legacy shop should project at least one public BUY_OFFER action.")
		return
	if not _assert_presentation_only_source():
		return

	var freeze_button := _find_command_button(view, "FREEZE_OFFER")
	if freeze_button == null:
		_fail("The legacy shop should expose the old offer lock action.")
		return
	var freeze_offer_id := String(Dictionary(freeze_button.get_meta("command", {})).get("offer_id", ""))
	freeze_button.emit_signal("pressed")
	await create_timer(0.5).timeout
	if not _offer_flag(game.state.snapshot(), freeze_offer_id, "frozen"):
		_fail("FREEZE_OFFER from the code-built view should update the authoritative snapshot.")
		return

	view = game.find_child("LegacyCodeShopView", true, false) as Control
	var unfreeze_button := _find_command_button(view, "UNFREEZE_OFFER")
	if unfreeze_button == null:
		_fail("A frozen offer should re-render with UNFREEZE_OFFER intent.")
		return
	unfreeze_button.emit_signal("pressed")
	await create_timer(0.5).timeout
	if _offer_flag(game.state.snapshot(), freeze_offer_id, "frozen"):
		_fail("UNFREEZE_OFFER from the code-built view should update the authoritative snapshot.")
		return

	view = game.find_child("LegacyCodeShopView", true, false) as Control
	var roll_button := _find_command_button(view, "ROLL_SHOP")
	var before_roll_log_count := Array(game.state.snapshot().get("log_lines", [])).size()
	if roll_button == null or roll_button.disabled:
		_fail("The legacy shop should expose an available public ROLL_SHOP action.")
		return
	roll_button.emit_signal("pressed")
	await create_timer(0.6).timeout
	if Array(game.state.snapshot().get("log_lines", [])).size() <= before_roll_log_count:
		_fail("ROLL_SHOP from the code-built view should reach the authoritative session.")
		return

	view = game.find_child("LegacyCodeShopView", true, false) as Control
	var buy_button := _find_command_button(view, "BUY_OFFER")
	if buy_button == null:
		_fail("The refreshed legacy shop should still expose BUY_OFFER.")
		return
	var before_buy: Dictionary = game.state.snapshot()
	var before_coins := int(before_buy.get("coins", 0))
	var before_roster_count := Array(before_buy.get("roster", [])).size()
	buy_button.emit_signal("pressed")
	await create_timer(0.6).timeout
	var after_buy: Dictionary = game.state.snapshot()
	if int(after_buy.get("coins", 0)) >= before_coins and Array(after_buy.get("roster", [])).size() <= before_roster_count:
		_fail("BUY_OFFER from the code-built view should change the authoritative shop outcome.")
		return

	view = game.find_child("LegacyCodeShopView", true, false) as Control
	var exit_button := _find_command_button(view, "EXIT_SHOP")
	if exit_button == null:
		_fail("The legacy shop should expose EXIT_SHOP.")
		return
	exit_button.emit_signal("pressed")
	await create_timer(1.0).timeout
	if String(game.state.snapshot().get("phase", "")) != "route" or view.visible:
		_fail("EXIT_SHOP should return to the LubiArt three-choice route and hide the fallback view.")
		return

	print("SMOKE_LEGACY_CODE_SHOP_VIEW_OK freeze+unfreeze+roll+buy+exit")
	quit(0)


func _find_command_button(parent: Node, command_type: String) -> BaseButton:
	if parent == null:
		return null
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null or button.disabled:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) == command_type:
			return button
	return null


func _command_button_count(parent: Node, command_type: String) -> int:
	var count := 0
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		if String(Dictionary(button.get_meta("command", {})).get("type", "")) == command_type:
			count += 1
	return count


func _offer_flag(snapshot: Dictionary, offer_id: String, field: String) -> bool:
	for value in Array(snapshot.get("shop_offers", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var offer := Dictionary(value)
		if String(offer.get("id", "")) == offer_id:
			return bool(offer.get(field, false))
	return false


func _label_contains(parent: Node, expected: String) -> bool:
	for node in parent.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text.contains(expected):
			return true
	return false


func _assert_presentation_only_source() -> bool:
	var source := FileAccess.get_file_as_string("res://core_ui/scripts/shop/views/legacy_code_shop_view.gd")
	for forbidden in ["YsbzsState", ".dispatch(", "GameSession", "core/state"]:
		if source.contains(forbidden):
			_fail("Legacy shop view must remain presentation-only; found %s." % forbidden)
			return false
	return true


func _fail(message: String) -> void:
	push_error("SMOKE_LEGACY_CODE_SHOP_VIEW_FAIL: %s" % message)
	quit(1)
