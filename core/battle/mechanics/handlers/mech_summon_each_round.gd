extends "res://core/battle/mechanics/handlers/bases/round_handler_base.gd"


func plugin_id() -> String:
	return "mech_summon_each_round"


func round_start(port: RefCounted, unit: Dictionary, _side: String, mechanism: Dictionary) -> Array:
	if not _accepts_round_port(port) or unit.is_empty():
		return []
	var flags := Dictionary(unit.get("flags", {}))
	if int(flags.get("summonEachRoundLastRound", 0)) == int(port.battle_round()):
		return []
	var count: int = max(1, int(port.mechanic_param_int(unit, mechanism, "count", 1)))
	var summoned_count := 0
	for _index in range(count):
		var cell := Dictionary(port.first_adjacent_empty_cell(unit))
		if cell.is_empty():
			break
		var summoned := Dictionary(port.summon_unit_on_cell(
			unit, mechanism, cell, "mon_swarm_plain_01", "召唤物", 6, 1
		))
		if summoned.is_empty():
			break
		summoned_count += 1
	if summoned_count <= 0:
		return []
	flags["summonEachRoundLastRound"] = int(port.battle_round())
	unit["flags"] = flags
	return ["%s 召唤 %d 个单位。" % [String(unit.get("name", "单位")), summoned_count]]
