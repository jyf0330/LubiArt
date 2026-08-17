extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	root.size = Vector2i(1080, 1920)
	var packed: PackedScene = load("res://art/scenes/app/game.tscn")
	if packed == null:
		push_error("Could not load ysbzs_singleplayer scene.")
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await _settle_frames(3)
	if not _assert_scene_text_absent(scene, ["数据快照", "CSV 快照", "奖励池", "商店池", "夜市基础货架"], "route capture"):
		quit(1)
		return
	if scene.find_child("ExportBattleTraceButton", true, false) == null:
		push_error("Route capture missing battle trace export button.")
		quit(1)
		return
	if not _assert_scene_text_present(scene, "导出战报", "route capture"):
		quit(1)
		return
	if not await _save_capture("res://output/ysbzs_singleplayer_route.png"):
		quit(1)
		return
	var route_event_state = load("res://core/state/game_state.gd").new()
	route_event_state.day = 3
	route_event_state.coins = 10
	scene.set("state", route_event_state)
	scene.render_current_view()
	await _settle_frames(3)
	if not _assert_scene_text_present(scene, "贪婪诅咒", "route event capture"):
		quit(1)
		return
	if not _assert_scene_text_present(scene, "护盾祝福", "route event capture"):
		quit(1)
		return
	if scene.find_child("RouteEventButton_evt_curse_gold", true, false) == null:
		push_error("Route event capture missing visible curse event button.")
		quit(1)
		return
	if scene.find_child("RouteEventButton_evt_shield_bless", true, false) == null:
		push_error("Route event capture missing visible pre-battle event button.")
		quit(1)
		return
	if not await _save_capture("res://output/ysbzs_singleplayer_route_event.png"):
		quit(1)
		return
	scene.set("state", load("res://core/state/game_state.gd").new())
	scene.render_current_view()
	await _settle_frames(3)
	scene.state.dispatch({"type": "PICK_NODE", "nodeId": "node_reward_pet"})
	scene.render_current_view()
	await _settle_frames(10)
	if not _assert_scene_text_absent(scene, ["reward_pT1", "奖励池"], "reward capture"):
		quit(1)
		return
	if not await _save_capture("res://output/ysbzs_singleplayer_reward.png"):
		quit(1)
		return
	var pet_reward_index := _first_reward_index(scene.state, "pet")
	if pet_reward_index < 0:
		push_error("Could not find pet reward for capture.")
		quit(1)
		return
	scene.state.dispatch({"type": "PICK_REWARD", "index": pet_reward_index})
	scene.render_current_view()
	await _settle_frames(2)
	var shop_node_id := _first_route_node_id(scene.state, "shop")
	if shop_node_id == "":
		push_error("Could not find shop route node for capture.")
		quit(1)
		return
	if not scene.state.dispatch({"type": "PICK_NODE", "nodeId": shop_node_id}):
		push_error("Could not enter shop route node for capture: %s." % shop_node_id)
		quit(1)
		return
	scene.render_current_view()
	await _settle_frames(3)
	if String(scene.state.snapshot().get("phase", "")) != "shop":
		push_error("Shop capture did not enter shop phase.")
		quit(1)
		return
	if not _assert_scene_text_present(scene, "离开商店", "shop capture"):
		quit(1)
		return
	if not _assert_scene_text_absent(scene, ["night_base", "基础货架", "货架 "], "shop capture"):
		quit(1)
		return
	if not _roster_cards_inside_capture(scene, 1):
		push_error("Shop capture clips roster cards.")
		quit(1)
		return
	if not await _save_capture("res://output/ysbzs_singleplayer_shop.png"):
		quit(1)
		return
	var shop_offer_id := _first_buyable_offer_id(scene.state)
	if shop_offer_id == "":
		push_error("Could not find buyable shop offer for capture.")
		quit(1)
		return
	if not scene.state.dispatch({"type": "BUY_OFFER", "offer_id": shop_offer_id}):
		push_error("Could not buy shop offer for capture: %s." % shop_offer_id)
		quit(1)
		return
	if not scene.state.dispatch({"type": "EXIT_SHOP"}):
		push_error("Could not exit shop through public command for capture.")
		quit(1)
		return
	var battle_state = load("res://core/state/game_state.gd").new()
	if not battle_state.dispatch({"type": "START_BATTLE"}):
		push_error("Could not start battle fixture for capture.")
		quit(1)
		return
	scene.set("state", battle_state)
	_set_unit_quality_upgrade(scene.state, "pal_002", "G01")
	var preview_enemy_id := _place_first_enemy(scene.state, 3, 5, 80)
	var threat_enemy_placed := false
	for unit in scene.state.units:
		if String(unit.get("side", "")) != "enemy" or String(unit.get("id", "")) == preview_enemy_id:
			continue
		unit["x"] = 2
		unit["y"] = 5
		unit["hp"] = 20
		unit["max_hp"] = max(20, int(unit.get("max_hp", 20)))
		unit["atk"] = 6
		unit["def"] = 0
		unit["shield"] = 0
		threat_enemy_placed = true
		break
	if not threat_enemy_placed:
		push_error("Battle capture could not place threat enemy.")
		quit(1)
		return
	scene.state.dispatch({"type": "SELECT_UNIT", "unitId": "pal_002"})
	scene.state.dispatch({"type": "SELECT_ACTION_SLOT", "index": 0})
	scene.state.dispatch({"type": "SET_ACTION_DIRECTION", "unitId": "pal_002", "slotId": 0, "dir": "right"})
	scene.state.dispatch({"type": "SET_ACTION_AP", "unitId": "pal_002", "slotId": 0, "ap": 2})
	scene.render_current_view()
	await _settle_frames(3)
	if scene.find_child("QualityMode_Guard", true, false) == null:
		push_error("Battle capture missing quality mode button.")
		quit(1)
		return
	if scene.find_child("ActionPreviewSummary", true, false) == null:
		push_error("Battle capture missing action preview summary.")
		quit(1)
		return
	if scene.find_child("SelectedThreatSummary", true, false) == null:
		push_error("Battle capture missing selected threat summary.")
		quit(1)
		return
	var battle_toolbar := scene.find_child("BattleToolbar", true, false)
	if battle_toolbar == null:
		push_error("Battle capture missing battle toolbar.")
		quit(1)
		return
	if battle_toolbar.get_child_count() != 3:
		push_error("Battle capture exposes %d toolbar actions, expected 3 player battle actions." % battle_toolbar.get_child_count())
		quit(1)
		return
	if scene.find_child("AutoPositionButton", true, false) == null:
		push_error("Battle capture missing auto-position toolbar button.")
		quit(1)
		return
	if not _assert_scene_text_absent(scene, ["返回路线"], "battle capture"):
		quit(1)
		return
	if not _assert_scene_text_absent(scene, ["wave_d01_morning", "Wave_d01_morning"], "battle capture"):
		quit(1)
		return
	if not _assert_scene_text_present(scene, "第1天上午对战", "battle capture"):
		quit(1)
		return
	var threatened_cell := scene.find_child("Cell_2_6", true, false)
	if threatened_cell == null or not String(threatened_cell.get("text")).contains("威胁"):
		push_error("Battle capture missing threatened-cell text.")
		quit(1)
		return
	if not await _save_capture("res://output/ysbzs_singleplayer_battle.png"):
		quit(1)
		return
	if not _build_trace_capture(scene):
		quit(1)
		return
	scene.render_current_view()
	await _settle_frames(3)
	if not await _save_capture("res://output/ysbzs_singleplayer_trace.png"):
		quit(1)
		return
	_clear_battle_to_result(scene.state)
	scene.render_current_view()
	await _settle_frames(3)
	if not _assert_scene_text_absent(scene, ["WIN_FAST", "reward_pT1", "reward_fast_clear", "wave_d01_morning", "Wave_d01_morning", "奖励池", "暂无候选", "已回退", "候选"], "battle-end capture"):
		quit(1)
		return
	if not await _save_capture("res://output/ysbzs_singleplayer_battle_end.png"):
		quit(1)
		return
	var day_end_state = load("res://core/state/game_state.gd").new()
	_drive_current_day_to_end(day_end_state)
	if String(day_end_state.snapshot().get("phase", "")) != "day_end":
		push_error("Day-end capture did not reach day_end phase.")
		quit(1)
		return
	scene.set("state", day_end_state)
	scene.render_current_view()
	await _settle_frames(3)
	if not await _save_capture("res://output/ysbzs_singleplayer_day_end.png"):
		quit(1)
		return
	var terminal_state = load("res://core/state/game_state.gd").new()
	if not terminal_state.dispatch({"type": "RUN_FULL_RUN"}):
		push_error("Terminal capture could not run full route.")
		quit(1)
		return
	scene.set("state", terminal_state)
	scene.render_current_view()
	await _settle_frames(3)
	if scene.find_child("NewRunButton", true, false) == null:
		push_error("Terminal capture missing new-run button.")
		quit(1)
		return
	if not await _save_capture("res://output/ysbzs_singleplayer_terminal.png"):
		quit(1)
		return
	print("CAPTURE_SINGLEPLAYER_OK res://output/ysbzs_singleplayer_route.png res://output/ysbzs_singleplayer_route_event.png res://output/ysbzs_singleplayer_reward.png res://output/ysbzs_singleplayer_shop.png res://output/ysbzs_singleplayer_battle.png res://output/ysbzs_singleplayer_trace.png res://output/ysbzs_singleplayer_battle_end.png res://output/ysbzs_singleplayer_day_end.png res://output/ysbzs_singleplayer_terminal.png")
	quit(0)

