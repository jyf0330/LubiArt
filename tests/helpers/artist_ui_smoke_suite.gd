extends SceneTree

## Shared fixture and interaction helpers for independently runnable artist UI
## contract smokes. This owns no gameplay state; each smoke creates a fresh
## formal three-choice Scene and authoritative session.

const ARTIST_UI_MAPPED_SEED := "artist-ui-mapped-1"


func _open_artist_ui_fixture(mapped_catalog: bool = true) -> Dictionary:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed := load("res://art/scenes/app/game.tscn") as PackedScene
	if packed == null:
		push_error("Could not load the formal Game Scene.")
		return {}
	var scene := packed.instantiate()
	root.add_child(scene)
	await _settle_seconds(0.8)
	var middle := scene
	if middle == null or middle.get("state") == null:
		push_error("Artist UI fixture requires the formal Game controller and state.")
		return {}
	if mapped_catalog:
		middle.state.call("set_run_seed", ARTIST_UI_MAPPED_SEED)
		middle.call("render_current_view")
		await _settle_seconds(0.2)
	return {
		"scene": scene,
		"middle": middle,
		"view": middle.call("get_three_choice_view"),
		"three_grid": scene.find_child("Middle_Three_Option", true, false),
		"shop_grid": scene.find_child("Middle_Shop", true, false),
		"bag_grid": scene.find_child("Middle_Bag", true, false),
	}


func _enter_artist_shop(fixture: Dictionary) -> bool:
	var scene := fixture.get("scene") as Node
	var middle := fixture.get("middle") as Node
	var shop_grid := fixture.get("shop_grid") as Control
	var shop_button := _find_button_with_command(scene, "CHOOSE_ROUTE", "shop")
	if shop_button == null or not _assert_button_texture_contains(shop_button, "three_shang.png"):
		push_error("Artist UI fixture requires a mapped formal shop route.")
		return false
	shop_button.emit_signal("pressed")
	await _settle_seconds(0.12)
	if not _assert_stage_transition_hud(scene, middle):
		return false
	await _settle_seconds(1.4)
	if String(middle.state.snapshot().get("phase", "")) != "shop" or shop_grid == null or not shop_grid.visible:
		push_error("Artist UI fixture did not reach the authored shop view.")
		return false
	return true


func _finish_artist_ui(success: bool, sentinel: String) -> void:
	if success:
		print(sentinel)
		quit(0)
		return
	quit(1)


func _find_button_with_command(scene: Node, command_type: String, kind: String) -> BaseButton:
	var buttons := scene.find_children("*", "BaseButton", true, false)
	for node in buttons:
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != command_type:
			continue
		if kind == "shop":
			var text := "%s %s" % [String(command.get("option_id", "")), String(button.get_meta("route_kind", ""))]
			if text.to_lower().contains("shop") or text.contains("商店"):
				return button
		elif kind == "reward":
			var text := "%s %s" % [String(command.get("option_id", "")), String(button.get_meta("route_kind", ""))]
			if text.to_lower().contains("reward") or text.contains("奖励"):
				return button
		elif kind == "battle":
			var text := "%s %s" % [String(command.get("option_id", "")), String(button.get_meta("route_kind", ""))]
			if text.to_lower().contains("battle") or text.contains("战斗"):
				return button
		else:
			return button
	return null


func _assert_command_textures(scene: Node, command_type: String, expected_minimum: int) -> bool:
	var matched: Array[TextureButton] = []
	var buttons := scene.find_children("*", "BaseButton", true, false)
	for node in buttons:
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != command_type:
			continue
		var texture_button := button as TextureButton
		if texture_button == null:
			push_error("%s command is not bound to original TextureButton." % command_type)
			return false
		matched.append(texture_button)
	if matched.size() < expected_minimum:
		var middle := scene
		var snapshot: Dictionary = middle.state.snapshot() if middle != null and middle.get("state") != null else {}
		push_error("%s command count is %d, expected at least %d; phase=%s offers=%s." % [
			command_type,
			matched.size(),
			expected_minimum,
			String(snapshot.get("phase", "")),
			JSON.stringify(snapshot.get("shop_offers", [])),
		])
		return false
	for button in matched:
		if _button_display_texture(button) == null:
			push_error("%s command button has no image texture: path=%s command=%s drag=%s has_pet_texture=%s." % [
				command_type,
				button.get_path(),
				JSON.stringify(button.get_meta("command", {})),
				JSON.stringify(button.get_meta("drag_record", {})),
				button.has_meta("pet_texture"),
			])
			return false
	return true


func _button_display_texture(button: TextureButton) -> Texture2D:
	if button.texture_normal != null:
		return button.texture_normal
	var shared_texture := button.get_meta("pet_texture") as Texture2D if button.has_meta("pet_texture") else null
	if shared_texture != null:
		return shared_texture
	var slot := button.get_parent() as Control
	var visual := slot.find_child("PetVisual", true, false) as Control if slot != null else null
	if visual != null and visual.has_method("get_display_texture"):
		return visual.call("get_display_texture") as Texture2D
	return null


