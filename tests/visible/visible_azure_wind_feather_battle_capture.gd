extends SceneTree

const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")
const SOURCE_PATH := "res://art/images/shared/pets/animations/spr_012_azure_wind_feather/anim_001_idle/frames/frame_001.png"
const OUTPUT_DIR := "res://output/qa/azure_wind_feather/battle_runtime"
const MOVE_DURATION := 1.28


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var battle := BattleUiScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	battle.call("render_snapshot", _snapshot())
	for _frame in range(12):
		await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for sample in range(5):
		if not await _capture("%s/idle_%02d.png" % [OUTPUT_DIR, sample + 1]):
			return
		await create_timer(0.3).timeout

	var probe := BattleSceneProbe.new(battle)
	var origin_cell := probe.cell_at(Vector2i(2, 5))
	var target_cell := probe.cell_at(Vector2i(4, 5))
	var pet := origin_cell.call("get_unit_node") as Control if origin_cell != null else null
	if pet == null or target_cell == null:
		_fail("could not resolve battle unit or target cell")
		return
	pet.call(
		"play_grid_movement",
		pet.global_position,
		target_cell.global_position,
		MOVE_DURATION
	)
	for sample in range(9):
		for _frame in range(2):
			await process_frame
		if not await _capture("%s/move_%02d.png" % [OUTPUT_DIR, sample + 1]):
			return
		await create_timer(MOVE_DURATION / 8.0).timeout

	print("VISIBLE_AZURE_WIND_FEATHER_BATTLE_PASS output=%s" % OUTPUT_DIR)
	quit(0)


func _snapshot() -> Dictionary:
	var units := [
		{
			"id": "azure_wind_feather",
			"name": "Azure Wind Feather",
			"image_path": SOURCE_PATH,
			"side": "player",
			"hp": 10,
			"max_hp": 10,
			"shield": 0,
			"x": 2,
			"y": 5,
		},
		{
			"id": "enemy_reference",
			"pet_id": "pal_001",
			"name": "Reference Enemy",
			"side": "enemy",
			"hp": 10,
			"max_hp": 10,
			"shield": 0,
			"x": 5,
			"y": 2,
		},
	]
	var cells := []
	for unit in units:
		cells.append({
			"x": unit["x"],
			"y": unit["y"],
			"unitId": unit["id"],
			"id": unit["id"],
			"pet_id": unit.get("pet_id", ""),
			"image_path": unit.get("image_path", ""),
			"name": unit["name"],
			"side": unit["side"],
			"hp": unit["hp"],
			"max_hp": unit["max_hp"],
			"atk": 3,
			"shield": unit["shield"],
			"elements": {},
		})
	return {
		"phase": "battle",
		"stateVersion": 1,
		"stateHash": "azure-wind-feather-visible",
		"battle_round": 1,
		"battle_period": "morning",
		"board": {"width": 8, "height": 7, "cells": cells},
		"units": units,
		"battleTrace": [],
	}


func _capture(path: String) -> bool:
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		_fail("viewport texture is unavailable")
		return false
	var viewport_image := viewport_texture.get_image()
	if viewport_image == null or viewport_image.is_empty():
		_fail("viewport image is unavailable")
		return false
	if viewport_image.save_png(ProjectSettings.globalize_path(path)) != OK:
		_fail("could not save %s" % path)
		return false
	return true


func _fail(message: String) -> void:
	push_error("VISIBLE_AZURE_WIND_FEATHER_BATTLE_FAIL: %s" % message)
	quit(1)
