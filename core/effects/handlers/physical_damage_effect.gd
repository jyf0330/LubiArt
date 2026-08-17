extends RefCounted
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
func plugin_id() -> String: return "physical_damage"
func consumed_stats(_effect: Dictionary, source_kind: String) -> Array[String]:
	return [
		StatIdsScript.ATK,
		StatIdsScript.PHYSICAL_POWER_PERMILLE,
		StatIdsScript.COMBO_POWER_PERMILLE if source_kind == EffectHookIdsScript.COMBO else StatIdsScript.SKILL_POWER_PERMILLE,
		StatIdsScript.ELEMENT_POWER_PERMILLE,
		StatIdsScript.BOSS_DAMAGE_PERMILLE,
		StatIdsScript.CRIT_RATE_PERMILLE,
		StatIdsScript.CRIT_DAMAGE_PERMILLE,
		StatIdsScript.LIFESTEAL_PERMILLE,
	]
func execute(port: RefCounted, context: Dictionary, effect: Dictionary) -> Variant:
	var definition := effect.duplicate(true)
	if not definition.has(EffectVocabularyScript.FIELD_TARGET):
		definition[EffectVocabularyScript.FIELD_TARGET] = EffectVocabularyScript.DEFAULT_ACTION_TARGET
	return port.call(&"apply_physical_damage", context, definition)
