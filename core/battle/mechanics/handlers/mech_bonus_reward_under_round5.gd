extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_bonus_reward_under_round5"


func battle_end(port: RefCounted, unit: Dictionary, win: bool, reward_state: Dictionary, mechanism: Dictionary) -> Dictionary:
	var next := _reward_copy(reward_state)
	if not _accepts_lifecycle_port(port) or not win or int(unit.get("hp", 0)) <= 0 or int(port.battle_round()) > 5:
		return next
	var before := int(next.get("gold", 0))
	var after := before + 1
	next["gold"] = after
	Array(next["logs"]).append("%s 触发快速奖励+1金币。" % String(unit.get("name", "单位")))
	Array(next["applied"]).append({
		"mechanic_id": plugin_id(),
		"unit_id": String(unit.get("id", "")),
		"name": String(mechanism.get("name", plugin_id())),
		"gold_from": before,
		"gold_to": after,
	})
	return next
