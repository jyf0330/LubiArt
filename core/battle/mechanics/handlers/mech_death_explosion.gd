extends "res://core/battle/mechanics/handlers/bases/lifecycle_death_explosion_handler_base.gd"


func plugin_id() -> String:
	return "mech_death_explosion"


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
		"damage": max(1, _mechanic_param_int(unit, mechanism, "damage", 6)),
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
	return "死亡爆炸波及"
