extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
func plugin_id() -> String: return "action_cost"
func event_id() -> String: return EffectHookIdsScript.ACTION_COST
func order() -> int: return 100
func consumed_stats() -> Array[String]: return [StatIdsScript.ACTION_POINTS, StatIdsScript.ACTION_COST_DELTA]
func apply(context: Dictionary) -> Dictionary:
	var unit := Dictionary(context.get("unit", {}))
	var cap: int = max(0, _stat(context, unit, StatIdsScript.ACTION_POINTS, 3))
	var requested := clampi(max(0, int(context.get("requested", 0))), 0, cap)
	context["requested"] = requested
	context["cost"] = max(0, requested + _stat(context, unit, StatIdsScript.ACTION_COST_DELTA, 0))
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, fallback: int) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": EffectHookIdsScript.ACTION_COST})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
