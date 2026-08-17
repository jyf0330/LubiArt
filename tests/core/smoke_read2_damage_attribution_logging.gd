extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const PlayerOperationProjectorScript := preload("res://core/logging/player_operation_projector.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture starts a formal battle")
	var players := _units_for_side(state, StateScript.PLAYER)
	var enemies := _units_for_side(state, StateScript.ENEMY)
	_expect(not players.is_empty() and not enemies.is_empty(), "fixture exposes a player and an enemy")
	if players.is_empty() or enemies.is_empty():
		_finish()
		return

	var killer := Dictionary(players[0])
	var victim := killer.duplicate(true)
	var bomb := Dictionary(enemies[0])
	killer["id"] = "pal_002"
	killer["name"] = "捣蛋猫"
	killer["x"] = 2
	killer["y"] = 3
	killer["hp"] = 24
	killer["max_hp"] = 24
	victim["id"] = "shop_004"
	victim["name"] = "波娜兔"
	victim["x"] = 4
	victim["y"] = 4
	victim["hp"] = 10
	victim["max_hp"] = 10
	victim["shield"] = 0
	victim["def"] = 0
	bomb["id"] = "enemy_r01_002"
	bomb["name"] = "炽焰牛"
	bomb["x"] = 4
	bomb["y"] = 3
	bomb["hp"] = 4
	bomb["max_hp"] = 10
	bomb["shield"] = 0
	bomb["def"] = 0
	bomb["mechanism_id"] = "mech_self_destruct"
	bomb["mechanism_params"] = ""
	bomb["flags"] = {}
	state.units = [killer, victim, bomb]
	state.battle_trace = []
	state.log_lines = []

	state.call("_deal_damage", killer, bomb, 4, "无", true, {
		"sourceType": "action",
		"strikeIndex": 1,
		"strikeCount": 3
	})

	var action_event := _damage_event(state.battle_trace, "action", "enemy_r01_002")
	var explosion_event := _damage_event(state.battle_trace, "mech_self_destruct", "shop_004")
	_expect(not action_event.is_empty(), "killer action damage remains attributed to 捣蛋猫")
	_expect(not explosion_event.is_empty(), "death self-destruct emits a separate damage event")
	if not explosion_event.is_empty():
		var actor := Dictionary(explosion_event.get("actor", {}))
		var payload := Dictionary(explosion_event.get("payload", {}))
		_expect(String(actor.get("id", "")) == "enemy_r01_002", "self-destruct actor is 炽焰牛, not its killer")
		_expect(String(payload.get("causedById", "")) == "pal_002", "self-destruct keeps the causal killer as secondary metadata")
		_expect(int(payload.get("finalDamage", -1)) == 8, "read2 self-destruct still deals the configured 8 damage")
		_expect(int(payload.get("hpDamage", -1)) == 8 and int(victim.get("hp", -1)) == 2, "波娜兔 loses exactly 8 HP")
		var text := String(explosion_event.get("text", ""))
		_expect(text.contains("炽焰牛自爆波及波娜兔造成 8 伤害"), "trace text names the real source, target, and damage")
		_expect(text.contains("生命 8") and text.contains("HP 10→2"), "trace text includes HP damage and before/after values")
		_expect(_log_contains(state.log_lines, text), "the detailed damage line is copied into the player recent log")
		var summaries := PlayerOperationProjectorScript.new().event_summaries([explosion_event], {
			"round": state.battle_round,
			"phase": state.phase,
		})
		var summary := Dictionary(summaries[0]) if not summaries.is_empty() else {}
		_expect(String(summary.get("actorName", "")) == "炽焰牛", "operation event summary includes the real source name")
		_expect(String(summary.get("targetName", "")) == "波娜兔", "operation event summary includes the target name")
		_expect(String(summary.get("sourceType", "")) == "mech_self_destruct", "operation event summary includes the source type")
		_expect(String(summary.get("causedByName", "")) == "捣蛋猫", "operation event summary preserves the causal killer name")

	state.log_lines = ["新伤害 2", "新伤害 1", "旧日志 1", "旧日志 2", "旧日志 3", "旧日志 4", "旧日志 5", "旧日志 6"]
	var projector := PlayerOperationProjectorScript.new()
	var new_logs := projector.new_logs([
		"旧日志 1", "旧日志 2", "旧日志 3", "旧日志 4",
		"旧日志 5", "旧日志 6", "旧日志 7", "旧日志 8"
	], state.log_lines)
	_expect(new_logs == ["新伤害 2", "新伤害 1"], "operation log captures newly push-fronted rows after the recent-log cap")
	var unchanged_logs := projector.new_logs(state.log_lines, state.log_lines)
	_expect(unchanged_logs.is_empty(), "operation log emits no rows when the recent log did not change")

	_finish()


func _units_for_side(state: RefCounted, side: String) -> Array:
	var rows: Array = []
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == side:
			rows.append(unit)
	return rows


func _damage_event(events: Array, source_type: String, target_id: String) -> Dictionary:
	for event_value in events:
		var event := Dictionary(event_value)
		var payload := Dictionary(event.get("payload", {}))
		var target := Dictionary(event.get("target", {}))
		if (
			String(event.get("type", "")) == "DAMAGE_APPLIED"
			and String(payload.get("sourceType", "")) == source_type
			and String(target.get("id", "")) == target_id
		):
			return event
	return {}


func _log_contains(lines: Array, needle: String) -> bool:
	for line in lines:
		if String(line) == needle:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_READ2_DAMAGE_ATTRIBUTION_LOGGING_FAIL: %s" % message)


func _finish() -> void:
	if failed:
		quit(1)
		return
	print("SMOKE_READ2_DAMAGE_ATTRIBUTION_LOGGING_OK")
	quit(0)
