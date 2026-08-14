extends SceneTree

const BATTLE_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MOCK_SESSION := preload("res://session/mock_game_session.gd")
const BATTLE_SCENE_PROBE := preload("res://tests/helpers/battle_scene_probe.gd")
const POINTER_CURSOR_SIZE := Vector2(64.0, 64.0)
const POINTER_CURSOR_HOTSPOT := Vector2(15.0, 8.0)
const MINIMUM_TOOLTIP_FONT_SIZE := 24

var _capture_dir := ""
var _expect_enabled := false
var _case_start := 1
var _case_end := 9


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("UI_TOOLTIP_CAPTURE_DIR").strip_edges()
	_expect_enabled = OS.get_environment("UI_TOOLTIP_EXPECT_ENABLED") == "1"
	_case_start = maxi(1, int(OS.get_environment("UI_TOOLTIP_CASE_START")))
	_case_end = int(OS.get_environment("UI_TOOLTIP_CASE_END"))
	if _case_end <= 0:
		_case_end = 9
	if _capture_dir == "":
		_fail("UI_TOOLTIP_CAPTURE_DIR is required")
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
	record["element"] = "dark"
	record["quality"] = "diamond"
	record["quality_progression"] = {"upgrade_selection": "legacy_first"}
	card.call("set_info", record, portrait)
	await _settle(3)

	await _capture_case(1, card.get_node("PortraitPanel/ElementIcon") as Control, "01_element.png")
	await _capture_case(2, card.get_node("HealthBar") as Control, "02_health.png")
	await _capture_case(3, card.get_node("ShieldBar") as Control, "03_shield.png")
	await _capture_case(4, card.get_node("AttackRangePanel") as Control, "04_attack_range.png")
	await _capture_case(5, card.get_node("TraitSlots/TraitSlotSilver") as Control, "05_trait_meaning.png")

	record["quality"] = "bronze"
	card.call("set_info", record, portrait)
	await _settle(3)
	await _capture_case(6, card.get_node("TraitSlots/TraitSlotGold") as Control, "06_empty_trait_unlock.png")
	await _capture_case(7, card.get_node("StatsPanel/StatsGrid/AttackStat") as Control, "07_attack.png")
	await _capture_case(8, card.get_node("StatsPanel/StatsGrid/DefenseStat") as Control, "08_defense.png")
	await _capture_case(9, card.get_node("StatsPanel/StatsGrid/RegenStat") as Control, "09_regen.png")

	print("VISIBLE_BATTLE_PET_INFO_CARD_TOOLTIPS_PASS: %s" % _capture_dir)
	quit(0)


func _hover_and_capture(control: Control, file_name: String) -> void:
	if _expect_enabled:
		assert(control.mouse_filter == Control.MOUSE_FILTER_STOP)
		assert(control.tooltip_text.strip_edges() != "")
	var outside := Vector2(1200.0, 1000.0)
	Input.warp_mouse(Vector2i(outside))
	_push_mouse_motion(outside)
	await create_timer(0.12).timeout
	var center := control.get_global_rect().get_center()
	Input.warp_mouse(Vector2i(center))
	_push_mouse_motion(center)
	await create_timer(1.15).timeout
	if _expect_enabled:
		var tooltip_popup := _find_tooltip_popup(control)
		assert(tooltip_popup != null)
		assert(tooltip_popup.visible)
		var popup_rect := Rect2(Vector2(tooltip_popup.position), Vector2(tooltip_popup.size))
		var cursor_rect := Rect2(center - POINTER_CURSOR_HOTSPOT, POINTER_CURSOR_SIZE)
		assert(not popup_rect.intersects(cursor_rect, true))
		var tooltip_label := _find_tooltip_label(tooltip_popup)
		assert(tooltip_label != null)
		assert(tooltip_label.get_theme_font_size("font_size") >= MINIMUM_TOOLTIP_FONT_SIZE)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1920, 1080):
		_fail("unexpected capture size for %s" % file_name)
		return
	var output_path := _capture_dir.path_join(file_name)
	if image.save_png(output_path) != OK:
		_fail("could not save %s" % output_path)
		return
	print("VISIBLE_BATTLE_PET_INFO_CARD_TOOLTIP_SAVED: %s" % output_path)


func _capture_case(index: int, control: Control, file_name: String) -> void:
	if index < _case_start or index > _case_end:
		return
	await _hover_and_capture(control, file_name)


func _push_mouse_motion(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)


func _find_tooltip_popup(control: Control) -> PopupPanel:
	for child in control.get_children():
		if child is PopupPanel:
			return child as PopupPanel
	return null


func _find_tooltip_label(node: Node) -> Label:
	if node is Label:
		return node as Label
	for child in node.get_children():
		var label := _find_tooltip_label(child)
		if label != null:
			return label
	return null


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	push_error("VISIBLE_BATTLE_PET_INFO_CARD_TOOLTIPS_FAIL: %s" % message)
	quit(1)
