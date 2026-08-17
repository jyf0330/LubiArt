extends SceneTree

const BATTLE_UI_SCENE := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var battle := BATTLE_UI_SCENE.instantiate() as Control
	if battle == null:
		push_error("Battle UI scene should instantiate for pet-stat smoke.")
		quit(1)
		return
	root.add_child(battle)
	await process_frame
	var probe := BattleSceneProbe.new(battle)
	var snapshot := _snapshot_with_threat(7)
	battle.call("render_snapshot", snapshot)
	var opened := Dictionary(probe.open_first_pet_detail())
	if not bool(opened.get("opened", false)):
		push_error("Battle pet detail should open from a rendered pet cell.")
		quit(1)
		return
	battle.call("render_snapshot", snapshot)
	await process_frame
	var summary := Dictionary(probe.detail_summary())
	if not bool(summary.get("usesSharedPrefab", false)):
		push_error("Battle CellDetail should reuse the formal pet prefab: %s" % JSON.stringify(summary))
		quit(1)
		return
	var detail_panel := battle.get_node_or_null("OverlayHost/BattlePetDetailPanel") as Control
	if detail_panel == null or detail_panel.scene_file_path != "res://art/prefabs/pet/pet_detail.tscn":
		push_error("Battle CellDetail must instantiate the formal pet-detail prefab.")
		quit(1)
		return
	var stats := Dictionary(detail_panel.call("get_detail_snapshot")) if detail_panel.has_method("get_detail_snapshot") else {}
	if int(stats.get("hp", -1)) != 24 or int(stats.get("attack", -1)) != 4 or int(stats.get("shield", -1)) != 3:
		push_error("Battle CellDetail pet should project real health, attack and shield data, got %s." % JSON.stringify(stats))
		quit(1)
		return
	battle.call("render_snapshot", snapshot)
	await process_frame
	var capture_saved := await _save_capture("res://output/battle_ui_pet_three_stats.png")
	if not capture_saved:
		print("SMOKE_BATTLE_PET_THREE_STATS_CAPTURE_SKIPPED headless viewport texture unavailable")
	print("SMOKE_BATTLE_PET_THREE_STATS_OK")
	if _should_keep_open():
		print("SMOKE_BATTLE_PET_THREE_STATS_KEEP_OPEN")
		return
	quit(0)


func _snapshot_with_threat(incoming_damage: int) -> Dictionary:
	return {
		"board": {
			"cells": [{
				"x": 0,
				"y": 0,
				"unitId": "pet_001",
				"unitName": "捣蛋猫",
				"side": "player",
				"hp": 24,
				"threat": {"damage": incoming_damage, "unitName": "棉悠悠"}
			}]
		},
		"battle": {
			"shape_catalog": [{
				"shape_id": "01",
				"label": "形状01",
				"offsets": [{"dr": 0, "dc": 1}],
				"note": "一格，右侧相邻。"
			}]
		},
		"units": [{
			"id": "pet_001",
			"name": "捣蛋猫",
			"side": "player",
			"element": "风",
			"quality": "白银",
			"hp": 24,
			"max_hp": 24,
			"atk": 4,
			"def": 2,
			"shield": 3,
			"ap": 5,
			"available_ap": 2,
			"move_range": 4,
			"alive": true,
			"active": true,
			"x": 0,
			"y": 0,
			"quality_upgrade": {"name": "银色护体", "effect": "入场获得固定护盾。"},
			"shape_id": "01"
		}]
	}


func _should_keep_open() -> bool:
	if OS.get_environment("KEEP_GODOT_OPEN") == "1":
		return true
	for arg in OS.get_cmdline_args():
		if String(arg) == "--keep-open":
			return true
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "--keep-open":
			return true
	return false


func _save_capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		return false
	return image.save_png(path) == OK
