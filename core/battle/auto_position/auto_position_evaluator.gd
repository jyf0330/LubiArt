extends RefCounted

## Pure value evaluator for deterministic auto-position search. Configured
## collaborators are stateless per-authority services; every call receives a
## detached AutoPositionContextV1 and returns detached values.

const AutoPositionConfigScript := preload("res://core/battle/auto_position/auto_position_config.gd")
const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const QualityBoardTraceScript := preload("res://core/battle/quality/quality_board_trace.gd")
const SkillShapeRulesScript := preload("res://core/battle/skills/skill_shape_rules.gd")

const SCHEMA := "ysbzs.auto-position-context.v1"
const PLAYER := "player"
const ENEMY := "enemy"
const DIRECTIONS := ["right", "down", "left", "up"]

var _battle_query_projector: RefCounted
var _action_slot_service: RefCounted
var _attack_option_service: RefCounted
var _targeting_service: RefCounted
var _stat_query_service: RefCounted
var _quality_effect_registry: RefCounted
var _quality_hit_context_projector: RefCounted
var _threat_target_policy: RefCounted
var _mechanic_projection_service: RefCounted
var _auto_position_policy: RefCounted


func configure(
	battle_query_projector: RefCounted,
	action_slot_service: RefCounted,
	attack_option_service: RefCounted,
	targeting_service: RefCounted,
	stat_query_service: RefCounted,
	quality_effect_registry: RefCounted,
	quality_hit_context_projector: RefCounted,
	threat_target_policy: RefCounted,
	mechanic_projection_service: RefCounted,
	auto_position_policy: RefCounted
) -> RefCounted:
	_battle_query_projector = battle_query_projector
	_action_slot_service = action_slot_service
	_attack_option_service = attack_option_service
	_targeting_service = targeting_service
	_stat_query_service = stat_query_service
	_quality_effect_registry = quality_effect_registry
	_quality_hit_context_projector = quality_hit_context_projector
	_threat_target_policy = threat_target_policy
	_mechanic_projection_service = mechanic_projection_service
	_auto_position_policy = auto_position_policy
	return self


func sorted_units(context: Dictionary, side: String) -> Array:
	if not _valid(context):
		return []
	var query := _query(context)
	var entries: Array = []
	var query_units := Array(query.get("units", []))
	for index in range(query_units.size()):
		var unit := Dictionary(query_units[index])
		if String(unit.get("side", "")) != side or int(unit.get("hp", 0)) <= 0:
			continue
		var effect: RefCounted = _quality_effect_registry.call("effect_for_unit", unit) as RefCounted
		entries.append({
			"unit": unit.duplicate(true),
			"qualityOrder": int(effect.get("actor_order")) if effect != null else 0,
			"speed": _stat(query, unit, "speed", EffectHookIdsScript.ACTION_ORDER, {}, 100),
			"initiative": _stat(query, unit, "initiative", EffectHookIdsScript.ACTION_ORDER, {}, 0),
			"index": index,
		})
	entries.sort_custom(func(left_value, right_value):
		var left := Dictionary(left_value)
		var right := Dictionary(right_value)
		if int(left.get("speed", 100)) != int(right.get("speed", 100)):
			return int(left.get("speed", 100)) > int(right.get("speed", 100))
		if int(left.get("initiative", 0)) != int(right.get("initiative", 0)):
			return int(left.get("initiative", 0)) > int(right.get("initiative", 0))
		if int(left.get("qualityOrder", 0)) != int(right.get("qualityOrder", 0)):
			return int(left.get("qualityOrder", 0)) < int(right.get("qualityOrder", 0))
		return int(left.get("index", 0)) < int(right.get("index", 0))
	)
	var result: Array = []
	for entry_value in entries:
		result.append(Dictionary(Dictionary(entry_value).get("unit", {})).duplicate(true))
	return result


func effective_move_range(context: Dictionary, unit: Dictionary) -> int:
	if not _valid(context) or unit.is_empty():
		return 0
	return max(0, _stat(_query(context), unit, "move_range", EffectHookIdsScript.MOVEMENT, {}, int(unit.get("move_range", 0))))


