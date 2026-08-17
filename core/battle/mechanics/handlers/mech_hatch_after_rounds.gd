extends "res://core/battle/mechanics/handlers/bases/round_handler_base.gd"


func plugin_id() -> String:
	return "mech_hatch_after_rounds"


func round_end(port: RefCounted, unit: Dictionary, _side: String, mechanism: Dictionary) -> Array:
	if not _accepts_round_port(port) or unit.is_empty() or bool(unit.get("hatched", false)):
		return []
	var rounds: int = max(1, int(port.mechanic_param_int(unit, mechanism, "rounds", 3)))
	var flags := Dictionary(unit.get("flags", {}))
	var tick: int = int(flags.get("hatchTicks", 0)) + 1
	flags["hatchTicks"] = tick
	unit["flags"] = flags
	if tick < rounds:
		return ["%s 孵化倒计时 %d/%d。" % [String(unit.get("name", "单位")), tick, rounds]]
	var hatch_id := String(port.mechanic_param_string(unit, mechanism, "summon", "hatched_unit"))
	var hp_before: int = max(1, int(unit.get("max_hp", unit.get("maxHp", unit.get("hp", 1)))))
	var atk_before: int = max(0, int(unit.get("atk", unit.get("attack", 0))))
	var hp_after: int = hp_before + max(6, int(ceil(float(hp_before) * 0.5)))
	var atk_after: int = atk_before + max(2, int(ceil(float(max(1, atk_before)) * 0.5)))
	flags["hatchComplete"] = true
	unit["flags"] = flags
	unit["hatched"] = true
	unit["hatch_summon_id"] = hatch_id
	unit["max_hp"] = hp_after
	unit["maxHp"] = hp_after
	unit["hp"] = hp_after
	unit["atk"] = atk_after
	unit["attack"] = atk_after
	unit["name"] = "%s孵化体" % String(unit.get("name", "单位"))
	return ["%s 孵化完成，成长为 %s：HP %d→%d，攻击 %d→%d。" % [
		String(unit.get("name", "单位")), hatch_id, hp_before, hp_after, atk_before, atk_after
	]]