func _assert_no_missing_images(middle: Node) -> bool:
	if not middle.has_method("get_missing_image_report"):
		return true
	var missing_images := Array(middle.call("get_missing_image_report"))
	if missing_images.is_empty():
		return true
	push_error("SMOKE_ARTIST_UI_MISSING_IMAGES %s" % JSON.stringify(missing_images))
	return false


func _assert_button_texture_contains(button: BaseButton, expected: String) -> bool:
	var texture_button := button as TextureButton
	if texture_button == null or texture_button.texture_normal == null:
		push_error("Button has no texture for %s." % expected)
		return false
	var texture_path := String(texture_button.texture_normal.resource_path)
	if texture_path.contains(expected):
		return true
	push_error("Button texture should contain %s, got %s." % [expected, texture_path])
	return false


func _assert_shop_character_assets() -> bool:
	var map_path := "res://art/manifests/route/shop/characters/shop_character_map.json"
	if not FileAccess.file_exists(map_path):
		push_error("Shop character map is missing.")
		return false
	var file := FileAccess.open(map_path, FileAccess.READ)
	if file == null:
		push_error("Shop character map cannot be opened.")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Shop character map is not a dictionary.")
		return false
	var data := Dictionary(parsed)
	var base_count := 0
	for key in data.keys():
		if String(key).begins_with("shop_character_"):
			base_count += 1
	if base_count != 33:
		push_error("Shop character map should contain 33 base entries, got %d." % base_count)
		return false
	for key in ["shop_character_001", "shop_character_033"]:
		var path := String(data.get(key, ""))
		if path == "" or not ResourceLoader.exists(path):
			push_error("Shop character slice is missing: %s -> %s." % [key, path])
			return false
	return true


func _assert_reward_node_assets() -> bool:
	var map_path := "res://art/manifests/route/rewards/reward_node_map.json"
	if not FileAccess.file_exists(map_path):
		push_error("Reward node map is missing.")
		return false
	var file := FileAccess.open(map_path, FileAccess.READ)
	if file == null:
		push_error("Reward node map cannot be opened.")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Reward node map is not a dictionary.")
		return false
	var data := Dictionary(parsed)
	var base_count := 0
	for key in data.keys():
		if String(key).begins_with("reward_node_"):
			base_count += 1
	if base_count != 25:
		push_error("Reward node map should contain 25 base entries, got %d." % base_count)
		return false
	for key in ["reward_node_001", "reward_node_025"]:
		var path := String(data.get(key, ""))
		if path == "" or not ResourceLoader.exists(path):
			push_error("Reward node slice is missing: %s -> %s." % [key, path])
			return false
	return true


func _assert_run_tools_basic(scene: Node, middle: Node) -> bool:
	middle.call("set_developer_tools_enabled", true)
	await process_frame
	await process_frame
	var run_tools := scene.find_child("RunTools", true, false) as Control
	if run_tools == null:
		push_error("Temporary RunTools save/load toolbar is missing.")
		return false
	if not bool(run_tools.get("visible")):
		push_error("Temporary RunTools save/load toolbar should be visible.")
		return false
	for button_name in ["SaveButton", "LoadButton", "SaveSlot2Button", "LoadSlot2Button", "SaveSlot3Button", "LoadSlot3Button", "ExportReplayButton", "ExportBattleTraceButton"]:
		var button := run_tools.find_child(button_name, true, false) as BaseButton
		if button == null:
			push_error("Temporary RunTools button is missing: %s." % button_name)
			return false
	var save_button := run_tools.find_child("SaveButton", true, false) as BaseButton
	var status_label := run_tools.find_child("RunToolsStatus", true, false) as Label
	if save_button == null or status_label == null:
		push_error("Temporary RunTools slot 1 save button or status label is missing.")
		return false
	save_button.emit_signal("pressed")
	await _settle_seconds(0.2)
	if not String(status_label.text).contains("保存"):
		push_error("Slot 1 save button should update the temporary RunTools status.")
		return false
	if not _log_contains(Array(middle.state.snapshot().get("log_lines", [])), "已保存"):
		push_error("Slot 1 save button should call the core save_to_user path.")
		return false
	return true


func _assert_bazaar_information(scene: Node, expected_view: String) -> bool:
	var panel := scene.find_child("BazaarInfoPanel", true, false)
	if panel == null or not bool(panel.get("visible")):
		push_error("Bazaar information panel should be visible for %s." % expected_view)
		return false
	if not panel.has_method("get_summary_text"):
		push_error("Bazaar information panel should expose its rendered summary.")
		return false
	var summary := String(panel.call("get_summary_text"))
	if not summary.contains("金币"):
		push_error("Bazaar information panel should show coins, got %s." % summary)
		return false
	if expected_view == "route" and not summary.contains("路线"):
		push_error("Bazaar information panel should show route context, got %s." % summary)
		return false
	if expected_view == "shop":
		if not summary.contains("刷新"):
			push_error("Bazaar information panel should show shop refresh information, got %s." % summary)
			return false
		var refresh_button := panel.find_child("RefreshButton", true, false) as BaseButton
		if refresh_button == null or not bool(refresh_button.get("visible")):
			push_error("Bazaar information panel should expose the refresh command outside the art slots.")
			return false
	return true


