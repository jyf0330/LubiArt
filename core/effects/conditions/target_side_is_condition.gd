extends RefCounted
func plugin_id() -> String: return "target_side_is"
func matches(condition: Dictionary, context: Dictionary) -> bool: return String(Dictionary(context.get("target", {})).get("side", "")) == String(condition.get("value", ""))
