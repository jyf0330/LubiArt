extends RefCounted
func plugin_id() -> String: return "roll_permille_lte"
func matches(condition: Dictionary, context: Dictionary) -> bool: return int(context.get("roll_permille", 1001)) <= int(condition.get("value", 0))
