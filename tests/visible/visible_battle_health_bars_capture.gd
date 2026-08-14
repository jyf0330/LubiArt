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
	for child in battle.get_node("Board/UnitHost").get_children():
		if child.has_method("stop_damage_preview"):
			child.call("stop_damage_preview")
	await process_frame
	await RenderingServer.frame_post_draw

	var player_bar_found := false
	var enemy_bar_found := false
	var player_pixel_coverage_found := false
	var enemy_pixel_coverage_found := false
	var viewport_image := root.get_texture().get_image()
	for child in battle.get_node("Board/UnitHost").get_children():
		var unit := child as Control
		if unit == null or not unit.visible:
			continue
		var health := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health") as ProgressBar
		var shield := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield") as ProgressBar
		var fill := health.get_theme_stylebox("fill") as StyleBoxFlat
		var shield_fill := shield.get_theme_stylebox("fill") as StyleBoxFlat
		if shield.z_index <= (health.get_node("Icon") as TextureRect).z_index:
			push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: shield is covered by the frame")
			quit(1)
			return
		if shield_fill == null or not shield_fill.bg_color.is_equal_approx(Color("cbdbfc")):
			push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: shield does not use the authored blue-gray")
			quit(1)
			return
		var unit_data := Dictionary(unit.get("cell_data"))
		var current_shield := maxi(0, int(unit_data.get("shield", 0)))
		if current_shield > 0:
			if not shield.visible \
					or not is_equal_approx(shield.position.x, health.position.x) \
					or not is_equal_approx(
						shield.position.y - health.position.y,
						12.0 * health.scale.y
					) \
					or not shield.size.is_equal_approx(Vector2(health.size.x, 3.0)):
				push_error(
					"VISIBLE_BATTLE_HEALTH_BARS_FAIL: shield is not in the separate lower slot " \
					+ "visible=%s health_pos=%s shield_pos=%s health_scale=%s shield_size=%s" % [
						shield.visible,
						health.position,
						shield.position,
						health.scale,
						shield.size,
					]
				)
				quit(1)
				return
		var unit_side := String(unit.get("side")).to_lower()
		var fill_width := health.get_global_rect().size.x \
			* clampf(health.value / maxf(0.0001, health.max_value), 0.0, 1.0)
		if fill_width >= 2.0:
			var coverage_error := _health_fill_coverage_error(viewport_image, health)
			if coverage_error != "":
				push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: %s" % coverage_error)
				quit(1)
				return
		if unit_side in ["player", "ally", "hero", "hero_leader", "player_leader"]:
			player_bar_found = player_bar_found or (fill != null and fill.bg_color.g > fill.bg_color.r)
			player_pixel_coverage_found = true
		else:
			enemy_bar_found = enemy_bar_found or (fill != null and fill.bg_color.r > fill.bg_color.g)
			enemy_pixel_coverage_found = true
	if not player_bar_found or not enemy_bar_found:
		push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: side colors were not both present")
		quit(1)
		return
	if not player_pixel_coverage_found or not enemy_pixel_coverage_found:
		push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: both factions need pixel coverage evidence")
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
		await _capture_bar_closeup(
			battle,
			output_dir.path_join("health_bar_%02d_%s_closeup.png" % [tier_index + 1, tier])
		)
	print("VISIBLE_BATTLE_HEALTH_BARS_PASS: %s" % output_dir)
	quit(0)


func _capture(output_path: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: %s" % error_string(error))
		quit(1)


func _capture_bar_closeup(battle: Control, output_path: String) -> void:
	await RenderingServer.frame_post_draw
	for child in battle.get_node("Board/UnitHost").get_children():
		var unit := child as Control
		if unit == null or not unit.visible:
			continue
		var shield := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Shield") as ProgressBar
		if not shield.visible:
			continue
		var health := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health") as ProgressBar
		var frame := health.get_node("Icon") as TextureRect
		var frame_rect := frame.get_global_rect().grow(6.0)
		var viewport_image := root.get_texture().get_image()
		var coverage_error := _health_fill_coverage_error(viewport_image, health)
		if coverage_error != "":
			push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: %s" % coverage_error)
			quit(1)
			return
		var image_rect := Rect2i(
			Vector2i(maxi(0, floori(frame_rect.position.x)), maxi(0, floori(frame_rect.position.y))),
			Vector2i(
				mini(viewport_image.get_width(), ceili(frame_rect.end.x)) - maxi(0, floori(frame_rect.position.x)),
				mini(viewport_image.get_height(), ceili(frame_rect.end.y)) - maxi(0, floori(frame_rect.position.y))
			)
		)
		var error := viewport_image.get_region(image_rect).save_png(output_path)
		if error != OK:
			push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: %s" % error_string(error))
			quit(1)
		return
	push_error("VISIBLE_BATTLE_HEALTH_BARS_FAIL: no visible shield bar for close-up")
	quit(1)


func _health_fill_coverage_error(viewport_image: Image, health: ProgressBar) -> String:
	var health_rect := health.get_global_rect()
	if roundi(health_rect.size.y) != 10:
		return "health control is missing its one-pixel Godot render compensation"
	if not is_equal_approx(health_rect.position.y, roundf(health_rect.position.y)):
		return "health slot is positioned between pixel rows"
	var value_range := maxf(0.0001, health.max_value - health.min_value)
	var fill_ratio := clampf((health.value - health.min_value) / value_range, 0.0, 1.0)
	var fill_width := health_rect.size.x * fill_ratio
	if fill_width < 2.0:
		return "health fill is too narrow for pixel coverage sampling"
	var sample_x := clampi(
		floori(health_rect.position.x + minf(4.0, fill_width * 0.5)),
		0,
		viewport_image.get_width() - 1
	)
	var fill_style := health.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style == null:
		return "health fill style is missing"
	var solid_rows := PackedInt32Array()
	var scan_top := maxi(0, floori(health_rect.position.y) - 1)
	var scan_bottom := mini(
		viewport_image.get_height() - 1,
		ceili(health_rect.end.y) + 1
	)
	for y in range(scan_top, scan_bottom + 1):
		if viewport_image.get_pixel(sample_x, y).to_rgba32() == fill_style.bg_color.to_rgba32():
			solid_rows.append(y)
	if solid_rows.size() != 9:
		var sampled_colors := PackedStringArray()
		for y in range(scan_top, scan_bottom + 1):
			sampled_colors.append(viewport_image.get_pixel(sample_x, y).to_html())
		return "health fill covers %d rows instead of the exact 9-row authored slot; expected=%s sampled=%s" % [
			solid_rows.size(),
			fill_style.bg_color.to_html(),
			",".join(sampled_colors),
		]
	for index in range(1, solid_rows.size()):
		if solid_rows[index] != solid_rows[index - 1] + 1:
			return "health fill rows are not continuous"
	var row_below := solid_rows[solid_rows.size() - 1] + 1
	if row_below >= viewport_image.get_height():
		return "health fill ends at the viewport boundary"
	var below := viewport_image.get_pixel(sample_x, row_below)
	if maxf(below.r, maxf(below.g, below.b)) >= 0.15 or below.a <= 0.99:
		return "health fill leaves a non-frame row below it: %s" % below.to_html()
	return ""
