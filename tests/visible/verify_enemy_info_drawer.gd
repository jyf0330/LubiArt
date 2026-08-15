extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const DebugScene := preload("res://art/scenes/enemy_info_drawer_debug/enemy_info_drawer_debug_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")

var output_dir := ""


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	output_dir = OS.get_environment("ENEMY_INFO_CAPTURE_DIR")
	if output_dir == "":
		push_error("ENEMY_INFO_CAPTURE_DIR is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	await _verify_debug_scene()
	await _verify_battle_scene()
	print("ENEMY_INFO_DRAWER_VISIBLE_PASS")
	quit(0)


func _verify_debug_scene() -> void:
	var debug := DebugScene.instantiate()
	root.add_child(debug)
	await _settle(8)
	await _capture("debug_default.png")
	var hp_slider := debug.get_node("DebugPanel/Margin/Controls/HpSlider") as HSlider
	hp_slider.value = 7
	await _settle(3)
	await _capture("debug_hp_one_digit.png")
	var shield_slider := debug.get_node("DebugPanel/Margin/Controls/ShieldSlider") as HSlider
	shield_slider.value = 18
	await _settle(3)
	await _capture("debug_shield_partial.png")
	debug.get_node("DebugPanel/Margin/Controls/ToggleLogo").emit_signal("pressed")
	await _settle(3)
	await _capture("debug_logo_variant.png")
	debug.get_node("DebugPanel/Margin/Controls/AttackerCount").emit_signal("item_selected", 1)
	await _settle(3)
	await _capture("debug_two_attackers.png")
	debug.queue_free()
	await _settle(3)


func _verify_battle_scene() -> void:
	var battle := BattleScene.instantiate()
	root.add_child(battle)
	await _settle(8)
	var session := MockSession.new({"start_phase": "battle"})
	var snapshot := Dictionary(session.call("current_snapshot"))
	_add_public_preview_fixture(snapshot)
	battle.call("render_snapshot", snapshot)
	await _settle(8)
	var drawer := battle.get_node("EnemyInfoDrawer") as Control
	if drawer == null or not drawer.has_method("set_expanded"):
		push_error("EnemyInfoDrawer unavailable")
		quit(1)
		return
	await _capture("battle_drawer_closed.png")
	drawer.call("set_expanded", true, false)
	await _settle(4)
	await _capture("battle_drawer_open.png")
	var visible_cards := 0
	for index in range(1, 6):
		if (drawer.get_node("CardList/Card%d" % index) as Control).visible:
			visible_cards += 1
	print("ENEMY_INFO_VISIBLE_CARDS=%d" % visible_cards)
	if visible_cards != 5:
		push_error("expected five visible attacked target cards, got %d" % visible_cards)
		quit(1)
		return
	battle.queue_free()
	await _settle(3)


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	var error := root.get_texture().get_image().save_png(output_dir.path_join(name))
	if error != OK:
		push_error("capture failed: %s" % name)
		quit(1)

func _add_public_preview_fixture(snapshot: Dictionary) -> void:
	var board := Dictionary(snapshot.get("board", {}))
	var cells := Array(board.get("cells", []))
	var player_ids: Array[String] = []
	var enemy_indexes: Array[int] = []
	for index in range(cells.size()):
		var cell := Dictionary(cells[index])
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		var side := String(cell.get("side", cell.get("unitSide", "")))
		if unit_id == "":
			continue
		if side == "player" and player_ids.size() < 4:
			player_ids.append(unit_id)
		elif side in ["enemy", "monster"] and enemy_indexes.size() < 5:
			enemy_indexes.append(index)
	if player_ids.is_empty() or enemy_indexes.size() < 5:
		push_error("fixture requires player and five enemy targets")
		quit(1)
		return
	for target_order in range(5):
		var target := Dictionary(cells[enemy_indexes[target_order]]).duplicate(true)
		var previews: Array[Dictionary] = []
		for actor_index in range(player_ids.size()):
			previews.append({
				"actorId": player_ids[actor_index],
				"order": actor_index + 1,
				"targetId": String(target.get("unitId", target.get("unit_id", ""))),
				"hitEnemy": true,
				"preview_type": "enemy",
				"predictedHpFrom": int(target.get("hp", 1)),
				"predictedHpTo": maxi(0, int(target.get("hp", 1)) - target_order - 1),
				"predictedShieldFrom": int(target.get("shield", 0)),
				"predictedShieldTo": maxi(0, int(target.get("shield", 0)) - 1),
			})
		target["previews"] = previews
		cells[enemy_indexes[target_order]] = target
	board["cells"] = cells
	snapshot["board"] = board