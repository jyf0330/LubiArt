extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_reduce_reward_if_alive"


func battle_end(port: RefCounted, unit: Dictionary, _win: bool, reward_state: Dictionary, mechanism: Dictionary) -> Dictionary:
	var next := _reward_copy(reward_state)
	if (
		not _accepts_lifecycle_port(port)
		or int(unit.get("hp", 0)) <= 0
		or String(unit.get("side", "")) != String(port.enemy_side())
	):
		return next
	var reward_pct := float(port.mechanic_param_float(unit, mechanism, "reward_pct", -0.2))
	if reward_pct >= 0.0:
		return next
	var before := int(next.get("gold", 0))
	var reduction := 0
	if before > 0:
		reduction = max(1, int(ceil(float(before) * abs(reward_pct))))
	var after: int = max(0, before - reduction)
	next["gold"] = after
	Array(next["logs"]).append("%s 存活，奖励降低：金币 %d→%d。" % [
		String(unit.get("name", "敌人")), before, after
	])
	Array(next["applied"]).append({
		"mechanic_id": plugin_id(),
		"unit_id": String(unit.get("id", "")),
		"name": String(mechanism.get("name", plugin_id())),
		"reward_pct": reward_pct,
		"gold_from": before,
		"gold_to": after,
	})
	return next
