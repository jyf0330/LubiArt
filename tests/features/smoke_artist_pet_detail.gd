extends SceneTree

const ARTIST_UI_MAPPED_SEED := "artist-ui-mapped-1"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	if packed == null:
		push_error("Could not load ysbzs_singleplayer scene.")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await create_timer(0.8).timeout
	var middle := scene
	var view := middle.call("get_three_choice_view") as Control
	var party_grid := scene.find_child("Party_Container", true, false) as Control
	if middle == null or party_grid == null or party_grid.get_child_count() == 0:
		push_error("Artist pet detail smoke could not find the live UI targets.")
		quit(1)
		return
	middle.state.call("set_run_seed", ARTIST_UI_MAPPED_SEED)
	middle.call("render_current_view")
	await create_timer(0.2).timeout
	if not await _assert_shop_context_detail(middle, scene):
		quit(1)
		return
	var party_slot := party_grid.get_child(0) as Control
	if party_slot == null:
		push_error("Artist pet detail smoke party slot is not a Control.")
		quit(1)
		return
	var party_buttons := party_slot.find_children("*", "TextureButton", true, false)
	var party_button := party_slot as TextureButton if party_slot is TextureButton else (party_buttons[0] as TextureButton if not party_buttons.is_empty() else null)
	if party_button == null:
		push_error("Artist pet detail smoke could not find the authored party button.")
		quit(1)
		return
	party_button.emit_signal("mouse_entered")
	await process_frame
	var panel := scene.find_child("ArtistPetDetailPanel", true, false)
	if panel == null or not bool(panel.get("visible")):
		push_error("Artist pet detail panel did not open from the live party slot.")
		quit(1)
		return
	if not panel.has_method("get_attack_shape_cell_count") or int(panel.call("get_attack_shape_cell_count")) != 21:
		push_error("Migrated sprite info prefab should render the authored 7x3 attack-shape grid.")
		quit(1)
		return
	var detail := Dictionary(panel.call("get_detail_snapshot")) if panel.has_method("get_detail_snapshot") else {}
	var shape := Dictionary(detail.get("attack_shape", {}))
	if String(shape.get("shape_id", "")) == "" or Array(shape.get("offsets", [])).is_empty():
		push_error("Artist pet detail panel should receive the pet attack shape from the core shape catalog: %s." % JSON.stringify(detail))
		quit(1)
		return
	var component := panel.find_child("SpriteInfoCard", true, false) as Control
	if component == null or not component.has_method("get_source_psd"):
		push_error("Artist pet detail should host the PetInfoPanelV2 prefab.")
		quit(1)
		return
	if String(component.call("get_source_psd")) != "宠物信息栏实装(修改).psd":
		push_error("Artist pet detail should preserve PetInfoPanelV2 PSD provenance.")
		quit(1)
		return
	for required_node in ["BaseArt", "AttackFormatPlate", "StatSlotArt", "StatsUI", "TraitArt", "ElementArt"]:
		var image_root := component.get_node_or_null(required_node) as TextureRect
		if image_root == null or image_root.texture == null or not image_root.size.is_equal_approx(image_root.texture.get_size()):
			push_error("PetInfoPanelV2 image root %s must directly carry an image at image size." % required_node)
			quit(1)
			return
	if component.find_child("same", true, false) != null or component.find_child("Same", true, false) != null:
		push_error("PSD same resource collection must not become a runtime node.")
		quit(1)
		return
	if component.get_node_or_null("FrameArt") != null or component.get_node_or_null("CardBase") != null:
		push_error("Latest authored card should use the quality-bound BaseArt image root.")
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		var screenshot := get_root().get_texture().get_image()
		if screenshot == null:
			push_error("Artist pet detail smoke could not capture the live viewport.")
			quit(1)
			return
		var save_error := screenshot.save_png("res://output/artist_ui_pet_shape.png")
		if save_error != OK:
			push_error("Artist pet detail screenshot could not be saved: %s" % save_error)
			quit(1)
			return
	if not await _assert_reward_detail_confirmation(middle, scene):
		quit(1)
		return
	print("SMOKE_ARTIST_PET_DETAIL_OK %s" % ("headless" if DisplayServer.get_name() == "headless" else "res://output/artist_ui_pet_shape.png"))
	if DisplayServer.get_name() == "headless":
		quit(0)


func _center_of_control(control: Control) -> Vector2:
	var rect := control.get_global_rect()
	return rect.position + rect.size * 0.5


