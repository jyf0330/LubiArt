extends SceneTree

const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var _failed := false
var _trace_finished := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle := BattleUiScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	var probe := BattleSceneProbe.new(battle)
	battle.call("render_snapshot", _snapshot(1, 10, 3, []))
	await process_frame

	var target_cell := probe.cell_at(Vector2i(5, 2))
	var target_unit := target_cell.call("get_unit_node") as Control if target_cell != null else null
	_expect(target_unit != null, "initial snapshot creates the target unit")
	if target_unit == null:
		_finish(battle)
		return
	var original_instance_id := target_unit.get_instance_id()
	var presentation_scale := Vector2(0.93, 0.97)
	var presentation_rotation := 0.031
	target_unit.scale = presentation_scale
	target_unit.rotation = presentation_rotation

	battle.trace_sequence_finished.connect(_on_trace_finished)
	battle.call("render_snapshot", _snapshot(2, 6, 1, [_damage_event()]))
	var deadline := Time.get_ticks_msec() + 4000
	while not _trace_finished and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(_trace_finished, "trace sequence reaches the final Snapshot reconciliation point")

	target_cell = probe.cell_at(Vector2i(5, 2))
	var reconciled_unit := target_cell.call("get_unit_node") as Control if target_cell != null else null
	_expect(reconciled_unit != null, "final snapshot keeps a target unit")
	if reconciled_unit != null:
		_expect(reconciled_unit.get_instance_id() == original_instance_id, "final snapshot reuses the stable unit node")
		_expect(reconciled_unit.scale.is_equal_approx(presentation_scale), "final snapshot does not reset the presentation scale")
		_expect(is_equal_approx(reconciled_unit.rotation, presentation_rotation), "final snapshot does not reset the presentation rotation")
		var stats := Dictionary(reconciled_unit.call("get_dynamic_stat_snapshot"))
		_expect(int(stats.get("hp", -1)) == 6, "final HP is reconciled to hpTo")
		_expect(int(stats.get("shield", -1)) == 1, "final shield is reconciled to shieldTo")
	var cell_summary := probe.cell_summary(Vector2i(5, 2))
	var final_cell_data := Dictionary(cell_summary.get("data", {}))
	_expect(int(final_cell_data.get("hp", -1)) == 6, "board presentation cache commits final HP")
	_expect(int(final_cell_data.get("shield", -1)) == 1, "board presentation cache commits final shield")

	_finish(battle)


func _snapshot(version: int, enemy_hp: int, enemy_shield: int, trace: Array) -> Dictionary:
	var cells := [
		_unit_cell(Vector2i(1, 6), "player_reconcile", "player", 10, 0),
		_unit_cell(Vector2i(5, 2), "enemy_reconcile", "enemy", enemy_hp, enemy_shield),
	]
	return {
		"phase": "battle",
		"stateVersion": version,
		"stateHash": "reconcile-%d" % version,
		"board": {"width": 8, "height": 7, "cells": cells},
		"units": [
			{"id": "player_reconcile", "pet_id": "pal_002", "name": "灰尾狸", "side": "player", "hp": 10, "shield": 0, "x": 1, "y": 6},
			{"id": "enemy_reconcile", "pet_id": "pal_001", "name": "棉角羊", "side": "enemy", "hp": enemy_hp, "shield": enemy_shield, "x": 5, "y": 2},
		],
		"battleTrace": trace.duplicate(true),
	}


func _unit_cell(grid: Vector2i, unit_id: String, unit_side: String, hp: int, shield: int) -> Dictionary:
	return {
		"x": grid.x,
		"y": grid.y,
		"unitId": unit_id,
		"id": unit_id,
		"pet_id": "pal_002" if unit_side == "player" else "pal_001",
		"name": "灰尾狸" if unit_side == "player" else "棉角羊",
		"side": unit_side,
		"hp": hp,
		"max_hp": 10,
		"atk": 3,
		"shield": shield,
		"elements": {},
	}


func _damage_event() -> Dictionary:
	return {
		"eventId": "reconcile_damage_1",
		"type": "DAMAGE_APPLIED",
		"actor": {"id": "player_reconcile", "name": "灰尾狸", "side": "player", "x": 1, "y": 6},
		"target": {"id": "enemy_reconcile", "name": "棉角羊", "side": "enemy", "x": 5, "y": 2},
		"payload": {
			"element": "water",
			"sourceType": "action",
			"rawDamage": 6,
			"finalDamage": 6,
			"shieldDamage": 2,
			"hpDamage": 4,
			"hpFrom": 10,
			"hpTo": 6,
			"shieldFrom": 3,
			"shieldTo": 1,
		},
	}


func _on_trace_finished() -> void:
	_trace_finished = true


func _finish(battle: Control) -> void:
	battle.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("SMOKE_BATTLE_SNAPSHOT_VISUAL_RECONCILIATION_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_BATTLE_SNAPSHOT_VISUAL_RECONCILIATION_FAIL: %s" % message)
