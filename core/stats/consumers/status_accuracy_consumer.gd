extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
func plugin_id() -> String: return "status_accuracy"
func event_id() -> String: return "status_apply"
func order() -> int: return 100
func consumed_stats() -> Array[String]: return [StatIdsScript.STATUS_HIT_PERMILLE, StatIdsScript.STATUS_RESIST_PERMILLE, StatIdsScript.CONTROL_RESIST_PERMILLE, StatIdsScript.STATUS_DURATION_PERMILLE]
func apply(context: Dictionary) -> Dictionary:
	var source := Dictionary(context.get("source", {}))
	var target := Dictionary(context.get("target", {}))
	var hit: int = max(0, _stat(context, source, StatIdsScript.STATUS_HIT_PERMILLE, 1000, EffectHookIdsScript.STATUS_OUTGOING))
	var resist := clampi(_stat(context, target, StatIdsScript.STATUS_RESIST_PERMILLE, 0, EffectHookIdsScript.STATUS_INCOMING), 0, 1000)
	if bool(Dictionary(context.get("status_definition", {})).get("control", false)):
		resist = clampi(resist + _stat(context, target, StatIdsScript.CONTROL_RESIST_PERMILLE, 0, EffectHookIdsScript.STATUS_INCOMING), 0, 1000)
	var chance := clampi(int((hit * (1000 - resist) + 500) / 1000), 0, 1000)
	var roll := _roll(context, "status")
	context["status_chance"] = chance
	context["status_roll"] = roll
	context["accepted"] = chance > 0 and roll <= chance
	var duration_ratio: int = max(0, _stat(context, source, StatIdsScript.STATUS_DURATION_PERMILLE, 1000, EffectHookIdsScript.STATUS_OUTGOING))
	context["duration"] = max(1, int((max(1, int(context.get("duration", 1))) * duration_ratio + 500) / 1000))
	return context
func _stat(context: Dictionary, unit: Dictionary, stat_id: String, fallback: int, hook: String) -> int:
	var query: Variant = context.get("stat_value")
	return int((query as Callable).call(unit, stat_id, {"hook": hook, "source": context.get("source", {}), "target": context.get("target", {})})) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, fallback))
func _roll(context: Dictionary, suffix: String) -> int: return posmod((String(context.get("event_seed", "")) + ":" + suffix).hash(), 1000) + 1
