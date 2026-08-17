extends SceneTree


func _initialize() -> void:
	call_deferred("_show_shop")


func _show_shop() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	if packed == null:
		_fail("Could not load the formal Game Scene.")
		return
	var game := packed.instantiate()
	root.add_child(game)
	await create_timer(0.8).timeout
	if game.get("state") == null or not game.state.dispatch({"type": "ENTER_SHOP", "poolId": "night_base", "slots": 5}):
		_fail("Could not enter the stable night shop fixture.")
		return
	game.state.active_stall = {
		"id": "night_base",
		"pool_id": "night_base",
		"name": "夜市商人",
		"tags": ["通用", "夜市"],
		"slots": 5,
	}
	game.call("render_current_view")
	await create_timer(0.8).timeout
	var view := game.find_child("LegacyCodeShopView", true, false) as Control
	var offers := Array(game.state.snapshot().get("shop_offers", []))
	if view == null or not view.visible or offers.is_empty():
		_fail("The visible fixture did not show the code-built shop with offers.")
		return
	print("SHOW_LEGACY_CODE_SHOP_READY offers=%d" % offers.size())
	if DisplayServer.get_name() == "headless":
		quit(0)


func _fail(message: String) -> void:
	push_error("SHOW_LEGACY_CODE_SHOP_FAIL: %s" % message)
	quit(1)