func candidates_for_unit(context: Dictionary, unit: Dictionary, options: Dictionary = {}) -> Array:
	if not _valid(context) or unit.is_empty():
		return []
	var query := _query(context)
	var unit_side := String(unit.get("side", ""))
	if not [PLAYER, ENEMY].has(unit_side) or int(unit.get("hp", 0)) <= 0:
		return []
	if bool(unit.get("has_attacked", false)) or _has_used_action_slot(unit):
		return []
	var limit: int = max(1, int(options.get("limit", _limit(context, "candidate", AutoPositionConfigScript.CANDIDATE_LIMIT))))
	var movement_budget := int(options.get("movementBudget", -1))
	var allow_direction_changes := bool(options.get("allowDirectionChanges", true))
	var position_independent := bool(options.get("positionIndependent", false))
	var query_session: RefCounted = _battle_query_projector.call("begin", query) as RefCounted
	if query_session == null:
		return []
	var projected_unit := unit.duplicate(true)
	var start_x := int(projected_unit.get("x", -1))
	var start_y := int(projected_unit.get("y", -1))
	var candidates: Array = []
	var approach_by_destination := {}
	var start_approach_distance := _current_approach_distance(query, projected_unit)
	var target_side := _opponent_side(unit_side)
	var available_slots: Array = []
	for slot_value in _action_slots(query, projected_unit):
		var slot := Dictionary(slot_value)
		if bool(slot.get("used", false)):
			continue
		available_slots.append({
			"slot": slot,
			"directions": _directions_for_slot(query, projected_unit, int(slot.get("index", 0)), allow_direction_changes),
		})
	for cell_value in _cells_for_unit(query, projected_unit, movement_budget):
		var cell := Dictionary(cell_value)
		var candidate_x := int(cell.get("x", start_x))
		var candidate_y := int(cell.get("y", start_y))
		projected_unit["x"] = candidate_x
		projected_unit["y"] = candidate_y
		var base_move_cost: int = 0 if position_independent else abs(start_x - candidate_x) + abs(start_y - candidate_y)
		var move_cost := _effective_movement_cost(query, projected_unit, base_move_cost)
		var shape_options := _shape_attack_options(query, projected_unit)
		for slot_entry_value in available_slots:
			var slot_entry := Dictionary(slot_entry_value)
			var slot := Dictionary(slot_entry.get("slot", {}))
			for direction_value in Array(slot_entry.get("directions", [])):
				var direction := String(direction_value)
				var option := Dictionary(_attack_option_service.call(
					"option_for_direction", shape_options, direction
				)).duplicate(true)
				if option.is_empty():
					continue
				var targets := _targets_in_option(query, projected_unit, option)
				if targets.is_empty():
					var approach_distance := _approach_distance(query, option, target_side)
					var approach_candidate := {
						"unitId": String(projected_unit.get("id", "")),
						"from": {"x": start_x, "y": start_y},
						"to": {"x": candidate_x, "y": candidate_y},
						"slotIndex": int(slot.get("index", 0)),
						"dir": direction,
						"canonicalDirectionOrder": DIRECTIONS.find(direction) if position_independent else 0,
						"score": -float(approach_distance),
						"effective": 0, "overflow": 0, "kills": 0, "bossDamage": 0,
						"approachDistance": approach_distance,
						"approachGain": max(0, _board_width(query) + _board_height(query) - approach_distance) if position_independent else max(0, start_approach_distance - approach_distance),
						"moveCost": move_cost,
						"targets": [],
						"cells": Array(option.get("cells", [])).duplicate(true),
					}
					var approach_key := _cell_key(candidate_x, candidate_y)
					if not approach_by_destination.has(approach_key) or _candidate_is_better(approach_candidate, Dictionary(approach_by_destination[approach_key])):
						approach_by_destination[approach_key] = approach_candidate
					continue
				var metrics := _damage_metrics(query, projected_unit, slot, option, targets, {}, query_session)
				if int(metrics.get("effective", 0)) <= 0:
					continue
				candidates.append({
					"unitId": String(projected_unit.get("id", "")),
					"from": {"x": start_x, "y": start_y},
					"to": {"x": candidate_x, "y": candidate_y},
					"slotIndex": int(slot.get("index", 0)),
					"dir": direction,
					"canonicalDirectionOrder": DIRECTIONS.find(direction) if position_independent else 0,
					"score": int(metrics.get("score", 0)),
					"effective": int(metrics.get("effective", 0)),
					"overflow": int(metrics.get("overflow", 0)),
					"kills": int(metrics.get("kills", 0)),
					"bossDamage": int(metrics.get("bossDamage", 0)),
					"bossKilled": bool(metrics.get("bossKilled", false)),
					"priorityEffective": int(metrics.get("priorityEffective", metrics.get("effective", 0))),
					"rawDamage": int(metrics.get("rawDamage", 0)),
					"damageByTarget": Dictionary(metrics.get("damageByTarget", {})).duplicate(true),
					"ap": int(metrics.get("selectedAp", 1)),
					"moveCost": move_cost,
					"targets": _unit_ids(targets),
					"cells": Array(option.get("cells", [])).duplicate(true),
				})
	return _select_candidates(context, projected_unit, candidates, approach_by_destination, limit, position_independent, start_approach_distance)


func choices_conflict(choices: Array, candidate: Dictionary) -> bool:
	var candidate_to := Dictionary(candidate.get("to", {}))
	var candidate_key := _cell_key(int(candidate_to.get("x", -1)), int(candidate_to.get("y", -1)))
	for choice_value in choices:
		var choice_to := Dictionary(Dictionary(choice_value).get("to", {}))
		if _cell_key(int(choice_to.get("x", -1)), int(choice_to.get("y", -1))) == candidate_key:
			return true
	return false


func optimization_context(context: Dictionary) -> Dictionary:
	if not _valid(context):
		return {}
	var query := _query(context)
	var target_states := {}
	var has_living_non_boss_enemy := false
	for unit_value in Array(query.get("units", [])):
		var unit := Dictionary(unit_value)
		if int(unit.get("hp", 0)) <= 0:
			continue
		var unit_id := String(unit.get("id", ""))
		if unit_id == "":
			continue
		var is_boss := _is_boss(unit)
		target_states[unit_id] = {"hp": int(unit.get("hp", 0)), "shield": int(unit.get("shield", 0)), "isBoss": is_boss}
		if String(unit.get("side", "")) == ENEMY and not is_boss:
			has_living_non_boss_enemy = true
	for side in [PLAYER, ENEMY]:
		var leader := _leader_for_side(query, side)
		if not bool(leader.get("alive", false)):
			continue
		var leader_id := String(leader.get("id", ""))
		if leader_id != "":
			target_states[leader_id] = {"hp": int(leader.get("hp", 0)), "shield": int(leader.get("shield", 0)), "isBoss": _is_boss(leader)}
	return {"targetStates": target_states, "hasLivingNonBossEnemy": has_living_non_boss_enemy}


