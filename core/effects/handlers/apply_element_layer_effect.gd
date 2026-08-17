extends RefCounted
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
func plugin_id() -> String: return "apply_element_layer"
func consumed_stats(_effect: Dictionary, _source_kind: String) -> Array[String]: return [StatIdsScript.ELEMENT_LAYER_BONUS]
func execute(port: RefCounted, context: Dictionary, effect: Dictionary) -> Variant:
	var definition := effect.duplicate(true)
	if not definition.has(EffectVocabularyScript.FIELD_TARGET):
		definition[EffectVocabularyScript.FIELD_TARGET] = EffectVocabularyScript.DEFAULT_ACTION_TARGET
	return port.call(&"apply_element_layers", context, definition)
