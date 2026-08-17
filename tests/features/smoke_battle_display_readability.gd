extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleUnitScene := preload("res://art/prefabs/pet/pet.tscn")

var _failed := false


func _init() -> void:
	var battle := BattleScene.instantiate()
	root.add_child(battle)
	await process_frame
	var panel := battle.get_node("Hud/BattleActionPanel")
	_expect(panel.get_node("Margin/Content/Title").get_theme_font_size("font_size") == 24, "action title uses recording-readable size")
	_expect(panel.get_node("Margin/Content/Summary").get_theme_stylebox("normal") is StyleBoxFlat, "action summary has a contrast surface")
	var action_buttons: Array[Button] = []
	for button_name in ["ResetPetsButton", "AllOutButton", "EndTurnButton", "MonsterTurnButton"]:
		action_buttons.append(panel.find_child(button_name, true, false) as Button)
	var skill_queue_grid := panel.find_child("SkillQueueGrid", true, false) as GridContainer
	_expect(skill_queue_grid != null and skill_queue_grid.get_child_count() == 8, "action panel exposes eight authored skill slots")
	if skill_queue_grid != null:
		for child in skill_queue_grid.get_children():
			action_buttons.append(child as Button)
	for button in action_buttons:
		_expect(button != null, "action panel readability target exists")
		if button == null:
			continue
		_expect(button.get_theme_stylebox("normal") is StyleBoxFlat, "%s has a normal hierarchy style" % button.name)
		_expect(button.get_theme_stylebox("disabled") is StyleBoxFlat, "%s has an explicit disabled style" % button.name)
	battle.queue_free()

	var unit := BattleUnitScene.instantiate()
	root.add_child(unit)
	await process_frame
	var stats_path := "CompleteBattleCreaturePrefab/01_UnitVisual/Stats"
	for stat_name in ["Health", "Attack", "DamageCap"]:
		var label := unit.get_node("%s/%s/Value_Text" % [stats_path, stat_name]) as Label
		_expect(label.label_settings != null and label.label_settings.outline_size >= 2, "%s preserves the authored readable outline" % stat_name)
	unit.set_unit_data({"id": "readability_pet", "hp": 24, "atk": 4, "shield": 0, "damage_cap": 7}, "player", null)
	var projected_stats := Dictionary(unit.call("get_dynamic_stat_snapshot")) if unit.has_method("get_dynamic_stat_snapshot") else {}
	_expect(int(projected_stats.get("hp", -1)) == 24, "public pet status projection keeps authored health")
	_expect(int(projected_stats.get("atk", projected_stats.get("attack", -1))) == 4, "public pet status projection keeps authored attack")
	_expect(int(projected_stats.get("damage_cap", projected_stats.get("damageCap", -1))) == 7, "public pet status projection keeps authored damage cap")
	for stat_name in ["Health", "Attack", "DamageCap"]:
		var label := unit.get_node("%s/%s/Value_Text" % [stats_path, stat_name]) as Label
		_expect(label.visible and not label.text.is_empty(), "%s renders a visible readable value" % stat_name)
	var sprite_rect := unit.call("get_battle_sprite_visible_rect") as Rect2
	var stat_rects := unit.call("get_battle_stat_rects") as Array
	_expect(sprite_rect.size.x > 0.0 and sprite_rect.size.y > 0.0, "battle creature exposes its actual visible art bounds")
	_expect(not stat_rects.is_empty(), "battle creature exposes visible status HUD bounds")
	for stat_rect_value in stat_rects:
		var stat_rect := Rect2(stat_rect_value)
		_expect(stat_rect.intersection(sprite_rect).get_area() <= 0.01, "status HUD remains outside the creature art bounds")
	unit.queue_free()
	if _failed:
		quit(1)
		return
	print("SMOKE_BATTLE_DISPLAY_READABILITY_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