func decorate_finalists(context: Dictionary, beams: Array, side: String) -> Array:
	var result := beams.duplicate(true)
	if not _valid(context) or side != String(context.get("playerSide", PLAYER)):
		return result
	var query := _query(context)
	var query_session: RefCounted = _battle_query_projector.call("begin", query) as RefCounted
	if query_session == null:
		return result
	for index in range(result.size()):
		var beam := Dictionary(result[index])
		var choices := Array(beam.get("choices", []))
		var evaluation := Dictionary(beam.get("evaluation", {})).duplicate(true)
		var retaliation := _retaliation_metrics(query, choices, Dictionary(evaluation.get("projectedDamage", {})), query_session)
		evaluation["playerDeaths"] = int(retaliation.get("playerDeaths", 0))
		evaluation["playerHpDamage"] = int(retaliation.get("playerHpDamage", 0))
		evaluation["playerShieldDamage"] = int(retaliation.get("playerShieldDamage", 0))
		evaluation["incomingDamage"] = int(retaliation.get("incomingDamage", 0))
		beam["evaluation"] = evaluation
		result[index] = beam
	return result


func _select_candidates(
	context: Dictionary,
	unit: Dictionary,
	candidates: Array,
	approach_by_destination: Dictionary,
	limit: int,
	position_independent: bool,
	start_approach_distance: int
) -> Array:
	var start_x := int(unit.get("x", -1))
	var start_y := int(unit.get("y", -1))
	var approach_candidates: Array = approach_by_destination.values()
	approach_candidates.sort_custom(func(a, b): return _candidate_is_better(Dictionary(a), Dictionary(b)))
	if not candidates.is_empty():
		candidates.sort_custom(func(a, b): return _candidate_is_better(Dictionary(a), Dictionary(b)))
		var standby_reserve: int = min(_limit(context, "standby", AutoPositionConfigScript.STANDBY_CANDIDATE_LIMIT), approach_candidates.size())
		var attack_limit: int = max(1, limit - standby_reserve)
		var selected: Array = []
		var signature_counts := {}
		var selected_destinations := {}
		for candidate_value in candidates:
			var candidate := Dictionary(candidate_value)
			var signature := String(_auto_position_policy.call("target_signature", candidate))
			var signature_count := int(signature_counts.get(signature, 0))
			if signature_count >= _limit(context, "targetSignature", AutoPositionConfigScript.TARGET_SIGNATURE_LIMIT):
				continue
			signature_counts[signature] = signature_count + 1
			selected.append(candidate.duplicate(true))
			var candidate_to := Dictionary(candidate.get("to", {}))
			selected_destinations[_cell_key(int(candidate_to.get("x", -1)), int(candidate_to.get("y", -1)))] = true
			if selected.size() >= attack_limit:
				break
		var standby_added := 0
		for approach_value in approach_candidates:
			if standby_added >= standby_reserve or selected.size() >= limit:
				break
			var standby := Dictionary(approach_value).duplicate(true)
			var standby_to := Dictionary(standby.get("to", {}))
			var standby_key := _cell_key(int(standby_to.get("x", start_x)), int(standby_to.get("y", start_y)))
			if selected_destinations.has(standby_key) or (not position_independent and standby_key == _cell_key(start_x, start_y)):
				continue
			standby["standby"] = true
			selected_destinations[standby_key] = true
			selected.append(standby)
			standby_added += 1
		if not position_independent:
			selected.append(_attack_skip_candidate(unit))
		return selected
	if approach_candidates.is_empty():
		return [_minimal_skip_candidate(unit)]
	var selected_approaches: Array = []
	var seen_destinations := {}
	for approach_value in approach_candidates:
		var approach := Dictionary(approach_value).duplicate(true)
		var approach_to := Dictionary(approach.get("to", {}))
		var destination_key := _cell_key(int(approach_to.get("x", start_x)), int(approach_to.get("y", start_y)))
		if seen_destinations.has(destination_key):
			continue
		seen_destinations[destination_key] = true
		if int(approach_to.get("x", start_x)) == start_x and int(approach_to.get("y", start_y)) == start_y:
			approach["skip"] = true
		selected_approaches.append(approach)
		if selected_approaches.size() >= min(limit, _limit(context, "approach", AutoPositionConfigScript.APPROACH_CANDIDATE_LIMIT)):
			break
	var start_key := _cell_key(start_x, start_y)
	if not position_independent and not seen_destinations.has(start_key):
		selected_approaches.append(_approach_skip_candidate(unit, start_approach_distance))
	return selected_approaches


func _attack_skip_candidate(unit: Dictionary) -> Dictionary:
	var x := int(unit.get("x", -1))
	var y := int(unit.get("y", -1))
	return {
		"unitId": String(unit.get("id", "")), "from": {"x": x, "y": y}, "to": {"x": x, "y": y},
		"skip": true, "moveCost": 0, "approachGain": 0,
		"effective": 0, "overflow": 0, "kills": 0, "bossDamage": 0, "ap": 0, "targets": [], "cells": [],
	}


func _minimal_skip_candidate(unit: Dictionary) -> Dictionary:
	var x := int(unit.get("x", -1))
	var y := int(unit.get("y", -1))
	return {
		"unitId": String(unit.get("id", "")), "from": {"x": x, "y": y}, "to": {"x": x, "y": y},
		"skip": true, "moveCost": 0, "approachGain": 0, "ap": 0, "targets": [], "cells": [],
	}


