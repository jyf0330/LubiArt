extends RefCounted
func plugin_id() -> String: return "skill_has_tag"
func matches(condition: Dictionary, context: Dictionary) -> bool: return Array(Dictionary(context.get("definition", {})).get("tags", [])).has(String(condition.get("value", "")))
