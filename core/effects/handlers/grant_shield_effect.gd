extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
func plugin_id() -> String: return "grant_shield"
func consumed_stats(_effect: Dictionary, _source_kind: String) -> Array[String]: return [StatIdsScript.SHIELD_GAIN_PERMILLE]
func execute(port: RefCounted, context: Dictionary, effect: Dictionary) -> Variant: return port.call(&"apply_shield", context, effect)