func _approach_skip_candidate(unit: Dictionary, approach_distance: int) -> Dictionary:
	var candidate := _minimal_skip_candidate(unit)
	candidate["approachDistance"] = approach_distance
	return candidate


func _damage_metrics(
	query: Dictionary,
	unit_value: Dictionary,
	slot: Dictionary,
	option: Dictionary,
	target_values: Array,
	projected_damage: Dictionary,
	query_session: RefCounted
) -> Dictionary:
	var unit := unit_value.duplicate(true)
	var targets := target_values.duplicate(true)
	var slot_index := int(slot.get("index", 0))
	var selected_ap := int(_action_slot_service.call(
		"selected_ap", unit, slot_index, Dictionary(query.get("actionApChoices", {})), int(Dictionary(query.get("selection", {})).get("ap", 0))
	))
	var projected_slot := slot.duplicate(true)
	var base_layers: int = max(1, int(projected_slot.get("base_layers", projected_slot.get("layers", 1))))
	var slot_layers := base_layers * selected_ap
	projected_slot["ap_used"] = selected_ap
	projected_slot["layers"] = slot_layers
	projected_slot["effective_layers"] = slot_layers
	var damage_bonus := _skill_damage_bonus(unit, projected_slot, targets)
	var strike_count: int = max(1, int(projected_slot.get("strike_count", 1)))
	var base_strike_damage: int = max(0, _stat(query, unit, "atk", EffectHookIdsScript.NORMAL_ATTACK, {"option": option, "slot": projected_slot}, int(unit.get("atk", 0))))
	var base_damage: int = base_strike_damage * strike_count + damage_bonus
	var slot_element := String(projected_slot.get("element", unit.get("element", "")))
	var quality_slot_layers := _quality_element_layers(unit, slot_element, slot_layers)
	var effective := 0
	var overflow := 0
	var kills := 0
	var boss_damage := 0
	var boss_killed := false
	var damage_by_target := {}
	var hit_index := 0
	for target_value in targets:
		var target := Dictionary(target_value)
		var target_id := String(target.get("id", ""))
		var target_cell := {"x": int(target.get("x", -1)), "y": int(target.get("y", -1))}
		var apply_count := _quality_element_apply_count(query, unit, target_cell)
		var after_elements := _cell_elements_at(query, int(target_cell.get("x", -1)), int(target_cell.get("y", -1)))
		after_elements[slot_element] = int(after_elements.get(slot_element, 0)) + quality_slot_layers * strike_count * apply_count
		var settlement := Dictionary(query_session.call("project_settlement", after_elements, slot_element, unit))
		var settlement_damage := _project_damage_final(query, query_session, unit, target, int(settlement.get("rawDamage", 0)), slot_element, {"sourceType": "auto_position_settlement"}) if not settlement.is_empty() else 0
		var aggregate_hit_damage := _quality_damage_for_hit(query, unit, projected_slot, option, targets, target, hit_index, base_damage)
		var strike_damage_values := _strike_damage_values(base_strike_damage, strike_count, aggregate_hit_damage)
		var action_damage := 0
		for strike_index in range(strike_count):
			var hit_damage := _leader_guarded_damage_packet(query, target, int(strike_damage_values[strike_index]))
			action_damage += _project_damage_final(query, query_session, unit, target, hit_damage, slot_element, {"sourceType": "auto_position_action", "calculationKind": "physical", "strikeIndex": strike_index + 1})
		var final_damage := settlement_damage + action_damage
		damage_by_target[target_id] = final_damage
		var allocation := _damage_allocation(target, final_damage, int(projected_damage.get(target_id, 0)))
		effective += int(allocation.get("effective", 0))
		overflow += int(allocation.get("overflow", 0))
		if bool(allocation.get("killed", false)):
			kills += 1
		if _is_boss(target):
			boss_damage += int(allocation.get("effective", 0))
			boss_killed = boss_killed or bool(allocation.get("killed", false))
		hit_index += 1
	var nonlethal_boss_deprioritized := _has_living_non_boss_enemy(query) and boss_damage > 0 and not boss_killed
	var priority_effective: int = max(0, effective - (boss_damage if nonlethal_boss_deprioritized else 0))
	var boss_priority_damage := 0 if nonlethal_boss_deprioritized else boss_damage
	return {
		"effective": effective, "overflow": overflow, "kills": kills, "bossDamage": boss_damage,
		"bossKilled": boss_killed, "rawDamage": base_damage, "damageByTarget": damage_by_target,
		"selectedAp": selected_ap, "priorityEffective": priority_effective,
		"score": kills * 1_000_000 + (100_000 if boss_killed else 0) + priority_effective * 100 + boss_priority_damage * 10 - overflow,
	}


