extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_split_into_minions"


func on_death(port: RefCounted, unit: Dictionary, _source: Dictionary, mechanism: Dictionary) -> Array:
	if not _accepts_lifecycle_port(port) or unit.is_empty() or int(unit.get("hp", 0)) > 0:
		return []
	var count: int = max(1, int(port.mechanic_param_int(unit, mechanism, "count", 2)))
	var maximum: int = max(1, int(unit.get("max_hp", unit.get("maxHp", unit.get("hp", 1)))))
	var hp_pct: float = max(0.01, float(port.mechanic_param_float(unit, mechanism, "hp_pct", 0.4)))
	var split_hp: int = max(1, int(ceil(float(maximum) * hp_pct)))
	var split_count := _summon_death_units(port, unit, mechanism, count, "分裂小怪", split_hp, 1)
	return [
		"%s 分裂成 %d 只小怪。" % [String(unit.get("name", "单位")), split_count],
		"%s 死亡召唤/分裂被记录。" % String(unit.get("name", "单位")),
	]
