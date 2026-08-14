extends SceneTree

const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const OUTPUT_DIR := "res://output/visible_horned_wing_dragon_idle_4frame"
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
	var target := _find_unit(battle, "horned_wing_dragon")
	if target == null:
		_fail("target unit missing")
		return
	var animation := target.get_node("CompleteBattleCreaturePrefab/03_AttackActions")
	var sprite := target.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/CreatureArt") as TextureRect
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var captured := {}
	var deadline_msec := Time.get_ticks_msec() + 20000
	while captured.size() < 4 and Time.get_ticks_msec() < deadline_msec:
		var snapshot := Dictionary(animation.call("get_frame_animation_snapshot"))
		var frame_index := int(snapshot.get("frame_index", -1))
		if frame_index >= 0 and frame_index < 4 and not captured.has(frame_index):
			await process_frame
			var path := output_dir.path_join("idle_battle_frame_%02d.png" % (frame_index + 1))
			if root.get_texture().get_image().save_png(path) != OK:
				_fail("could not save %s" % path)
				return
			captured[frame_index] = String(sprite.texture.resource_path)
		await process_frame
	if captured.size() != 4:
		_fail("did not render all four idle phases")
		return
	for frame_index in range(4):
		var expected_suffix := "/frame_%03d.png" % (frame_index + 1)
		if not String(captured.get(frame_index, "")).ends_with(expected_suffix):
			_fail("phase %d used the wrong texture" % (frame_index + 1))
			return
	print("VISIBLE_HORNED_WING_DRAGON_IDLE_4FRAME_PASS samples=4 output=%s" % output_dir)
	quit(0)


func _find_unit(battle: Control, unit_id: String) -> Control:
	for node in battle.find_children("*", "", true, false):
		if node is Control and node.has_method("get_unit_id") \
				and String(node.call("get_unit_id")) == unit_id:
			return node as Control
	return null


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
			"x": unit["x"], "y": unit["y"], "unitId": unit["id"], "id": unit["id"],
			"pet_id": unit.get("pet_id", ""), "image": unit.get("image", ""),
			"name": unit["name"], "side": unit["side"], "hp": unit["hp"],
			"max_hp": unit["max_hp"], "atk": 3, "shield": unit["shield"], "elements": {},
		})
	return {
		"phase": "battle", "stateVersion": 1, "stateHash": "horned-idle-four-frame",
		"battle_round": 1, "battle_period": "morning",
		"board": {"width": 8, "height": 7, "cells": cells},
		"units": units, "battleTrace": [],
	}


func _fail(message: String) -> void:
	push_error("VISIBLE_HORNED_WING_DRAGON_IDLE_4FRAME_FAIL: %s" % message)
	quit(1)
