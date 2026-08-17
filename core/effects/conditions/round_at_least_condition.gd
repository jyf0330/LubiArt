extends RefCounted
func plugin_id() -> String: return "round_at_least"
func matches(condition: Dictionary, context: Dictionary) -> bool: return int(context.get("round", 0)) >= int(condition.get("value", 0))
