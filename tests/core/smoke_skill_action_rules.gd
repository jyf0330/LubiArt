extends SceneTree

const SkillActionRulesScript := preload("res://core/battle/skills/skill_action_rules.gd")

var failed := false


func _initialize() -> void:
	_expect(SkillActionRulesScript.action_slot_index({"action_slot_index": 2, "shape_slot": 1}) == 2, "canonical action slot wins over legacy shape slot")
	_expect(SkillActionRulesScript.action_slot_index({"shape_slot": 1}) == 1, "legacy shape slot remains readable")
	_expect(SkillActionRulesScript.action_slot_index({}) == 0, "missing action slot defaults to zero")

	var shape_with_legacy_cadence := {"settle_count": 3}
	_expect(SkillActionRulesScript.physical_strike_count({}, {}) == 1, "skill damage defaults to one strike")
	_expect(SkillActionRulesScript.physical_strike_count(shape_with_legacy_cadence, {}) == 1, "legacy shape cadence cannot change skill strike count")
	_expect(SkillActionRulesScript.physical_strike_count({"strike_count": 2}, {}) == 2, "skill definition may own strike count")
	_expect(SkillActionRulesScript.physical_strike_count({"strike_count": 2}, {"strike_count": 4}) == 4, "effect strike count overrides the skill default")
	_expect(SkillActionRulesScript.legacy_action_strike_count({"action_strike_count": 2}, {"settle_count": 3}) == 2, "canonical action cadence wins over legacy shape data")
	_expect(SkillActionRulesScript.legacy_action_strike_count({}, {"settle_count": 3}) == 3, "legacy shape cadence is isolated behind one compatibility accessor")

	_expect(SkillActionRulesScript.element_application_count({"layers": 3}) == 1, "element layers do not imply repeated applications")
	_expect(SkillActionRulesScript.element_application_count({"layers": 2, "application_count": 3}) == 3, "element application count is explicit")

	if failed:
		quit(1)
		return
	print("SMOKE_SKILL_ACTION_RULES_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_SKILL_ACTION_RULES_FAIL: %s" % message)
