extends RefCounted


func plugin_id() -> String:
	return "mech_multi_element_bonus"


func project_element_settlement(
	unit: Dictionary,
	mechanism: Dictionary,
	facts: Dictionary
) -> Dictionary:
	if int(facts.get("active_element_type_count", 0)) < 2:
		return {}
	var bonus: int = max(0, _mechanic_param_int(unit, mechanism, "bonus", 3))
	return {
		"exclusive_key": "multi_element_bonus",
		"damage_add": bonus,
		"source": unit.duplicate(true),
		"target_pattern": "",
	}


func _mechanic_param_int(unit: Dictionary, mechanism: Dictionary, key: String, fallback: int) -> int:
	var unit_params: Dictionary = Dictionary(unit.get("mechanic_params", unit.get("mechanicParams", {})))
	if unit_params.has(key):
		return int(unit_params.get(key, fallback))
	for part in String(mechanism.get("default_params", "")).replace("；", ";").split(";", false):
		var text := String(part).strip_edges()
		var equals_index := text.find("=")
		if equals_index > 0 and text.substr(0, equals_index).strip_edges() == key:
			return int(float(text.substr(equals_index + 1).strip_edges()))
	return fallback
