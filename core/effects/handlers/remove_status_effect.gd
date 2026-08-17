extends RefCounted
func plugin_id() -> String: return "remove_status"
func consumed_stats(_effect: Dictionary, _source_kind: String) -> Array[String]: return []
func execute(port: RefCounted, context: Dictionary, effect: Dictionary) -> Variant: return port.call(&"remove_status", context, effect)
