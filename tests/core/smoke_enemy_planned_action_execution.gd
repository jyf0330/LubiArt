extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var production: RefCounted = StateScript.new()
	var fixture_content := Dictionary(production.game_data).duplicate(true)
	var skill_catalog := Dictionary(fixture_content.get("skill_catalog", {}))
	var strike_skill := Dictionary(skill_catalog.get("skill_vanguard", {})).duplicate(true)
	strike_skill["strike_count"] = 3
	skill_catalog["skill_vanguard"] = strike_skill
	fixture_content["skill_catalog"] = skill_catalog
	var state: RefCounted = StateScript.new({
		"mode": "test",
		"content_pack": fixture_content,
		"content_source_kind": production.call("content_source_kind"),
	})
	state.phase = "battle"
	state.battle_round = 5
	state.ap = 3
	state.units = [
		_player("player_a", "我方甲", 2, 0),
		_player("player_b", "我方乙", 2, 2),
		_enemy("enemy_a", "敌方甲", 0, 0),
		_enemy("enemy_b", "敌方乙", 0, 2),
	]
	state.battle_roster_templates[StateScript.ENEMY] = [
		Dictionary(state.units[2]).duplicate(true),
		Dictionary(state.units[3]).duplicate(true),
	]
	state._initialize_skill_control_orders()

	state.call("_enemy_turn")
	var player_a := Dictionary(state.call("unit_by_id", "player_a"))
	var player_b := Dictionary(state.call("unit_by_id", "player_b"))
	var damage_events: Array = []
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		var payload := Dictionary(event.get("payload", {}))
		if String(event.get("type", "")) == "DAMAGE_APPLIED" \
			and String(payload.get("sourceType", "")) == "skill":
			damage_events.append(event)

	var ok := true
	ok = _expect(int(player_a.get("hp", -1)) == 0, "distance-2 shape action blocks kill player A") and ok
	ok = _expect(int(player_b.get("hp", -1)) == 0, "distance-2 shape action blocks kill player B") and ok
	ok = _expect(damage_events.size() == 6, "two attack-count-3 enemies emit three skill damage blocks each") and ok
	if damage_events.size() == 6:
		var attacker_counts := {"enemy_a": 0, "enemy_b": 0}
		for event_value in damage_events:
			var attacker_id := String(Dictionary(event_value).get("actor", {}).get("id", ""))
			attacker_counts[attacker_id] = int(attacker_counts.get(attacker_id, 0)) + 1
		ok = _expect(int(attacker_counts.get("enemy_a", 0)) == 3 and int(attacker_counts.get("enemy_b", 0)) == 3, "both planned enemies spend all three action blocks") and ok
		for event_value in damage_events:
			var payload := Dictionary(Dictionary(event_value).get("payload", {}))
			ok = _expect(String(payload.get("sourceType", "")) == "skill", "enemy damage trace identifies the planned skill source") and ok

	print("SMOKE_ENEMY_PLANNED_ACTION_EXECUTION_%s" % ["OK" if ok else "FAIL"])
	quit(0 if ok else 1)


func _player(id: String, display_name: String, x: int, y: int) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"side": "player",
		"x": x,
		"y": y,
		"hp": 10,
		"max_hp": 10,
		"shield": 0,
		"def": 0,
		"atk": 1,
		"ap": 3,
		"active": true,
	}


func _enemy(id: String, display_name: String, x: int, y: int) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"side": "enemy",
		"x": x,
		"y": y,
		"hp": 10,
		"max_hp": 10,
		"shield": 0,
		"def": 0,
		"atk": 4,
		"ap": 3,
		"attack_count": 3,
		"skill": "skill_vanguard",
		"move_range": 0,
		"shape_id": "05",
		"shape_name": "形状05",
		"slot_count": 3,
		"slot_elements": ["火", "火", "火"],
		"base_layers": 1,
		"action_slots_used": {},
		"active": true,
	}


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("SMOKE_ENEMY_PLANNED_ACTION_EXECUTION_FAIL: %s" % message)
	return condition
