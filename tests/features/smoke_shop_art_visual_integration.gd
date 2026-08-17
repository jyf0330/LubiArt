extends SceneTree

const ShopViewScript := preload("res://core_ui/scripts/shop/views/legacy_code_shop_view.gd")
const BellNormal := preload("res://art/images/shop/screen_shop_godot_v1/refresh_bell_normal.png")
const BellHover := preload("res://art/images/shop/screen_shop_godot_v1/refresh_bell_hover.png")
const WidePartyPetTexture := preload("res://art/images/shared/pets/generated/pal_002.png")
const SquarePartyPetTexture := preload("res://art/images/shared/pets/generated/pal_009.png")
const PartyShadowTexture := preload("res://art/images/shop/screen_shop_godot_v1/shared_party_shadow.png")
const BagOpenTexture := preload("res://art/images/shop/screen_shop_godot_v1/shared_bag_open.png")
const BagInventoryTexture := preload("res://art/images/shop/screen_shop_godot_v1/shared_bag_inventory.png")
const BagItemHighlightTexture := preload("res://art/images/shop/screen_shop_godot_v1/shared_bag_item_highlight.png")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var view := ShopViewScript.new() as Control
	root.add_child(view)
	await process_frame
	view.configure(Callable(self, "_resolve_pet_texture"), Callable())
	view.render_snapshot(_ten_offer_snapshot())
	await process_frame

	var backdrop := view.find_child("ShopArtBackdrop", true, false) as Control
	if backdrop == null:
		_fail("The formal shop must own the reusable art backdrop.")
		return
	for layer_name in ["ForestBackground", "ShopFacade", "ReadabilityVeil", "TopReadabilityBand", "RefreshCurtain"]:
		if backdrop.find_child(layer_name, true, false) == null:
			_fail("Missing formal shop art layer: %s" % layer_name)
			return
	var background := backdrop.find_child("ForestBackground", true, false) as TextureRect
	var facade := backdrop.find_child("ShopFacade", true, false) as TextureRect
	if background == null or background.texture == null or facade == null or facade.texture == null:
		_fail("Background and facade textures must be loadable Texture2D resources.")
		return
	if not _rect_matches(facade.get_global_rect(), Rect2(31.0, 86.0, 1766.0, 988.0)):
		_fail("The formal facade must align to the authored 1920x1080 storefront bounds.")
		return
	var veil := backdrop.find_child("ReadabilityVeil", true, false) as ColorRect
	if veil == null or veil.color.a > 0.01:
		_fail("The old full-screen dark veil must not obscure the delivered storefront.")
		return

	var refresh_button := view.find_child("RollShopButton", true, false) as TextureButton
	if refresh_button == null or refresh_button.texture_normal != BellNormal:
		_fail("The formal refresh action must use the delivered normal bell art at its authored size.")
		return
	if refresh_button.texture_hover != BellHover or refresh_button.texture_focused != BellHover:
		_fail("The refresh action must switch to the delivered hover bell art.")
		return
	refresh_button.emit_signal("pressed")
	var refresh_curtain := backdrop.find_child("RefreshCurtain", true, false) as TextureRect
	if refresh_curtain == null or not refresh_curtain.visible:
		_fail("The delivered refresh curtain must be driven by the formal refresh intent.")
		return
	if not refresh_button.disabled:
		_fail("The formal refresh action must reject repeat input while the curtain is revealing.")
		return
	if not refresh_curtain.scale.is_equal_approx(Vector2.ONE):
		_fail("The refresh reveal must preserve the authored curtain rectangle throughout the animation.")
		return
	await create_timer(0.4).timeout
	if refresh_curtain.visible or refresh_button.disabled:
		_fail("The formal refresh action must restore availability after the curtain reveal completes.")
		return

	var bag_button := view.find_child("ShopBagButton", true, false) as TextureButton
	var bag_overlay := view.find_child("ShopBagOverlay", true, false) as Control
	var bag_overlay_mask := view.find_child("BagOverlayMask", true, false) as ColorRect
	var bag_inventory := view.find_child("BagInventoryArt", true, false) as TextureRect
	if bag_button == null or bag_overlay == null or bag_overlay_mask == null or bag_inventory == null:
		_fail("The shared shop rail must expose the authored bag overlay composition.")
		return
	bag_button.emit_signal("pressed")
	if not bag_overlay.visible or bag_button.texture_normal != BagOpenTexture:
		_fail("The shared bag action must open the authored chest and inventory panel.")
		return
	if not _rect_matches(bag_overlay_mask.get_global_rect(), Rect2(0.0, 0.0, 1920.0, 1060.0)):
		_fail("The formal bag veil must preserve the authored 20px clear bottom edge.")
		return
	if bag_inventory.texture != BagInventoryTexture or not _rect_matches(bag_inventory.get_global_rect(), Rect2(502.0, 379.0, 818.0, 439.0)):
		_fail("The authored bag inventory must keep its synchronized 1920x1080 projection.")
		return
	view.visible = false
	view.visible = true
	if bag_overlay.visible or bool(view.find_child("ShopSharedRail", true, false).call("is_bag_open")):
		_fail("A reused formal shop view must close its local bag overlay on every new visible visit.")
		return
	var empty_bag_interaction := view.find_child("BagSlotButton_0", true, false) as TextureButton
	var bag_highlight := view.find_child("BagSlotHoverHighlight", true, false) as TextureRect
	if empty_bag_interaction == null or bag_highlight == null or empty_bag_interaction.has_meta("bag_record"):
		_fail("Every authored empty bag slot must expose an independent presentation surface.")
		return
	if empty_bag_interaction.mouse_filter != Control.MOUSE_FILTER_STOP or empty_bag_interaction.focus_mode != Control.FOCUS_NONE:
		_fail("Empty bag slots must stop pointer click-through without adding inert keyboard focus targets.")
		return
	empty_bag_interaction.mouse_entered.emit()
	if not bag_highlight.visible or not _rect_matches(bag_highlight.get_global_rect(), Rect2(541.0, 409.0, 183.0, 177.0)):
		_fail("Hovering an empty formal bag slot must align the returned authored highlight.")
		return
	empty_bag_interaction.mouse_exited.emit()
	if bag_highlight.visible:
		_fail("Leaving an empty formal bag slot must clear its authored highlight.")
		return
	bag_button.emit_signal("pressed")
	if not bag_overlay.visible:
		_fail("The shared bag action must still open after a shop-entry lifecycle reset.")
		return
	bag_button.emit_signal("pressed")
	if bag_overlay.visible:
		_fail("A repeated shared bag action must close the authored inventory panel.")
		return
	var bag_snapshot := _ten_offer_snapshot()
	var bag_roster := Array(bag_snapshot.get("roster", [])).duplicate(true)
	bag_roster.append({"id": "pal_009", "active": false})
	bag_snapshot["roster"] = bag_roster
	view.render_snapshot(bag_snapshot)
	var bag_pet := view.find_child("BagPet_0", true, false) as TextureRect
	if bag_pet == null or bag_pet.texture != SquarePartyPetTexture:
		_fail("The authored bag slots must project inactive public roster records through the formal texture resolver.")
		return
	if not _rect_matches(bag_pet.get_global_rect(), Rect2(570.0, 438.0, 116.0, 116.0)):
		_fail("The first formal bag pet must fit independently inside the first authored inventory slot.")
		return
	var bag_interaction := view.find_child("BagSlotButton_0", true, false) as TextureButton
	if bag_interaction == null or bag_highlight == null or bag_highlight.texture != BagItemHighlightTexture:
		_fail("Occupied formal bag slots must expose the returned authored hover highlight independently.")
		return
	bag_button.emit_signal("pressed")
	bag_interaction.mouse_entered.emit()
	if not bag_highlight.visible or not _rect_matches(bag_highlight.get_global_rect(), Rect2(541.0, 409.0, 183.0, 177.0)):
		_fail("Hovering the first formal bag pet must align the authored highlight to the first inventory slot.")
		return
	bag_interaction.mouse_exited.emit()
	if bag_highlight.visible:
		_fail("Leaving a formal bag pet must hide the authored slot highlight.")
		return
	bag_button.emit_signal("pressed")
	if bag_highlight.visible:
		_fail("Closing the formal bag must clear the authored slot highlight.")
		return
	var party_interaction := view.find_child("PartySlotButton_0", true, false) as TextureButton
	var hover_party_shadow := view.find_child("PartyShadow_0", true, false) as TextureRect
	if party_interaction == null or hover_party_shadow == null:
		_fail("Occupied formal party slots must expose an independent semantic hover surface.")
		return
	party_interaction.mouse_entered.emit()
	if hover_party_shadow.self_modulate.r <= 1.0 or hover_party_shadow.self_modulate.a <= 1.0:
		_fail("Hovering an occupied formal party slot must brighten the authored ground shadow.")
		return
	party_interaction.mouse_exited.emit()
	if hover_party_shadow.self_modulate != Color.WHITE:
		_fail("Leaving a formal party slot must restore the authored ground shadow.")
		return

	var merchant_portrait := view.find_child("MerchantPortrait", true, false) as TextureRect
	if merchant_portrait == null or not merchant_portrait.visible or merchant_portrait.texture == null:
		_fail("The delivered default merchant must cover unmapped presentation fixtures.")
		return
	if not _rect_matches(merchant_portrait.get_global_rect(), Rect2(813.0, 580.0, 177.0, 202.0)):
		_fail("The formal merchant must align to the authored counter position.")
		return
	if _command_button_count(view, "BUY_OFFER") != 10:
		_fail("The visual integration must preserve a dynamic 10-offer projection.")
		return
	var shelf := view.find_child("ShopShelfLayout", true, false)
	if shelf == null or int(shelf.call("page_count")) != 2:
		_fail("Ten formal offers must remain available through two independent five-slot shelf pages.")
		return
	var first_offer := view.find_child("BuyOfferButton_00", true, false) as Button
	if first_offer == null or not _rect_matches(first_offer.get_global_rect(), Rect2(498.0, 360.0, 160.0, 190.0)):
		_fail("The first formal offer must align to the first authored shelf aperture.")
		return
	if first_offer.get_theme_constant("icon_max_width") != 152 or first_offer.vertical_icon_alignment != VERTICAL_ALIGNMENT_TOP:
		_fail("Formal offer art must keep the authored 152px top-aligned projection.")
		return
	var disabled_offer_style := first_offer.get_theme_stylebox("disabled") as StyleBoxFlat
	if disabled_offer_style == null or not is_zero_approx(disabled_offer_style.bg_color.a):
		_fail("A sold formal offer must remain disabled without covering the authored empty aperture.")
		return
	var third_offer := view.find_child("BuyOfferButton_02", true, false) as Button
	if third_offer == null or not _rect_matches(third_offer.get_global_rect(), Rect2(1148.0, 375.0, 160.0, 190.0)):
		_fail("The third formal offer must preserve the full authored aperture under the sloped roof.")
		return
	if third_offer.vertical_icon_alignment != VERTICAL_ALIGNMENT_CENTER:
		_fail("The third formal offer must center wide pet art without moving square pet art.")
		return
	var second_price := view.find_child("ShelfOffer_01", true, false).find_child("PriceLabel", true, false) as Label
	if second_price == null or second_price.get_theme_font_size("font_size") != 18 or not is_equal_approx(second_price.anchor_top, 0.90):
		_fail("Formal price text must use the authored compact lower plaque treatment.")
		return
	if second_price.has_theme_color_override("font_shadow_color") or second_price.has_theme_constant_override("shadow_offset_x") or second_price.has_theme_constant_override("shadow_offset_y"):
		_fail("Formal price text must not add a shadow absent from the authored price glyph.")
		return
	if not second_price.get_theme_color("font_color").is_equal_approx(Color(0.99, 0.84, 0.36, 1.0)):
		_fail("Formal price text must preserve the authored floating-point gold color.")
		return
	var third_price := view.find_child("ShelfOffer_02", true, false).find_child("PriceLabel", true, false) as Label
	if third_price == null or not _rect_matches(third_price.get_global_rect(), Rect2(1176.8, 532.0, 102.4, 19.0)):
		_fail("The sloped third aperture must keep its price on the authored plaque independently of pet art.")
		return
	var first_lock := view.find_child("FreezeOfferButton_00", true, false) as Button
	if first_lock == null or first_lock.visible:
		_fail("Unlocked shelf controls must stay out of the authored aperture until interaction.")
		return
	var hover_style := first_offer.get_theme_stylebox("hover") as StyleBoxFlat
	var focus_style := first_offer.get_theme_stylebox("focus") as StyleBoxFlat
	var pressed_style := first_offer.get_theme_stylebox("pressed") as StyleBoxFlat
	if hover_style == null or hover_style.bg_color.a > 0.0 or hover_style.border_width_left != 0:
		_fail("Mouse hover must not add a formal-only frame over the authored shelf aperture.")
		return
	if pressed_style == null or pressed_style.bg_color.a > 0.0 or pressed_style.border_width_left != 0:
		_fail("Mouse press must preserve the authored frameless shelf aperture until purchase release.")
		return
	if focus_style == null or focus_style.border_width_left != 3 or focus_style.border_color.a <= 0.0:
		_fail("Keyboard focus must retain a visible accessibility frame independently of mouse hover.")
		return
	var original_offer_icon := first_offer.icon
	var original_offer_tooltip := first_offer.tooltip_text
	if original_offer_tooltip == "" or first_offer.accessibility_name != original_offer_tooltip:
		_fail("Formal offer details must expose both a visual Tooltip and an independent accessibility label.")
		return
	first_offer.emit_signal("button_down")
	var hold_feedback := view.find_child("OfferHoldFeedback", true, false) as TextureRect
	if first_offer.icon != null or hold_feedback == null or hold_feedback.texture != original_offer_icon:
		_fail("Holding a formal offer must replace the full-size icon with independent visual feedback.")
		return
	if not hold_feedback.size.is_equal_approx(Vector2(126.0, 124.0)) or not is_equal_approx(hold_feedback.self_modulate.a, 0.82):
		_fail("Offer hold feedback must preserve the authored 126x124 translucent treatment.")
		return
	if first_offer.tooltip_text != "" or first_offer.accessibility_name != original_offer_tooltip:
		_fail("Holding a formal offer must hide its visual Tooltip without dropping the accessibility label.")
		return
	first_offer.emit_signal("button_up")
	if first_offer.icon != original_offer_icon or first_offer.tooltip_text != "":
		_fail("Cancelling an offer hold outside must restore the source icon without reviving the old visual Tooltip.")
		return
	first_offer.emit_signal("mouse_entered")
	if first_offer.tooltip_text != original_offer_tooltip or first_offer.accessibility_name != original_offer_tooltip:
		_fail("Re-entering a cancelled offer must restore its Tooltip while preserving the accessibility label.")
		return
	first_offer.emit_signal("button_down")
	if first_lock.visible:
		_fail("An active mouse hold must hide the contextual lock action immediately.")
		return
	first_offer.emit_signal("focus_entered")
	first_offer.emit_signal("mouse_exited")
	if first_lock.visible:
		_fail("An active mouse hold must not reveal the keyboard-only lock action after the pointer leaves.")
		return
	first_offer.emit_signal("button_up")
	first_offer.emit_signal("focus_exited")
	first_offer.emit_signal("mouse_entered")
	if not first_offer.get_parent_control().scale.is_equal_approx(Vector2.ONE):
		_fail("Hover and keyboard focus must not move or resize authored offer art.")
		return
	if not first_lock.visible:
		_fail("Hovering an offer must reveal its independent lock action.")
		return
	first_offer.emit_signal("mouse_exited")
	if first_lock.visible:
		_fail("The unlocked shelf control must clear after hover.")
		return
	first_offer.emit_signal("focus_entered")
	first_offer.emit_signal("mouse_entered")
	first_offer.emit_signal("mouse_exited")
	if not first_lock.visible:
		_fail("Keyboard focus must keep the lock action visible after the pointer leaves.")
		return
	first_offer.emit_signal("focus_exited")
	if first_lock.visible:
		_fail("The unlocked shelf control must clear after both hover and focus end.")
		return
	var shared_rail := view.find_child("ShopSharedRail", true, false) as Control
	var bag := view.find_child("ShopBagButton", true, false) as TextureButton
	var party_shelf := view.find_child("PartyShelfArt", true, false) as TextureRect
	var coin_panel := view.find_child("CoinPanelArt", true, false) as TextureRect
	var coin_label := view.find_child("CoinLabel", true, false) as Label
	var exit_button := view.find_child("ExitShopButton", true, false) as TextureButton
	var party_layer := view.find_child("PartyPetLayer", true, false) as Control
	if shared_rail == null or bag == null or party_shelf == null or coin_panel == null or coin_label == null or exit_button == null or party_layer == null:
		_fail("The formal shop must project the art-owned shared bottom rail resources.")
		return
	if not _rect_matches(bag.get_global_rect(), Rect2(313.0, 776.0, 236.0, 233.0)):
		_fail("The returned art-package chest must align to the shared bottom rail.")
		return
	if not _rect_matches(party_shelf.get_global_rect(), Rect2(519.0, 587.0, 882.0, 419.0)):
		_fail("The returned four-slot shelf must align to the authored bottom rail.")
		return
	if party_shelf.z_index <= bag.z_index or party_layer.z_index <= party_shelf.z_index:
		_fail("The party shelf must cover the chest edge while party art remains above the shelf.")
		return
	if not _rect_matches(coin_panel.get_global_rect(), Rect2(1303.0, 885.0, 165.0, 124.0)):
		_fail("The returned coin panel must align to the authored bottom rail.")
		return
	if coin_panel.z_index <= exit_button.z_index or coin_panel.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("The art-owned coin panel must cover the overlapping exit edge without stealing input.")
		return
	if coin_label.z_index <= coin_panel.z_index or coin_label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("The coin value must remain readable above the coin panel without stealing input.")
		return
	if coin_label.has_theme_color_override("font_shadow_color") or coin_label.has_theme_constant_override("shadow_offset_x") or coin_label.has_theme_constant_override("shadow_offset_y"):
		_fail("The coin value must preserve the art-package glyph without an added formal-only shadow.")
		return
	if not coin_label.get_theme_color("font_color").is_equal_approx(Color(0.99, 0.84, 0.36, 1.0)):
		_fail("The coin value must preserve the authored floating-point gold color.")
		return
	if not _rect_matches(exit_button.get_global_rect(), Rect2(1410.0, 490.0, 269.0, 472.0)):
		_fail("The returned exit overlay must align to the storefront sign.")
		return
	if exit_button.texture_click_mask == null:
		_fail("The exit overlay must use an art-aware click mask.")
		return
	if exit_button.texture_click_mask.get_bitv(Vector2i(2, 440)):
		_fail("The coin-covered exit edge must not remain clickable.")
		return
	if not exit_button.texture_click_mask.get_bitv(Vector2i(134, 236)):
		_fail("The visible center of the exit sign must remain clickable.")
		return
	if exit_button.tooltip_text != "离开商店" or exit_button.accessibility_name != "离开商店":
		_fail("The exit action must expose its formal label before interaction.")
		return
	exit_button.button_down.emit()
	if exit_button.tooltip_text != "" or exit_button.accessibility_name != "离开商店":
		_fail("Holding the exit action must hide its visual Tooltip without dropping the accessibility label.")
		return
	exit_button.button_up.emit()
	if exit_button.tooltip_text != "离开商店" or exit_button.accessibility_name != "离开商店":
		_fail("Releasing the exit action must restore its Tooltip and preserve the accessibility label.")
		return
	var wide_party_pet := view.find_child("PartyPet_0", true, false) as TextureRect
	var square_party_pet := view.find_child("PartyPet_1", true, false) as TextureRect
	var party_shadow := view.find_child("PartyShadow_0", true, false) as TextureRect
	if wide_party_pet == null or wide_party_pet.texture != WidePartyPetTexture:
		_fail("The shared rail must resolve the active party pet through the formal texture resolver.")
		return
	if square_party_pet == null or square_party_pet.texture != SquarePartyPetTexture:
		_fail("The shared rail must preserve each resolved party texture independently.")
		return
	if not _rect_matches(wide_party_pet.get_global_rect(), Rect2(565.0, 805.0, 154.0, 124.0)):
		_fail("Wide party art must fit the authored bounds without shrinking square sources.")
		return
	if not _rect_matches(square_party_pet.get_global_rect(), Rect2(757.0, 804.0, 126.0, 126.0)):
		_fail("Square party art must preserve the authored 126px projection.")
		return
	if party_shadow == null or party_shadow.texture != PartyShadowTexture or not party_shadow.self_modulate.is_equal_approx(Color.WHITE):
		_fail("Party shadows must render the baked art-owned shop texture without runtime retinting.")
		return
	var sold_snapshot := _ten_offer_snapshot()
	var sold_offers := Array(sold_snapshot.get("shop_offers", []))
	var sold_offer := Dictionary(sold_offers[0])
	sold_offer["sold"] = true
	sold_offers[0] = sold_offer
	sold_snapshot["shop_offers"] = sold_offers
	view.render_snapshot(sold_snapshot)
	await process_frame
	var sold_button := view.find_child("BuyOfferButton_00", true, false) as Button
	var sold_price := sold_button.get_parent().find_child("PriceLabel", true, false) as Label if sold_button != null else null
	if sold_button == null or not sold_button.disabled or sold_button.icon != null or sold_price == null or sold_price.text != "":
		_fail("A sold formal offer must preserve state while clearing the authored shelf aperture.")
		return
	if not _assert_independent_sources():
		return

	print("SMOKE_SHOP_ART_VISUAL_INTEGRATION_OK layers=5 facade=aligned veil=clear merchant=aligned shelf=5x2 shared_rail=chest+party+coin+exit bell=normal+hover curtain=refresh dynamic_offers=10 independent=true")
	quit(0)