func _retaliation_metrics(query: Dictionary, choices: Array, projected_damage: Dictionary, query_session: RefCounted) -> Dictionary:
	var player_states := _projected_player_states(query, choices)
	var player_position_ids := {}
	for player_id_value in player_states.keys():
		var player_id := String(player_id_value)
		var player := Dictionary(player_states[player_id])
		player_position_ids[_cell_key(int(player.get("x", -1)), int(player.get("y", -1)))] = player_id
	var projected_incoming := _on_death_incoming(query, player_states, projected_damage)
	for enemy_value in Array(query.get("units", [])):
		var enemy := Dictionary(enemy_value)
		if String(enemy.get("side", "")) != ENEMY or int(enemy.get("hp", 0)) <= 0:
			continue
		var enemy_id := String(enemy.get("id", ""))
		var durability: int = max(0, int(enemy.get("shield", 0))) + max(0, int(enemy.get("hp", 0)))
		if int(projected_damage.get(enemy_id, 0)) >= durability:
			continue
		var start_x := int(enemy.get("x", -1))
		var start_y := int(enemy.get("y", -1))
		var movement_budget := _effective_move_range_query(query, enemy)
		var best := {}
		for y in range(_board_height(query)):
			for x in range(_board_width(query)):
				var move_cost: int = abs(start_x - x) + abs(start_y - y)
				if move_cost > movement_budget or player_position_ids.has(_cell_key(x, y)):
					continue
				var projected_enemy := enemy.duplicate(true)
				projected_enemy["x"] = x
				projected_enemy["y"] = y
				for option_value in _shape_attack_options(query, projected_enemy):
					var option := Dictionary(option_value)
					var target_ids: Array = []
					var effective_damage := 0
					var overflow := 0
					var kills := 0
					for cell_value in Array(option.get("cells", [])):
						var cell := Dictionary(cell_value)
						var target_id := String(player_position_ids.get(_cell_key(int(cell.get("x", -1)), int(cell.get("y", -1))), ""))
						if target_id == "" or target_ids.has(target_id):
							continue
						target_ids.append(target_id)
						var target := Dictionary(player_states[target_id])
						var existing_damage := int(projected_incoming.get(target_id, 0))
						var enemy_attack := _stat(query, enemy, "atk", EffectHookIdsScript.RETALIATION_PREVIEW, {"target": target}, int(enemy.get("atk", 0)))
						var final_damage := _project_damage_final(query, query_session, enemy, target, enemy_attack, String(enemy.get("element", "")), {"sourceType": "retaliation_preview"})
						var allocation := _damage_allocation(target, final_damage, existing_damage)
						effective_damage += int(allocation.get("effective", 0))
						overflow += int(allocation.get("overflow", 0))
						if bool(allocation.get("killed", false)):
							kills += 1
					if target_ids.is_empty():
						continue
					var candidate := {"kills": kills, "effective": effective_damage, "overflow": overflow, "moveCost": move_cost, "x": x, "y": y, "directionOrder": DIRECTIONS.find(String(option.get("direction", "right"))), "targetIds": target_ids}
					if best.is_empty() or bool(_auto_position_policy.call("enemy_response_is_better", candidate, best)):
						best = candidate
		if best.is_empty():
			continue
		var action_count: int = min(_enemy_attack_count(query, enemy), max(1, _action_slots(query, enemy).size()))
		for target_id_value in Array(best.get("targetIds", [])):
			var target_id := String(target_id_value)
			var target := Dictionary(player_states[target_id])
			var enemy_attack := _stat(query, enemy, "atk", EffectHookIdsScript.RETALIATION_PREVIEW, {"target": target}, int(enemy.get("atk", 0)))
			var final_damage := _project_damage_final(query, query_session, enemy, target, enemy_attack, String(enemy.get("element", "")), {"sourceType": "retaliation_preview"})
			projected_incoming[target_id] = int(projected_incoming.get(target_id, 0)) + final_damage * action_count
	return _retaliation_summary(player_states, projected_incoming)


func _projected_player_states(query: Dictionary, choices: Array) -> Dictionary:
	var planned_positions := _choice_positions(choices)
	var player_states := {}
	for unit_value in Array(query.get("units", [])):
		var unit := Dictionary(unit_value)
		var unit_id := String(unit.get("id", ""))
		if String(unit.get("side", "")) != PLAYER or int(unit.get("hp", 0)) <= 0:
			continue
		var position := Dictionary(planned_positions.get(unit_id, {"x": int(unit.get("x", -1)), "y": int(unit.get("y", -1))}))
		var projected_unit := unit.duplicate(true)
		projected_unit["x"] = int(position.get("x", -1))
		projected_unit["y"] = int(position.get("y", -1))
		player_states[unit_id] = projected_unit
	return player_states


func _on_death_incoming(query: Dictionary, player_states: Dictionary, projected_damage: Dictionary) -> Dictionary:
	var projected_incoming := {}
	if _mechanic_projection_service == null:
		return projected_incoming
	var mechanisms := _battle_mechanisms(query)
	for enemy_value in Array(query.get("units", [])):
		var defeated_enemy := Dictionary(enemy_value)
		if String(defeated_enemy.get("side", "")) != ENEMY or int(defeated_enemy.get("hp", 0)) <= 0:
			continue
		var defeated_id := String(defeated_enemy.get("id", ""))
		var durability: int = max(0, int(defeated_enemy.get("shield", 0))) + max(0, int(defeated_enemy.get("hp", 0)))
		if int(projected_damage.get(defeated_id, 0)) < durability:
			continue
		var effects := Array(_mechanic_projection_service.call(
			"death_preview_effects",
			defeated_enemy.duplicate(true),
			mechanisms,
			{"projected_dead": true}
		)).duplicate(true)
		for effect_value in effects:
			var effect := Dictionary(effect_value)
			if String(effect.get("metric", "")) != "manhattan":
				continue
			var radius: int = max(0, int(effect.get("radius", 0)))
			var explosion_damage: int = max(0, int(effect.get("damage", 0)))
			if radius <= 0 or explosion_damage <= 0:
				continue
			for player_id_value in player_states.keys():
				var player_id := String(player_id_value)
				var player := Dictionary(player_states[player_id])
				var distance: int = abs(int(player.get("x", -1)) - int(defeated_enemy.get("x", -1))) + abs(int(player.get("y", -1)) - int(defeated_enemy.get("y", -1)))
				if distance <= radius:
					projected_incoming[player_id] = int(projected_incoming.get(player_id, 0)) + explosion_damage
	return projected_incoming


