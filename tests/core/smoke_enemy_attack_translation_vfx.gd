extends SceneTree

const BattleUiScene := preload("res://art/scenes/battle/battle_art_scene.tscn")

var failed := false
var sequence_finished := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle := BattleUiScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	battle.call("render_snapshot", _snapshot())
	await process_frame
	var attacker := _find_unit(battle, "enemy_attacker")
	var target := _find_unit(battle, "player_target")
	_expect(attacker != null and target != null, "fixture renders both attacker and target")
	var vfx_player := battle.get_node_or_null("Board/VfxHost") as Control
	_expect(vfx_player != null, "battle exposes VFX player")
	if attacker == null or target == null or vfx_player == null:
		quit(1)
		return
	var origin := attacker.position
	vfx_player.trace_sequence_finished.connect(func(): sequence_finished = true)
	vfx_player.call("play_trace", [_enemy_damage_event()])
	await create_timer(0.21).timeout
	_expect(attacker.position.x < origin.x - 20.0, "enemy attacker visibly translates toward the player target before impact")
	_expect(is_equal_approx(attacker.position.y, origin.y), "horizontal attack translation keeps the authored row")
	await create_timer(1.0).timeout
	_expect(attacker.position.is_equal_approx(origin), "enemy attacker returns exactly to its authored cell after the attack")
	_expect(sequence_finished, "damage trace sequence finishes after translation, bite and impact")
	if failed:
		quit(1)
		return
	print("SMOKE_ENEMY_ATTACK_TRANSLATION_VFX_OK")
	quit(0)


func _snapshot() -> Dictionary:
	return {
		"board": {"cells": [
			{"x": 5, "y": 1, "unitId": "enemy_attacker", "unitName": "敌方攻击者", "side": "enemy", "hp": 20, "shield": 0, "atk": 4},
			{"x": 3, "y": 1, "unitId": "player_target", "unitName": "我方目标", "side": "player", "hp": 20, "shield": 0, "atk": 3},
		]},
		"units": [
			{"id": "enemy_attacker", "name": "敌方攻击者", "side": "enemy", "x": 5, "y": 1, "hp": 20, "shield": 0, "atk": 4},
			{"id": "player_target", "name": "我方目标", "side": "player", "x": 3, "y": 1, "hp": 20, "shield": 0, "atk": 3},
		],
	}


func _enemy_damage_event() -> Dictionary:
	return {
		"eventId": "enemy_translation_attack",
		"type": "DAMAGE_APPLIED",
		"actor": {"id": "enemy_attacker", "name": "敌方攻击者", "side": "enemy", "x": 5, "y": 1},
		"target": {"id": "player_target", "name": "我方目标", "side": "player", "x": 3, "y": 1},
		"payload": {
			"sourceType": "enemy_pet_action",
			"finalDamage": 4,
			"shieldDamage": 0,
			"hpDamage": 4,
			"shieldFrom": 0,
			"shieldTo": 0,
			"hpFrom": 20,
			"hpTo": 16,
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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_ENEMY_ATTACK_TRANSLATION_VFX_FAIL: %s" % message)
