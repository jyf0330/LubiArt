extends RefCounted
func plugin_id() -> String: return "unit_side_is"
func matches(condition: Dictionary, context: Dictionary) -> bool: return String(Dictionary(context.get("unit", {})).get("side", "")) == String(condition.get("value", ""))
