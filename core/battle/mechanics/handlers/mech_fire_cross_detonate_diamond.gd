extends RefCounted

const QualityRulesScript := preload("res://core/party/quality_rules.gd")


func plugin_id() -> String:
	return "mech_fire_cross_detonate_diamond"


func project_element_settlement(
	unit: Dictionary,
	_mechanism: Dictionary,
	facts: Dictionary
) -> Dictionary:
	if (
		String(facts.get("element", "")) != "火"
		or String(unit.get("element", "")) != "火"
		or QualityRulesScript.normalize(String(unit.get("quality", ""))) != "钻石"
	):
		return {}
	return {
		"exclusive_key": "",
		"damage_add": 0,
		"source": unit.duplicate(true),
		"target_pattern": "cross",
	}
