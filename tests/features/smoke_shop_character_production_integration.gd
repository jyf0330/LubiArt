extends SceneTree

const GAME_SCENE := preload("res://art/scenes/app/game.tscn")
const EXPECTED_CHARACTER_PATH := "res://art/images/route/shop/characters/generated/shop_character_033.png"

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var view := game.call("get_three_choice_view") as Control
	_expect(view != null, "formal Game shell exposes the authored three-choice view")
	if view == null:
		_finish()
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
	await process_frame
	await process_frame
	var route_portrait := _route_shop_portrait(view)
	_expect(route_portrait != null, "formal shop route card owns a portrait surface")
	_expect(_texture_path(route_portrait) == EXPECTED_CHARACTER_PATH, "formal shop route card consumes the mapped character texture")

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
	await process_frame
	await process_frame
	var shop_portrait := view.get_node_or_null("LegacyCodeShopView/SafeArea/MainColumn/ShopSummary/MerchantPortrait") as TextureRect
	_expect(shop_portrait != null and shop_portrait.visible, "formal shop panel exposes the active merchant portrait")
	_expect(_texture_path(shop_portrait) == EXPECTED_CHARACTER_PATH, "formal shop panel consumes the same mapped character texture")
	_finish()


func _route_shop_portrait(view: Control) -> TextureRect:
	for button_value in view.find_children("*", "BaseButton", true, false):
		var button := button_value as BaseButton
		if button == null or String(button.get_meta("route_kind", "")) != "shop":
			continue
		return button.get_parent().get_node_or_null("Portrait") as TextureRect
	return null


func _texture_path(rect: TextureRect) -> String:
	return rect.texture.resource_path if rect != null and rect.texture != null else ""


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("SMOKE_SHOP_CHARACTER_PRODUCTION_INTEGRATION_OK route=true shop=true")
	quit(0)
