extends RefCounted
func plugin_id() -> String: return "all_enemies"
func resolve(context: Dictionary, _effect: Dictionary) -> Array:
	var source := Dictionary(context.get("unit", {})); var result: Array = []
	for value in Array(context.get("all_units", [])):
		var unit := Dictionary(value)
		if String(unit.get("side", "")) != String(source.get("side", "")) and int(unit.get("hp", 0)) > 0: result.append(unit)
	return result
