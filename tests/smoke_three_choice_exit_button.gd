extends SceneTree

const GameScene := preload("res://art/scenes/app/game.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GameScene.instantiate() as Control
	root.add_child(game)
	await _settle()

	var view := game.call("get_three_choice_view") as Control
	var card_grid := view.get_node("MainBG/Containers/Middle/Middle_Three_Option/CardGrid") as Control
	var route_button := _first_shop_route_button(card_grid)
	_expect(route_button != null, "mock route exposes a shop choice")
	if route_button == null:
		quit(1)
		return
	var route_highlight := route_button.get_parent().get_node("RouteHighlight") as TextureRect
	var exit_button := view.get_node("RouteSharedUi/ExitButton") as TextureButton
	var party_button := view.get_node("RouteSharedUi/Party/Party_Container/Party_Slot") as TextureButton
	_expect(party_button.get_meta("pet_texture", null) is Texture2D, "route shared UI renders the session party sprite")
	_expect(view.get_node_or_null("MainBG/Containers/Middle/Middle_Shop") == null, "legacy Middle_Shop node tree is deleted")

	route_button.pressed.emit()
	await process_frame
	_expect(route_highlight.visible, "route selection keeps the selected card highlight visible")
	exit_button.pressed.emit()
	await _settle()
	_expect(String(game.call("get_active_feature_id")) == "shop", "accepted shop route mounts the dedicated ShopScene")
	var shop := game.call("get_active_feature_view") as Control
	_expect(shop != null and shop.name == "ShopScene", "FeatureHost owns the dedicated ShopScene")
	_expect(not view.visible, "ThreeChoiceScene is hidden while ShopScene is active")
	if shop == null:
		game.queue_free()
		await process_frame
		quit(1)
		return
	_expect(shop.get_node("Offers").get_child_count() == 5, "ShopScene exposes exactly five authored offer buttons")
	_expect(shop.get_node("RouteSharedUi") != null, "ShopScene reuses RouteSharedUi")

	var shop_exit := shop.get_node("RouteSharedUi/ExitButton") as TextureButton
	shop_exit.pressed.emit()
	await _settle()
	_expect(String(game.call("get_active_feature_id")) == "", "EXIT_SHOP releases the ShopScene feature")
	_expect(view.visible, "EXIT_SHOP restores ThreeChoiceScene")

	game.queue_free()
	await process_frame
	print("SMOKE_THREE_CHOICE_EXIT_BUTTON_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _settle() -> void:
	for _frame in range(36):
		await process_frame
	await create_timer(0.2).timeout


func _first_shop_route_button(card_grid: Control) -> TextureButton:
	for card in card_grid.get_children():
		var button := card.get_node_or_null("Three_Button") as TextureButton
		if button != null and String(button.get_meta("route_kind", "")) == "shop":
			return button
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_THREE_CHOICE_EXIT_BUTTON_FAIL: %s" % message)