func _assert_run_tools_round_trip(scene: Node, middle: Node) -> bool:
	middle.call("set_developer_tools_enabled", true)
	await process_frame
	await process_frame
	var run_tools := scene.find_child("RunTools", true, false) as Control
	if run_tools == null:
		push_error("Temporary RunTools toolbar is missing before load round trip.")
		return false
	var save_button := run_tools.find_child("SaveButton", true, false) as BaseButton
	var load_button := run_tools.find_child("LoadButton", true, false) as BaseButton
	var export_replay_button := run_tools.find_child("ExportReplayButton", true, false) as BaseButton
	var export_battle_trace_button := run_tools.find_child("ExportBattleTraceButton", true, false) as BaseButton
	var status_label := run_tools.find_child("RunToolsStatus", true, false) as Label
	if save_button == null or load_button == null or export_replay_button == null or export_battle_trace_button == null or status_label == null:
		push_error("Temporary RunTools round-trip controls are incomplete.")
		return false
	save_button.emit_signal("pressed")
	await _settle_seconds(0.2)
	var saved_phase := String(middle.state.snapshot().get("phase", ""))
	if saved_phase == "shop" and not middle.state.dispatch({"type": "EXIT_SHOP"}):
		push_error("RunTools round-trip setup should leave shop through the legal command.")
		return false
	if not middle.state.dispatch({"type": "START_BATTLE"}):
		push_error("RunTools round-trip setup should start battle from route.")
		return false
	middle.call("render_current_view")
	await _settle_seconds(0.5)
	if String(middle.state.snapshot().get("phase", "")) != "battle":
		push_error("RunTools round-trip setup should be able to enter battle before loading.")
		return false
	if not bool(run_tools.get("visible")):
		push_error("RunTools toolbar should remain visible over the battle view.")
		return false
	load_button.emit_signal("pressed")
	await _settle_seconds(1.0)
	if String(middle.state.snapshot().get("phase", "")) != saved_phase:
		push_error("Load button should restore the phase saved by the temporary RunTools toolbar.")
		return false
	if not String(status_label.text).contains("读档"):
		push_error("Load button should update the temporary RunTools status.")
		return false
	export_replay_button.emit_signal("pressed")
	await _settle_seconds(0.2)
	if not String(status_label.text).contains("回放"):
		push_error("Export replay button should update the temporary RunTools status.")
		return false
	export_battle_trace_button.emit_signal("pressed")
	await _settle_seconds(0.2)
	if not String(status_label.text).contains("战报"):
		push_error("Export battle trace button should update the temporary RunTools status.")
		return false
	return true


func _assert_stage_transition_hud(scene: Node, middle: Node) -> bool:
	if not bool(_presentation_view(middle).get("_is_transitioning")):
		push_error("Route-to-shop should keep the UI in transition state while the middle stage swaps.")
		return false
	var bags_panel := scene.find_child("Bags", true, false) as Control
	var party_panel := scene.find_child("Party", true, false) as Control
	if bags_panel == null or party_panel == null:
		push_error("Persistent HUD panels are missing.")
		return false
	if not bool(bags_panel.get("visible")) or not bool(party_panel.get("visible")):
		push_error("Persistent bag and party HUD should stay visible during middle-stage transitions.")
		return false
	return true


func _assert_bag_toggle_from_shop(scene: Node, middle: Node, shop_grid: Node, bag_grid: Node) -> bool:
	var bags_panel := scene.find_child("Bags", true, false) as Control
	if bags_panel == null:
		push_error("Original bags panel is missing.")
		return false
	var phase_before := String(middle.state.snapshot().get("phase", ""))
	var open_event := InputEventMouseButton.new()
	open_event.button_index = MOUSE_BUTTON_LEFT
	open_event.pressed = false
	open_event.position = Vector2(100.0, 100.0)
	bags_panel.emit_signal("gui_input", open_event)
	await _settle_seconds(0.12)
	if not _assert_stage_transition_hud(scene, middle):
		return false
	await _settle_seconds(1.4)
	if String(middle.state.snapshot().get("phase", "")) != phase_before:
		push_error("Opening bag should not dispatch shop exit or change core phase.")
		return false
	if not bool(bag_grid.get("visible")):
		push_error("Clicking the visible bags panel should show the original bag panel.")
		return false
	if bool(shop_grid.get("visible")):
		push_error("Opening bag from shop should use the original bag view transition.")
		return false
	var close_event := InputEventMouseButton.new()
	close_event.button_index = MOUSE_BUTTON_LEFT
	close_event.pressed = false
	close_event.position = Vector2(100.0, 100.0)
	bags_panel.emit_signal("gui_input", close_event)
	await _settle_seconds(0.12)
	if not _assert_stage_transition_hud(scene, middle):
		return false
	await _settle_seconds(1.4)
	if String(middle.state.snapshot().get("phase", "")) != phase_before:
		push_error("Closing bag should return to the previous UI without changing core phase.")
		return false
	if not bool(shop_grid.get("visible")) or bool(bag_grid.get("visible")):
		push_error("Closing bag from shop should restore the original shop panel.")
		return false
	return true