func _retaliation_summary(player_states: Dictionary, projected_incoming: Dictionary) -> Dictionary:
	var result := {"playerDeaths": 0, "playerHpDamage": 0, "playerShieldDamage": 0, "incomingDamage": 0}
	for unit_id_value in player_states.keys():
		var unit_id := String(unit_id_value)
		var allocation := _damage_allocation(Dictionary(player_states[unit_id]), int(projected_incoming.get(unit_id, 0)))
		result["playerHpDamage"] = int(result["playerHpDamage"]) + int(allocation.get("hpDamage", 0))
		result["playerShieldDamage"] = int(result["playerShieldDamage"]) + int(allocation.get("shieldDamage", 0))
		result["incomingDamage"] = int(result["incomingDamage"]) + int(allocation.get("effective", 0))
		if bool(allocation.get("killed", false)):
			result["playerDeaths"] = int(result["playerDeaths"]) + 1
	return result


func _damage_allocation(target: Dictionary, final_damage: int, already_damage: int = 0) -> Dictionary:
	var shield: int = max(0, int(target.get("shield", 0)))
	var hp: int = max(0, int(target.get("hp", 0)))
	var applied_before: int = max(0, already_damage)
	var remaining_shield: int = max(0, shield - applied_before)
	var remaining_hp: int = max(0, hp - max(0, applied_before - shield))
	var damage: int = max(0, final_damage)
	var shield_damage: int = min(remaining_shield, damage)
	var hp_damage: int = min(remaining_hp, max(0, damage - shield_damage))
	var effective: int = shield_damage + hp_damage
	return {"final": damage, "effective": effective, "overflow": max(0, damage - effective), "hpDamage": hp_damage, "shieldDamage": shield_damage, "killed": remaining_hp > 0 and hp_damage >= remaining_hp}


func _cells_for_unit(query: Dictionary, unit: Dictionary, movement_budget: int) -> Array:
	var cells: Array = []
	var start_x := int(unit.get("x", -1))
	var start_y := int(unit.get("y", -1))
	var unit_side := String(unit.get("side", ""))
	for y in range(_board_height(query)):
		for x in range(_board_width(query)):
			if movement_budget >= 0 and abs(start_x - x) + abs(start_y - y) > movement_budget:
				continue
			if not _leader_at(query, x, y).is_empty():
				continue
			var occupant := _unit_at(query, x, y)
			if not occupant.is_empty() and String(occupant.get("id", "")) != String(unit.get("id", "")):
				var occupant_can_vacate := String(occupant.get("side", "")) == unit_side and int(occupant.get("hp", 0)) > 0 and not bool(occupant.get("has_attacked", false)) and not _has_used_action_slot(occupant)
				if not occupant_can_vacate:
					continue
			cells.append({"x": x, "y": y})
	return cells


func _current_approach_distance(query: Dictionary, unit: Dictionary) -> int:
	var best_distance := 1_000_000
	var target_side := _opponent_side(String(unit.get("side", PLAYER)))
	var shape_options := _shape_attack_options(query, unit)
	for direction in DIRECTIONS:
		var option := Dictionary(_attack_option_service.call(
			"option_for_direction", shape_options, direction
		)).duplicate(true)
		if not option.is_empty():
			best_distance = min(best_distance, _approach_distance(query, option, target_side))
	return best_distance


func _approach_distance(query: Dictionary, option: Dictionary, target_side: String) -> int:
	var best_distance := 1_000_000
	var cells := Array(option.get("cells", []))
	for enemy_value in Array(query.get("units", [])):
		var enemy := Dictionary(enemy_value)
		if String(enemy.get("side", "")) != target_side or int(enemy.get("hp", 0)) <= 0:
			continue
		for cell_value in cells:
			var cell := Dictionary(cell_value)
			best_distance = min(best_distance, abs(int(enemy.get("x", -1)) - int(cell.get("x", cell.get("c", -1)))) + abs(int(enemy.get("y", -1)) - int(cell.get("y", cell.get("r", -1)))))
	var target_leader := _leader_for_side(query, target_side)
	if bool(target_leader.get("alive", false)):
		for cell_value in cells:
			var cell := Dictionary(cell_value)
			best_distance = min(best_distance, abs(int(target_leader.get("x", -1)) - int(cell.get("x", cell.get("c", -1)))) + abs(int(target_leader.get("y", -1)) - int(cell.get("y", cell.get("r", -1)))))
	return best_distance


func _directions_for_slot(query: Dictionary, unit: Dictionary, slot_index: int, allow_direction_changes: bool) -> Array:
	if allow_direction_changes or String(unit.get("side", "")) != PLAYER:
		return DIRECTIONS.duplicate()
	return [String(_action_slot_service.call("stored_direction", unit, slot_index, Dictionary(query.get("actionDirections", {}))))]


func _action_slots(query: Dictionary, unit: Dictionary) -> Array:
	return Array(_action_slot_service.call("project_slots", unit, {
		"availableAp": int(Dictionary(query.get("selection", {})).get("ap", 0)),
		"selectedApChoices": Dictionary(query.get("actionApChoices", {})),
		"directions": Dictionary(query.get("actionDirections", {})),
		"shapeDefinition": SkillShapeRulesScript.shape_definition(unit, Dictionary(query.get("gameData", {}))),
	})).duplicate(true)


