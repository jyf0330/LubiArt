extends SceneTree

const BATTLE_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MOCK_SESSION := preload("res://session/mock_game_session.gd")
const BATTLE_SCENE_PROBE := preload("res://tests/helpers/battle_scene_probe.gd")
const CARD_RECT := Rect2i(1540, 80, 380, 820)


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var capture_dir := OS.get_environment("UI_ATTACK_SHAPE_CAPTURE_DIR").strip_edges()
	if capture_dir == "":
		_fail("UI_ATTACK_SHAPE_CAPTURE_DIR is required")
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)

	var battle := BATTLE_SCENE.instantiate() as Control
	root.add_child(battle)
	await _settle(8)
	var probe: RefCounted = BATTLE_SCENE_PROBE.new(battle)
	var session: RefCounted = MOCK_SESSION.new({"start_phase": "battle"})
	var snapshot := Dictionary(session.call("current_snapshot"))
	battle.call("render_snapshot", snapshot)
	await _settle(10)
	if not bool(Dictionary(probe.call("open_first_pet_detail")).get("opened", false)):
		_fail("pet detail could not be opened")
		return
	battle.call("render_snapshot", snapshot)
	await _settle(8)

	var detail := battle.get_node_or_null("OverlayHost/BattlePetDetailPanel") as Control
	if detail == null or not detail.visible:
		_fail("battle pet detail panel is unavailable")
		return
	var card := detail.call("get_info_card") as Control
	var portrait := (card.get_node("PortraitPanel/Portrait") as TextureRect).texture
	var record := Dictionary(detail.call("get_detail_snapshot"))
	var battle_data := Dictionary(snapshot.get("battle", {}))
	var shape_catalog := Array(battle_data.get(
		"shape_catalog",
		battle_data.get("shapeCatalog", [])
	))
	if shape_catalog.size() != 19:
		_fail("expected 19 attack shapes, got %d" % shape_catalog.size())
		return

	var requested_id := OS.get_environment("UI_ATTACK_SHAPE_SAMPLE_ID").strip_edges()
	var captured_count := 0
	for shape_value in shape_catalog:
		var shape := Dictionary(shape_value)
		var shape_id := str(shape.get("shape_id", shape.get("shapeId", ""))).pad_zeros(2)
		if requested_id != "" and shape_id != requested_id.pad_zeros(2):
			continue
		record["attack_shape"] = shape
		card.call("set_info", record, portrait)
		await _settle(3)
		var expected_hits := Array(shape.get("offsets", [])).size()
		var target_indices := Array(card.call("get_target_cell_indices"))
		if target_indices.size() != expected_hits:
			_fail("shape %s lost targets: expected %d, got %d" % [
				shape_id,
				expected_hits,
				target_indices.size(),
			])
			return
		for index in target_indices:
			if int(index) < 0 or int(index) >= int(card.call("get_attack_shape_cell_count")):
				_fail("shape %s produced an out-of-range target index" % shape_id)
				return
		await RenderingServer.frame_post_draw
		var full_image := root.get_texture().get_image()
		var full_path := capture_dir.path_join("shape_%s_full_1920x1080.png" % shape_id)
		if full_image.save_png(full_path) != OK:
			_fail("could not save full screenshot for shape %s" % shape_id)
			return
		var crop_path := capture_dir.path_join("shape_%s_card_380x820.png" % shape_id)
		if full_image.get_region(CARD_RECT).save_png(crop_path) != OK:
			_fail("could not save card crop for shape %s" % shape_id)
			return
		captured_count += 1
		print("VISIBLE_BATTLE_PET_ATTACK_SHAPE_SAVED: %s" % crop_path)

	var expected_capture_count := 1 if requested_id != "" else 19
	if captured_count != expected_capture_count:
		_fail("expected %d captures, got %d" % [expected_capture_count, captured_count])
		return
	print("VISIBLE_BATTLE_PET_ATTACK_SHAPES_PASS: %s" % capture_dir)
	quit(0)


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	push_error("VISIBLE_BATTLE_PET_ATTACK_SHAPES_FAIL: %s" % message)
	quit(1)
