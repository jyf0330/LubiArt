extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
func plugin_id() -> String: return "movement_cost"
func event_id() -> String: return EffectHookIdsScript.MOVEMENT_COST
func order() -> int: return 100
func consumed_stats() -> Array[String]: return [StatIdsScript.MOVEMENT_COST_DELTA]
func apply(context: Dictionary) -> Dictionary:
	var unit := Dictionary(context.get("unit", {}))
	context["cost"] = max(0, int(context.get("base_cost", 0)) + _stat(context, unit, StatIdsScript.MOVEMENT_COST_DELTA, 0))
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, fallback: int) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": EffectHookIdsScript.MOVEMENT_COST})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