func _settle_frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _save_capture(path: String) -> bool:
	var image: Image = null
	for _attempt in range(60):
		image = root.get_texture().get_image()
		if image != null and not image.is_empty() and not _is_black_capture(image):
			break
		await process_frame
	if image == null or image.is_empty():
		push_error("Viewport capture is empty: %s" % path)
		return false
	if _is_black_capture(image):
		push_error("Viewport capture is black after waiting: %s" % path)
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save screenshot: %s" % error)
		return false
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		push_error("Screenshot was not written: %s" % absolute_path)
		return false
	return true

func _roster_cards_inside_capture(scene: Node, min_count: int) -> bool:
	var nodes := scene.find_children("Roster_*", "Control", true, false)
	if nodes.size() < min_count:
		push_error("Capture has %d roster cards, expected at least %d." % [nodes.size(), min_count])
		return false
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Capture image unavailable while checking roster cards.")
		return false
	var capture_height := image.get_height()
	var visible_bottom := float(capture_height - 8)
	var scroll := scene.find_child("ShopRosterScroll", true, false)
	if scroll != null and scroll is Control:
		visible_bottom = min(visible_bottom, (scroll as Control).get_global_rect().end.y - 8.0)
	for node in nodes:
		var rect := (node as Control).get_global_rect()
		var inside := rect.position.y >= 0.0 and rect.end.y <= visible_bottom
		if not inside:
			push_error("%s rect y=%.1f..%.1f visible_bottom=%.1f capture_height=%d" % [node.name, rect.position.y, rect.end.y, visible_bottom, capture_height])
			return false
	return true

