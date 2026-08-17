extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_elite_reward_bonus"


func battle_end(port: RefCounted, unit: Dictionary, win: bool, reward_state: Dictionary, mechanism: Dictionary) -> Dictionary:
	var next := _reward_copy(reward_state)
	if not _accepts_lifecycle_port(port) or not win or int(unit.get("hp", 0)) > 0:
		return next
	var reward_id := String(port.mechanic_param_string(unit, mechanism, "reward", "elite_chest"))
	var reward := {
		"mechanic_id": plugin_id(),
		"unit_id": String(unit.get("id", "")),
		"name": String(mechanism.get("name", "精英额外奖励")),
		"reward_id": reward_id,
	}
	Array(next["extra_rewards"]).append(reward)
	Array(next["applied"]).append(reward)
	Array(next["logs"]).append("击败精英，获得额外奖励：%s。" % reward_id)
	return next