func _assert_shop_context_detail(middle: Node, scene: Node) -> bool:
	var view := middle.call("get_three_choice_view") as Control
	var shop_index := -1
	for index in range(Array(middle.state.snapshot().get("route_options", [])).size()):
		if String(Dictionary(Array(middle.state.snapshot().get("route_options", []))[index]).get("kind", "")) == "shop":
			shop_index = index
			break
	if shop_index < 0:
		push_error("Artist shop context smoke could not find a shop route.")
		return false
	view.call("_on_three_pressed", shop_index)
	await create_timer(1.4).timeout
	if String(middle.state.snapshot().get("phase", "")) != "shop":
		push_error("Shop context smoke could not enter the shop phase.")
		return false
	var legacy_shop := scene.find_child("LegacyCodeShopView", true, false) as Control
	if legacy_shop != null and legacy_shop.visible:
		var has_buy_command := false
		for button_value in legacy_shop.find_children("*", "Button", true, false):
			var button := button_value as Button
			if button != null and String(Dictionary(button.get_meta("command", {})).get("type", "")) == "BUY_OFFER":
				has_buy_command = true
				break
		if not has_buy_command:
			push_error("Production legacy shop surface must expose a semantic BUY_OFFER action.")
			return false
		await view.call("_on_shop_back_pressed")
		await create_timer(1.4).timeout
		if String(middle.state.snapshot().get("phase", "")) == "shop":
			push_error("Production legacy shop surface could not leave the shop after validation.")
			return false
		return true
	var shop_grid := scene.find_child("Middle_Shop", true, false) as Control
	var last_shop_button := _last_live_shop_button(shop_grid)
	if last_shop_button == null:
		push_error("Shop context smoke could not find the last live shop button.")
		return false
	var last_shop_index := last_shop_button.get_parent().get_index()
	view.call("_on_shop_pet_mouse_entered", last_shop_index)
	await process_frame
	var panel := scene.find_child("ArtistPetDetailPanel", true, false)
	var dim := panel.get_node_or_null("Dim") as Control if panel != null else null
	if panel == null or not bool(panel.get("visible")) or not panel.has_method("is_context_detail") or not bool(panel.call("is_context_detail")):
		push_error("Hovering a shop pet should show the non-modal right-side context detail.")
		return false
	if dim == null or bool(dim.get("visible")) or not _all_controls_ignore_mouse(panel):
		push_error("Shop pet context detail should not dim or block the bazaar UI.")
		return false
	var center := _center_of_control(last_shop_button)
	var party_grid := scene.find_child("Party_Container", true, false) as Control
	var drop_slot := _last_control_child(party_grid)
	if drop_slot == null:
		push_error("Last shop pet drag smoke could not find a party drop target.")
		return false
	var drop_position := _center_of_control(drop_slot)
	var command_count_before := Array(middle.state.snapshot().get("command_log", [])).size()
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(center)
		await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	await process_frame
	if DisplayServer.get_name() != "headless":
		var screenshot := get_root().get_texture().get_image()
		if screenshot == null or screenshot.save_png("res://output/artist_ui_shop_pet_context.png") != OK:
			push_error("Artist shop context smoke could not save the visible context screenshot.")
			return false
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = center
	press.global_position = center
	Input.parse_input_event(press)
	await process_frame
	if String(view.get("_drag_candidate_source")) != "shop" or int(view.get("_drag_candidate_index")) != last_shop_index or not bool(view.call("_has_active_drag")):
		push_error("Real GUI press on the last shop pet should start its drag candidate: source=%s index=%s active=%s hovered=%s." % [view.get("_drag_candidate_source"), view.get("_drag_candidate_index"), view.call("_has_active_drag"), scene.get_viewport().gui_get_hovered_control()])
		return false
	if bool(panel.get("visible")):
		push_error("Shop pet context detail should close when purchase drag begins.")
		return false
	var drag_motion := InputEventMouseMotion.new()
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(drop_position)
		await process_frame
	drag_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag_motion.position = drop_position
	drag_motion.global_position = drop_position
	drag_motion.relative = drop_position - center
	Input.parse_input_event(drag_motion)
	# The headless DisplayServer does not dispatch parsed pointer motion through
	# SceneTree input reliably. Exercise the preview projection directly there;
	# visible validation covers OS-level pointer delivery and release routing.
	if DisplayServer.get_name() == "headless":
		view.call("_update_drag_preview", drop_position)
	await process_frame
	var drag_preview := scene.get_tree().root.find_child("DragPreview", true, false) as TextureRect
	if drag_preview == null or not drag_preview.get_global_rect().has_point(drop_position):
		var controller_preview := view.get("_drag_preview") as TextureRect
		push_error(
			(
				"Dragging the last shop pet should move its visible preview to the party target: "
				+ "drop=%s preview_path=%s preview_rect=%s preview_min=%s controller_preview=%s controller_rect=%s requested_size=%s locked_size=%s "
				+ "event_position=%s event_global_position=%s."
			)
			% [
				drop_position,
				drag_preview.get_path() if drag_preview != null else NodePath(),
				drag_preview.get_global_rect() if drag_preview != null else Rect2(),
				drag_preview.custom_minimum_size if drag_preview != null else Vector2.ZERO,
				controller_preview,
				controller_preview.get_global_rect() if controller_preview != null else Rect2(),
				view.call("_drag_preview_size_for_candidate"),
				view.get("_drag_preview_locked_size"),
				drag_motion.position,
				drag_motion.global_position,
			]
		)
		return false
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.button_mask = 0
	release.pressed = false
	release.position = drop_position
	release.global_position = drop_position
	if DisplayServer.get_name() == "headless":
		await view.call("_drop_dragged_shop_item", drop_position)
		view.call("_clear_drag_state")
	else:
		Input.parse_input_event(release)
	await create_timer(1.6).timeout
	var command_log := Array(middle.state.snapshot().get("command_log", []))
	if command_log.size() != command_count_before + 1 or String(Dictionary(command_log.back()).get("type", "")) != "DROP_ITEM_ON_TARGET":
		push_error("Releasing the last shop pet on a party slot should dispatch DROP_ITEM_ON_TARGET: %s" % JSON.stringify(command_log))
		return false
	if bool(view.call("_has_active_drag")) or scene.get_tree().root.find_child("DragPreview", true, false) != null:
		push_error("Successful last-shop-pet drop should clear the active drag and preview.")
		return false
	view.call("_on_shop_pet_mouse_entered", last_shop_index)
	await process_frame
	view.call("_on_shop_pet_mouse_exited", last_shop_index)
	await process_frame
	if bool(panel.get("visible")):
		push_error("Shop pet context detail should close when the pointer leaves the offer.")
		return false
	await view.call("_on_shop_back_pressed")
	await create_timer(1.4).timeout
	if String(middle.state.snapshot().get("phase", "")) == "shop":
		push_error("Shop context smoke could not leave the shop after validation.")
		return false
	return true


