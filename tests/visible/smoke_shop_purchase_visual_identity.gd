extends "res://tests/helpers/singleplayer_smoke_suite.gd"

const OUTPUT_PATH := "res://output/validation/shop-purchase-identity-20260817/after/route_after_purchase.png"


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	_expect(packed != null, "formal Game Scene loads")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.8).timeout

	var state = scene.get("state")
	var three_choice_view := scene.call("get_three_choice_view") as Control
	var shop_button := _find_button_with_command(scene, "CHOOSE_ROUTE", "shop")
	_expect(state != null and three_choice_view != null and shop_button != null, "shop player flow is available")
	shop_button.emit_signal("pressed")
	await _wait_for_phase_and_idle(state, three_choice_view, "shop")

	var buy_button := _find_connected_command_button(scene, "BUY_OFFER")
	_expect(buy_button != null, "shop exposes a connected purchase button")
	var offered := Dictionary(buy_button.get_meta("offer", {}))
	var offered_pet_id := String(offered.get("pet_id", ""))
	var offered_name := String(offered.get("name", ""))
	var offered_texture_path := String((buy_button as Button).icon.resource_path) if (buy_button as Button).icon != null else ""
	var before_roster_count := Array(state.get("roster")).size()
	var before_version := int(state.get("state_version"))
	buy_button.emit_signal("pressed")
	await _wait_for_version_and_idle(state, three_choice_view, before_version)

	var purchased := _roster_record_for_pet_id(Array(state.get("roster")), offered_pet_id)
	var party_portraits := scene.find_children("PartyPet_*", "TextureRect", true, false)
	var party_texture_paths: Array[String] = []
	for value in party_portraits:
		var portrait := value as TextureRect
		if portrait != null and portrait.texture != null:
			party_texture_paths.append(String(portrait.texture.resource_path))
	print("SHOP_IDENTITY_DIAGNOSTIC offer=%s pet_id=%s offer_texture=%s roster_before=%d roster_after=%d purchased_id=%s purchased_pet_id=%s party_count=%d party_textures=%s" % [
		offered_name,
		offered_pet_id,
		offered_texture_path,
		before_roster_count,
		Array(state.get("roster")).size(),
		String(purchased.get("id", "")),
		String(purchased.get("pet_id", "")),
		party_portraits.size(),
		str(party_texture_paths),
	])
	_expect(not purchased.is_empty(), "purchased pet identity exists in authoritative roster")
	_expect(Array(state.get("roster")).size() == before_roster_count + 1, "distinct purchased pet appends to roster")
	_expect(party_portraits.size() == _active_roster_count(Array(state.get("roster"))), "shop party shelf renders every active roster pet")
	_expect(party_texture_paths.has(offered_texture_path), "shop party shelf uses the purchased offer texture")

	var exit_button := _find_connected_command_button(scene, "EXIT_SHOP")
	_expect(exit_button != null, "shop exposes a connected exit button")
	var exit_version := int(state.get("state_version"))
	if exit_button != null:
		exit_button.emit_signal("pressed")
		await _wait_for_version_and_idle(state, three_choice_view, exit_version)
	_expect(String(state.get("phase")) == "route", "shop exit returns to the three-choice route")
	var route_party_texture_paths := _three_choice_party_texture_paths(three_choice_view)
	print("ROUTE_PARTY_IDENTITY_DIAGNOSTIC purchased_texture=%s route_party_textures=%s" % [
		offered_texture_path,
		str(route_party_texture_paths),
	])
	_expect(route_party_texture_paths.size() == _active_roster_count(Array(state.get("roster"))), "three-choice party renders every active roster pet after shop exit")
	_expect(route_party_texture_paths.has(offered_texture_path), "three-choice party keeps the purchased offer texture after shop exit")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty() and image.save_png(OUTPUT_PATH) == OK, "1920x1080 route-after-purchase evidence is captured")
	_finish("SMOKE_SHOP_PURCHASE_VISUAL_IDENTITY_OK")


func _find_connected_command_button(root_node: Node, command_type: String) -> BaseButton:
	for node in root_node.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null or button.disabled or button.pressed.get_connections().is_empty():
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) == command_type:
			return button
	return null


func _wait_for_phase_and_idle(state, view: Control, expected_phase: String) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		if String(state.get("phase")) == expected_phase and not bool(view.call("is_presentation_busy")):
			return
		await process_frame


func _wait_for_version_and_idle(state, view: Control, previous_version: int) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		if int(state.get("state_version")) > previous_version and not bool(view.call("is_presentation_busy")):
			await process_frame
			return
		await process_frame


func _roster_record_for_pet_id(roster: Array, pet_id: String) -> Dictionary:
	for value in roster:
		if typeof(value) == TYPE_DICTIONARY and String(Dictionary(value).get("pet_id", Dictionary(value).get("id", ""))) == pet_id:
			return Dictionary(value)
	return {}


func _active_roster_count(roster: Array) -> int:
	var count := 0
	for value in roster:
		if typeof(value) == TYPE_DICTIONARY and bool(Dictionary(value).get("active", true)):
			count += 1
	return count


func _three_choice_party_texture_paths(three_choice_view: Control) -> Array[String]:
	var result: Array[String] = []
	var party_container := three_choice_view.get_node_or_null("MainBG/Containers/Party/Party_Container")
	if party_container == null:
		return result
	for value in party_container.find_children("Party_Slot*", "TextureButton", true, false):
		var button := value as TextureButton
		var texture := button.get_meta("pet_texture") as Texture2D if button != null and button.has_meta("pet_texture") else null
		if texture != null:
			result.append(String(texture.resource_path))
	return result
