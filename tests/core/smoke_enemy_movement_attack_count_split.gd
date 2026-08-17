extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = StateScript.new()
	state.phase = "battle"
	state.battle_round = 1
	var player_unit := _player("player_target", 0, 3)
	var enemy_unit := _enemy("enemy_split", 4, 3)
	state.units = [player_unit, enemy_unit]
	state.battle_roster_templates = {
		StateScript.PLAYER: [player_unit.duplicate(true)],
		StateScript.ENEMY: [enemy_unit.duplicate(true)],
	}
	state.call("_initialize_skill_control_orders")
	state.battle_trace = []

	state.call("_enemy_turn")
	var enemy := Dictionary(state.call("unit_by_id", "enemy_split"))
	var player := Dictionary(state.call("unit_by_id", "player_target"))
	var moved_distance := 0
	var move_range := -1
	var damage_events := 0
	var total_final_damage := 0
	var skill_events := 0
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) == "MOVE_MONSTER":
			var from_pos := Dictionary(event.get("from", {}))
			var to_pos := Dictionary(event.get("to", {}))
			moved_distance = (
				abs(int(from_pos.get("x", -1)) - int(to_pos.get("x", -1)))
				+ abs(int(from_pos.get("y", -1)) - int(to_pos.get("y", -1)))
			)
			move_range = int(event.get("moveRange", -1))
		elif String(event.get("type", "")) == "DAMAGE_APPLIED":
			damage_events += 1
			total_final_damage += int(Dictionary(event.get("payload", {})).get("finalDamage", 0))
		elif String(event.get("type", "")) == "SKILL_TRIGGERED":
			skill_events += 1
	var expected_queue: Array = state.call("_skill_control_entries", StateScript.ENEMY)

	var ok := true
	ok = _expect(moved_distance == 3, "enemy uses independent movement range 3") and ok
	ok = _expect(move_range == 3, "movement trace reports independent movement range") and ok
	ok = _expect(int(enemy.get("ap", -1)) == 5, "legacy AP remains unchanged") and ok
	ok = _expect(int(enemy.get("attack_count", -1)) == 1, "enemy keeps independent attack count 1") and ok
	ok = _expect(expected_queue.size() == 2, "one enemy contributes exactly A/B to the shared control bar") and ok
	ok = _expect(skill_events == expected_queue.size(), "each queued enemy skill emits one ordered trigger") and ok
	ok = _expect(damage_events > int(enemy.get("attack_count", 0)), "legacy attack_count no longer truncates the multi-skill action queue") and ok
	ok = _expect(int(player.get("hp", -1)) == max(0, 50 - total_final_damage), "authoritative damage traces exactly explain the resulting player hp") and ok

	var legacy_enemy := _enemy("enemy_legacy", 2, 2)
	legacy_enemy.erase("attack_count")
	legacy_enemy["ap"] = 2
	ok = _expect(int(state.call("_enemy_attack_count", legacy_enemy)) == 2, "legacy enemy without attack_count falls back to AP") and ok

	print("SMOKE_ENEMY_MOVEMENT_ATTACK_COUNT_SPLIT_%s" % ["OK" if ok else "FAIL"])
	quit(0 if ok else 1)


func _player(unit_id: String, x: int, y: int) -> Dictionary:
	return {
		"id": unit_id,
		"name": "我方目标",
		"side": "player",
		"x": x,
		"y": y,
		"hp": 50,
		"max_hp": 50,
		"shield": 0,
		"def": 0,
		"atk": 1,
		"ap": 3,
		"active": true,
	}


func _enemy(unit_id: String, x: int, y: int) -> Dictionary:
	return {
		"id": unit_id,
		"name": "拆分敌人",
		"side": "enemy",
		"x": x,
		"y": y,
		"hp": 20,
		"max_hp": 20,
		"shield": 0,
		"def": 0,
		"atk": 4,
		"ap": 5,
		"move_range": 3,
		"attack_count": 1,
		"shape_id": "01",
		"shape_name": "形状01",
		"slot_count": 3,
		"slot_elements": ["火", "火", "火"],
		"base_layers": 1,
		"action_slots_used": {},
		"active": true,
	}


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("SMOKE_ENEMY_MOVEMENT_ATTACK_COUNT_SPLIT_FAIL: %s" % message)
	return condition