func _assert_shop_back_hot_area(scene: Node, middle: Node, shop_grid: Node) -> bool:
	if String(middle.state.snapshot().get("phase", "")) != "shop":
		push_error("Shop back smoke should start from shop phase.")
		return false
	var top_shop := scene.find_child("Top_Shop", true, false) as Control
	if top_shop == null:
		push_error("Original Top_Shop hot area is missing.")
		return false
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = Vector2(100.0, 100.0)
	top_shop.emit_signal("gui_input", event)
	await _settle_seconds(1.4)
	if String(middle.state.snapshot().get("phase", "")) != "route":
		push_error("Clicking the visible Top_Shop area should dispatch EXIT_SHOP and return to route.")
		return false
	if bool(shop_grid.get("visible")):
		push_error("Shop panel should be hidden after clicking the shop back hot area.")
		return false
	return true


func _assert_shop_drag_semantics(scene: Node, middle: Node) -> bool:
	var buy_button := _find_button_with_command(scene, "BUY_OFFER", "") as BaseButton
	if buy_button == null:
		push_error("No shop offer button is bound for drag purchase.")
		return false
	var before_click_roster := Array(middle.state.snapshot().get("roster", []))
	buy_button.emit_signal("pressed")
	await _settle_frames(3)
	var after_click_roster := Array(middle.state.snapshot().get("roster", []))
	if after_click_roster.size() != before_click_roster.size():
		push_error("Shop offer click should not buy; drag release should be required.")
		return false
	var party_grid := scene.find_child("Party_Container", true, false) as Control
	if party_grid == null or party_grid.get_child_count() == 0:
		push_error("Party drop target is missing.")
		return false
	var first_party_slot := party_grid.get_child(0) as Control
	if first_party_slot == null:
		push_error("Party drop target is not a Control.")
		return false
	var source_buttons := Array(_presentation_view(middle).get("_shop_buttons"))
	var source_index := source_buttons.find(buy_button)
	if source_index < 0:
		push_error("Shop drag source does not belong to an authored slot.")
		return false
	var source_size_before_drag := buy_button.size
	_presentation_view(middle).call("_on_shop_button_down", source_index)
	await _settle_frames(1)
	var drag_preview := scene.get_tree().root.find_child("DragPreview", true, false) as TextureRect
	if drag_preview == null:
		push_error("Dragging shop offer should create the original-style image preview.")
		_presentation_view(middle).call("_clear_drag_state")
		return false
	var dragged_shop_button := buy_button as TextureButton
	if dragged_shop_button == null or dragged_shop_button.texture_normal != null:
		push_error("Dragging shop offer should hide the source shop image.")
		_presentation_view(middle).call("_clear_drag_state")
		return false
	if drag_preview.size.distance_to(source_size_before_drag) > 1.0:
		var candidate_button := _presentation_view(middle).call("_drag_button_for_candidate") as TextureButton
		push_error("Drag preview should use the source item size captured before the authored grid reflows: preview=%s before=%s current=%s minimum=%s index=%d path=%s candidate=%s candidate_size=%s." % [
			drag_preview.size,
			source_size_before_drag,
			dragged_shop_button.size,
			dragged_shop_button.custom_minimum_size,
			source_index,
			dragged_shop_button.get_path(),
			candidate_button.get_path() if candidate_button != null else NodePath(),
			candidate_button.size if candidate_button != null else Vector2.ZERO,
		])
		_presentation_view(middle).call("_clear_drag_state")
		return false
	var view_before_drag := String(_presentation_view(middle).get("_current_view"))
	await _presentation_view(middle).call("_on_bag_pressed")
	await _settle_frames(1)
	if String(_presentation_view(middle).get("_current_view")) != view_before_drag:
		push_error("Dragging an item should block lower UI actions such as opening the bag.")
		_presentation_view(middle).call("_clear_drag_state")
		return false
	var preview_target := _center_of_control(first_party_slot) + Vector2(40.0, 32.0)
	_presentation_view(middle).call("_update_drag_preview", preview_target)
	await _settle_frames(1)
	var expected_position := preview_target - drag_preview.size * 0.5
	if drag_preview.global_position.distance_to(expected_position) > 1.0:
		push_error("Drag preview should follow the current mouse position.")
		_presentation_view(middle).call("_clear_drag_state")
		return false
	await _presentation_view(middle).call("_drop_dragged_shop_item", _center_of_control(first_party_slot))
	_presentation_view(middle).call("_clear_drag_state")
	await _settle_seconds(0.2)
	if scene.get_tree().root.find_child("DragPreview", true, false) != null:
		push_error("Drag preview should be removed after shop drag completes.")
		return false
	var after_drag_roster := Array(middle.state.snapshot().get("roster", []))
	if after_drag_roster.size() <= before_click_roster.size():
		push_error("Dragging shop offer to party should dispatch core buy and update roster.")
		return false
	if dragged_shop_button.texture_normal != null or not Dictionary(dragged_shop_button.get_meta("command", {})).is_empty():
		push_error("Purchased shop offer should clear its shop image and command.")
		return false
	return true


