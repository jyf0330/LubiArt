extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
func plugin_id() -> String: return "boss_damage"
func event_id() -> String: return EffectHookIdsScript.DAMAGE_OUTGOING
func order() -> int: return 110
func consumed_stats() -> Array[String]: return [StatIdsScript.BOSS_DAMAGE_PERMILLE]
func apply(context: Dictionary) -> Dictionary:
	if bool(context.get("target_is_boss", false)):
		context["amount"] = _permille(int(context.get("amount", 0)), _stat(context, Dictionary(context.get("source", {})), StatIdsScript.BOSS_DAMAGE_PERMILLE, 1000))
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, fallback: int) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": EffectHookIdsScript.DAMAGE_OUTGOING, "target": context.get("target", {})})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
func _permille(value: int, ratio: int) -> int: return int((value * ratio + 500) / 1000)
