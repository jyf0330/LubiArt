extends SceneTree


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
	var panel := scene.find_child("BazaarInfoPanel", true, false)
	if middle == null or panel == null or not panel.has_method("get_summary_text"):
		push_error("Bazaar information smoke could not find the live information panel.")
		quit(1)
		return
	if not String(panel.call("get_summary_text")).contains("路线"):
		push_error("Bazaar information panel should render route context.")
		quit(1)
		return
	if not middle.state.dispatch({"type": "ENTER_SHOP", "poolId": "night_base", "slots": 5}):
		push_error("Bazaar information smoke could not enter shop through core command.")
		quit(1)
		return
	middle.state.active_stall = {
		"id": "night_base",
		"name": "夜市商人",
		"tags": ["通用", "夜市"],
		"slots": 5,
		"price_rule": "标准价格",
	}
	middle.call("render_current_view")
	await create_timer(0.3).timeout
	var shop_summary := String(panel.call("get_summary_text"))
	var refresh_button := panel.find_child("RefreshButton", true, false) as BaseButton
	var primary_button := panel.find_child("PrimaryButton", true, false) as BaseButton
	if not _assert_passive_panel_mouse_filters(panel, refresh_button, primary_button):
		quit(1)
		return
	if not shop_summary.contains("刷新") or refresh_button == null or not refresh_button.visible:
		push_error("Bazaar information panel should render shop prices and refresh command, got %s." % shop_summary)
		quit(1)
		return
	var first_offer := Dictionary(Array(middle.state.snapshot().get("shop_offers", []))[0])
	if not shop_summary.contains("夜市商人") or not shop_summary.contains("通用 / 夜市"):
		push_error("Bazaar information panel should show the current stall identity and tags, got %s." % shop_summary)
		quit(1)
		return
	if not shop_summary.contains("2金币"):
		push_error("Bazaar information panel should show core next_refresh_cost=2, got %s." % shop_summary)
		quit(1)
		return
	if not shop_summary.contains(String(first_offer.get("quality", ""))):
		push_error("Bazaar information panel should show the public quality of shop offers, got %s." % shop_summary)
		quit(1)
		return
	var log_size := Array(middle.state.snapshot().get("log_lines", [])).size()
	refresh_button.emit_signal("pressed")
	await create_timer(0.3).timeout
	if Array(middle.state.snapshot().get("log_lines", [])).size() <= log_size:
		push_error("Bazaar information refresh button should dispatch ROLL_SHOP.")
		quit(1)
		return
	if not await _assert_bag_pagination(scene, middle, panel):
		quit(1)
		return
	if String(middle.state.snapshot().get("phase", "")) == "shop":
		var event_button := panel.find_child("PrimaryButton", true, false) as BaseButton
		var events := Array(middle.state.snapshot().get("shop_events", []))
		if not events.is_empty() and (event_button == null or not event_button.visible):
			push_error("Bazaar information panel should expose the currently available shop event.")
			quit(1)
			return
	if DisplayServer.get_name() != "headless":
		var image := get_root().get_texture().get_image()
		if image == null or image.save_png("res://output/bazaar_information_surfaces.png") != OK:
			push_error("Could not capture bazaar information panel.")
			quit(1)
			return
	if not middle.state.dispatch({"type": "EXIT_SHOP"}):
		push_error("Bazaar information smoke could not leave shop through core command.")
		quit(1)
		return
	if not middle.state.dispatch({"type": "START_BATTLE"}) or not middle.state.dispatch({"type": "RUN_BATTLE"}):
		push_error("Bazaar information smoke could not create battle result state.")
		quit(1)
		return
	middle.call("render_current_view")
	await create_timer(0.3).timeout
	var result_summary := String(panel.call("get_summary_text"))
	if not result_summary.contains("战斗结算") or not result_summary.contains("金币"):
		push_error("Bazaar information panel should render terminal battle result, got %s." % result_summary)
		quit(1)
		return
	print("SMOKE_BAZAAR_INFORMATION_OK")
	if DisplayServer.get_name() == "headless":
		quit(0)


