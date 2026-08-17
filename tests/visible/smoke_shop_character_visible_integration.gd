extends SceneTree

const GAME_SCENE := preload("res://art/scenes/app/game.tscn")
const EXPECTED_CHARACTER_PATH := "res://art/images/route/shop/characters/generated/shop_character_033.png"
const OUTPUT_DIR := "res://output/shop_character_production"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await _settle_seconds(0.8)
	var view := game.call("get_three_choice_view") as Control
	if view == null:
		_fail("Formal Game shell does not expose the authored three-choice view.")
		return

	var shop_option := {
		"id": "node_shop_skill_day1",
		"optionId": "node_1_1_node_shop_skill_day1",
		"nodeId": "node_shop_skill_day1",
		"title": "技能训练师",
		"kind": "shop",
		"sourceNode": {
			"nodeId": "node_shop_skill_day1",
			"name": "技能训练师",
			"shopPoolId": "day1_skill",
		},
	}
	game.state.phase = "route"
	game.state.route_options = [shop_option]
	game.call("render_current_view")
	await _settle_seconds(0.8)
	var route_portrait := _route_shop_portrait(view)
	if route_portrait == null or _texture_path(route_portrait) != EXPECTED_CHARACTER_PATH:
		_fail("Formal shop route card does not render the mapped character texture.")
		return
	if not _save_capture("route.png"):
		_fail("Could not save the formal shop route-card evidence.")
		return

	game.state.phase = "shop"
	game.state.active_stall = {
		"node_id": "node_shop_skill_day1",
		"name": "技能训练师",
		"pool_id": "day1_skill",
		"available": true,
		"slots": 8,
	}
	game.state.active_shop_pool = "day1_skill"
	game.state.shop_offers = []
	game.call("render_current_view")
	await _settle_seconds(0.8)
	var shop_portrait := view.get_node_or_null("LegacyCodeShopView/SafeArea/MainColumn/ShopSummary/MerchantPortrait") as TextureRect
	if shop_portrait == null or not shop_portrait.visible or _texture_path(shop_portrait) != EXPECTED_CHARACTER_PATH:
		_fail("Formal shop panel does not render the mapped active merchant texture.")
		return
	if not _save_capture("shop.png"):
		_fail("Could not save the formal shop-panel evidence.")
		return

	print("SMOKE_SHOP_CHARACTER_VISIBLE_INTEGRATION_OK route=true shop=true")
	quit(0)


func _route_shop_portrait(view: Control) -> TextureRect:
	for button_value in view.find_children("*", "BaseButton", true, false):
		var button := button_value as BaseButton
		if button == null or String(button.get_meta("route_kind", "")) != "shop":
			continue
		return button.get_parent().get_node_or_null("Portrait") as TextureRect
	return null


func _texture_path(rect: TextureRect) -> String:
	return rect.texture.resource_path if rect != null and rect.texture != null else ""


func _save_capture(file_name: String) -> bool:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return false
	var image := root.get_texture().get_image()
	return image != null and image.save_png(absolute_dir.path_join(file_name)) == OK


func _settle_seconds(seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(seconds * 1000.0):
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
