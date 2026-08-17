extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
func plugin_id() -> String: return "apply_status"
func consumed_stats(_effect: Dictionary, _source_kind: String) -> Array[String]: return [StatIdsScript.STATUS_HIT_PERMILLE, StatIdsScript.STATUS_DURATION_PERMILLE]
func execute(port: RefCounted, context: Dictionary, effect: Dictionary) -> Variant: return port.call(&"apply_status", context, effect)