func _shape_attack_options(query: Dictionary, unit: Dictionary) -> Array:
	var definition := SkillShapeRulesScript.shape_definition(unit, Dictionary(query.get("gameData", {})))
	var upgrade := Dictionary(unit.get("quality_upgrade", {}))
	return Array(_attack_option_service.call("build_options", unit, _board_width(query), _board_height(query), definition, _quality_effect_registry.call("effect_for_unit", unit), String(upgrade.get("name", upgrade.get("id", ""))))).duplicate(true)


func _attack_option_for_direction(query: Dictionary, unit: Dictionary, direction: String) -> Dictionary:
	return Dictionary(_attack_option_service.call("option_for_direction", _shape_attack_options(query, unit), direction)).duplicate(true)


func _targets_in_option(query: Dictionary, attacker: Dictionary, option: Dictionary) -> Array:
	var target_side := _opponent_side(String(attacker.get("side", PLAYER)))
	var targets := Array(_targeting_service.call("targets_in_option", attacker, option, Array(query.get("units", [])), _leader_for_side(query, target_side), target_side)).duplicate(true)
	var effect: RefCounted = _quality_effect_registry.call("effect_for_unit", attacker) as RefCounted
	if effect != null:
		effect.call("sort_targets", targets, option)
	return targets


func _quality_damage_for_hit(query: Dictionary, attacker: Dictionary, slot: Dictionary, option: Dictionary, targets: Array, target: Dictionary, hit_index: int, base_damage: int) -> int:
	var incoming_bonus: int = max(0, int(target.get("incoming_damage_bonus", 0)))
	if incoming_bonus > 0:
		target["incoming_damage_bonus"] = 0
	var damage: int = max(0, base_damage + int(_quality_hit_context_projector.call("cell_damage_delta", option, target)) + incoming_bonus)
	var runtime := Dictionary(attacker.get("quality_runtime", {}))
	var marked_cell := Dictionary(runtime.get("marked_cell", {}))
	var hit_context := Dictionary(_quality_hit_context_projector.call("build", attacker, option, targets, target, hit_index, damage, _option_all_cells_occupied(query, option), _mark_matches_unit(marked_cell, target)))
	var effect: RefCounted = _quality_effect_registry.call("effect_for_unit", attacker) as RefCounted
	return int(effect.call("modify_hit_damage", hit_context)) if effect != null else damage


func _quality_element_apply_count(query: Dictionary, attacker: Dictionary, cell: Dictionary) -> int:
	var effect: RefCounted = _quality_effect_registry.call("effect_for_unit", attacker) as RefCounted
	var effect_bonus := int(effect.get("element_apply_bonus")) if effect != null else 0
	return max(1, 1 + effect_bonus + QualityBoardTraceScript.element_apply_bonus(_board_traces_at(query, int(cell.get("x", -1)), int(cell.get("y", -1)))))


func _quality_element_layers(attacker: Dictionary, slot_element: String, base_layers: int) -> int:
	var effect: RefCounted = _quality_effect_registry.call("effect_for_unit", attacker) as RefCounted
	return int(effect.call("element_layers", attacker, slot_element, base_layers)) if effect != null else max(1, base_layers)


func _option_all_cells_occupied(query: Dictionary, option: Dictionary) -> bool:
	for cell_value in Array(option.get("cells", [])):
		var cell := Dictionary(cell_value)
		if _unit_at(query, int(cell.get("x", -1)), int(cell.get("y", -1))).is_empty():
			return false
	return true


func _skill_damage_bonus(attacker: Dictionary, slot: Dictionary, targets: Array) -> int:
	match String(attacker.get("skill", "")):
		"spaceExplosionBonus":
			return max(2, int(slot.get("layers", 1)) * 2)
		"advHitBonus":
			return 1 if targets.size() == 1 else 0
	return 0


func _strike_damage_values(base_strike_damage: int, strike_count: int, aggregate_damage: int) -> Array:
	var values: Array = []
	var remaining_delta: int = aggregate_damage - base_strike_damage * strike_count
	for _strike_index in range(strike_count):
		var strike_damage: int = max(0, base_strike_damage)
		if remaining_delta > 0:
			strike_damage += remaining_delta
			remaining_delta = 0
		elif remaining_delta < 0:
			var reduction: int = min(strike_damage, -remaining_delta)
			strike_damage -= reduction
			remaining_delta += reduction
		values.append(strike_damage)
	return values


func _project_damage_final(query: Dictionary, query_session: RefCounted, source: Dictionary, target: Dictionary, amount: int, element: String, trace_context: Dictionary) -> int:
	if query_session != null:
		return int(query_session.call("project_damage_final", source, target, amount, element, trace_context, {}))
	return int(Dictionary(_battle_query_projector.call("project_damage", query, source, target, amount, element, trace_context, {})).get("final", 0))


func _effective_move_range_query(query: Dictionary, unit: Dictionary) -> int:
	return max(0, _stat(query, unit, "move_range", EffectHookIdsScript.MOVEMENT, {}, int(unit.get("move_range", 0))))


func _effective_movement_cost(query: Dictionary, unit: Dictionary, base_cost: int) -> int:
	return max(0, base_cost + _stat(query, unit, "movement_cost_delta", EffectHookIdsScript.MOVEMENT_COST, {}, int(unit.get("movement_cost_delta", 0))))


func _enemy_attack_count(query: Dictionary, unit: Dictionary) -> int:
	return max(0, _stat(query, unit, "attack_count", EffectHookIdsScript.ACTION_COUNT, {}, int(unit.get("attack_count", 0))))


