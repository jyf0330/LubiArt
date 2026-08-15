extends SceneTree

const BATTLE_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MOCK_SESSION := preload("res://session/mock_game_session.gd")
const BATTLE_SCENE_PROBE := preload("res://tests/helpers/battle_scene_probe.gd")


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var capture_dir := OS.get_environment("UI_PRICE_MATRIX_CAPTURE_DIR").strip_edges()
	if capture_dir == "":
		_fail("UI_PRICE_MATRIX_CAPTURE_DIR is required")
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
	var qualities := ["bronze", "silver", "gold", "diamond"]
	var prices := {
		"bronze": [2, 4, 6],
		"silver": [4, 8, 12],
		"gold": [8, 16, 24],
		"diamond": [16, 32, 48],
	}
	for attack_cell_count in range(1, 4):
		for quality in qualities:
			record["quality"] = quality
			record["attack_shape"] = _attack_shape(attack_cell_count)
			card.call("set_info", record, portrait)
			await _settle(3)
			if int(card.call("get_display_price")) != int(prices[quality][attack_cell_count - 1]):
				_fail("price mismatch for %s/%d" % [quality, attack_cell_count])
				return
			await RenderingServer.frame_post_draw
			var file_name := "%d_cell_%s_%02d.png" % [
				attack_cell_count,
				quality,
				int(prices[quality][attack_cell_count - 1]),
			]
			var output_path := capture_dir.path_join(file_name)
			if root.get_texture().get_image().save_png(output_path) != OK:
				_fail("could not save %s" % file_name)
				return
			print("VISIBLE_BATTLE_PET_INFO_PRICE_SAVED: %s" % output_path)

	print("VISIBLE_BATTLE_PET_INFO_PRICE_MATRIX_PASS: %s" % capture_dir)
	quit(0)


func _attack_shape(cell_count: int) -> Dictionary:
	var offsets: Array[Dictionary] = []
	for index in range(cell_count):
		offsets.append({"dr": index - 1, "dc": 1})
	return {"cell_count": cell_count, "offsets": offsets}


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	push_error("VISIBLE_BATTLE_PET_INFO_PRICE_MATRIX_FAIL: %s" % message)
	quit(1)
