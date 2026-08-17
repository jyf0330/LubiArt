extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_copy_weak_self"


func after_action(port: RefCounted, actor: Dictionary, mechanism: Dictionary) -> Array:
	var logs: Array = []
	if not _accepts_lifecycle_port(port) or actor.is_empty() or int(actor.get("hp", 0)) <= 0:
		return logs
	var flags := Dictionary(actor.get("flags", {}))
	if int(flags.get("copyWeakSelfRound", -1)) == int(port.battle_round()):
		return logs
	var count: int = max(1, int(port.mechanic_param_int(actor, mechanism, "count", 1)))
	var hp_pct: float = max(0.01, float(port.mechanic_param_float(actor, mechanism, "hp_pct", 0.5)))
	var atk_pct: float = max(0.0, float(port.mechanic_param_float(actor, mechanism, "atk_pct", 0.5)))
	var copied_count := 0
	for _copy_index in range(count):
		var cell := Dictionary(port.first_adjacent_empty(actor))
		if cell.is_empty():
			break
		var copied := Dictionary(port.copy_weak_self(actor, cell, hp_pct, atk_pct))
		if copied.is_empty():
			break
		copied_count += 1
		logs.append("%s 触发%s：复制出一个弱化体%s，落点(%d,%d)，HP%d，攻击%d。" % [
			String(actor.get("name", "单位")),
			String(mechanism.get("name", plugin_id())),
			String(copied.get("name", "复制体")),
			int(copied.get("x", 0)) + 1,
			int(copied.get("y", 0)) + 1,
			int(copied.get("hp", 0)),
			int(copied.get("atk", 0)),
		])
	if copied_count > 0:
		flags["copyWeakSelfRound"] = int(port.battle_round())
		actor["flags"] = flags
	else:
		logs.append("%s 触发%s：复制弱化体没有可用空格。" % [
			String(actor.get("name", "单位")), String(mechanism.get("name", plugin_id()))
		])
	return logs
