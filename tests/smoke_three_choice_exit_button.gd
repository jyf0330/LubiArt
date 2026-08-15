extends SceneTree

const GameScene := preload("res://art/scenes/app/game.tscn")

var _failed := false
var _view: Control = null
var _commands: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GameScene.instantiate() as Control
	root.add_child(game)
	await _settle()

	var view := game.call("get_three_choice_view") as Control
	_view = view
	var game_callback := Callable(game, "_on_command_requested")
	if view.command_requested.is_connected(game_callback):
		view.command_requested.disconnect(game_callback)
	view.command_requested.connect(_complete_command_request)
	var card_grid := view.get_node("MainBG/Containers/Middle/Middle_Three_Option/CardGrid") as Control
	var route_button := _first_shop_route_button(card_grid)
	_expect(route_button != null, "mock route exposes a shop choice")
	if route_button == null:
		quit(1)
		return
	var route_highlight := route_button.get_parent().get_node("RouteHighlight") as TextureRect
	var exit_button := view.get_node("MainBG/Containers/ExitButton") as TextureButton
	var party_button := view.get_node("MainBG/Containers/Party/Party_Container/Party_Slot") as TextureButton
	_expect(party_button.get_meta("pet_texture", null) is Texture2D, "default application entry renders the session party sprite")
	_expect(not exit_button.disabled, "route exit keeps its authored hover state before a choice is selected")

	route_button.pressed.emit()
	await process_frame
	_expect(not exit_button.disabled, "route selection keeps the authored exit door interactive")
	_expect(route_highlight.visible, "route selection keeps the selected card highlight visible")
	_expect(_commands.is_empty(), "route card click does not submit immediately")

	exit_button.pressed.emit()
	await _settle()
	_expect(_commands.size() == 1 and String(_commands[0].get("type", "")) == "CHOOSE_ROUTE", "route exit submits the selected CHOOSE_ROUTE command")
	_expect(String(_commands[0].get("kind", "")) == "shop", "route exit preserves the selected route kind")
	_expect((view.get_node("MainBG/Containers/Middle/Middle_Shop") as Control).visible, "accepted route choice renders the shop view")

	exit_button.pressed.emit()
	await _settle()
	_expect(_commands.size() == 2 and String(_commands[1].get("type", "")) == "EXIT_SHOP", "shop exit submits EXIT_SHOP through the page root")
	_expect((view.get_node("MainBG/Containers/Middle/Middle_Three_Option") as Control).visible, "accepted shop exit returns to the route view")

	game.queue_free()
	await process_frame
	print("SMOKE_THREE_CHOICE_EXIT_BUTTON_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _settle() -> void:
	for _frame in range(24):
		await process_frame
	await create_timer(0.35).timeout


func _first_shop_route_button(card_grid: Control) -> TextureButton:
	for card in card_grid.get_children():
		var button := card.get_node_or_null("Three_Button") as TextureButton
		if button != null and String(button.get_meta("route_kind", "")) == "shop":
			return button
	return null


func _complete_command_request(command: Dictionary, request_id: int) -> void:
	_commands.append(command.duplicate(true))
	var snapshot := Dictionary(_view.get("_snapshot")).duplicate(true)
	match String(command.get("type", "")):
		"CHOOSE_ROUTE":
			snapshot["phase"] = "shop"
		"EXIT_SHOP":
			snapshot["phase"] = "route"
	_view.call("complete_command_request", request_id, {
		"accepted": true,
		"command": String(command.get("type", "")),
		"snapshot": snapshot,
	})


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_THREE_CHOICE_EXIT_BUTTON_FAIL: %s" % message)
