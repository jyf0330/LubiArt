extends SceneTree

const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle := BattleUiScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	var probe := BattleSceneProbe.new(battle)
	var origin := Vector2i(1, 7)
	var target := Vector2i(4, 4)
	battle.call("render_snapshot", _snapshot(1, origin))
	await process_frame

	var origin_cell := probe.cell_at(origin)
	var unit := origin_cell.call("get_unit_node") as Control if origin_cell != null else null
	_expect(unit != null, "initial snapshot creates the moving unit")
	if unit == null:
		_finish(battle)
		return
	var unit_instance_id := unit.get_instance_id()
	var origin_size := origin_cell.size
	var enemy_cell := probe.cell_at(Vector2i(5, 2))
	var enemy_unit := enemy_cell.call("get_unit_node") as Control if enemy_cell != null else null
	_expect(not bool(origin_cell.call("uses_perspective_geometry")), "board cells use orthographic geometry")
	_expect(origin_cell.get_theme_stylebox("panel") is StyleBoxEmpty, "orthographic cells keep the minimal white-line style")
	_expect(unit.size == origin_size, "unit starts at the fixed board cell size")
	_expect(
		bool(Dictionary(unit.call("get_damage_preview_snapshot")).get("active", false)),
		"initial placement damage preview is visible"
	)
	_expect(enemy_unit != null, "initial snapshot creates the aggregate-damage target")
	if enemy_unit != null:
		var enemy_preview := Dictionary(enemy_unit.call("get_damage_preview_snapshot"))
		_expect(bool(enemy_preview.get("active", false)), "aggregate enemy damage preview is visible without selecting an attacker")
		_expect(int(enemy_preview.get("predicted_damage", 0)) == 7, "aggregate enemy damage preview uses placement_damage_by_unit")

	var final_snapshot := _snapshot(2, target)
	battle.call("render_command_response", {"type": "AUTO_POSITION_HEROES"}, {
		"accepted": true,
		"command": "AUTO_POSITION_HEROES",
		"result": {"ok": true},
		"snapshot": final_snapshot,
	})
	battle.call("render_snapshot", final_snapshot)
	var target_cell := probe.cell_at(target)
	var committed_unit := target_cell.call("get_unit_node") as Control if target_cell != null else null
	_expect(target_cell != null and target_cell.size == origin_size, "every row keeps the same cell size")
	_expect(committed_unit != null, "auto arrange immediately commits the unit to the target cell")
	if committed_unit != null:
		_expect(committed_unit.get_instance_id() == unit_instance_id, "instant placement reuses the existing pet prefab")
		_expect(committed_unit.position.distance_to(target_cell.position) < 1.0, "unit snaps exactly to the target cell")
		_expect(committed_unit.size == origin_size, "instant placement keeps the unit size")
		var damage_preview := Dictionary(committed_unit.call("get_damage_preview_snapshot"))
		_expect(bool(damage_preview.get("active", false)), "damage preview remains visible after auto arrange")
		_expect(int(damage_preview.get("predicted_damage", 0)) == 4, "damage preview refreshes from the arranged snapshot")
	_expect(not bool(battle.call("is_battle_input_locked")), "instant auto arrange does not leave board input locked")
	var capture_path := OS.get_environment("DAMAGE_PREVIEW_CAPTURE")
	if capture_path != "":
		await RenderingServer.frame_post_draw
		var capture_error := root.get_texture().get_image().save_png(capture_path)
		_expect(capture_error == OK, "damage preview verification capture is saved")
	_finish(battle)


func _snapshot(version: int, grid: Vector2i) -> Dictionary:
	var occupied_cell := {
		"x": grid.x,
		"y": grid.y,
		"unitId": "player_auto_arrange",
		"id": "player_auto_arrange",
		"pet_id": "pal_002",
		"name": "自动布置测试精灵",
		"side": "player",
		"hp": 10,
		"max_hp": 10,
		"atk": 3,
		"shield": 0,
		"elements": {},
	}
	var enemy_cell := {
		"x": 5,
		"y": 2,
		"unitId": "enemy_damage_target",
		"id": "enemy_damage_target",
		"pet_id": "pal_001",
		"name": "浼ゅ棰勮鐩爣",
		"side": "enemy",
		"hp": 12,
		"max_hp": 12,
		"atk": 2,
		"shield": 0,
		"elements": {},
	}
	var cells: Array = []
	for y in range(8):
		for x in range(8):
			var cell_grid := Vector2i(x, y)
			if cell_grid == grid:
				cells.append(occupied_cell.duplicate(true))
			elif cell_grid == Vector2i(5, 2):
				cells.append(enemy_cell.duplicate(true))
			else:
				cells.append({"x": x, "y": y, "elements": {}})
	return {
		"phase": "battle",
		"stateVersion": version,
		"stateHash": "auto-arrange-%d" % version,
		"board": {"width": 8, "height": 8, "cells": cells},
		"placement_damage_by_unit": {
			"player_auto_arrange": {
				"predictedHpTo": 6,
				"predictedShieldTo": 0,
				"predictedDamage": 4,
			},
			"enemy_damage_target": {
				"hpTo": 12,
				"shieldTo": 0,
				"totalDamage": 7,
			}
		},
		"units": [{
			"id": "player_auto_arrange",
			"pet_id": "pal_002",
			"name": "自动布置测试精灵",
			"side": "player",
			"hp": 10,
			"shield": 0,
			"x": grid.x,
			"y": grid.y,
		}, {
			"id": "enemy_damage_target",
			"pet_id": "pal_001",
			"name": "浼ゅ棰勮鐩爣",
			"side": "enemy",
			"hp": 12,
			"shield": 0,
			"x": 5,
			"y": 2,
		}],
		"battleTrace": [],
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_BATTLE_AUTO_ARRANGE_MOVEMENT_FAIL: %s" % message)


func _finish(battle: Control) -> void:
	if battle != null:
		battle.queue_free()
	if _failed:
		quit(1)
		return
	print("SMOKE_BATTLE_AUTO_ARRANGE_MOVEMENT_PASS")
	quit(0)
