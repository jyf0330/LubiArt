extends SceneTree

const GameScene := preload("res://art/scenes/app/game.tscn")
const ShopScene := preload("res://art/scenes/shop/shop_scene.tscn")
const EXPECTED_PRICE_TAG_CENTERS := [
	Vector2(583.0, 542.0),
	Vector2(904.5, 542.0),
	Vector2(1228.0, 542.0),
	Vector2(582.5, 792.0),
	Vector2(1227.0, 793.0),
]

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := GameScene.instantiate() as Control
	root.add_child(game)
	await _settle(24)
	_expect(String(game.call("get_active_feature_id")) == "", "application starts at the real route entry")
	var session := game.call("get_game_session") as RefCounted
	var route_snapshot := Dictionary(session.call("current_snapshot"))
	var shop_option := {}
	for value in Array(route_snapshot.get("route_options", [])):
		var option := Dictionary(value)
		if String(option.get("kind", option.get("nodeType", ""))) == "shop":
			shop_option = option
			break
	_expect(not shop_option.is_empty(), "route Snapshot provides an exported shop option")
	if shop_option.is_empty():
		quit(1)
		return
	var option_id := String(shop_option.get("id", shop_option.get("optionId", shop_option.get("option_id", ""))))
	session.call("submit_command", {"type": "CHOOSE_ROUTE", "option_id": option_id, "kind": "shop"})
	game.call("render_current_view")
	await _settle(24)
	var shop := game.call("get_active_feature_view") as Control
	_expect(String(game.call("get_active_feature_id")) == "shop", "route Snapshot mounts ShopScene through FeatureHost")
	_expect(shop != null, "dedicated ShopScene is available")
	if shop == null:
		quit(1)
		return

	var offers := shop.get_node("Offers") as Control
	_expect(offers.get_child_count() == 5, "ShopScene keeps exactly five authored goods")
	for index in range(offers.get_child_count()):
		var child := offers.get_child(index)
		var button := child as Button
		_expect(button != null, "%s is a Button leaf" % child.name)
		if button == null:
			continue
		_expect(button.get_child_count() == 0, "%s stays a single leaf node" % button.name)
		_expect(button.flat, "%s does not draw the default black button frame" % button.name)
		_expect(button.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s centers its pet independently from the authored price tag" % button.name)
		_expect(button.has_meta("price_tag_center"), "%s authors its own price-tag center" % button.name)
		_expect(button.get_meta("price_tag_center") == EXPECTED_PRICE_TAG_CENTERS[index], "%s preserves its measured price-tag center" % button.name)
		_expect(float(button.get_meta("price_tag_width", 0.0)) == 30.0, "%s constrains its price inside the red label" % button.name)
		_expect(button.text.is_empty(), "%s does not rely on Button icon/text layout for price placement" % button.name)
		_expect(String(button.get_meta("price", "")).strip_edges() != "", "%s keeps a dynamic price for the authored tag" % button.name)
		_expect(button.icon != null, "%s resolves an existing pet image" % button.name)
	var rock_offer := offers.get_node("Offer03") as Button
	_expect(rock_offer.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER, "Offer03 centers only the landscape rock pet art vertically")
	_expect(rock_offer.position.y == 375.0 and rock_offer.size.y == 190.0, "Offer03 keeps the authored grounded rock-pet hit rect")
	_expect(shop.get_node("RefreshCurtain").z_index > offers.z_index, "refresh curtain draws above goods and prices")
	_expect(shop.get_node("RouteSharedUi").z_index > shop.get_node("RefreshCurtain").z_index, "shared controls remain above refresh curtain")
	_expect(shop.get_node("RouteSharedUi") != null, "shop reuses the shared bag/party/coin/exit component")
	_expect((shop.get_node("RouteSharedUi") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "shared full-screen root cannot intercept shop or route pointer input")
	_expect(shop.get_node_or_null("BazaarInfoPanel") == null, "shop has no duplicate legacy information panel")
	var party_container := shop.get_node("RouteSharedUi/Party/Party_Container") as Control
	for index in range(4):
		var party_button := party_container.get_node("Party_Slot" if index == 0 else "Party_Slot%d" % (index + 1)) as TextureButton
		_expect(party_button.texture_normal != null, "%s keeps an authored hit texture for real hover and press input" % party_button.name)
	_assert_shop_manifest_and_images()
	var first_offer := offers.get_child(0) as Button
	var first_offer_id := String(Dictionary(first_offer.get_meta("offer", {})).get("id", ""))
	var coins_before_buy := int(session.call("current_snapshot").get("coins", 0))
	var roster_before_buy := Array(session.call("current_snapshot").get("roster", [])).size()
	first_offer.button_down.emit()
	await _release_at(shop, first_offer.get_global_rect().get_center())
	await _settle(8)
	var bought_snapshot := Dictionary(session.call("current_snapshot"))
	_expect(not _offer_ids(bought_snapshot).has(first_offer_id), "offer release path removes the purchased offer from Snapshot")
	_expect(Array(bought_snapshot.get("shop_offers", [])).size() == 5, "offer release keeps all five authored shelf positions")
	_expect(Dictionary(Array(bought_snapshot.get("shop_offers", []))[0]).is_empty(), "offer release leaves its original shelf position empty")
	_expect((offers.get_node("Offer01") as Button).icon == null, "purchased first shelf position is visibly empty")
	_expect((offers.get_node("Offer02") as Button).icon != null, "following shelf position is not compacted forward")
	_expect(Array(bought_snapshot.get("roster", [])).size() == roster_before_buy + 1, "offer release path adds the purchased pet to the roster")
	_expect(int(bought_snapshot.get("coins", 0)) < coins_before_buy, "offer release path pays the exported offer price")

	var bag_button := shop.get_node("RouteSharedUi/Bags/Bag_Button") as TextureButton
	bag_button.pressed.emit()
	await process_frame
	_expect(shop.get_node("RouteSharedUi/Middle_Bag").visible, "shared bag opens inside ShopScene")
	_expect(shop.get_node("RouteSharedUi/BagOverlayMask").visible, "shared bag mask opens inside ShopScene")
	var bag_slots := shop.get_node("RouteSharedUi/Middle_Bag/Slots") as GridContainer
	_expect(bag_slots.get_child_count() == 8, "RouteSharedUi owns exactly eight runtime bag leaves")
	var shared_bag_shader: Shader = null
	var bag_materials: Array[ShaderMaterial] = []
	for child in bag_slots.get_children():
		var slot := child as TextureButton
		_expect(slot != null and slot.texture_normal != null and slot.material is ShaderMaterial, "every shared bag leaf keeps transparent hit and fitted-render surfaces")
		if slot != null and slot.material is ShaderMaterial:
			var slot_material := slot.material as ShaderMaterial
			_expect(not bag_materials.has(slot_material), "each bag leaf keeps independent texture parameters")
			bag_materials.append(slot_material)
			var slot_shader := slot_material.shader
			if shared_bag_shader == null:
				shared_bag_shader = slot_shader
			else:
				_expect(slot_shader == shared_bag_shader, "all bag leaves share one compiled shader resource")
	bag_button.pressed.emit()
	await process_frame
	_expect(not shop.get_node("RouteSharedUi/Middle_Bag").visible, "shared bag closes inside ShopScene")

	var refresh := shop.get_node("RefreshButton") as TextureButton
	var offer_ids_before_roll := _visible_offer_ids(offers)
	refresh.pressed.emit()
	await _settle(10)
	_expect(shop.get_node("RefreshCurtain").visible, "refresh briefly shows the authored curtain")
	_expect(String((offers.get_node("Offer01") as Button).get_meta("price", "")).is_empty(), "the purchased shelf position keeps no stale price while the curtain is down")
	await create_timer(0.55).timeout
	_expect(not shop.get_node("RefreshCurtain").visible, "refresh curtain clears after the short transition")
	_expect(_visible_offer_ids(offers) != offer_ids_before_roll, "refresh replaces the visible offer set after the curtain rises")
	for child in offers.get_children():
		_expect(String((child as Button).get_meta("price", "")).strip_edges() != "", "refreshed offer restores the authored price inside its tag")

	game.queue_free()
	await process_frame
	await _assert_direct_shop_preview()
	await _assert_unanswered_refresh_recovers()
	print("SMOKE_SHOP_SCENE_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _assert_direct_shop_preview() -> void:
	var shop := ShopScene.instantiate() as Control
	root.add_child(shop)
	await _settle(16)
	_expect(bool(shop.call("is_standalone_art_preview")), "direct ShopScene enters its non-authoritative interactive preview")
	_expect(shop.command_requested.get_connections().is_empty(), "direct ShopScene does not create or require a Session owner")
	var offers := shop.get_node("Offers") as Control
	_expect(_visible_offer_ids(offers).size() == 5, "direct ShopScene assigns five draggable offer records")
	var party := shop.get_node("RouteSharedUi/Party/Party_Container") as Control
	for index in range(4):
		var button := party.get_node("Party_Slot" if index == 0 else "Party_Slot%d" % (index + 1)) as TextureButton
		var material := button.material as ShaderMaterial
		var occupied := index == 0
		_expect(bool(material.get_shader_parameter("source_enabled")) == occupied, "direct party slot %d source visibility matches occupancy" % (index + 1))
		_expect(bool(material.get_shader_parameter("shadow_enabled")) == occupied, "direct party slot %d shadow visibility matches occupancy" % (index + 1))
	var first_party := party.get_node("Party_Slot") as TextureButton
	var second_party := party.get_node("Party_Slot2") as TextureButton
	first_party.button_down.emit()
	await _release_at(shop, second_party.get_global_rect().get_center())
	await _settle(6)
	_expect(bool((second_party.material as ShaderMaterial).get_shader_parameter("source_enabled")), "direct party drag moves the pet to the target slot")
	_expect(not bool((first_party.material as ShaderMaterial).get_shader_parameter("shadow_enabled")), "direct party drag removes the old slot shadow")
	var before_roll := _visible_offer_ids(offers)
	(shop.get_node("RefreshButton") as TextureButton).pressed.emit()
	await create_timer(0.55).timeout
	_expect(not (shop.get_node("RefreshCurtain") as TextureRect).visible, "direct refresh always raises the curtain")
	_expect(not (shop.get_node("RefreshButton") as TextureButton).disabled, "direct refresh restores the bell")
	_expect(not _has_overlap(_visible_offer_ids(offers), before_roll), "direct refresh replaces the visible preview offers")
	shop.queue_free()
	await process_frame


func _assert_unanswered_refresh_recovers() -> void:
	var shop := ShopScene.instantiate() as Control
	shop.command_requested.connect(_ignore_command_request)
	root.add_child(shop)
	await _settle(12)
	var refresh := shop.get_node("RefreshButton") as TextureButton
	var curtain := shop.get_node("RefreshCurtain") as TextureRect
	refresh.pressed.emit()
	await _settle(12)
	_expect(curtain.visible and refresh.disabled, "unanswered refresh still enters the authored curtain transition")
	await _settle(360)
	_expect(not curtain.visible and not refresh.disabled, "unanswered refresh times out and always restores the curtain and bell")
	shop.call("complete_command_request", 1, {"accepted": true, "snapshot": {"phase": "shop"}})
	await _settle(2)
	_expect(not curtain.visible and not refresh.disabled, "late refresh responses cannot re-open a completed transition")
	shop.queue_free()
	await process_frame


func _ignore_command_request(_command: Dictionary, _request_id: int) -> void:
	pass


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await process_frame


func _release_at(shop: Control, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	shop.call("_input", event)
	await process_frame


func _offer_ids(snapshot: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for value in Array(snapshot.get("shop_offers", [])):
		result.append(String(Dictionary(value).get("id", "")))
	return result


func _visible_offer_ids(offers: Control) -> PackedStringArray:
	var result := PackedStringArray()
	for child in offers.get_children():
		result.append(String(Dictionary((child as Button).get_meta("offer", {})).get("id", "")))
	return result


func _has_overlap(left: PackedStringArray, right: PackedStringArray) -> bool:
	for value in left:
		if right.has(value):
			return true
	return false


func _assert_shop_manifest_and_images() -> void:
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/manifests/shop/psd_layer_manifest.json"))
	_expect(manifest_value is Dictionary, "shop PSD manifest parses")
	if not (manifest_value is Dictionary):
		return
	var manifest := Dictionary(manifest_value)
	_expect(int(Dictionary(manifest.get("policy", {})).get("offer_count", 0)) == 5, "manifest fixes five goods")
	_expect(String(Dictionary(manifest.get("policy", {})).get("hidden_source_layers", "")) == "IGNORE", "manifest ignores every hidden source layer")
	_expect(Array(manifest.get("dynamic_fields", [])).size() == 5, "manifest maps five dynamic offer fields")
	_expect(not JSON.stringify(manifest).contains("/Users/"), "manifest has no local absolute path dependency")
	var background := (load("res://art/images/shop/screen_shop_godot_v1/background.png") as Texture2D).get_image()
	var facade := (load("res://art/images/shop/screen_shop_godot_v1/shop_facade.png") as Texture2D).get_image()
	var facade_source := Image.load_from_file(ProjectSettings.globalize_path("res://art/images/shop/screen_shop_godot_v1/shop_facade.png"))
	var merchant_image := (load("res://art/images/shop/screen_shop_godot_v1/merchant_default.png") as Texture2D).get_image()
	_expect(background.get_size() == Vector2i(1920, 1080), "shop background keeps the 1920x1080 canvas")
	_expect(facade.get_size() == Vector2i(1766, 988), "shop facade crop matches manifest")
	_expect(facade_source != null and _alpha_masks_match(facade, facade_source), "Godot imported facade alpha mask matches the current formal PNG instead of a stale cut-door cache")
	var import_text := FileAccess.get_file_as_string("res://art/images/shop/screen_shop_godot_v1/shop_facade.png.import")
	var import_path := _first_import_path(import_text)
	_expect(not import_path.is_empty() and FileAccess.file_exists(import_path), "formal facade import artifact exists")
	if not import_path.is_empty() and FileAccess.file_exists(import_path):
		_expect(FileAccess.get_modified_time(import_path) >= FileAccess.get_modified_time("res://art/images/shop/screen_shop_godot_v1/shop_facade.png"), "formal facade import cache is not older than its PNG source")
	_expect(ResourceUID.get_id_path(ResourceUID.text_to_id("uid://cgxbplupbjcl1")) == "res://art/images/shop/screen_shop_godot_v1/shop_facade.png", "ShopFacade UID resolves to the formal full-door PNG")
	_expect(merchant_image.get_size() == Vector2i(177, 202), "merchant fallback matches authored rect")
	_expect(merchant_image.get_pixel(0, 0).a == 0.0, "merchant fallback has true transparent corners")
	_expect(facade.get_pixel(1469, 524).a > 0.0, "facade preserves the PSD exit-door base under the shared ExitButton")


func _first_import_path(import_text: String) -> String:
	for line in import_text.split("\n"):
		if line.begins_with("path=\""):
			return line.trim_prefix("path=\"").trim_suffix("\"")
	return ""


func _alpha_masks_match(imported: Image, source: Image) -> bool:
	if imported == null or source == null or imported.get_size() != source.get_size():
		return false
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var imported_pixel := imported.get_pixel(x, y)
			var source_pixel := source.get_pixel(x, y)
			if not is_equal_approx(imported_pixel.a, source_pixel.a):
				return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_SHOP_SCENE_FAIL: %s" % message)
