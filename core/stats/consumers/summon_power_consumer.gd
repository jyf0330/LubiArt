extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
func plugin_id() -> String: return "summon_power"
func event_id() -> String: return EffectHookIdsScript.SUMMON
func order() -> int: return 100
func consumed_stats() -> Array[String]: return [StatIdsScript.SUMMON_POWER_PERMILLE]
func apply(context: Dictionary) -> Dictionary:
	var ratio: int = max(0, _stat(context, Dictionary(context.get("unit", {})), StatIdsScript.SUMMON_POWER_PERMILLE, 1000))
	for key in ["hp", StatIdsScript.ATK, "shield"]:
		if context.has(key): context[key] = int((max(0, int(context.get(key, 0))) * ratio + 500) / 1000)
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, fallback: int) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": EffectHookIdsScript.SUMMON})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
