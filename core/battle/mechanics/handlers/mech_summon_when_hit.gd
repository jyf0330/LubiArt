extends RefCounted


func plugin_id() -> String:
	return "mech_summon_when_hit"


func after_hit(port: RefCounted, target: Dictionary, _source: Dictionary, _amount: int, _damage_props: Dictionary, mechanism: Dictionary) -> Array:
	return _summon(port, target, mechanism, "summonWhenHitRound", "受击分裂")


func _summon(port: RefCounted, target: Dictionary, mechanism: Dictionary, round_flag: String, verb: String) -> Array:
	var logs: Array = []
	if int(target.get("hp", 0)) <= 0:
		return logs
	var flags := Dictionary(target.get("flags", {}))
	if int(flags.get(round_flag, -1)) == int(port.battle_round()):
		return logs
	var summon_count: int = max(1, int(port.mechanic_param_int(target, mechanism, "count", 1)))
	var summoned_count := 0
	for _summon_index in range(summon_count):
		var summon_cell := Dictionary(port.first_adjacent_empty_cell(target))
		if summon_cell.is_empty():
			break
		var summoned := Dictionary(port.summon_unit_on_cell(target, mechanism, summon_cell, "mon_swarm_plain_01", "分裂小怪", 6, 1))
		if summoned.is_empty():
			break
		summoned_count += 1
		logs.append("%s 触发%s：%s出%s，落点(%d,%d)。" % [
			String(target.get("name", "单位")), String(mechanism.get("name", plugin_id())), verb,
			String(summoned.get("name", "小怪")), int(summoned.get("x", 0)) + 1, int(summoned.get("y", 0)) + 1,
		])
	if summoned_count > 0:
		flags[round_flag] = int(port.battle_round())
		target["flags"] = flags
	else:
		logs.append("%s 触发%s：%s没有可用空格。" % [
			String(target.get("name", "单位")), String(mechanism.get("name", plugin_id())), verb,
		])
	return logs
