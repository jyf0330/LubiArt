extends RefCounted

## Stateless ordering and difficulty policy for deterministic auto-position plans.


func mode(side: String, player_side: String, difficulty: String, easy_difficulty: String, constrain_movement_by_unit: bool) -> Dictionary:
	return {
		"allowDirectionChanges": side != player_side or difficulty == easy_difficulty,
		"positionIndependent": side == player_side and not constrain_movement_by_unit,
		"directionPolicy": "optimize" if side != player_side or difficulty == easy_difficulty else "preserve"
	}


func candidate_is_better(left: Dictionary, right: Dictionary) -> bool:
	var left_kills := int(left.get("kills", 0))
	var right_kills := int(right.get("kills", 0))
	if left_kills != right_kills:
		return left_kills > right_kills
	var left_boss_killed := bool(left.get("bossKilled", false))
	var right_boss_killed := bool(right.get("bossKilled", false))
	if left_boss_killed != right_boss_killed:
		return left_boss_killed
	var left_priority_effective := int(left.get("priorityEffective", left.get("effective", 0)))
	var right_priority_effective := int(right.get("priorityEffective", right.get("effective", 0)))
	if left_priority_effective != right_priority_effective:
		return left_priority_effective > right_priority_effective
	var left_effective := int(left.get("effective", 0))
	var right_effective := int(right.get("effective", 0))
	if left_effective != right_effective:
		return left_effective > right_effective
	var left_overflow := int(left.get("overflow", 0))
	var right_overflow := int(right.get("overflow", 0))
	if left_overflow != right_overflow:
		return left_overflow < right_overflow
	var left_ap := int(left.get("ap", 0))
	var right_ap := int(right.get("ap", 0))
	if left_ap != right_ap:
		return left_ap < right_ap
	var left_approach := int(left.get("approachDistance", 1_000_000))
	var right_approach := int(right.get("approachDistance", 1_000_000))
	if left_approach != right_approach:
		return left_approach < right_approach
	var left_move_cost := int(left.get("moveCost", 0))
	var right_move_cost := int(right.get("moveCost", 0))
	if left_move_cost != right_move_cost:
		return left_move_cost < right_move_cost
	var left_direction_order := int(left.get("canonicalDirectionOrder", 0))
	var right_direction_order := int(right.get("canonicalDirectionOrder", 0))
	if left_direction_order != right_direction_order:
		return left_direction_order < right_direction_order
	var left_to := Dictionary(left.get("to", {}))
	var right_to := Dictionary(right.get("to", {}))
	if int(left_to.get("y", -1)) != int(right_to.get("y", -1)):
		return int(left_to.get("y", -1)) < int(right_to.get("y", -1))
	if int(left_to.get("x", -1)) != int(right_to.get("x", -1)):
		return int(left_to.get("x", -1)) < int(right_to.get("x", -1))
	if int(left.get("slotIndex", 0)) != int(right.get("slotIndex", 0)):
		return int(left.get("slotIndex", 0)) < int(right.get("slotIndex", 0))
	return String(left.get("dir", "")) < String(right.get("dir", ""))


func target_signature(candidate: Dictionary) -> String:
	var ids := PackedStringArray()
	for target_id in Array(candidate.get("targets", [])):
		ids.append(String(target_id))
	ids.sort()
	return ",".join(ids)


func choices_signature(choices: Array) -> String:
	var rows := PackedStringArray()
	for choice_value in choices:
		var choice := Dictionary(choice_value)
		var to := Dictionary(choice.get("to", {}))
		rows.append("%s#%02d@%02d,%02d#%02d:%s:%s:%s" % [
			String(choice.get("unitId", "")),
			int(choice.get("canonicalDirectionOrder", 0)),
			int(to.get("y", -1)),
			int(to.get("x", -1)),
			int(choice.get("slotIndex", -1)),
			String(choice.get("dir", "")),
			target_signature(choice),
			"skip" if bool(choice.get("skip", false)) else "act"
		])
	rows.sort()
	return "|".join(rows)


func choices_placement_signature(choices: Array) -> String:
	var rows := PackedStringArray()
	for choice_value in choices:
		var choice := Dictionary(choice_value)
		var to := Dictionary(choice.get("to", {}))
		rows.append("%s@%02d,%02d:%s" % [
			String(choice.get("unitId", "")),
			int(to.get("y", -1)),
			int(to.get("x", -1)),
			"skip" if bool(choice.get("skip", false)) else "act"
		])
	rows.sort()
	return "|".join(rows)


