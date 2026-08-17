extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
func plugin_id() -> String: return "lifesteal_damage"
func event_id() -> String: return EffectHookIdsScript.DAMAGE_AFTER
func order() -> int: return 100
func consumed_stats() -> Array[String]: return [StatIdsScript.LIFESTEAL_PERMILLE]
func apply(context: Dictionary) -> Dictionary:
	var ratio := clampi(_stat(context, Dictionary(context.get("source", {})), StatIdsScript.LIFESTEAL_PERMILLE, 0), 0, 1000)
	context["lifesteal_heal"] = int((max(0, int(context.get("hp_damage", 0))) * ratio + 500) / 1000)
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, fallback: int) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": EffectHookIdsScript.DAMAGE_AFTER, "target": context.get("target", {})})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
