extends RefCounted

const AutoPositionConfigScript := preload("res://core/battle/auto_position/auto_position_config.gd")


static func build(
	state: RefCounted,
	side: String = "player",
	action_budget: int = -1,
	constrain_movement_by_unit: bool = false
) -> Dictionary:
	var input := AutoPositionConfigScript.defaults()
	var resolved_action_budget := int(state.get("ap")) if action_budget < 0 else action_budget
	return {
		"schema": "ysbzs.auto-position-context.v1",
		"query": Dictionary(state.call("_battle_query_context")),
		"side": side,
		"playerSide": "player",
		"difficulty": String(state.get("difficulty")),
		"easyDifficulty": "easy",
		"actionBudget": resolved_action_budget,
		"constrainMovementByUnit": constrain_movement_by_unit,
		"limits": {
			"candidate": int(input.get("candidateLimit", AutoPositionConfigScript.CANDIDATE_LIMIT)),
			"targetSignature": int(input.get("targetSignatureLimit", AutoPositionConfigScript.TARGET_SIGNATURE_LIMIT)),
			"approach": int(input.get("approachCandidateLimit", AutoPositionConfigScript.APPROACH_CANDIDATE_LIMIT)),
			"standby": int(input.get("standbyCandidateLimit", AutoPositionConfigScript.STANDBY_CANDIDATE_LIMIT)),
			"beam": int(input.get("beamWidth", AutoPositionConfigScript.BEAM_WIDTH)),
			"survivalFinalist": int(input.get("survivalFinalistLimit", AutoPositionConfigScript.SURVIVAL_FINALIST_LIMIT)),
			"actionCountDiversity": int(input.get("actionCountDiversity", AutoPositionConfigScript.ACTION_COUNT_DIVERSITY)),
		},
	}


static func evaluator(state: RefCounted) -> RefCounted:
	var composition: RefCounted = state.get("_core_composition") as RefCounted
	if composition == null:
		return null
	return composition.get("auto_position_evaluator") as RefCounted


static func candidates(
	state: RefCounted,
	unit: Dictionary,
	options: Dictionary = {}
) -> Array:
	var service: RefCounted = evaluator(state)
	return [] if service == null else Array(service.call("candidates_for_unit", build(state, String(unit.get("side", "player"))), unit, options)).duplicate(true)


static func retaliation(
	state: RefCounted,
	choices: Array,
	projected_damage: Dictionary = {}
) -> Dictionary:
	var service: RefCounted = evaluator(state)
	if service == null:
		return {}
	var beams_value: Variant = service.call("decorate_finalists", build(state), [{
		"choices": choices.duplicate(true),
		"evaluation": {"projectedDamage": projected_damage.duplicate(true)},
	}], "player")
	if not beams_value is Array or Array(beams_value).is_empty():
		return {}
	return Dictionary(Dictionary(Array(beams_value)[0]).get("evaluation", {})).duplicate(true)
