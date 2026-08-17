extends RefCounted

const AutoPositionPolicyScript := preload("res://core/battle/auto_position/auto_position_policy.gd")

## Exact AP-budget optimizer for one placement beam. Candidate damage is already
## projected by the domain rules; this service selects the best action subset
## without reading or mutating authoritative state.

var _policy := AutoPositionPolicyScript.new()


func optimize(choices: Array, action_budget: int, context: Dictionary) -> Dictionary:
	var budget: int = max(0, action_budget)
	var subsets: Array = [{"indices": [], "apSpent": 0}]
	for choice_index in range(choices.size()):
		var choice := Dictionary(choices[choice_index])
		if bool(choice.get("skip", false)) or Array(choice.get("targets", [])).is_empty():
			continue
		var action_ap: int = max(1, int(choice.get("ap", 1)))
		if action_ap > budget:
			continue
		var additions: Array = []
		for subset_value in subsets:
			var subset := Dictionary(subset_value)
			var spent := int(subset.get("apSpent", 0)) + action_ap
			if spent > budget:
				continue
			var indices := Array(subset.get("indices", [])).duplicate()
			indices.append(choice_index)
			additions.append({"indices": indices, "apSpent": spent})
		subsets.append_array(additions)

	var placement := _placement_metrics(choices)
	var best: Dictionary = {}
	for subset_value in subsets:
		var indices := Array(Dictionary(subset_value).get("indices", []))
		var evaluation := _evaluate_selection(choices, indices, context, placement)
		if best.is_empty() or _policy.evaluation_is_better(evaluation, best):
			best = evaluation
	best["actionSubsetsEvaluated"] = subsets.size()
	return best


func selected_actions(choices: Array, evaluation: Dictionary) -> Array:
	var selected: Array = []
	for index_value in Array(evaluation.get("selectedChoiceIndices", [])):
		var index := int(index_value)
		if index >= 0 and index < choices.size():
			selected.append(Dictionary(choices[index]).duplicate(true))
	return selected


func _placement_metrics(choices: Array) -> Dictionary:
	var move_cost := 0
	var approach_gain := 0
	for choice_value in choices:
		var choice := Dictionary(choice_value)
		move_cost += int(choice.get("moveCost", 0))
		approach_gain += int(choice.get("approachGain", 0))
	return {
		"moveCost": move_cost,
		"approachGain": approach_gain,
		"signature": _policy.choices_signature(choices)
	}


func _evaluate_selection(choices: Array, selected_indices: Array, context: Dictionary, placement: Dictionary) -> Dictionary:
	var target_states := Dictionary(context.get("targetStates", {}))
	var projected_damage := {}
	var effective := 0
	var overflow := 0
	var kills := 0
	var boss_damage := 0
	var boss_kills := 0
	var ap_spent := 0
	var action_signature_rows := PackedStringArray()
	for index_value in selected_indices:
		var choice_index := int(index_value)
		if choice_index < 0 or choice_index >= choices.size():
			continue
		var choice := Dictionary(choices[choice_index])
		ap_spent += max(1, int(choice.get("ap", 1)))
		var damage_by_target := Dictionary(choice.get("damageByTarget", {}))
		for target_id_value in Array(choice.get("targets", [])):
			var target_id := String(target_id_value)
			if not target_states.has(target_id):
				continue
			var target := Dictionary(target_states[target_id])
			var final_damage: int = max(0, int(damage_by_target.get(target_id, choice.get("rawDamage", 0))))
			var allocation := _damage_allocation(target, final_damage, int(projected_damage.get(target_id, 0)))
			projected_damage[target_id] = int(projected_damage.get(target_id, 0)) + final_damage
			effective += int(allocation.get("effective", 0))
			overflow += int(allocation.get("overflow", 0))
			if bool(allocation.get("killed", false)):
				kills += 1
				if bool(target.get("isBoss", false)):
					boss_kills += 1
			if bool(target.get("isBoss", false)):
				boss_damage += int(allocation.get("effective", 0))
		action_signature_rows.append("%s#%d:%s" % [
			String(choice.get("unitId", "")),
			int(choice.get("slotIndex", 0)),
			String(choice.get("dir", ""))
		])
	action_signature_rows.sort()
	var nonlethal_boss_deprioritized := bool(context.get("hasLivingNonBossEnemy", false)) and boss_damage > 0 and boss_kills == 0
	return {
		"effectiveDamage": effective,
		"priorityEffective": max(0, effective - (boss_damage if nonlethal_boss_deprioritized else 0)),
		"overflow": overflow,
		"kills": kills,
		"bossDamage": boss_damage,
		"bossKills": boss_kills,
		"playerDeaths": 0,
		"playerHpDamage": 0,
		"playerShieldDamage": 0,
		"incomingDamage": 0,
		"actionsUsed": selected_indices.size(),
		"apSpent": ap_spent,
		"selectedChoiceIndices": selected_indices.duplicate(),
		"moveCost": int(placement.get("moveCost", 0)),
		"approachGain": int(placement.get("approachGain", 0)),
		"projectedDamage": projected_damage,
		"signature": "%s::actions=%s" % [String(placement.get("signature", "")), ",".join(action_signature_rows)]
	}


func _damage_allocation(target: Dictionary, final_damage: int, already_damage: int) -> Dictionary:
	var shield: int = max(0, int(target.get("shield", 0)))
	var hp: int = max(0, int(target.get("hp", 0)))
	var applied_before: int = max(0, already_damage)
	var remaining_shield: int = max(0, shield - applied_before)
	var remaining_hp: int = max(0, hp - max(0, applied_before - shield))
	var damage: int = max(0, final_damage)
	var shield_damage: int = min(remaining_shield, damage)
	var hp_damage: int = min(remaining_hp, max(0, damage - shield_damage))
	var effective: int = shield_damage + hp_damage
	return {
		"effective": effective,
		"overflow": max(0, damage - effective),
		"killed": remaining_hp > 0 and hp_damage >= remaining_hp
	}
