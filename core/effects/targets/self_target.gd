extends RefCounted
func plugin_id() -> String: return "self"
func resolve(context: Dictionary, _effect: Dictionary) -> Array: return [Dictionary(context.get("unit", {}))]
