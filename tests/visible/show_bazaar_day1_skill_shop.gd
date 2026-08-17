extends SceneTree


func _initialize() -> void:
	call_deferred("_show_skill_shop")


func _show_skill_shop() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	if packed == null:
		push_error("Could not load the single-player scene.")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await create_timer(0.8).timeout
	var middle := scene
	var view := middle.call("get_three_choice_view") as Control
	if middle == null or not middle.state.dispatch({"type": "ENTER_SHOP", "poolId": "day1_skill", "slots": 5, "seedContext": "visible-day1-skill-shop"}):
		push_error("Could not enter the day-one skill shop.")
		quit(1)
		return
	middle.state.active_stall = {
		"id": "day1_skill",
		"pool_id": "day1_skill",
		"name": "技能训练师",
		"tags": ["技能", "永久成长"],
		"slots": 5,
		"status": "正式",
	}
	middle.call("render_current_view")
	await create_timer(0.5).timeout
	var offers := Array(middle.state.snapshot().get("shop_offers", []))
	if offers.size() != 5:
		push_error("Visible skill shop expected five offers, got %d." % offers.size())
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		var coins_before: int = int(middle.state.coins)
		view.call("_on_shop_button_down", 0)
		await create_timer(0.2).timeout
		if int(middle.state.coins) >= coins_before or not bool(Dictionary(Array(middle.state.shop_offers)[0]).get("sold", false)):
			push_error("Headless visible-shop fixture could not click-purchase a skill item.")
			quit(1)
			return
		print("SHOW_BAZAAR_DAY1_SKILL_SHOP_CLICK_OK")
		quit(0)
		return
	print("SHOW_BAZAAR_DAY1_SKILL_SHOP_READY offers=5")
