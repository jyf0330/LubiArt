extends RefCounted

const AutoPositionPolicyScript := preload("res://core/battle/auto_position/auto_position_policy.gd")
const AutoPositionTurnOptimizerScript := preload("res://core/battle/auto_position/auto_position_turn_optimizer.gd")

## Functional planner: reads candidates through a narrow port and returns one plan.
## Applying moves, directions, AP, traces, and authoritative state stays outside.

var _policy := AutoPositionPolicyScript.new()
var _turn_optimizer := AutoPositionTurnOptimizerScript.new()


func build_plan(input: Dictionary, read_port: RefCounted) -> Dictionary:
	var side := String(input.get("side", "player"))
	var player_side := String(input.get("playerSide", "player"))
	var difficulty := String(input.get("difficulty", "normal"))
	var easy_difficulty := String(input.get("easyDifficulty", "easy"))
	var action_budget := int(input.get("actionBudget", 0))
	var constrain_movement_by_unit := bool(input.get("constrainMovementByUnit", false))
	var candidate_limit := int(input.get("candidateLimit", 1))
	var beam_width := int(input.get("beamWidth", 1))
	var survival_finalist_limit := int(input.get("survivalFinalistLimit", 1))
	var action_count_diversity := int(input.get("actionCountDiversity", 1))
	var mode := _policy.mode(side, player_side, difficulty, easy_difficulty, constrain_movement_by_unit)
	var allow_direction_changes := bool(mode.get("allowDirectionChanges", false))
	var position_independent := bool(mode.get("positionIndependent", false))
	var optimization_context: Dictionary = Dictionary(read_port.optimization_context())
	var candidate_started_usec := Time.get_ticks_usec()

	var candidate_sets: Array = []
	for unit_value in read_port.sorted_units(side):
		var unit := Dictionary(unit_value)
		var movement_budget: int = read_port.effective_move_range(unit) if constrain_movement_by_unit else -1
		var candidates: Array = read_port.candidates_for_unit(unit, candidate_limit, movement_budget, allow_direction_changes, position_independent)
		if not candidates.is_empty():
			candidate_sets.append(candidates)
	var candidate_duration_usec := Time.get_ticks_usec() - candidate_started_usec

	var beam_started_usec := Time.get_ticks_usec()
	var beams: Array = [{"choices": [], "evaluation": _turn_optimizer.optimize([], action_budget, optimization_context)}]
	var evaluated_plans := 0
	for candidates_value in candidate_sets:
		var next_beams: Array = []
		for beam_value in beams:
			var beam := Dictionary(beam_value)
			var choices := Array(beam.get("choices", []))
			for candidate_value in Array(candidates_value):
				var candidate := Dictionary(candidate_value)
				if read_port.choices_conflict(choices, candidate):
					continue
				var next_choices := choices.duplicate(true)
				next_choices.append(candidate)
				evaluated_plans += 1
				next_beams.append({
					"choices": next_choices,
					"evaluation": _turn_optimizer.optimize(next_choices, action_budget, optimization_context)
				})
		beams = _policy.prune_beams(next_beams, beam_width, action_count_diversity)
	if side == player_side:
		# Retaliation simulation is the expensive exact phase. The preceding beam
		# ordering is deterministic, so evaluate the configured finalist budget
		# directly instead of doubling it and immediately pruning half afterward.
		var retaliation_candidate_limit: int = min(beam_width, survival_finalist_limit)
		beams = _policy.prune_beams(beams, retaliation_candidate_limit, action_count_diversity)
	var beam_duration_usec := Time.get_ticks_usec() - beam_started_usec
	var retaliation_started_usec := Time.get_ticks_usec()
	var retaliation_finalists_evaluated := beams.size() if side == player_side else 0
	beams = read_port.decorate_finalists(beams, side)
	if side == player_side:
		beams = _policy.prune_beams(beams, survival_finalist_limit, action_count_diversity)
	var retaliation_duration_usec := Time.get_ticks_usec() - retaliation_started_usec
	beams.sort_custom(func(a, b): return _policy.beam_is_better(Dictionary(a), Dictionary(b)))

	var best_beam: Dictionary = Dictionary(beams[0]) if not beams.is_empty() else {
		"choices": [],
		"evaluation": _turn_optimizer.optimize([], action_budget, optimization_context)
	}
	var evaluation := Dictionary(best_beam.get("evaluation", {}))
	var moves: Array = []
	var directions: Array = []
	var actions: Array = []
	for best_value in Array(best_beam.get("choices", [])):
		var best := Dictionary(best_value)
		if bool(best.get("skip", false)):
			continue
		var from := Dictionary(best.get("from", {}))
		var to := Dictionary(best.get("to", {}))
		if int(from.get("x", -1)) != int(to.get("x", -1)) or int(from.get("y", -1)) != int(to.get("y", -1)):
			var move_reason := "智能站位优先扩大击杀数"
			if Array(best.get("targets", [])).is_empty():
				move_reason = "智能站位接近可攻击位置"
			moves.append({
				"unitId": String(best.get("unitId", "")),
				"from": from,
				"to": to,
				"reason": move_reason
			})
	for action_value in _turn_optimizer.selected_actions(Array(best_beam.get("choices", [])), evaluation):
		var planned_action := Dictionary(action_value)
		var action_row := {
			"unitId": String(planned_action.get("unitId", "")),
			"slotIndex": int(planned_action.get("slotIndex", 0)),
			"dir": String(planned_action.get("dir", "right")),
			"ap": max(1, int(planned_action.get("ap", 1))),
			"at": Dictionary(planned_action.get("to", {})).duplicate(true),
			"targets": Array(planned_action.get("targets", [])).duplicate(true),
			"cells": Array(planned_action.get("cells", [])).duplicate(true),
			"damageByTarget": Dictionary(planned_action.get("damageByTarget", {})).duplicate(true)
		}
		directions.append(action_row.duplicate(true))
		actions.append(action_row)

	return {
		"objective": "max_kills_then_effective_damage",
		"decisionModel": "placement_ap_lookahead_v2",
		"difficulty": difficulty,
		"directionPolicy": String(mode.get("directionPolicy", "preserve")),
		"resultCount": 1,
		"resultSignature": String(evaluation.get("signature", "")),
		"moves": moves,
		"directions": directions,
		"actions": actions,
		"effectiveDamage": int(evaluation.get("effectiveDamage", 0)),
		"overflow": int(evaluation.get("overflow", 0)),
		"kills": int(evaluation.get("kills", 0)),
		"bossDamage": int(evaluation.get("bossDamage", 0)),
		"playerDeaths": int(evaluation.get("playerDeaths", 0)),
		"playerHpDamage": int(evaluation.get("playerHpDamage", 0)),
		"playerShieldDamage": int(evaluation.get("playerShieldDamage", 0)),
		"incomingDamage": int(evaluation.get("incomingDamage", 0)),
		"approachGain": int(evaluation.get("approachGain", 0)),
		"sandbox": {
			"candidateLimit": candidate_limit,
			"targetSignatureLimit": int(input.get("targetSignatureLimit", 0)),
			"approachCandidateLimit": int(input.get("approachCandidateLimit", 0)),
			"standbyCandidateLimit": int(input.get("standbyCandidateLimit", 0)),
			"beamWidth": beam_width,
			"survivalFinalistLimit": survival_finalist_limit,
			"actionCountDiversity": action_count_diversity,
			"evaluatedPlans": evaluated_plans,
			"candidateDurationMs": snappedf(float(candidate_duration_usec) / 1000.0, 0.01),
			"beamDurationMs": snappedf(float(beam_duration_usec) / 1000.0, 0.01),
			"retaliationDurationMs": snappedf(float(retaliation_duration_usec) / 1000.0, 0.01),
			"actionSubsetsEvaluated": int(evaluation.get("actionSubsetsEvaluated", 0)),
			"retaliationFinalistsEvaluated": retaliation_finalists_evaluated,
			"candidateCounts": candidate_sets.map(func(items): return Array(items).size()),
			"priority": ["kills", "playerDeaths", "playerHpDamage", "bossKills", "priorityEffective", "effectiveDamage", "playerShieldDamage", "overflow", "apSpent", "approachGain", "moveCost", "canonicalSignature"]
		},
		"summary": "智能站位唯一方案：移动%d只，预计击杀%d只、我方掉血%d；同击杀与掉血下有效伤害%d。" % [moves.size(), int(evaluation.get("kills", 0)), int(evaluation.get("playerHpDamage", 0)), int(evaluation.get("effectiveDamage", 0))]
	}