func _assert_party_click_opens_detail(scene: Node, middle: Node) -> bool:
	var party_grid := scene.find_child("Party_Container", true, false) as Control
	if party_grid == null or party_grid.get_child_count() == 0:
		push_error("Party detail smoke target is missing.")
		return false
	var party_slot := party_grid.get_child(0) as Control
	if party_slot == null:
		push_error("Party detail smoke target is not a Control.")
		return false
	var party_button := _first_texture_button(party_slot)
	if party_button == null:
		push_error("Party detail smoke requires the authored party button.")
		return false
	party_button.emit_signal("mouse_entered")
	await _settle_frames(2)
	return await _assert_pet_detail_panel(scene, "hovered party pet")


func _assert_shop_click_opens_detail(scene: Node, middle: Node) -> bool:
	var shop_grid := scene.find_child("Middle_Shop", true, false) as Control
	if shop_grid == null or shop_grid.get_child_count() == 0:
		push_error("Shop detail smoke target is missing.")
		return false
	var shop_slot := shop_grid.get_child(0) as Control
	if shop_slot == null:
		push_error("Shop detail smoke target is not a Control.")
		return false
	_presentation_view(middle).call("_on_shop_button_down", 0)
	await _settle_frames(1)
	await _presentation_view(middle).call("_drop_dragged_shop_item", _center_of_control(shop_slot))
	_presentation_view(middle).call("_clear_drag_state")
	await _settle_frames(2)
	return await _assert_pet_detail_panel(scene, "shop offer")


func _assert_pet_detail_panel(scene: Node, context: String) -> bool:
	var panel := scene.find_child("ArtistPetDetailPanel", true, false)
	if panel == null or not bool(panel.get("visible")):
		push_error("Clicking %s should open the pet detail panel." % context)
		return false
	if not panel.has_method("get_detail_snapshot"):
		push_error("Pet detail panel should expose its rendered snapshot.")
		return false
	var detail := Dictionary(panel.call("get_detail_snapshot"))
	if String(detail.get("name", "")) == "" or String(detail.get("element", "")) == "":
		push_error("Pet detail panel should render name and element for %s: %s" % [context, JSON.stringify(detail)])
		return false
	if String(detail.get("skill", "")).contains("castleReduce"):
		push_error("Pet detail panel should show player-facing skill text instead of raw skill ids: %s" % JSON.stringify(detail))
		return false
	if not panel.has_method("close"):
		push_error("Pet detail panel should expose a close action.")
		return false
	panel.call("close")
	await _settle_frames(1)
	if bool(panel.get("visible")):
		push_error("Pet detail panel should close after its close action.")
		return false
	return true


func _assert_bag_stays_open_during_roster_moves(scene: Node, middle: Node, shop_grid: Node, bag_grid: Node) -> bool:
	var party_grid := scene.find_child("Party_Container", true, false) as Control
	if party_grid == null or party_grid.get_child_count() == 0 or bag_grid == null or bag_grid.get_child_count() == 0:
		push_error("Party or bag slots are missing for bag-persistent roster moves.")
		return false
	var first_party_slot := party_grid.get_child(0) as Control
	var first_bag_slot := bag_grid.get_child(0) as Control
	if first_party_slot == null or first_bag_slot == null:
		push_error("Party or bag move target is not a Control.")
		return false
	if String(_presentation_view(middle).get("_current_view")) != "shop":
		push_error("Bag-persistent move smoke expects to start from shop view.")
		return false
	await _presentation_view(middle).call("_on_bag_pressed")
	await _settle_seconds(1.5)
	if not _assert_bag_view_open(middle, shop_grid, bag_grid, "Opening bag before roster move"):
		return false

	_presentation_view(middle).call("_on_party_button_down", 0)
	await _settle_frames(1)
	await _presentation_view(middle).call("_drop_dragged_storage_item", _center_of_control(first_bag_slot))
	_presentation_view(middle).call("_clear_drag_state")
	await _settle_seconds(0.2)
	if not _assert_bag_view_open(middle, shop_grid, bag_grid, "Moving a party pet into bag"):
		return false

	_presentation_view(middle).call("_on_bag_slot_button_down", 0)
	await _settle_frames(1)
	await _presentation_view(middle).call("_drop_dragged_storage_item", _center_of_control(first_party_slot))
	_presentation_view(middle).call("_clear_drag_state")
	await _settle_seconds(0.2)
	if not _assert_bag_view_open(middle, shop_grid, bag_grid, "Moving a bag pet back to party"):
		return false

	await _presentation_view(middle).call("_on_bag_pressed")
	await _settle_seconds(1.5)
	if String(_presentation_view(middle).get("_current_view")) != "shop" or not bool(shop_grid.get("visible")) or bool(bag_grid.get("visible")):
		push_error("Closing bag after roster moves should return to shop view.")
		return false
	return true