func _assert_passive_panel_mouse_filters(panel: Control, refresh_button: BaseButton, primary_button: BaseButton) -> bool:
	for path in ["Margin", "Margin/Content", "Margin/Content/Title", "Margin/Content/Summary", "Margin/Content/Actions"]:
		var passive := panel.get_node_or_null(path) as Control
		if passive == null or passive.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			push_error("Bazaar passive surface must ignore mouse input: %s" % path)
			return false
	if panel.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		push_error("Bazaar panel root must not block authored controls behind it.")
		return false
	for button in [refresh_button, primary_button]:
		if button == null or button.mouse_filter != Control.MOUSE_FILTER_STOP:
			push_error("Bazaar action buttons must keep receiving mouse input.")
			return false
	return true


func _assert_bag_pagination(scene: Node, middle: Node, panel: Node) -> bool:
	var view := middle.call("get_three_choice_view") as Control
	if view == null or not view.has_method("_apply_bag_page"):
		push_error("Bag pagination smoke needs the formal three-choice page API: %s." % str(view))
		return false
	var roster := Array(middle.state.snapshot().get("roster", []))
	if roster.is_empty():
		push_error("Bag pagination smoke needs a roster fixture.")
		return false
	for index in range(9):
		var pet := Dictionary(roster[0]).duplicate(true)
		pet["id"] = "ui_bench_%d" % index
		pet["name"] = "候补%d" % (index + 1)
		pet["active"] = false
		pet["bag_slot"] = index + 1
		middle.state.roster.append(pet)
	middle.call("render_current_view")
	await view.call("_on_bag_pressed")
	await create_timer(1.4).timeout
	var first_slot := scene.find_child("Bag_Slot", true, false) as Control
	var first_button := _first_texture_button(first_slot)
	var first_id := String(Dictionary(first_button.get_meta("drag_record", {})).get("id", "")) if first_button != null else ""
	if not String(panel.call("get_summary_text")).contains("第1/2页") or first_id == "":
		push_error("Bag information panel should show the first page of a nine-pet bench.")
		return false
	var next_button := panel.find_child("PrimaryButton", true, false) as BaseButton
	if next_button == null or not next_button.visible:
		push_error("Bag information panel should expose its next-page command.")
		return false
	var ready_elapsed := 0.0
	while ready_elapsed < 3.0 and (bool(view.get("_is_transitioning")) or bool(view.get("_is_toggling_bag"))):
		await create_timer(0.05).timeout
		ready_elapsed += 0.05
	if bool(view.get("_is_transitioning")) or bool(view.get("_is_toggling_bag")):
		push_error("Bag information panel did not settle before pagination.")
		return false
	var page_command := Dictionary(panel.get("_primary_command"))
	if String(page_command.get("type", "")) != "UI_SET_BAG_PAGE":
		push_error("Bag information panel should publish a semantic page command.")
		return false
	# Use the same semantic page application method as the production signal
	# receiver. Synthetic mouse/button signals are not a reliable click
	# substitute in headless Godot runs.
	view.call("_apply_bag_page", int(page_command.get("page", 0)), Dictionary(middle.state.snapshot()))
	var second_id := ""
	var elapsed := 0.0
	while elapsed < 2.0:
		await create_timer(0.05).timeout
		var refreshed_slot := scene.find_child("Bag_Slot", true, false) as Control
		var refreshed_button := _first_texture_button(refreshed_slot)
		second_id = String(Dictionary(refreshed_button.get_meta("drag_record", {})).get("id", "")) if refreshed_button != null else ""
		if String(panel.call("get_summary_text")).contains("第2/2页") and second_id != "" and second_id != first_id:
			break
		elapsed += 0.05
	if not String(panel.call("get_summary_text")).contains("第2/2页") or second_id == first_id:
		push_error("Bag next-page command should swap the visible eight art slots without mutating core roster records.")
		return false
	return true


func _first_texture_button(root_node: Node) -> TextureButton:
	if root_node == null:
		return null
	if root_node is TextureButton:
		return root_node as TextureButton
	var buttons := root_node.find_children("*", "TextureButton", true, false)
	return buttons[0] as TextureButton if not buttons.is_empty() else null
