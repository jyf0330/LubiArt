extends RefCounted
func plugin_id() -> String: return "unit_element_is"
func matches(condition: Dictionary, context: Dictionary) -> bool:
	var unit := Dictionary(context.get("unit", {}))
	var elements := Array(unit.get("element_types", [])).duplicate()
	if not elements.has(String(unit.get("element", ""))): elements.append(String(unit.get("element", "")))
	return elements.has(String(condition.get("value", "")))
