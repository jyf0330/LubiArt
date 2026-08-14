extends SceneTree

const BATTLE_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MOCK_SESSION := preload("res://session/mock_game_session.gd")
const BATTLE_SCENE_PROBE := preload("res://tests/helpers/battle_scene_probe.gd")

var _capture_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("UI_SHIELD_STATE_CAPTURE_DIR").strip_edges()
	if _capture_dir == "":
		_fail("UI_SHIELD_STATE_CAPTURE_DIR is required")
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)

	var battle := BATTLE_SCENE.instantiate() as Control
	root.add_child(battle)
	await _settle(8)
	var probe: RefCounted = BATTLE_SCENE_PROBE.new(battle)
	var session: RefCounted = MOCK_SESSION.new({"start_phase": "battle"})
	var snapshot := Dictionary(session.call("current_snapshot"))
	battle.call("render_snapshot", snapshot)
	await _settle(10)
	var opened := Dictionary(probe.call("open_first_pet_detail"))
	if not bool(opened.get("opened", false)):
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
	record["shield"] = 6
	record["max_shield"] = 9
	card.call("set_info", record, portrait)
	await _settle(3)
	_assert_card_state(card, 6.0, 9.0, "6 / 9")
	await _capture("shield_06_of_09.png")

	record["shield"] = 0
	record["max_shield"] = 0
	card.call("set_info", record, portrait)
	await _settle(3)
	_assert_card_state(card, 0.0, 1.0, "0 / 0")
	await _capture("shield_00_of_00.png")

	print("VISIBLE_BATTLE_PET_INFO_CARD_SHIELD_STATES_PASS: %s" % _capture_dir)
	quit(0)


func _assert_card_state(card: Control, expected_value: float, expected_maximum: float, expected_text: String) -> void:
	var shield_bar := card.get_node("ShieldBar") as TextureProgressBar
	assert(is_equal_approx(shield_bar.value, expected_value))
	assert(is_equal_approx(shield_bar.max_value, expected_maximum))
	assert((card.get_node("ShieldBar/ShieldValue") as Label).text == expected_text)
	assert(not (card.get_node("StatsPanel/StatsGrid/HpStat") as Control).visible)
	assert(not (card.get_node("StatsPanel/StatsGrid/ApStat") as Control).visible)
	assert(not (card.get_node("StatsPanel/StatsGrid/ShieldStat") as Control).visible)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var output_path := _capture_dir.path_join(file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		_fail("could not save %s" % file_name)
		return
	print("VISIBLE_BATTLE_PET_INFO_CARD_SHIELD_STATE_SAVED: %s" % output_path)


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	push_error("VISIBLE_BATTLE_PET_INFO_CARD_SHIELD_STATES_FAIL: %s" % message)
	quit(1)
