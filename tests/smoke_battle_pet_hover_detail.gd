extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var _commands: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	battle.command_requested.connect(func(command: Dictionary):
		_commands.append(command.duplicate(true))
	)
	await process_frame
	battle.call("render_snapshot", _snapshot())
	await process_frame
	await process_frame

	var player_cell := _cell_for_unit(battle, "pet_player")
	var enemy_cell := _cell_for_unit(battle, "pet_enemy")
	if player_cell == null or enemy_cell == null:
		_fail("Both player and enemy pet cells must render.")
		return
	if not await _hover_pet(battle, player_cell):
		_fail("Moving the pointer onto the player pet art must show its detail.")
		return
	if not _assert_visible_detail(battle, "测试我方宠物"):
		return
	if not _assert_context_layout(battle):
		return
	if not _commands.is_empty():
		_fail("Pet hover must stay presentation-only and emit no Command: %s" % JSON.stringify(_commands))
		return

	if not await _hover_pet(battle, enemy_cell):
		_fail("Moving directly to the enemy pet art must switch the detail.")
		return
	if not _assert_visible_detail(battle, "测试敌方宠物"):
		return
	if not _commands.is_empty():
		_fail("Enemy pet hover must emit no Command: %s" % JSON.stringify(_commands))
		return

	var enemy_grid := enemy_cell.call("get_grid_position") as Vector2i
	enemy_cell.emit_signal("cell_unhovered", enemy_grid.x, enemy_grid.y)
	await process_frame
	var overlay := battle.get_node("OverlayHost") as Control
	if bool(overlay.call("has_visible_detail")):
		_fail("Moving the pointer away from the pet must close the hover detail.")
		return
	print("SMOKE_BATTLE_PET_HOVER_DETAIL_OK")
	quit(0)


func _hover_pet(battle: Control, cell: Control) -> bool:
	var unit := cell.call("get_unit_node") as Control
	if unit == null or not unit.has_method("contains_art_point"):
		return false
	var point := _find_art_point(unit)
	if point.x < 0.0:
		return false
	Input.warp_mouse(Vector2i(point))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	battle.get_viewport().push_input(motion, true)
	var grid := cell.call("get_grid_position") as Vector2i
	cell.emit_signal("cell_hovered", grid.x, grid.y)
	await process_frame
	await process_frame
	return true


func _find_art_point(unit: Control) -> Vector2:
	var rect := unit.get_global_rect()
	for y_step in range(1, 10):
		for x_step in range(1, 10):
			var point := rect.position + Vector2(
				rect.size.x * float(x_step) / 10.0,
				rect.size.y * float(y_step) / 10.0
			)
			if bool(unit.call("contains_art_point", point)):
				return point
	return Vector2(-1.0, -1.0)


func _cell_for_unit(battle: Control, unit_id: String) -> Control:
	var host := battle.get_node("Board/CellHost") as Control
	for child in host.get_children():
		if not (child is Control):
			continue
		var raw_data = child.get("cell_data")
		var data := Dictionary(raw_data) if raw_data is Dictionary else {}
		if String(data.get("unitId", data.get("unit_id", ""))) == unit_id:
			return child as Control
	return null


func _assert_visible_detail(battle: Control, expected_name: String) -> bool:
	var overlay := battle.get_node("OverlayHost") as Control
	var detail := overlay.get_node_or_null("BattlePetDetailPanel") as Control
	if detail == null or not detail.visible or not bool(overlay.call("has_visible_detail")):
		_fail("Hover detail should be visible for %s." % expected_name)
		return false
	var snapshot := Dictionary(detail.call("get_detail_snapshot"))
	if String(snapshot.get("name", "")) != expected_name:
		_fail("Hover detail should switch to %s, got %s." % [expected_name, JSON.stringify(snapshot)])
		return false
	return true


func _assert_context_layout(battle: Control) -> bool:
	var detail := battle.get_node("OverlayHost/BattlePetDetailPanel") as Control
	var panel := detail.get_node("Panel") as Control
	var card := detail.get_node("Panel/SpriteInfoCard") as Control
	if not panel.scale.is_equal_approx(Vector2.ONE):
		_fail("Hover detail must use the confirmed PSD scale, got %s." % panel.scale)
		return false
	var rect := card.get_global_rect()
	var viewport_size := battle.get_viewport_rect().size
	if rect.position.x < 16.0 or rect.position.y < 16.0 \
			or rect.end.x > viewport_size.x - 16.0 or rect.end.y > viewport_size.y - 16.0:
		_fail("Hover detail card must remain inside the viewport margin, got rect %s." % rect)
		return false
	if not rect.size.is_equal_approx(Vector2(360.0, 460.0)):
		_fail("Hover detail card must match the confirmed 360x460 PSD geometry, got rect %s." % rect)
		return false
	return true


func _snapshot() -> Dictionary:
	return {
		"board": {
			"width": 8,
			"height": 7,
			"cells": [
				{"x": 1, "y": 1, "unitId": "pet_player", "unitName": "测试我方宠物", "side": "player", "hp": 24, "atk": 4, "shield": 3},
				{"x": 6, "y": 2, "unitId": "pet_enemy", "unitName": "测试敌方宠物", "side": "enemy", "hp": 20, "atk": 5, "shield": 1},
			]
		},
		"units": [
			{"id": "pet_player", "name": "测试我方宠物", "side": "player", "element": "wind", "quality": "silver", "hp": 24, "max_hp": 24, "atk": 4, "def": 2, "shield": 3, "ap": 2, "active": true, "alive": true, "x": 1, "y": 1},
			{"id": "pet_enemy", "name": "测试敌方宠物", "side": "enemy", "element": "fire", "quality": "gold", "hp": 20, "max_hp": 20, "atk": 5, "def": 1, "shield": 1, "ap": 2, "active": true, "alive": true, "x": 6, "y": 2},
		],
		"battle": {"shape_catalog": []},
	}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
