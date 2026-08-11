extends SceneTree

const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const OUTPUT_DIR := "res://output/visible_horned_wing_dragon_battle"
const SOURCE_PATH := "res://art/images/shared/pets/sheets/slices/pet_style_014_horned_wing_dragon.png"


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

	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	for sample in range(1):
		await process_frame
		var image := root.get_texture().get_image()
		var path := output_dir.path_join("idle_battle_%02d.png" % (sample + 1))
		if image.save_png(path) != OK:
			push_error("VISIBLE_HORNED_WING_DRAGON_BATTLE_FAIL could not save %s" % path)
			quit(1)
			return
	print("VISIBLE_HORNED_WING_DRAGON_BATTLE_PASS output=%s" % output_dir)
	quit(0)


func _snapshot() -> Dictionary:
	var units := [
		{
			"id": "horned_wing_dragon",
			"image": SOURCE_PATH,
			"name": "Horned Wing Dragon",
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
			"image": unit.get("image", ""),
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
		"stateHash": "horned-wing-dragon-visible",
		"battle_round": 1,
		"battle_period": "morning",
		"board": {"width": 8, "height": 7, "cells": cells},
		"units": units,
		"battleTrace": [],
	}
