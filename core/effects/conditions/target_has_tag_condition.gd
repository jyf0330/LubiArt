extends RefCounted
func plugin_id() -> String: return "target_has_tag"
func matches(condition: Dictionary, context: Dictionary) -> bool: return Array(Dictionary(context.get("target", {})).get("tags", [])).has(String(condition.get("value", "")))
