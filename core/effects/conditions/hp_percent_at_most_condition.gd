extends RefCounted
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
func plugin_id() -> String: return "hp_percent_at_most"
func matches(condition: Dictionary, context: Dictionary) -> bool:
	var unit := Dictionary(context.get("unit", {}))
	var values := Dictionary(context.get("resolved_stats", {}))
	var query: Variant = context.get("stat_value")
	var maximum := int(values.get(StatIdsScript.MAX_HP, 0))
	if maximum <= 0 and query is Callable and (query as Callable).is_valid(): maximum = int((query as Callable).call(unit, StatIdsScript.MAX_HP, context))
	maximum = max(1, maximum if maximum > 0 else int(unit.get(StatIdsScript.MAX_HP, unit.get("hp", 1))))
	return int(max(0, int(unit.get("hp", 0))) * 1000 / maximum) <= int(condition.get("value", 0))
