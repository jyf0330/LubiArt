extends RefCounted


func plugin_id() -> String:
	return "mech_guard_taunt"


func project_threat_redirect(
	unit: Dictionary,
	mechanism: Dictionary,
	_facts: Dictionary
) -> Dictionary:
	return {
		"range": max(1, _mechanic_param_int(unit, mechanism, "range", 1)),
		"mechanic_id": String(mechanism.get("id", "")),
		"mechanic_name": String(mechanism.get("name", "嘲讽守护")),
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
