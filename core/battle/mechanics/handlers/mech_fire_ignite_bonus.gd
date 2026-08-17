extends RefCounted


func plugin_id() -> String:
	return "mech_fire_ignite_bonus"


func project_element_settlement(
	unit: Dictionary,
	mechanism: Dictionary,
	facts: Dictionary
) -> Dictionary:
	if String(facts.get("element", "")) != "火":
		return {}
	var layers: int = max(0, int(facts.get("layers", 0)))
	var per_layer: int = _mechanic_param_int(unit, mechanism, "per_layer", 1)
	return {
		"exclusive_key": "fire_ignite_bonus",
		"damage_add": layers * per_layer,
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
