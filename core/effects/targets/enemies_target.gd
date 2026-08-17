extends RefCounted
func plugin_id() -> String: return "enemies"
func resolve(context: Dictionary, _effect: Dictionary) -> Array: return Array(context.get("targets", []))
