extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_summon_after_kill"


func after_kill(port: RefCounted, killer: Dictionary, _defeated: Dictionary, mechanism: Dictionary) -> Array:
	var logs: Array = []
	if not _accepts_lifecycle_port(port) or killer.is_empty() or int(killer.get("hp", 0)) <= 0:
		return logs
	var count: int = max(1, int(port.mechanic_param_int(killer, mechanism, "count", 1)))
	var summoned_count := 0
	for _summon_index in range(count):
		var cell := Dictionary(port.first_adjacent_empty(killer))
		if cell.is_empty():
			break
		var summoned := Dictionary(port.summon_unit(killer, mechanism, cell, "ally_sprite", "小灵", 6, 1))
		if summoned.is_empty():
			break
		summoned_count += 1
		logs.append("%s 触发%s：击杀后召唤援军%s，落点(%d,%d)。" % [
			String(killer.get("name", "单位")),
			String(mechanism.get("name", plugin_id())),
			String(summoned.get("name", "援军")),
			int(summoned.get("x", 0)) + 1,
			int(summoned.get("y", 0)) + 1,
		])
	if summoned_count <= 0:
		logs.append("%s 触发%s：击杀后召唤没有可用空格。" % [
			String(killer.get("name", "单位")), String(mechanism.get("name", plugin_id()))
		])
	return logs
