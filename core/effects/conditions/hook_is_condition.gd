extends RefCounted
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
func plugin_id() -> String: return "hook_is"
func matches(condition: Dictionary, context: Dictionary) -> bool:
	return EffectVocabularyScript.text(context, EffectVocabularyScript.FIELD_HOOK) == String(condition.get("value", ""))