func enemy_response_is_better(left: Dictionary, right: Dictionary) -> bool:
	for key in ["kills", "effective"]:
		if int(left.get(key, 0)) != int(right.get(key, 0)):
			return int(left.get(key, 0)) > int(right.get(key, 0))
	for key in ["overflow", "moveCost", "y", "x", "directionOrder"]:
		if int(left.get(key, 0)) != int(right.get(key, 0)):
			return int(left.get(key, 0)) < int(right.get(key, 0))
	return false


func evaluation_is_better(left: Dictionary, right: Dictionary) -> bool:
	var left_kills := int(left.get("kills", 0))
	var right_kills := int(right.get("kills", 0))
	if left_kills != right_kills:
		return left_kills > right_kills
	var left_player_deaths := int(left.get("playerDeaths", 0))
	var right_player_deaths := int(right.get("playerDeaths", 0))
	if left_player_deaths != right_player_deaths:
		return left_player_deaths < right_player_deaths
	var left_player_hp_damage := int(left.get("playerHpDamage", 0))
	var right_player_hp_damage := int(right.get("playerHpDamage", 0))
	if left_player_hp_damage != right_player_hp_damage:
		return left_player_hp_damage < right_player_hp_damage
	var left_boss_kills := int(left.get("bossKills", 0))
	var right_boss_kills := int(right.get("bossKills", 0))
	if left_boss_kills != right_boss_kills:
		return left_boss_kills > right_boss_kills
	var left_priority_effective := int(left.get("priorityEffective", left.get("effectiveDamage", 0)))
	var right_priority_effective := int(right.get("priorityEffective", right.get("effectiveDamage", 0)))
	if left_priority_effective != right_priority_effective:
		return left_priority_effective > right_priority_effective
	var left_effective := int(left.get("effectiveDamage", 0))
	var right_effective := int(right.get("effectiveDamage", 0))
	if left_effective != right_effective:
		return left_effective > right_effective
	var left_player_shield_damage := int(left.get("playerShieldDamage", 0))
	var right_player_shield_damage := int(right.get("playerShieldDamage", 0))
	if left_player_shield_damage != right_player_shield_damage:
		return left_player_shield_damage < right_player_shield_damage
	var left_overflow := int(left.get("overflow", 0))
	var right_overflow := int(right.get("overflow", 0))
	if left_overflow != right_overflow:
		return left_overflow < right_overflow
	var left_ap_spent := int(left.get("apSpent", 0))
	var right_ap_spent := int(right.get("apSpent", 0))
	if left_ap_spent != right_ap_spent:
		return left_ap_spent < right_ap_spent
	var left_approach_gain := int(left.get("approachGain", 0))
	var right_approach_gain := int(right.get("approachGain", 0))
	if left_approach_gain != right_approach_gain:
		return left_approach_gain > right_approach_gain
	var left_move_cost := int(left.get("moveCost", 0))
	var right_move_cost := int(right.get("moveCost", 0))
	if left_move_cost != right_move_cost:
		return left_move_cost < right_move_cost
	return String(left.get("signature", "")) < String(right.get("signature", ""))


func beam_is_better(left: Dictionary, right: Dictionary) -> bool:
	return evaluation_is_better(
		Dictionary(left.get("evaluation", {})),
		Dictionary(right.get("evaluation", {}))
	)


func prune_beams(next_beams: Array, beam_width: int, action_count_diversity: int) -> Array:
	next_beams.sort_custom(func(a, b): return beam_is_better(Dictionary(a), Dictionary(b)))
	var selected: Array = []
	var selected_signatures := {}
	var diversity_counts := {}
	var diversity_placements := {}
	for beam_value in next_beams:
		var beam := Dictionary(beam_value)
		var evaluation := Dictionary(beam.get("evaluation", {}))
		var actions_used := int(evaluation.get("actionsUsed", 0))
		if int(diversity_counts.get(actions_used, 0)) >= action_count_diversity:
			continue
		var placement_signature := choices_placement_signature(Array(beam.get("choices", [])))
		var placement_key := "%d:%s" % [actions_used, placement_signature]
		if diversity_placements.has(placement_key):
			continue
		diversity_placements[placement_key] = true
		diversity_counts[actions_used] = int(diversity_counts.get(actions_used, 0)) + 1
		var signature := String(evaluation.get("signature", ""))
		if selected_signatures.has(signature):
			continue
		selected_signatures[signature] = true
		selected.append(beam)
		if selected.size() >= beam_width:
			return selected
	for beam_value in next_beams:
		if selected.size() >= beam_width:
			break
		var beam := Dictionary(beam_value)
		var evaluation := Dictionary(beam.get("evaluation", {}))
		var signature := String(evaluation.get("signature", ""))
		if selected_signatures.has(signature):
			continue
		selected_signatures[signature] = true
		selected.append(beam)
	return selected
