extends RefCounted

const LEGACY_DESCRIPTORS := {
	"party_attack": {
		"stat": "atk",
		"base_stat": "base_atk",
		"modifier_stat": "atk",
		"label": "攻击",
	},
	"party_defense": {
		"stat": "def",
		"base_stat": "base_def",
		"modifier_stat": "def",
		"label": "防御",
	},
	"party_vitality": {
		"stat": "max_hp",
		"base_stat": "base_max_hp",
		"modifier_stat": "max_hp",
		"label": "生命上限",
	},
	"party_shield": {
		"stat": "shield",
		"base_stat": "base_shield",
		"modifier_stat": "starting_shield",
		"label": "护盾",
	},
}


func normalize(effect: Dictionary) -> Dictionary:
	var normalized := effect.duplicate(true)
	var legacy_type := String(effect.get("type", ""))
	var descriptor := Dictionary(LEGACY_DESCRIPTORS.get(legacy_type, {}))
	if descriptor.is_empty():
		return normalized
	for key in descriptor:
		normalized[key] = descriptor[key]
	normalized["type"] = "party_stat"
	normalized["value"] = max(1, int(effect.get("value", 1)))
	normalized["legacy_source_id"] = legacy_type
	return normalized


func legacy_effect_types() -> Array[String]:
	var result: Array[String] = []
	for effect_type in LEGACY_DESCRIPTORS.keys():
		result.append(String(effect_type))
	result.sort()
	return result
