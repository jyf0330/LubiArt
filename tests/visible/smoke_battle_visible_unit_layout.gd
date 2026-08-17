extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var packed := load("res://art/scenes/app/game.tscn") as PackedScene
	if packed == null:
		_fail("Could not load ysbzs_singleplayer scene.")
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await _settle_seconds(0.8)
	var middle := scene
	if middle == null:
		_fail("Artist UI middle controller is missing.")
		return
	middle.state.reset()
	if not _prepare_four_active_roster(middle):
		_fail("Could not prepare four active pets for battle acceptance.")
		return
	middle.state.node_index = 3
	middle.state.route_options = middle.state._build_route_options()
	middle.call("render_current_view")
	await _settle_seconds(0.8)

	var battle_button := _find_route_button(scene, "battle")
	if battle_button == null:
		_fail("Route choices do not expose a battle entry.")
		return
	battle_button.emit_signal("pressed")
	if not await _wait_for_phase(middle, "battle", 2.0):
		_fail("Battle route did not enter battle phase.")
		return
	var battle_flow := await _wait_for_battle_flow(scene, 2.0)
	if battle_flow == null:
		_fail("BattleArtScene scene is missing or hidden.")
		return
	var unit_host := battle_flow.get_node_or_null("Board/UnitHost") as Control
	if unit_host == null:
		_fail("BattleArtScene Board/UnitHost is missing.")
		return

	var unit_count := 0
	var player_pet_count := 0
	for unit_value in unit_host.find_children("*", "Control", true, false):
		var unit := unit_value as Control
		if unit == null or not unit.has_method("get_unit_id"):
			continue
		unit_count += 1
		if String(unit.get("side")) == "player":
			player_pet_count += 1
		var frame := unit.get_node_or_null("CompleteBattleCreaturePrefab/01_UnitVisual/SelectionFrame") as TextureRect
		var sprite := unit.get_node_or_null("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
		if unit.size.x <= 1.0 or unit.size.y <= 1.0:
			_fail("BattleUnit %s has collapsed size %s." % [unit.call("get_unit_id"), unit.size])
			return
		if frame == null or frame.size.x <= 1.0 or frame.size.y <= 1.0:
			_fail("BattleUnit %s has no visible frame rect; unit=%s frame=%s." % [unit.call("get_unit_id"), unit.size, frame.size if frame != null else Vector2.ZERO])
			return
		if sprite == null or sprite.texture == null or sprite.size.x <= 1.0 or sprite.size.y <= 1.0:
			_fail("BattleUnit %s has no visible pet sprite rect; unit=%s sprite=%s." % [unit.call("get_unit_id"), unit.size, sprite.size if sprite != null else Vector2.ZERO])
			return
		var sprite_visible_rect := unit.call("get_battle_sprite_visible_rect") as Rect2
		for stat_rect_value in unit.call("get_battle_stat_rects") as Array:
			var stat_rect := Rect2(stat_rect_value)
			if stat_rect.intersection(sprite_visible_rect).get_area() > 0.01:
				_fail("BattleUnit %s status HUD overlaps creature art; stat=%s sprite=%s." % [unit.call("get_unit_id"), stat_rect, sprite_visible_rect])
				return

	if unit_count == 0:
		_fail("Battle board contains no unit prefabs.")
		return
	if player_pet_count != 4:
		_fail("Battle acceptance requires 4 deployed player pets, got %d." % player_pet_count)
		return
	var action_panel := battle_flow.find_child("BattleActionPanel", true, false) as Control
	var skill_grid := action_panel.find_child("SkillQueueGrid", true, false) as GridContainer if action_panel != null else null
	if action_panel == null or skill_grid == null or skill_grid.get_child_count() != 8:
		_fail("Battle action panel must expose the authored eight-slot shared skill bar.")
		return
	var initial_snapshot := Dictionary(middle.state.snapshot())
	if not _assert_shared_skill_bar(initial_snapshot, skill_grid):
		return
	if not await _save_capture("res://output/party_skill_control/default.png"):
		_fail("Could not save the default shared-bar evidence.")
		return

	var initial_ids := _entry_ids(Array(initial_snapshot.get("skillControlBar", [])))
	(skill_grid.get_child(0) as Button).emit_signal("pressed")
	(skill_grid.get_child(2) as Button).emit_signal("pressed")
	if not await _wait_for_reorder(middle, initial_ids, 3.0):
		_fail("Shared-bar slot clicks did not submit and apply one authoritative reorder.")
		return
	if not await _save_capture("res://output/party_skill_control/reordered.png"):
		_fail("Could not save the reordered shared-bar evidence.")
		return

	var all_out := action_panel.find_child("AllOutButton", true, false) as Button
	if all_out == null or all_out.disabled:
		_fail("The shared skill bar must be executable without selecting one pet.")
		return
	all_out.emit_signal("pressed")
	if not await _wait_for_input_lock(battle_flow, true, 3.0):
		_fail("Authoritative all-out execution did not lock battle input.")
		return
	if not await _save_capture("res://output/party_skill_control/executing.png"):
		_fail("Could not save the executing shared-bar evidence.")
		return
	if not await _wait_for_input_lock(battle_flow, false, 25.0):
		_fail("Authoritative Trace presentation did not settle and unlock input.")
		return
	if String(action_panel.call("feedback_text")).find("结果") < 0:
		_fail("Settled shared-bar execution does not expose authoritative result feedback.")
		return
	if not await _save_capture("res://output/party_skill_control/result.png"):
		_fail("Could not save the shared-bar result evidence.")
		return
	print("SMOKE_BATTLE_VISIBLE_UNIT_LAYOUT_OK units=%d entries=8" % unit_count)
	if _should_keep_open():
		print("SMOKE_BATTLE_VISIBLE_UNIT_LAYOUT_KEEP_OPEN")
		return
	quit(0)


func _prepare_four_active_roster(middle: Node) -> bool:
	var existing_pet_ids := {}
	for value in Array(middle.state.snapshot().get("roster", [])):
		var row := Dictionary(value)
		existing_pet_ids[String(row.get("pet_id", row.get("id", "")))] = true
	for value in Array(middle.state.game_data.get("shop_offers", [])):
		if _active_roster_count(middle) >= 4:
			break
		var offer := Dictionary(value).duplicate(true)
		var pet_id := String(offer.get("pet_id", offer.get("id", "")))
		if pet_id == "" or existing_pet_ids.has(pet_id):
			continue
		middle.state.call("_add_pet_to_roster", offer, "battle_visible_fixture", "party")
		existing_pet_ids[pet_id] = true
	return _active_roster_count(middle) == 4


func _active_roster_count(middle: Node) -> int:
	var count := 0
	for value in Array(middle.state.snapshot().get("roster", [])):
		if bool(Dictionary(value).get("active", false)):
			count += 1
	return count


func _assert_shared_skill_bar(snapshot: Dictionary, skill_grid: GridContainer) -> bool:
	var queue := Array(snapshot.get("skillControlBar", []))
	if queue.size() != 8:
		_fail("Four deployed pets must project exactly eight A/B entries, got %d." % queue.size())
		return false
	for index in range(queue.size()):
		var entry := Dictionary(queue[index])
		var button := skill_grid.get_child(index) as Button
		var unit_name := String(entry.get("unitName", ""))
		var slot := String(entry.get("skillSlot", "")).to_upper()
		var label := String(entry.get("label", ""))
		if button == null or not button.text.contains(unit_name) or not button.text.contains(slot) or not button.text.contains(label):
			_fail("Shared skill slot %d must display pet, A/B, and skill label; got %s." % [index + 1, button.text if button != null else "<missing>"])
			return false
	return true


func _entry_ids(queue: Array) -> Array[String]:
	var result: Array[String] = []
	for entry_value in queue:
		result.append(String(Dictionary(entry_value).get("entryId", "")))
	return result


func _wait_for_reorder(middle: Node, initial_ids: Array[String], timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		var current_ids := _entry_ids(Array(middle.state.snapshot().get("skillControlBar", [])))
		if current_ids.size() == initial_ids.size() and current_ids != initial_ids:
			return true
		await process_frame
	return false


func _wait_for_input_lock(battle_flow: Control, expected: bool, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if bool(battle_flow.call("is_battle_input_locked")) == expected:
			return true
		await process_frame
	return false


func _find_route_button(scene: Node, kind: String) -> BaseButton:
	for node in scene.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) == "CHOOSE_ROUTE" and String(button.get_meta("route_kind", "")).to_lower() == kind:
			return button
	return null


func _wait_for_phase(middle: Node, phase: String, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if String(middle.state.snapshot().get("phase", "")) == phase:
			return true
		await process_frame
	return false


func _wait_for_battle_flow(scene: Node, timeout_seconds: float) -> Control:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		var battle_flow := scene.find_child("BattleArtScene", true, false) as Control
		if battle_flow != null and battle_flow.visible:
			return battle_flow
		await process_frame
	return null


func _settle_seconds(seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(seconds * 1000.0):
		await process_frame


func _save_capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	return image != null and image.save_png(path) == OK


func _should_keep_open() -> bool:
	for arg in OS.get_cmdline_args():
		if String(arg) == "--keep-open":
			return true
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "--keep-open":
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
