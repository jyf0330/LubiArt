extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_curse_gold_loss"


func battle_end(port: RefCounted, unit: Dictionary, _win: bool, reward_state: Dictionary, mechanism: Dictionary) -> Dictionary:
	var next := _reward_copy(reward_state)
	if not _accepts_lifecycle_port(port) or int(unit.get("hp", 0)) <= 0:
		return next
	var before := int(next.get("gold", 0))
	var after: int = max(0, before - 1)
	next["gold"] = after
	Array(next["applied"]).append({
		"mechanic_id": plugin_id(),
		"unit_id": String(unit.get("id", "")),
		"name": String(mechanism.get("name", plugin_id())),
		"gold_from": before,
		"gold_to": after,
	})
	return next
