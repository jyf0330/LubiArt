extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_death_summon"


func on_death(port: RefCounted, unit: Dictionary, _source: Dictionary, mechanism: Dictionary) -> Array:
	if not _accepts_lifecycle_port(port) or unit.is_empty() or int(unit.get("hp", 0)) > 0:
		return []
	var count: int = max(1, int(port.mechanic_param_int(unit, mechanism, "count", 2)))
	var summoned_count := _summon_death_units(port, unit, mechanism, count, "死亡召唤物", 6, 1)
	return [
		"%s 死亡后留下 %d 个单位。" % [String(unit.get("name", "单位")), summoned_count],
		"%s 死亡召唤/分裂被记录。" % String(unit.get("name", "单位")),
	]