func _last_live_shop_button(shop_grid: Control) -> TextureButton:
	if shop_grid == null:
		return null
	for slot_index in range(shop_grid.get_child_count() - 1, -1, -1):
		var slot := shop_grid.get_child(slot_index)
		var buttons := slot.find_children("*", "TextureButton", true, false)
		var button := buttons[0] as TextureButton if not buttons.is_empty() else null
		if button != null and not Dictionary(button.get_meta("command", {})).is_empty():
			return button
	return null


func _last_control_child(container: Control) -> Control:
	if container == null:
		return null
	for index in range(container.get_child_count() - 1, -1, -1):
		var child := container.get_child(index) as Control
		if child != null and child.is_visible_in_tree():
			return child
	return null


func _all_controls_ignore_mouse(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _all_controls_ignore_mouse(child):
			return false
	return true


func _assert_reward_detail_confirmation(middle: Node, scene: Node) -> bool:
	var view := middle.call("get_three_choice_view") as Control
	var reward_index := -1
	for index in range(Array(middle.state.snapshot().get("route_options", [])).size()):
		var option := Dictionary(Array(middle.state.snapshot().get("route_options", []))[index])
		if String(option.get("kind", "")) == "reward":
			reward_index = index
			break
	if reward_index < 0:
		push_error("Artist pet detail smoke could not find a reward route.")
		return false
	view.call("_on_three_pressed", reward_index)
	await create_timer(1.4).timeout
	if String(middle.state.snapshot().get("phase", "")) != "reward":
		push_error("Reward route did not enter the reward phase.")
		return false
	view.call("_on_three_mouse_entered", 0)
	await process_frame
	var panel := scene.find_child("ArtistPetDetailPanel", true, false)
	if panel == null or not bool(panel.get("visible")) or panel.get_node_or_null("Panel/Actions") != null:
		push_error("Reward hover should open the authored context detail without restoring deleted action buttons.")
		return false
	view.call("_on_three_pressed", 0)
	await create_timer(1.4).timeout
	if String(middle.state.snapshot().get("phase", "")) == "reward":
		push_error("Clicking the original reward option should dispatch PICK_REWARD.")
		return false
	return true
