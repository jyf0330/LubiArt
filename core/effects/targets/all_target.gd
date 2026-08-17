extends RefCounted
func plugin_id() -> String: return "all"
func resolve(context: Dictionary, _effect: Dictionary) -> Array:
	var result := [Dictionary(context.get("unit", {}))]
	result.append_array(Array(context.get("targets", [])))
	return result