func _ten_offer_snapshot() -> Dictionary:
	var offers: Array = []
	for index in range(10):
		offers.append({
			"id": "formal_offer_%02d" % index,
			"name": "正式商品 %02d" % (index + 1),
			"element": "火",
			"quality": "青铜",
			"item_type": "宠物",
			"role": "输出",
			"max_hp": 20 + index,
			"atk": 8 + index,
			"shield": 0,
			"shape": "形状01",
			"range": "直线/1格",
			"price": 2,
			"sold": false,
			"frozen": false,
		})
	return {
		"day": 1,
		"node_index": 1,
		"coins": 16,
		"hero_hp": 80,
		"ap": 3,
		"active_stall": {"id": "unmapped_fixture", "name": "正式测试商人"},
		"shop_offers": offers,
		"shop_refresh": {"free_rolls": 1, "next_refresh_cost": 0, "next_discount": 0},
		"inventory": {"active_count": 2, "max_active": 4, "bench_count": 0, "max_bench": 24},
		"roster": [{"id": "pal_002", "active": true}, {"id": "pal_009", "active": true}],
		"shop_events": [],
	}


func _resolve_pet_texture(record: Dictionary) -> Texture2D:
	return WidePartyPetTexture if String(record.get("id", "")) == "pal_002" else SquarePartyPetTexture


