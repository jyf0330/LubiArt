extends "res://core/battle/mechanics/handlers/bases/round_handler_base.gd"


func plugin_id() -> String:
	return "mech_countdown_pressure"


func round_start(port: RefCounted, unit: Dictionary, _side: String, mechanism: Dictionary) -> Array:
	if not _accepts_round_port(port) or unit.is_empty():
		return []
	var trigger_round: int = max(1, int(port.mechanic_param_int(unit, mechanism, "round", 5)))
	if int(port.battle_round()) < trigger_round:
		return []
	var flags := Dictionary(unit.get("flags", {}))
	if bool(flags.get("countdownPressureTriggered", false)):
		return []
	var cell := Dictionary(port.first_adjacent_empty_cell(unit))
	if cell.is_empty():
		cell = Dictionary(port.first_empty_cell())
	var summoned := Dictionary(port.summon_unit_on_cell(
		unit, mechanism, cell, "pressure_spawn", "压力增援", 10, 2
	))
	if summoned.is_empty():
		return []
	flags["countdownPressureTriggered"] = true
	unit["flags"] = flags
	return ["倒计时触发，战场压力上升：%s 召唤%s。" % [
		String(unit.get("name", "单位")), String(summoned.get("name", "压力增援"))
	]]
