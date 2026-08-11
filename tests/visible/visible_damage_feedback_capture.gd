extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const OUTPUT_PATH := "res://output/damage_feedback_1920x1080.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	battle.call("render_snapshot", _snapshot())
	for _frame in range(4):
		await process_frame
	var target := _find_unshielded_unit(battle)
	if target.is_empty():
		_fail("an unshielded battle unit is unavailable")
		return
	var unit := target.get("unit") as Control
	var cell_data := Dictionary(target.get("cell_data", {}))
	var stats := Dictionary(unit.call("get_dynamic_stat_snapshot"))
	var hp_from := int(stats.get("hp", 0))
	if hp_from <= 1:
		_fail("target does not have enough health for the capture")
		return
	var damage := mini(5, hp_from - 1)
	var hp_to := hp_from - damage
	var vfx := battle.get_node("Board/VfxHost") as Control
	vfx.call("_apply_damage_impact", {
		"actor": {"id": "visual_capture_attacker", "x": 0, "y": 0},
		"target": {
			"id": String(unit.call("get_unit_id")),
			"x": int(cell_data.get("x", cell_data.get("c", 0))),
			"y": int(cell_data.get("y", cell_data.get("r", 0))),
		},
		"payload": {
			"finalDamage": damage,
			"hpDamage": damage,
			"shieldDamage": 0,
			"hpFrom": hp_from,
			"hpTo": hp_to,
			"shieldFrom": 0,
			"shieldTo": 0,
		},
	}, unit)
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw

	var health := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health") as ProgressBar
	if health.value >= float(hp_from) or health.value <= float(hp_to):
		_fail("health bar did not show its proportional in-between damage state")
		return
	var number_found := false
	for child in vfx.get_children():
		if child is Label and String(child.name).begins_with("DamageNumber_"):
			number_found = (child as Label).text == "-%d" % damage
			break
	if not number_found:
		_fail("floating damage number is unavailable")
		return
	var error := root.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(OUTPUT_PATH)
	)
	if error != OK:
		_fail("could not save damage feedback capture")
		return
	print("VISIBLE_DAMAGE_FEEDBACK_PASS capture=%s" % OUTPUT_PATH)
	quit(0)


func _find_unshielded_unit(battle: Control) -> Dictionary:
	var cell_host := battle.get_node("Board/CellHost") as Control
	for cell in cell_host.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var unit := cell.call("get_unit_node") as Control
		if unit == null or not unit.has_method("get_dynamic_stat_snapshot"):
			continue
		var stats := Dictionary(unit.call("get_dynamic_stat_snapshot"))
		if int(stats.get("shield", 0)) == 0 and int(stats.get("hp", 0)) > 1:
			return {"unit": unit, "cell_data": Dictionary(cell.get("cell_data"))}
	return {}


func _snapshot() -> Dictionary:
	return {
		"phase": "battle",
		"stateVersion": 1,
		"stateHash": "visible-damage-feedback",
		"board": {
			"width": 8,
			"height": 7,
			"cells": [
				{
					"x": 1, "y": 5, "unitId": "capture_ally", "id": "capture_ally",
					"pet_id": "pal_002", "name": "Ally", "side": "player",
					"hp": 12, "max_hp": 12, "atk": 3, "shield": 0, "elements": {},
				},
				{
					"x": 5, "y": 2, "unitId": "capture_enemy", "id": "capture_enemy",
					"pet_id": "pal_001", "name": "Enemy", "side": "enemy",
					"hp": 15, "max_hp": 15, "atk": 4, "shield": 0, "elements": {},
				},
			],
		},
		"units": [
			{"id": "capture_ally", "pet_id": "pal_002", "name": "Ally", "side": "player", "hp": 12, "max_hp": 12, "shield": 0, "x": 1, "y": 5},
			{"id": "capture_enemy", "pet_id": "pal_001", "name": "Enemy", "side": "enemy", "hp": 15, "max_hp": 15, "shield": 0, "x": 5, "y": 2},
		],
		"battleTrace": [],
	}


func _fail(message: String) -> void:
	push_error("VISIBLE_DAMAGE_FEEDBACK_FAIL: %s" % message)
	quit(1)