func _assert_bag_view_open(middle: Node, shop_grid: Node, bag_grid: Node, context: String) -> bool:
	if String(_presentation_view(middle).get("_current_view")) != "bag":
		push_error("%s should keep current view as bag." % context)
		return false
	if not bool(bag_grid.get("visible")) or bool(shop_grid.get("visible")):
		push_error("%s should keep the bag panel open and the shop panel hidden." % context)
		return false
	return true


func _assert_route_party_drag_respects_phase_policy(scene: Node, middle: Node, shop_grid: Node, bag_grid: Node) -> bool:
	var party_grid := scene.find_child("Party_Container", true, false) as Control
	var sell_button := scene.find_child("Top_Sell", true, false) as BaseButton
	if party_grid == null or party_grid.get_child_count() < 2:
		push_error("Route party drag policy smoke needs two party slots.")
		return false
	var first_party_slot := party_grid.get_child(0) as Control
	var second_party_slot := party_grid.get_child(1) as Control
	if first_party_slot == null or second_party_slot == null:
		push_error("Route party drag policy smoke targets are not Controls.")
		return false
	if String(_presentation_view(middle).get("_current_view")) != "three_option":
		push_error("Route party drag policy smoke should start on the route view.")
		return false
	if bool(shop_grid.get("visible")) or bool(bag_grid.get("visible")):
		push_error("Route party drag policy smoke should not start from shop or bag.")
		return false
	if _slot_record_id(second_party_slot) == "":
		if not _seed_second_party_pet(middle):
			push_error("Route party drag policy smoke could not seed a second party pet.")
			return false
		middle.call("render_current_view")
		await _settle_seconds(0.2)
	var first_id := _slot_record_id(first_party_slot)
	var second_id := _slot_record_id(second_party_slot)
	if first_id == "" or second_id == "":
		push_error("Route party drag policy smoke needs two visible party records.")
		return false
	var roster_before_drag := Array(middle.state.snapshot().get("roster", []))
	var first_slot_before := _roster_slot_for_id(roster_before_drag, first_id, true)
	var second_slot_before := _roster_slot_for_id(roster_before_drag, second_id, true)

	_presentation_view(middle).call("_on_party_button_down", 0)
	await _settle_frames(1)
	if not bool(_presentation_view(middle).call("_has_active_drag")):
		push_error("Party slots should start drag directly on route view without opening bag.")
		return false
	if sell_button != null and bool(sell_button.get("visible")):
		push_error("Route-only party reorder should not show the sell area.")
		_presentation_view(middle).call("_clear_drag_state")
		return false
	await _presentation_view(middle).call("_drop_dragged_storage_item", _center_of_control(second_party_slot))
	_presentation_view(middle).call("_clear_drag_state")
	await _settle_seconds(0.2)
	if _slot_record_id(first_party_slot) != first_id or _slot_record_id(second_party_slot) != second_id:
		push_error("Route party drag must not mutate roster slots outside the shop phase.")
		return false
	var roster_after_swap := Array(middle.state.snapshot().get("roster", []))
	if _roster_slot_for_id(roster_after_swap, first_id, true) != first_slot_before or _roster_slot_for_id(roster_after_swap, second_id, true) != second_slot_before:
		push_error("Rejected route party drag must preserve core active slot values.")
		return false
	if String(_presentation_view(middle).get("_current_view")) != "three_option" or bool(shop_grid.get("visible")) or bool(bag_grid.get("visible")):
		push_error("Rejected route party drag should keep the route view and not open shop or bag.")
		return false
	return true


