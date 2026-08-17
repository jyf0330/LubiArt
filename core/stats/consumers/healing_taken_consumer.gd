extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
func plugin_id() -> String: return "healing_taken"
func event_id() -> String: return EffectHookIdsScript.HEALING
func order() -> int: return 100
func consumed_stats() -> Array[String]: return [StatIdsScript.HEALING_TAKEN_PERMILLE]
func apply(context: Dictionary) -> Dictionary:
	var ratio: int = max(0, _stat(context, Dictionary(context.get("target", {})), StatIdsScript.HEALING_TAKEN_PERMILLE, 1000))
	context["amount"] = int((max(0, int(context.get("amount", 0))) * ratio + 500) / 1000)
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, fallback: int) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": EffectHookIdsScript.HEALING, "source": context.get("source", {})})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
