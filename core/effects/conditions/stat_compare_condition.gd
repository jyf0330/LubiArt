extends RefCounted
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
func plugin_id() -> String: return "stat_compare"
func content_schema_errors(condition: Dictionary) -> Array[String]:
	return ["CONDITION_STAT_REQUIRED"] if EffectVocabularyScript.stat_id(condition) == "" else []
func matches(condition: Dictionary, context: Dictionary) -> bool:
	var stat_id := EffectVocabularyScript.stat_id(condition)
	var values := Dictionary(context.get("resolved_stats", context.get("stat_defaults", {})))
	var actual := 0
	if values.has(stat_id):
		actual = int(values.get(stat_id, 0))
	else:
		var query: Variant = context.get("stat_value")
		var unit := Dictionary(context.get("unit", {}))
		actual = int((query as Callable).call(unit, stat_id, context)) if query is Callable and (query as Callable).is_valid() else int(unit.get(stat_id, 0))
	var expected := int(condition.get("value", 0))
	match String(condition.get("operator", "==")):
		">": return actual > expected
		">=": return actual >= expected
		"<": return actual < expected
		"<=": return actual <= expected
		"!=": return actual != expected
	return actual == expected