func _assert_scene_text_absent(scene: Node, needles: Array, context: String) -> bool:
	for needle_value in needles:
		var needle := String(needle_value)
		var offender := _first_text_node_containing(scene, needle)
		if offender != "":
			push_error("%s exposes raw id '%s' in %s." % [context, needle, offender])
			return false
	return true

func _assert_scene_text_present(scene: Node, needle: String, context: String) -> bool:
	if _first_text_node_containing(scene, needle) == "":
		push_error("%s missing text '%s'." % [context, needle])
		return false
	return true

func _first_text_node_containing(node: Node, needle: String) -> String:
	var text := ""
	var text_value = node.get("text")
	if text_value != null:
		text = str(text_value)
	if text.contains(needle):
		return "%s text=%s" % [node.get_path(), text]
	for child in node.get_children():
		var found := _first_text_node_containing(child, needle)
		if found != "":
			return found
	return ""

func _is_black_capture(image: Image) -> bool:
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return true
	var probes := [
		Vector2i(width / 2, height / 2),
		Vector2i(min(width - 1, 40), min(height - 1, 40)),
		Vector2i(max(0, width - 41), min(height - 1, 40)),
		Vector2i(min(width - 1, 40), max(0, height - 41)),
		Vector2i(max(0, width - 41), max(0, height - 41))
	]
	for point in probes:
		var color := image.get_pixelv(point)
		if color.r > 0.01 or color.g > 0.01 or color.b > 0.01:
			return false
	return true

func _build_trace_capture(scene: Node) -> bool:
	var state = scene.state
	var actor: Dictionary = state.unit_by_id("pal_002")
	if actor.is_empty():
		push_error("Trace capture missing pal_002 actor.")
		return false
	_set_unit_quality_upgrade(state, "pal_002", "D21")
	var target_id := _place_first_enemy(state, 3, 5, 80)
	if target_id == "":
		push_error("Trace capture missing enemy target.")
		return false
	if not state.dispatch({"type": "SELECT_UNIT", "unitId": "pal_002"}):
		push_error("Trace capture could not select pal_002.")
		return false
	if not state.dispatch({"type": "SELECT_CELL", "cell": {"c": 3, "r": 5}}):
		push_error("Trace capture could not trigger D21 trace.")
		return false
	return true

