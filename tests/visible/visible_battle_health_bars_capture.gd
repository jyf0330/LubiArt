extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	for _frame in range(8):
		await process_frame
	var session := MockSession.new({"start_phase": "battle"})
	var snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	var board := Dictionary(snapshot.get("board", {})).duplicate(true)
	var cells := Array(board.get("cells", [])).duplicate(true)
	var changed_player := false
	var changed_enemy := false
	for index in range(cells.size()):
		var cell := Dictionary(cells[index]).duplicate(true)
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		if unit_id == "":
			continue
		var unit_side := String(cell.get("side", cell.get("unitSide", ""))).to_lower()
		var max_hp := maxi(1, int(cell.get("max_hp", cell.get("maxHp", cell.get("hp", 1)))))
		if not changed_player and unit_side in ["player", "ally"]:
			cell["hp"] = max_hp
			cell["shield"] = maxi(1, int(round(max_hp * 0.22)))
			cell["max_hp"] = max_hp
			changed_player = true
		elif not changed_enemy and not unit_side in ["player", "ally", "hero", "hero_leader", "player_leader"]:
			cell["hp"] = maxi(1, int(round(max_hp * 0.34)))
			cell["shield"] = maxi(1, int(round(max_hp * 0.30)))
			cell["max_hp"] = max_hp
			changed_enemy = true
		cells[index] = cell
	board["cells"] = cells
	snapshot["board"] = board
	battle.call("render_snapshot", snapshot)
	for _frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw

	var player_bar_found := false
	var enemy_bar_found := false
	for child in battle.get_node("Board/UnitHost").get_children():
		var unit := child as Control
		if unit == null or not unit.visible:
			continue
		var health := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health") as ProgressBar
		var shield := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield") as ProgressBar
		var fill := health.get_theme_stylebox("fill") as StyleBoxFlat
		var shield_fill := shield.get_theme_stylebox("fill") as StyleBoxFlat
		if shield_fill == null or absf(shield_fill.bg_color.r - shield_fill.bg_color.g) >= 0.04:
			push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: shield is not gray-white")
			quit(1)
			return
		var unit_data := Dictionary(unit.get("cell_data"))
		var current_shield := maxi(0, int(unit_data.get("shield", 0)))
		if current_shield > 0:
			var expected_shield_x := health.position.x \
				+ health.size.x * float(health.value / health.max_value)
			var expected_shield_width := health.size.x \
				* float(current_shield) / float(health.max_value)
			if not shield.visible \
					or not is_equal_approx(shield.position.x, expected_shield_x) \
					or not is_equal_approx(shield.size.x, expected_shield_width):
				push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: shield is not a continuous segment")
				quit(1)
				return
		var unit_side := String(unit.get("side")).to_lower()
		if unit_side in ["player", "ally", "hero", "hero_leader", "player_leader"]:
			if current_shield > 0 and not is_equal_approx(
				shield.position.x + shield.size.x,
				health.position.x + health.size.x
			):
				push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: full-health opening shield is hidden")
				quit(1)
				return
			player_bar_found = player_bar_found or (fill != null and fill.bg_color.g > fill.bg_color.r)
		else:
			enemy_bar_found = enemy_bar_found or (fill != null and fill.bg_color.r > fill.bg_color.g)
	if not player_bar_found or not enemy_bar_found:
		push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: side colors were not both present")
		quit(1)
		return

	var output_dir := OS.get_environment("BATTLE_HEALTH_BAR_CAPTURE_DIR").strip_edges()
	if output_dir == "":
		output_dir = ProjectSettings.globalize_path("res://output/health_bar_battle_qa/tiers")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var hud := battle.get_node("Hud") as Control
	var tier_button := hud.get_node("BattleActionPanel/Margin/Content/HealthBarTierButton") as Button
	var tier_ids := ["bronze", "silver", "gold", "diamond"]
	for tier_index in range(tier_ids.size()):
		if tier_index > 0:
			tier_button.pressed.emit()
			await process_frame
		var tier := String(tier_ids[tier_index])
		for child in battle.get_node("Board/UnitHost").get_children():
			if child is Control and child.visible and child.has_method("get_health_bar_tier"):
				assert(String(child.call("get_health_bar_tier")) == tier)
		await _capture(output_dir.path_join("health_bar_%02d_%s.png" % [tier_index + 1, tier]))
	print("VISIBLE_BATTLE_HEALTH_BARS_PASS: %s" % output_dir)
	quit(0)


func _capture(output_path: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: %s" % error_string(error))
		quit(1)