func _command_button_count(parent: Node, command_type: String) -> int:
	var count := 0
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button != null and String(Dictionary(button.get_meta("command", {})).get("type", "")) == command_type:
			count += 1
	return count


func _assert_independent_sources() -> bool:
	var backdrop_source := FileAccess.get_file_as_string("res://core_ui/scripts/shop/views/shop_art_backdrop.gd")
	for forbidden in [".dispatch(", "command_requested", "_snapshot", "GameSession", "YsbzsState"]:
		if backdrop_source.contains(forbidden):
			_fail("ShopArtBackdrop must remain presentation-only; found %s." % forbidden)
			return false
	var view_source := FileAccess.get_file_as_string("res://core_ui/scripts/shop/views/legacy_code_shop_view.gd")
	for forbidden in ["godot-battle-ui-mock", "res://art/scenes/shop/ShopScene", "fixed_offer_count"]:
		if view_source.contains(forbidden):
			_fail("Formal shop integration must not copy the Mock implementation; found %s." % forbidden)
			return false
	var shelf_source := FileAccess.get_file_as_string("res://core_ui/scripts/shop/views/shop_shelf_layout.gd")
	for forbidden in ["godot-battle-ui-mock", ".dispatch(", "GameSession", "YsbzsState", "core/state"]:
		if shelf_source.contains(forbidden):
			_fail("ShopShelfLayout must remain a presentation-only public projection; found %s." % forbidden)
			return false
	var shared_rail_source := FileAccess.get_file_as_string("res://core_ui/scripts/shop/views/shop_shared_rail.gd")
	for forbidden in ["godot-battle-ui-mock", ".dispatch(", "command_requested", "GameSession", "YsbzsState", "core/state"]:
		if shared_rail_source.contains(forbidden):
			_fail("ShopSharedRail must remain presentation-only and intent-driven; found %s." % forbidden)
			return false
	return true


func _rect_matches(actual: Rect2, expected: Rect2, tolerance := 1.5) -> bool:
	return actual.position.distance_to(expected.position) <= tolerance and actual.size.distance_to(expected.size) <= tolerance


func _fail(message: String) -> void:
	push_error("SMOKE_SHOP_ART_VISUAL_INTEGRATION_FAIL: %s" % message)
	quit(1)