func _assert_roster_position_drag_semantics(scene: Node, middle: Node, shop_grid: Node, bag_grid: Node) -> bool:
	var party_grid := scene.find_child("Party_Container", true, false) as Control
	if party_grid == null or party_grid.get_child_count() < 2 or bag_grid == null or bag_grid.get_child_count() < 2:
		push_error("Roster position smoke needs at least two party and bag slots.")
		return false
	var first_party_slot := party_grid.get_child(0) as Control
	var second_party_slot := party_grid.get_child(1) as Control
	var first_bag_slot := bag_grid.get_child(0) as Control
	var second_bag_slot := bag_grid.get_child(1) as Control
	if first_party_slot == null or second_party_slot == null or first_bag_slot == null or second_bag_slot == null:
		push_error("Roster position smoke targets are not Controls.")
		return false
	if _slot_record_id(second_party_slot) == "":
		var offer_id := _first_unsold_offer_id(middle)
		if offer_id == "":
			push_error("Roster position smoke cannot find a second party item or shop offer.")
			return false
		if not middle.state.dispatch({"type": "DROP_ITEM_ON_TARGET", "source_type": "shop", "offer_id": offer_id, "target_type": "party", "target_index": 1}):
			push_error("Roster position smoke could not buy a second party item.")
			return false
		middle.call("render_current_view")
		await _settle_seconds(0.2)

	var first_id := _slot_record_id(first_party_slot)
	var second_id := _slot_record_id(second_party_slot)
	if first_id == "" or second_id == "":
		push_error("Roster position smoke needs two visible party records.")
		return false

	_presentation_view(middle).call("_on_party_button_down", 0)
	await _settle_frames(1)
	if not bool(_presentation_view(middle).call("_has_active_drag")):
		push_error("Roster position smoke failed to start party drag for slot 1. view=%s record=%s" % [
			String(_presentation_view(middle).get("_current_view")),
			JSON.stringify(Dictionary((_first_texture_button(first_party_slot) as TextureButton).get_meta("drag_record", {})) if _first_texture_button(first_party_slot) != null else {})
		])
		return false
	await _presentation_view(middle).call("_drop_dragged_storage_item", _center_of_control(second_party_slot))
	_presentation_view(middle).call("_clear_drag_state")
	await _settle_seconds(0.2)
	if _slot_record_id(first_party_slot) != second_id or _slot_record_id(second_party_slot) != first_id:
		push_error("Party-to-party drag should swap visible party slots from core slot data.")
		return false
	var roster_after_party_swap := Array(middle.state.snapshot().get("roster", []))
	if _roster_slot_for_id(roster_after_party_swap, first_id, true) != 2 or _roster_slot_for_id(roster_after_party_swap, second_id, true) != 1:
		push_error("Party-to-party drag should update core active slot values.")
		return false

	if String(_presentation_view(middle).get("_current_view")) != "bag":
		await _presentation_view(middle).call("_on_bag_pressed")
		await _settle_seconds(1.5)
	if not _assert_bag_view_open(middle, shop_grid, bag_grid, "Opening bag before bag position smoke"):
		return false

	var offer_ids := _unsold_offer_ids(middle)
	var bag_seed_count := mini(2, offer_ids.size())
	for index in range(bag_seed_count):
		if not middle.state.dispatch({"type": "DROP_ITEM_ON_TARGET", "source_type": "shop", "offer_id": String(offer_ids[index]), "target_type": "bag", "target_index": index}):
			push_error("Roster position smoke could not buy offer %s into bag slot %d." % [String(offer_ids[index]), index + 1])
			return false
	if bag_seed_count < 2:
		for value in Array(middle.state.game_data.get("shop_offers", [])):
			var fixture := Dictionary(value).duplicate(true)
			var fixture_pet_id := String(fixture.get("pet_id", fixture.get("id", "")))
			if fixture_pet_id == "" or _roster_has_pet_id(middle.state.snapshot(), fixture_pet_id):
				continue
			middle.state.call("_add_pet_to_roster", fixture, "smoke_fixture", "bag", bag_seed_count)
			bag_seed_count += 1
			if bag_seed_count >= 2:
				break
	if bag_seed_count < 2:
		push_error("Roster position smoke could not seed two distinct bag pets.")
		return false
	middle.call("render_current_view")
	await _settle_seconds(0.2)
	var bag_first_id := _slot_record_id(first_bag_slot)
	var bag_second_id := _slot_record_id(second_bag_slot)
	if bag_first_id == "" or bag_second_id == "":
		push_error("Buying two pets into bag should populate two visible bag records. bag1=%s bag2=%s logs=%s commands=%s roster=%s" % [
			bag_first_id,
			bag_second_id,
			JSON.stringify(middle.state.snapshot().get("log_lines", [])),
			JSON.stringify(middle.state.snapshot().get("command_log", [])),
			JSON.stringify(middle.state.snapshot().get("roster", []))
		])
		return false

	_presentation_view(middle).call("_on_bag_slot_button_down", 0)
	await _settle_frames(1)
	await _presentation_view(middle).call("_drop_dragged_storage_item", _center_of_control(second_bag_slot))
	_presentation_view(middle).call("_clear_drag_state")
	await _settle_seconds(0.2)
	if _slot_record_id(first_bag_slot) != bag_second_id or _slot_record_id(second_bag_slot) != bag_first_id:
		push_error("Bag-to-bag drag should swap visible bag slots from core bag_slot data.")
		return false
	var roster_after_bag_swap := Array(middle.state.snapshot().get("roster", []))
	if _roster_slot_for_id(roster_after_bag_swap, bag_first_id, false) != 2 or _roster_slot_for_id(roster_after_bag_swap, bag_second_id, false) != 1:
		push_error("Bag-to-bag drag should update core bag_slot values.")
		return false

	await _presentation_view(middle).call("_on_bag_pressed")
	await _settle_seconds(1.5)
	if String(_presentation_view(middle).get("_current_view")) != "shop" or not bool(shop_grid.get("visible")):
		push_error("Roster position smoke should restore shop view for following checks.")
		return false
	return true


