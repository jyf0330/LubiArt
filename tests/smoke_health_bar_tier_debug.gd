extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	for _frame in range(4):
		await process_frame
	var session := MockSession.new({"start_phase": "battle"})
	var snapshot := Dictionary(session.call("current_snapshot"))
	battle.call("render_snapshot", snapshot)
	for _frame in range(4):
		await process_frame
	var request := _first_unit_request(snapshot)
	assert(not request.is_empty())
	var overlay := battle.get_node("OverlayHost") as Control
	overlay.call(
		"request_detail",
		Vector2i(request["grid_x"], request["grid_y"]),
		String(request["unit_id"])
	)
	await process_frame
	var info_card := overlay.get_node("BattlePetDetailPanel/Panel/SpriteInfoCard") as Control
	var hud := battle.get_node("Hud") as Control
	var button := hud.get_node("BattleActionPanel/Margin/Content/HealthBarTierButton") as Button
	var expected := ["silver", "gold", "diamond", "bronze"]
	var expected_stars := [2, 3, 4, 1]
	for index in range(expected.size()):
		var tier := String(expected[index])
		button.pressed.emit()
		await process_frame
		assert(String(hud.call("debug_health_bar_tier")) == tier)
		assert(String(overlay.call("get_quality_tier_override")) == tier)
		assert(String(info_card.call("get_quality_key")) == tier)
		assert(int(info_card.call("get_quality_star_count")) == expected_stars[index])
		assert((info_card.get_node("QualityHeader/QualityStars") as Label).text.length() == expected_stars[index])
		assert(button.text == "调试星级：%s" % ["白银", "黄金", "钻石", "青铜"][index])
		for unit in battle.get_node("Board/UnitHost").get_children():
			if unit is Control and unit.visible and unit.has_method("get_health_bar_tier"):
				assert(String(unit.call("get_health_bar_tier")) == tier)
	print("HEALTH_BAR_TIER_DEBUG_SMOKE_PASS")
	quit(0)


func _first_unit_request(snapshot: Dictionary) -> Dictionary:
	var board := Dictionary(snapshot.get("board", {}))
	for cell_value in Array(board.get("cells", [])):
		var cell := Dictionary(cell_value)
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		if unit_id == "":
			continue
		return {
			"unit_id": unit_id,
			"grid_x": int(cell.get("x", cell.get("grid_x", cell.get("col", 0)))),
			"grid_y": int(cell.get("y", cell.get("grid_y", cell.get("row", 0)))),
		}
	return {}
