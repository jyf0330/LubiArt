extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
func plugin_id() -> String: return "heal"
func consumed_stats(effect: Dictionary, _source_kind: String) -> Array[String]:
	return [StatIdsScript.HEALING_POWER_PERMILLE] + ([StatIdsScript.ATK] if bool(effect.get("scale_with_atk", false)) else [])
func execute(port: RefCounted, context: Dictionary, effect: Dictionary) -> Variant: return port.call(&"apply_heal", context, effect)
