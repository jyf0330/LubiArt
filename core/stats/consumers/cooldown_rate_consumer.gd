extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
func plugin_id() -> String: return "cooldown_rate"
func event_id() -> String: return EffectHookIdsScript.COOLDOWN
func order() -> int: return 100
func consumed_stats() -> Array[String]: return [StatIdsScript.COOLDOWN_RATE_PERMILLE]
func apply(context: Dictionary) -> Dictionary:
	var rate: int = max(1, _stat(context, Dictionary(context.get("unit", {})), StatIdsScript.COOLDOWN_RATE_PERMILLE, 1000))
	var ticks: int = max(0, int(context.get("ticks", 0)))
	context["ticks"] = int((ticks * 1000 + rate - 1) / rate)
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, fallback: int) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": EffectHookIdsScript.COOLDOWN})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
