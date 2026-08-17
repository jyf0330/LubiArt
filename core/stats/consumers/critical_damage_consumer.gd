extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
func plugin_id() -> String: return "critical_damage"
func event_id() -> String: return EffectHookIdsScript.DAMAGE_OUTGOING
func order() -> int: return 120
func consumed_stats() -> Array[String]: return [StatIdsScript.CRIT_RATE_PERMILLE, StatIdsScript.CRIT_DAMAGE_PERMILLE]
func apply(context: Dictionary) -> Dictionary:
	var source := Dictionary(context.get("source", {}))
	var rate := clampi(_stat(context, source, StatIdsScript.CRIT_RATE_PERMILLE, 0), 0, 1000)
	var roll := _roll(context, "critical")
	context["critical_roll"] = roll
	context["critical"] = rate > 0 and roll <= rate
	if bool(context["critical"]):
		context["amount"] = _permille(int(context.get("amount", 0)), max(1000, _stat(context, source, StatIdsScript.CRIT_DAMAGE_PERMILLE, 1500)))
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, fallback: int) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": EffectHookIdsScript.DAMAGE_OUTGOING, "target": context.get("target", {})})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
func _roll(context: Dictionary, suffix: String) -> int:
	return posmod((String(context.get("event_seed", "")) + ":" + suffix).hash(), 1000) + 1
func _permille(value: int, ratio: int) -> int: return int((value * ratio + 500) / 1000)