func _roster_has_pet_id(snap: Dictionary, pet_id: String) -> bool:
	for value in Array(snap.get("roster", [])):
		var pet := Dictionary(value)
		if String(pet.get("pet_id", pet.get("id", ""))) == pet_id:
			return true
	return false


func _assert_roster_sell_drag_semantics(scene: Node, middle: Node) -> bool:
	var party_grid := scene.find_child("Party_Container", true, false) as Control
	var sell_button := scene.find_child("Top_Sell", true, false) as BaseButton
	if party_grid == null or party_grid.get_child_count() == 0 or sell_button == null:
		push_error("Roster sell drag targets are missing.")
		return false
	var first_party_slot := party_grid.get_child(0) as Control
	if first_party_slot == null:
		push_error("Party sell source is not a Control.")
		return false
	var gold_before := int(middle.state.snapshot().get("coins", 0))
	_presentation_view(middle).call("_on_party_button_down", 0)
	await _settle_frames(1)
	var party_source_button := _first_texture_button(first_party_slot)
	if party_source_button == null or party_source_button.texture_normal != null:
		push_error("Dragging roster pet should hide the source roster image.")
		_presentation_view(middle).call("_clear_drag_state")
		return false
	if not bool(sell_button.get("visible")) or String(sell_button.get("text")) != "出售":
		push_error("Dragging roster pet should show original Top_Sell sale area.")
		_presentation_view(middle).call("_clear_drag_state")
		return false
	await _presentation_view(middle).call("_drop_dragged_storage_item", _center_of_control(sell_button))
	_presentation_view(middle).call("_clear_drag_state")
	await _settle_seconds(0.2)
	if bool(sell_button.get("visible")):
		push_error("Top_Sell should hide after roster drag completes.")
		return false
	var gold_after := int(middle.state.snapshot().get("coins", 0))
	if gold_after <= gold_before:
		push_error("Dragging roster pet to Top_Sell should dispatch core sale and refund gold.")
		return false
	return true


func _center_of_control(control: Control) -> Vector2:
	var rect := control.get_global_rect()
	return rect.position + rect.size * 0.5


func _first_texture_button(root_node: Node) -> TextureButton:
	var buttons := root_node.find_children("*", "TextureButton", true, false)
	if buttons.is_empty():
		return null
	return buttons[0] as TextureButton


func _slot_record_id(slot: Node) -> String:
	var button := _first_texture_button(slot)
	if button == null:
		return ""
	return _record_ref(Dictionary(button.get_meta("drag_record", {})))


func _record_ref(record: Dictionary) -> String:
	for key in ["id", "unitId", "unit_id", "pet_id", "petId", "instance_id", "instanceId"]:
		var value := String(record.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func _first_unsold_offer_id(middle: Node) -> String:
	var offer_ids := _unsold_offer_ids(middle)
	return String(offer_ids[0]) if not offer_ids.is_empty() else ""


func _seed_second_party_pet(middle: Node) -> bool:
	var roster := Array(middle.state.roster)
	if roster.is_empty():
		return false
	var source := Dictionary(roster[0]).duplicate(true)
	source["id"] = "smoke_party_second"
	source["pet_id"] = String(source.get("pet_id", "pal_002"))
	source["name"] = "Smoke Second Party"
	source["active"] = true
	source["slot"] = 2
	source["bag_slot"] = 0
	source["side"] = "player"
	roster.append(source)
	middle.state.roster = roster
	return true


func _unsold_offer_ids(middle: Node) -> Array:
	var out: Array = []
	for value in Array(middle.state.snapshot().get("shop_offers", [])):
		var offer := Dictionary(value)
		if bool(offer.get("sold", false)):
			continue
		var offer_id := String(offer.get("id", offer.get("offer_id", offer.get("offerId", "")))).strip_edges()
		if offer_id != "":
			out.append(offer_id)
	return out


func _presentation_view(game: Node) -> Node:
	if game != null and game.has_method("get_three_choice_view"):
		return game.call("get_three_choice_view") as Node
	return null


func _roster_slot_for_id(roster: Array, unit_id: String, active: bool) -> int:
	for value in roster:
		var row := Dictionary(value)
		if _record_ref(row) != unit_id:
			continue
		if bool(row.get("active", false)) != active:
			return -1
		return int(row.get("slot", 0)) if active else int(row.get("bag_slot", row.get("bagSlot", 0)))
	return -1


func _settle_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _settle_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _has_runtime_overlay(scene: Node) -> bool:
	return scene.find_child("RuntimeLabel", true, false) != null or scene.find_child("RuntimeIcon", true, false) != null


func _log_contains(lines: Array, text: String) -> bool:
	for value in lines:
		if String(value).contains(text):
			return true
	return false


func _save_capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var image: Image = null
	for _attempt in range(60):
		await process_frame
		var texture := root.get_texture()
		if texture == null:
			continue
		image = texture.get_image()
		if image != null and not image.is_empty():
			var err := image.save_png(path)
			if err != OK:
				push_error("Could not save %s: %s." % [path, error_string(err)])
				return false
			return true
	return false
