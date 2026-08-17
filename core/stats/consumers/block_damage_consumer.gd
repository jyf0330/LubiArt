extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
func plugin_id() -> String: return "block_damage"
func event_id() -> String: return EffectHookIdsScript.DAMAGE_INCOMING
func order() -> int: return 110
func consumed_stats() -> Array[String]: return [StatIdsScript.BLOCK_RATE_PERMILLE, StatIdsScript.BLOCK_VALUE]
func apply(context: Dictionary) -> Dictionary:
	if int(context.get("amount", 0)) <= 0: return context
	var damage_props := Dictionary(context.get("damage_props", {}))
	if not DamagePropsScript.is_move(damage_props) or not DamagePropsScript.is_blockable(damage_props): return context
	var target := Dictionary(context.get("target", {}))
	var rate := clampi(_stat(context, target, StatIdsScript.BLOCK_RATE_PERMILLE, 0), 0, 1000)
	var roll := _roll(context, "block")
	context["block_roll"] = roll
	context["blocked"] = rate > 0 and roll <= rate
	if bool(context["blocked"]):
		var value: int = max(0, _stat(context, target, StatIdsScript.BLOCK_VALUE, 0))
		context["block_value_applied"] = min(value, int(context.get("amount", 0)))
		context["amount"] = max(0, int(context.get("amount", 0)) - value)
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, fallback: int) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": EffectHookIdsScript.DAMAGE_INCOMING, "source": context.get("source", {})})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
func _roll(context: Dictionary, suffix: String) -> int: return posmod((String(context.get("event_seed", "")) + ":" + suffix).hash(), 1000) + 1
