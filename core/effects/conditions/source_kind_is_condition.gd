extends RefCounted
func plugin_id() -> String: return "source_kind_is"
func matches(condition: Dictionary, context: Dictionary) -> bool: return String(context.get("source_kind", "")) == String(condition.get("value", ""))
