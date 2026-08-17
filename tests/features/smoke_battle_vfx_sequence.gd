extends SceneTree

const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")

var _started_event_ids: Array[String] = []
var _finished_event_ids: Array[String] = []
var _sequence_finished := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle_flow := BattleUiScene.instantiate() as Control
	root.add_child(battle_flow)
	await process_frame
	var vfx_player := battle_flow.get_node_or_null("Board/VfxHost") as Control
	if vfx_player == null:
		_fail("Battle UI must expose the Board-owned VfxHost.")
		return
	if not vfx_player.has_signal("trace_event_started") or not vfx_player.has_signal("trace_event_finished") or not vfx_player.has_signal("trace_sequence_finished"):
		_fail("VfxHost must expose observable sequential trace playback signals.")
		return
	vfx_player.connect("trace_event_started", _on_trace_event_started)
	vfx_player.connect("trace_event_finished", _on_trace_event_finished)
	vfx_player.connect("trace_sequence_finished", _on_trace_sequence_finished)
	battle_flow.call("render_snapshot", _snapshot_fixture())
	await process_frame
	var probe := BattleSceneProbe.new(battle_flow)
	vfx_player.call("play_trace", [
		_damage_event("seq_1", Vector2i(1, 6), Vector2i(5, 2), 3),
		_damage_event("seq_2", Vector2i(2, 6), Vector2i(6, 2), 4),
	])
	await process_frame
	var actor_cell := probe.cell_at(Vector2i(1, 6))
	var actor_unit := actor_cell.call("get_unit_node") as Control if actor_cell != null else null
	var projectile := actor_unit.find_child("ProjectileArt", true, false) as TextureRect if actor_unit != null else null
	if projectile == null or not projectile.visible or projectile.texture == null:
		_fail("Pet-owned authored projectile art must be visible during the first trace event.")
		return
	if _started_event_ids != ["seq_1"]:
		_fail("Only the first trace event may start immediately, got %s." % JSON.stringify(_started_event_ids))
		return
	await create_timer(0.20).timeout
	if _started_event_ids != ["seq_1"]:
		_fail("Second trace event started before the first 0.32s artist projectile completed: %s." % JSON.stringify(_started_event_ids))
		return
	await create_timer(1.20).timeout
	if _started_event_ids != ["seq_1", "seq_2"] or _finished_event_ids != ["seq_1", "seq_2"] or not _sequence_finished:
		_fail("Sequential trace playback did not finish in order: started=%s finished=%s sequence_finished=%s." % [
			JSON.stringify(_started_event_ids),
			JSON.stringify(_finished_event_ids),
			str(_sequence_finished),
		])
		return
	print("SMOKE_BATTLE_VFX_SEQUENCE_OK %s" % JSON.stringify(_finished_event_ids))
	quit(0)


func _snapshot_fixture() -> Dictionary:
	var cells := [
		_unit_cell(Vector2i(1, 6), "player_seq_1", "player"),
		_unit_cell(Vector2i(5, 2), "enemy_seq_1", "enemy"),
		_unit_cell(Vector2i(2, 6), "player_seq_2", "player"),
		_unit_cell(Vector2i(6, 2), "enemy_seq_2", "enemy"),
	]
	var units := []
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		units.append({
			"id": String(cell.get("unitId", "")),
			"name": String(cell.get("unitId", "")),
			"side": String(cell.get("side", "")),
			"hp": 10,
			"max_hp": 10,
			"atk": 3,
			"shield": 0,
			"x": int(cell.get("x", -1)),
			"y": int(cell.get("y", -1)),
		})
	return {
		"phase": "battle",
		"board": {"width": 8, "height": 7, "cells": cells},
		"units": units,
	}


func _unit_cell(grid: Vector2i, unit_id: String, side: String) -> Dictionary:
	return {
		"x": grid.x,
		"y": grid.y,
		"unitId": unit_id,
		"id": unit_id,
		"name": unit_id,
		"side": side,
		"hp": 10,
		"max_hp": 10,
		"atk": 3,
		"shield": 0,
	}


func _damage_event(event_id: String, from_grid: Vector2i, to_grid: Vector2i, amount: int) -> Dictionary:
	return {
		"eventId": event_id,
		"type": "DAMAGE_APPLIED",
		"actor": {"id": "player_%s" % event_id, "side": "player", "x": from_grid.x, "y": from_grid.y},
		"target": {"id": "enemy_%s" % event_id, "side": "enemy", "x": to_grid.x, "y": to_grid.y},
		"payload": {"element": "fire", "finalDamage": amount, "hpDamage": amount, "hpTo": 10 - amount},
	}


func _on_trace_event_started(event_id: String) -> void:
	_started_event_ids.append(event_id)


func _on_trace_event_finished(event_id: String) -> void:
	_finished_event_ids.append(event_id)


func _on_trace_sequence_finished() -> void:
	_sequence_finished = true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
