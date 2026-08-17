extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const PlayerOperationProjectorScript := preload("res://core/logging/player_operation_projector.gd")
const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	var state: RefCounted = StateScript.new()
	state.units = [{
		"id": "shield_pet",
		"name": "护盾测试宠",
		"side": "player",
		"x": 0,
		"y": 0,
		"hp": 24,
		"shield": 6,
		"atk": 4,
		"active": true,
	}]
	var board_cells := Array(Dictionary(state.snapshot().get("board", {})).get("cells", []))
	var projected_cell := Dictionary(board_cells[0]) if not board_cells.is_empty() else {}
	ok = _expect(int(projected_cell.get("shield", -1)) == 6, "core board projection carries shield") and ok
	var projector := PlayerOperationProjectorScript.new()
	var state_summary := projector.state_summary(_operation_context(state))
	var summary_units := Array(state_summary.get("units", []))
	ok = _expect(not summary_units.is_empty() and int(Dictionary(summary_units[0]).get("shield", -1)) == 6, "operation before/after state carries shield") and ok

	var event := _shield_and_hp_damage_event()
	var event_summaries := projector.event_summaries([event], {
		"round": state.battle_round,
		"phase": state.phase,
	})
	var event_summary := Dictionary(event_summaries[0]) if not event_summaries.is_empty() else {}
	ok = _expect(int(event_summary.get("shieldDamage", -1)) == 2, "operation event records shield damage") and ok
	ok = _expect(int(event_summary.get("hpDamage", -1)) == 3, "operation event records hp damage") and ok
	ok = _expect(int(event_summary.get("shieldFrom", -1)) == 2 and int(event_summary.get("shieldTo", -1)) == 0, "operation event records shield before/after") and ok
	ok = _expect(int(event_summary.get("hpFrom", -1)) == 24 and int(event_summary.get("hpTo", -1)) == 21, "operation event records hp before/after") and ok

	var battle := BattleUiScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	battle.call("render_snapshot", _snapshot())
	await process_frame
	var target_visual := _find_unit(battle, "shield_pet")
	ok = _expect(target_visual != null, "battle renders shield target unit") and ok
	if target_visual != null:
		var initial_stats := Dictionary(target_visual.call("get_dynamic_stat_snapshot")) if target_visual.has_method("get_dynamic_stat_snapshot") else {}
		ok = _expect(int(initial_stats.get("shield", -1)) == 2, "public pet status projection exposes the current shield") and ok

	var vfx_player := battle.get_node_or_null("Board/VfxHost") as Control
	ok = _expect(vfx_player != null, "battle exposes damage VFX player") and ok
	if vfx_player != null and target_visual != null:
		var prepared := vfx_player.call("_prepare_damage_target_visual", event) as Control
		var applied := vfx_player.call("_apply_damage_impact", event, prepared) as Control
		ok = _expect(applied == target_visual, "damage impact delegates to the UnitHost-owned target visual") and ok
		var updated_stats := Dictionary(target_visual.call("get_dynamic_stat_snapshot")) if target_visual.has_method("get_dynamic_stat_snapshot") else {}
		ok = _expect(int(updated_stats.get("shield", -1)) == 0, "damage impact updates the public shield projection to shieldTo") and ok
		ok = _expect(int(updated_stats.get("hp", -1)) == 21, "damage impact updates the public health projection to hpTo") and ok
		var shield_effect := target_visual.get_node_or_null("CompleteBattleCreaturePrefab/01_UnitVisual/ShieldHitEffectPlayer")
		var shield_effect_snapshot := Dictionary(shield_effect.call("snapshot")) if shield_effect != null and shield_effect.has_method("snapshot") else {}
		ok = _expect(bool(shield_effect_snapshot.get("active", false)), "shield absorption activates the unit-owned shield-hit effect") and ok
		ok = _expect(bool(shield_effect_snapshot.get("effect_visible", false)), "unit-owned shield-hit effect is visibly projected") and ok

	print("SMOKE_SHIELD_DAMAGE_FEEDBACK_%s" % ["OK" if ok else "FAIL"])
	quit(0 if ok else 1)


func _snapshot() -> Dictionary:
	return {
		"board": {"cells": [{
			"x": 0,
			"y": 0,
			"unitId": "shield_pet",
			"unitName": "护盾测试宠",
			"side": "player",
			"hp": 24,
			"shield": 2,
			"atk": 4,
			"threat": {"damage": 5},
		}]},
		"units": [{
			"id": "shield_pet",
			"name": "护盾测试宠",
			"side": "player",
			"hp": 24,
			"shield": 2,
			"atk": 4,
		}],
	}


func _operation_context(state: RefCounted) -> Dictionary:
	return {
		"phase": state.phase,
		"day": state.day,
		"nodeIndex": state.node_index,
		"battleRound": state.battle_round,
		"battlePeriod": state.battle_period,
		"difficulty": state.difficulty,
		"boardWidth": state.board_width,
		"boardHeight": state.board_height,
		"stateVersion": state.state_version,
		"selectedUnitId": state.selected_unit_id,
		"selectedActionSlotIndex": state.selected_action_slot_index,
		"ap": state.ap,
		"coins": state.coins,
		"heroHp": state.hero_hp,
		"units": state.units.duplicate(true),
	}


func _shield_and_hp_damage_event() -> Dictionary:
	return {
		"eventId": "shield_hp_split",
		"type": "DAMAGE_APPLIED",
		"actor": {"id": "enemy_attacker", "side": "enemy", "x": 1, "y": 0},
		"target": {"id": "shield_pet", "side": "player", "x": 0, "y": 0},
		"payload": {
			"finalDamage": 5,
			"shieldDamage": 2,
			"hpDamage": 3,
			"shieldFrom": 2,
			"shieldTo": 0,
			"hpFrom": 24,
			"hpTo": 21,
		},
	}


func _find_unit(node: Node, unit_id: String) -> Control:
	if node.has_method("get_unit_id") and String(node.call("get_unit_id")) == unit_id:
		return node as Control
	for child in node.get_children():
		var found := _find_unit(child, unit_id)
		if found != null:
			return found
	return null


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("SMOKE_SHIELD_DAMAGE_FEEDBACK_FAIL: %s" % message)
	return condition