func _stat(query: Dictionary, unit: Dictionary, stat_id: String, hook: String, context: Dictionary, fallback: int) -> int:
	if _stat_query_service == null:
		return fallback
	var effective_context := context.duplicate(true)
	effective_context["hook"] = hook
	return int(_stat_query_service.call("value", unit, Dictionary(query.get("gameData", {})), stat_id, hook, effective_context))


func _choice_positions(choices: Array) -> Dictionary:
	var positions := {}
	for choice_value in choices:
		var choice := Dictionary(choice_value)
		var unit_id := String(choice.get("unitId", ""))
		var to := Dictionary(choice.get("to", {}))
		if unit_id != "" and not to.is_empty():
			positions[unit_id] = {"x": int(to.get("x", -1)), "y": int(to.get("y", -1))}
	return positions


func _unit_ids(items: Array) -> Array:
	var ids: Array = []
	for item in items:
		var unit_id := String(Dictionary(item).get("id", ""))
		if unit_id != "":
			ids.append(unit_id)
	return ids


func _has_used_action_slot(unit: Dictionary) -> bool:
	return bool(_action_slot_service.call("has_used", unit))


func _has_living_non_boss_enemy(query: Dictionary) -> bool:
	for value in Array(query.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == ENEMY and int(unit.get("hp", 0)) > 0 and not _is_boss(unit):
			return true
	return false


func _leader_guarded_damage_packet(query: Dictionary, target: Dictionary, amount: int) -> int:
	var side := ""
	match String(target.get("id", "")):
		"player_hero": side = PLAYER
		"enemy_boss": side = ENEMY
	if side == "":
		return max(0, amount)
	for value in Array(query.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == side and int(unit.get("hp", 0)) > 0:
			return min(max(0, amount), 4)
	return max(0, amount)


func _is_boss(unit: Dictionary) -> bool:
	if String(unit.get("id", "")) == "enemy_boss":
		return true
	if String(unit.get("side", "")) != ENEMY:
		return false
	for key in ["is_boss", "isBoss", "boss"]:
		if bool(unit.get(key, false)):
			return true
	var role_text := "%s %s %s %s" % [String(unit.get("role", "")), String(unit.get("enemy_role", "")), String(unit.get("enemyType", "")), String(unit.get("type", ""))]
	if role_text.to_lower().find("boss") >= 0 or role_text.find("首领") >= 0:
		return true
	var identity_text := "%s %s" % [String(unit.get("id", "")), String(unit.get("name", ""))]
	return identity_text.to_lower().find("boss") >= 0 or identity_text.find("首领") >= 0


func _battle_mechanisms(query: Dictionary) -> Array:
	return Array(Dictionary(Dictionary(query.get("gameData", {})).get("battle", {})).get("mechanisms", [])).duplicate(true)


func _unit_at(query: Dictionary, x: int, y: int) -> Dictionary:
	for value in Array(query.get("units", [])):
		var unit := Dictionary(value)
		if int(unit.get("hp", 0)) > 0 and int(unit.get("x", -1)) == x and int(unit.get("y", -1)) == y:
			return unit
	return {}


func _leader_for_side(query: Dictionary, side: String) -> Dictionary:
	return Dictionary(Dictionary(query.get("leaders", {})).get("player" if side == PLAYER else "enemy", {}))


func _leader_at(query: Dictionary, x: int, y: int) -> Dictionary:
	for value in Dictionary(query.get("leaders", {})).values():
		var leader := Dictionary(value)
		if bool(leader.get("alive", false)) and int(leader.get("x", -1)) == x and int(leader.get("y", -1)) == y:
			return leader
	return {}


func _cell_elements_at(query: Dictionary, x: int, y: int) -> Dictionary:
	return ElementRulesScript.normalize_layers(
		Dictionary(Dictionary(query.get("cellElements", {})).get(_cell_key(x, y), {}))
	).duplicate(true)


func _board_traces_at(query: Dictionary, x: int, y: int) -> Array:
	var value: Variant = Dictionary(query.get("boardTraces", {})).get(_cell_key(x, y), {})
	if typeof(value) == TYPE_ARRAY:
		return Array(value).duplicate(true)
	if typeof(value) == TYPE_DICTIONARY and not Dictionary(value).is_empty():
		return [Dictionary(value).duplicate(true)]
	return []


func _mark_matches_unit(marked_cell: Dictionary, unit: Dictionary) -> bool:
	return not marked_cell.is_empty() and int(marked_cell.get("x", marked_cell.get("c", -1))) == int(unit.get("x", -2)) and int(marked_cell.get("y", marked_cell.get("r", -1))) == int(unit.get("y", -2))


func _candidate_is_better(left: Dictionary, right: Dictionary) -> bool:
	return bool(_auto_position_policy.call("candidate_is_better", left, right))


func _opponent_side(side: String) -> String:
	return PLAYER if side == ENEMY else ENEMY


func _board_width(query: Dictionary) -> int:
	return int(Dictionary(query.get("board", {})).get("width", 0))


func _board_height(query: Dictionary) -> int:
	return int(Dictionary(query.get("board", {})).get("height", 0))


func _cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func _limit(context: Dictionary, key: String, fallback: int) -> int:
	return max(1, int(Dictionary(context.get("limits", {})).get(key, fallback)))


func _query(context: Dictionary) -> Dictionary:
	return Dictionary(context.get("query", {}))


func _valid(context: Dictionary) -> bool:
	return String(context.get("schema", "")) == SCHEMA and typeof(context.get("query")) == TYPE_DICTIONARY
