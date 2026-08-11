extends SceneTree

const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const SOURCE_PATH := "res://art/images/shared/pets/animations/spr_010_void_octopus/anim_001_idle/frames/frame_001.png"
const OUTPUT_DIR := "res://output/qa/void_octopus_idle/battle_runtime"


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
	Input.warp_mouse(Vector2(1800.0, 1000.0))
	for _frame in range(4):
		await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for sample in range(5):
		RenderingServer.force_draw()
		await process_frame
		var image := root.get_texture().get_image()
		var path := "%s/idle_%02d.png" % [OUTPUT_DIR, sample + 1]
		if image.save_png(ProjectSettings.globalize_path(path)) != OK:
			_fail("could not save %s" % path)
			return
		await create_timer(0.72).timeout
	print("VISIBLE_VOID_OCTOPUS_IDLE_BATTLE_PASS output=%s" % OUTPUT_DIR)
	quit(0)


func _snapshot() -> Dictionary:
	var units := [
		{
			"id": "void_octopus_idle",
			"name": "Void Octopus",
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
		"stateHash": "void-octopus-idle-battle-visible",
		"battle_round": 1,
		"battle_period": "morning",
		"board": {"width": 8, "height": 7, "cells": cells},
		"units": units,
		"battleTrace": [],
	}


func _fail(message: String) -> void:
	push_error("VISIBLE_VOID_OCTOPUS_IDLE_BATTLE_FAIL: %s" % message)
	quit(1)