func _first_reward_index(state, wanted_type: String) -> int:
	var options: Array = Array(state.snapshot().get("reward_options", []))
	for index in range(options.size()):
		var row := Dictionary(options[index])
		if String(row.get("type", "pet")) == wanted_type:
			return index
	return -1

func _first_route_node_id(state, wanted_type: String) -> String:
	for option in Array(state.snapshot().get("route_options", [])):
		var row := Dictionary(option)
		if String(row.get("nodeType", row.get("type", row.get("kind", "")))) == wanted_type:
			return String(row.get("nodeId", row.get("id", "")))
	return ""

func _first_buyable_offer_id(state) -> String:
	var snap: Dictionary = state.snapshot()
	var coins := int(snap.get("coins", 0))
	var owned_pet_ids := {}
	for pet in Array(snap.get("roster", [])):
		var row := Dictionary(pet)
		var pet_id := String(row.get("pet_id", row.get("id", "")))
		if pet_id != "":
			owned_pet_ids[pet_id] = true
	for offer in Array(snap.get("shop_offers", [])):
		var row := Dictionary(offer)
		var offer_id := String(row.get("offer_id", row.get("id", "")))
		if offer_id == "":
			continue
		if bool(row.get("sold", false)):
			continue
		if int(row.get("price", 0)) > coins:
			continue
		var pet_id := String(row.get("pet_id", ""))
		if pet_id != "" and not owned_pet_ids.has(pet_id):
			return offer_id
	for offer in Array(snap.get("shop_offers", [])):
		var row := Dictionary(offer)
		var offer_id := String(row.get("offer_id", row.get("id", "")))
		if offer_id == "":
			continue
		if bool(row.get("sold", false)):
			continue
		if int(row.get("price", 0)) > coins:
			continue
		return offer_id
	return ""

func _clear_battle_to_result(state) -> void:
	var guard := 0
	while String(state.snapshot().get("phase", "")) == "battle" and guard < 12:
		for unit in state.units:
			if String(unit.get("side", "")) == "enemy":
				unit["hp"] = 0
		state._check_battle_end()
		guard += 1

func _drive_current_day_to_end(state) -> void:
	var starting_day := int(state.snapshot().get("day", 1))
	var guard := 0
	while int(state.snapshot().get("day", starting_day)) == starting_day and String(state.snapshot().get("phase", "")) != "day_end" and guard < 40:
		guard += 1
		var snap: Dictionary = state.snapshot()
		match String(snap.get("phase", "")):
			"route":
				var options := Array(snap.get("route_options", []))
				if options.is_empty():
					push_error("Day-end capture has no route option before day end.")
					return
				var option := Dictionary(options[0])
				if not state.dispatch({"type": "PICK_NODE", "nodeId": String(option.get("nodeId", option.get("id", "")))}):
					push_error("Day-end capture could not pick route option.")
					return
			"shop":
				if not state.dispatch({"type": "EXIT_SHOP"}):
					push_error("Day-end capture could not exit shop.")
					return
			"reward":
				if not state.dispatch({"type": "PICK_REWARD", "index": 0}):
					push_error("Day-end capture could not pick reward.")
					return
			"battle":
				_clear_battle_to_result(state)
			"battle_end":
				if not state.dispatch({"type": "CONTINUE_AFTER_BATTLE"}):
					push_error("Day-end capture could not continue after battle.")
					return
			_:
				push_error("Day-end capture reached unsupported phase: %s" % String(snap.get("phase", "")))
				return

func _set_unit_quality_upgrade(state, unit_id: String, upgrade_id: String) -> void:
	var unit: Dictionary = state.unit_by_id(unit_id)
	if unit.is_empty():
		return
	for item in Array(Dictionary(state.game_data.get("quality", {})).get("upgrades", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("id", "")) != upgrade_id:
			continue
		unit["quality_upgrade"] = row.duplicate(true)
		var progression := Dictionary(unit.get("quality_progression", {}))
		progression["upgrade_id"] = upgrade_id
		progression["upgrade_name"] = String(row.get("name", upgrade_id))
		unit["quality_progression"] = progression
		return

func _place_first_enemy(state, x: int, y: int, hp: int) -> String:
	var picked_id := ""
	for unit in state.units:
		if String(unit.get("side", "")) != "enemy":
			continue
		if picked_id == "":
			unit["x"] = x
			unit["y"] = y
			unit["hp"] = hp
			unit["max_hp"] = max(hp, int(unit.get("max_hp", hp)))
			unit["def"] = 0
			unit["shield"] = 0
			picked_id = String(unit.get("id", ""))
		else:
			unit["hp"] = 0
	return picked_id
