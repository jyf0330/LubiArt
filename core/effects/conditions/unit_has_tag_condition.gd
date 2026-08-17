extends RefCounted
func plugin_id() -> String: return "unit_has_tag"
func matches(condition: Dictionary, context: Dictionary) -> bool: return Array(Dictionary(context.get("unit", {})).get("tags", [])).has(String(condition.get("value", "")))
