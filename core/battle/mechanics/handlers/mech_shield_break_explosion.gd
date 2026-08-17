extends "res://core/battle/mechanics/handlers/bases/lifecycle_death_explosion_handler_base.gd"


func plugin_id() -> String:
	return "mech_shield_break_explosion"


func on_shield_break(port: RefCounted, unit: Dictionary, source: Dictionary, mechanism: Dictionary) -> Array:
	var logs: Array = []
	if not _accepts_lifecycle_port(port) or unit.is_empty():
		return logs
	var flags := Dictionary(unit.get("flags", {}))
	if bool(flags.get("shieldBreakExplosionResolving", false)):
		return logs
	var damage: int = max(1, int(port.mechanic_param_int(unit, mechanism, "damage", 5)))
	var label := "%s 破盾爆炸，造成 %d 点伤害" % [String(unit.get("name", "单位")), damage]
	flags["shieldBreakExplosionResolving"] = true
	unit["flags"] = flags
	var result := Dictionary(port.cross_damage(
		unit,
		source,
		damage,
		String(unit.get("element", "")),
		label,
		{"sourceType": plugin_id(), "sourceLabel": "破盾爆炸波及"}
	))
	logs.append("%s。" % label)
	for line in Array(result.get("logs", [])):
		logs.append(String(line))
	if int(result.get("hit_count", 0)) <= 0:
		logs.append("破盾爆炸没有波及相邻敌对单位。")
	flags = Dictionary(unit.get("flags", {}))
	flags["shieldBreakExplosionResolving"] = false
	unit["flags"] = flags
	return logs


func project_death_preview(
	unit: Dictionary,
	mechanism: Dictionary,
	facts: Dictionary
) -> Dictionary:
	if not bool(facts.get("projected_dead", false)):
		return {}
	return {
		"radius": 1,
		"metric": "manhattan",
		"damage": max(1, _mechanic_param_int(unit, mechanism, "damage", 5)),
	}


func _mechanic_param_int(unit: Dictionary, mechanism: Dictionary, key: String, fallback: int) -> int:
	var unit_params := Dictionary(unit.get("mechanic_params", unit.get("mechanicParams", {})))
	if unit_params.has(key):
		return int(unit_params.get(key, fallback))
	for part in String(mechanism.get("default_params", "")).replace("；", ";").split(";", false):
		var text := String(part).strip_edges()
		var equals_index := text.find("=")
		if equals_index > 0 and text.substr(0, equals_index).strip_edges() == key:
			return int(float(text.substr(equals_index + 1).strip_edges()))
	return fallback


func _trace_source_label() -> String:
	return "破盾爆炸波及"
