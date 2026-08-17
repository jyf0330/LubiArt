extends RefCounted
func plugin_id() -> String: return "modify_stat"
func consumed_stats(_effect: Dictionary, _source_kind: String) -> Array[String]: return []
func execute(port: RefCounted, context: Dictionary, effect: Dictionary) -> Variant: return port.call(&"apply_stat_modifier", context, effect)
