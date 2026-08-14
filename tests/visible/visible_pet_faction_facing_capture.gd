extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var output_path := OS.get_environment("PET_FACTION_FACING_CAPTURE_OUTPUT").strip_edges()
	if output_path == "":
		_fail("PET_FACTION_FACING_CAPTURE_OUTPUT is required")
		return
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await _settle(8)
	battle.call("render_snapshot", _snapshot())
	await _settle(16)
	var probe := BattleSceneProbe.new(battle)
	var cases := [
		[Vector2i(1, 5), 1, -1],
		[Vector2i(2, 5), 1, -1],
		[Vector2i(3, 5), 1, 1],
		[Vector2i(4, 5), 1, -1],
		[Vector2i(0, 6), 1, -1],
		[Vector2i(5, 2), -1, 1],
		[Vector2i(5, 3), -1, -1],
		[Vector2i(6, 2), -1, -1],
		[Vector2i(7, 0), -1, 1],
	]
	for test_case in cases:
		if not _verify_facing(
			probe,
			Vector2i(test_case[0]),
			int(test_case[1]),
			int(test_case[2])
		):
			return
	await _settle(2)
	var viewport_texture := root.get_texture()
	var viewport_image := viewport_texture.get_image() if viewport_texture != null else null
	if viewport_image == null or viewport_image.is_empty():
		_fail("viewport image is unavailable; run the visual capture with a rendering display driver")
		return
	var save_error := viewport_image.save_png(output_path)
	if save_error != OK:
		_fail("could not save capture: %s" % error_string(save_error))
		return
	print("VISIBLE_PET_FACTION_FACING_PASS: %s" % output_path)
	quit(0)


func _verify_facing(
	probe: RefCounted,
	grid_position: Vector2i,
	target_facing: int,
	authored_facing: int
) -> bool:
	var cell := probe.call("cell_at", grid_position) as Control
	var unit := cell.call("get_unit_node") as Control if cell != null else null
	if unit == null:
		_fail("missing unit at %s" % grid_position)
		return false
	var sprite := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
	var animation := unit.get_node("CompleteBattleCreaturePrefab/03_AttackActions")
	var state := Dictionary(animation.call("get_frame_animation_snapshot"))
	var expected_scale_sign := 1 if target_facing == authored_facing else -1
	var scale_is_correct := sprite.scale.x > 0.0 if expected_scale_sign > 0 else sprite.scale.x < 0.0
	if not scale_is_correct \
			or int(state.get("horizontal_facing", 0)) != target_facing \
			or int(state.get("authored_horizontal_facing", 0)) != authored_facing \
			or not bool(state.get("horizontal_facing_locked", false)):
		_fail("incorrect facing at %s: scale=%s state=%s" % [grid_position, sprite.scale, state])
		return false
	return true


func _snapshot() -> Dictionary:
	var units := [
		_unit("player_gold_mascot", "pal_002", "Gold Mascot", "player", 1, 5),
		_unit("player_gold_shell", "pal_011", "Gold Shell", "player", 2, 5),
		_unit("player_owl", "pal_028", "Azure Thunder Owl", "player", 3, 5),
		_unit("player_crystal_shell", "pal_030", "Crystal Shell", "player", 4, 5),
		_unit("player_hero", "", "Wukong", "hero_leader", 0, 6),
		_unit("enemy_r01_001", "pal_001", "Earth Slime", "enemy", 5, 2),
		_unit("enemy_r01_002", "pal_042", "Volcanic Dijiang", "enemy", 5, 3),
		_unit("enemy_r02_003", "pal_006", "Frost Fox", "enemy", 6, 2),
		_unit("enemy_boss", "", "Spider", "boss", 7, 0),
	]
	var cells := []
	for unit_value in units:
		var unit := Dictionary(unit_value)
		cells.append({
			"x": unit["x"],
			"y": unit["y"],
			"unitId": unit["id"],
			"id": unit["id"],
			"pet_id": unit["pet_id"],
			"name": unit["name"],
			"side": unit["side"],
			"hp": unit["hp"],
			"max_hp": unit["max_hp"],
			"atk": unit["atk"],
			"shield": unit["shield"],
			"elements": {},
		})
	return {
		"phase": "battle",
		"stateVersion": 1,
		"stateHash": "pet-faction-facing-visible",
		"battle_round": 1,
		"battle_period": "morning",
		"board": {"width": 8, "height": 7, "cells": cells},
		"units": units,
		"battleTrace": [],
	}


func _unit(
	unit_id: String,
	pet_id: String,
	unit_name: String,
	side: String,
	x: int,
	y: int
) -> Dictionary:
	return {
		"id": unit_id,
		"pet_id": pet_id,
		"name": unit_name,
		"side": side,
		"hp": 10,
		"max_hp": 10,
		"shield": 0,
		"atk": 3,
		"x": x,
		"y": y,
	}


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _fail(message: String) -> void:
	push_error("VISIBLE_PET_FACTION_FACING_FAIL: %s" % message)
	quit(1)
