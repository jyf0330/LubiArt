extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
func plugin_id() -> String: return "speed_action_order"
func event_id() -> String: return EffectHookIdsScript.ACTION_ORDER
func order() -> int: return 100
func consumed_stats() -> Array[String]: return [StatIdsScript.SPEED]
func apply(context: Dictionary) -> Dictionary:
	context[StatIdsScript.SPEED] = _stat(context, Dictionary(context.get("unit", {})), StatIdsScript.SPEED, EffectHookIdsScript.ACTION_ORDER, 100)
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, hook: String, fallback: int) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": hook})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
