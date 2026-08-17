extends RefCounted

## Pure battle outcome policy. Post-battle mechanics and route rewards are
## applied by the authoritative application layer; this policy owns the
## resulting verdict document and its compatibility aliases.


func terminal_reason(
	player_hero_hp: int,
	enemy_hero_hp: int,
	round_number: int,
	max_rounds: int,
	resolve_round_limit: bool
) -> Dictionary:
	if enemy_hero_hp <= 0:
		return {"finished": true, "win": true, "draw": false, "reason": "enemy_hero_dead"}
	if player_hero_hp <= 0:
		return {"finished": true, "win": false, "draw": false, "reason": "player_hero_dead"}
	if not resolve_round_limit or round_number < max_rounds:
		return {"finished": false}
	if player_hero_hp > enemy_hero_hp:
		return {"finished": true, "win": true, "draw": false, "reason": "hero_hp_higher"}
	if player_hero_hp < enemy_hero_hp:
		return {"finished": true, "win": false, "draw": false, "reason": "hero_hp_lower"}
	return {"finished": true, "win": false, "draw": true, "reason": "hero_hp_tie"}


func base_result(win: bool, draw: bool, reason: String, round_number: int, fast_round_limit: int = 5) -> Dictionary:
	if draw:
		return {
			"code": "DRAW",
			"grade": "DRAW",
			"gold": 0,
			"game_over": false,
			"reduce_defense": false,
		}
	if win:
		var fast := round_number <= fast_round_limit
		return {
			"code": "WIN_FAST" if fast else "WIN",
			"grade": "S" if fast else "A",
			"gold": 6 if fast else 4,
			"game_over": false,
			"reduce_defense": false,
		}
	return {
		"code": "LOSE",
		"grade": "D",
		"gold": 1,
		"game_over": reason == "player_hero_dead",
		"reduce_defense": reason not in ["player_hero_dead", "hero_hp_lower"],
	}


func assemble_result(context: Dictionary) -> Dictionary:
	var win := bool(context.get("win", false))
	var draw := bool(context.get("draw", false))
	var reason := String(context.get("reason", ""))
	var before_hp := int(context.get("hero_hp_from", 0))
	var hero_hp := int(context.get("hero_hp_to", before_hp))
	var before_castle_line := int(context.get("castle_line_from", 0))
	var castle_line := int(context.get("castle_line_to", before_castle_line))
	var before_economy_multiplier := float(context.get("economy_multiplier_from", 1.0))
	var economy_multiplier := float(context.get("economy_multiplier_to", before_economy_multiplier))
	var code := String(context.get("code", "LOSE"))
	var game_over := bool(context.get("game_over", false))
	var gold_base_delta := int(context.get("gold_base_delta", 0))
	var gold_delta := int(context.get("gold_delta", 0))
	var reward_pool_id := String(context.get("reward_pool_id", ""))
	var event_reward_pool_id := String(context.get("event_reward_pool_id", reward_pool_id))
	var failure_audit := {}
	if not win:
		failure_audit = {
			"reason": reason,
			"code": code,
			"hero_hp_from": before_hp,
			"hero_hp_to": hero_hp,
			"hero_hp_penalty": before_hp - hero_hp,
			"castle_line_from": before_castle_line,
			"castle_line_to": castle_line,
			"economy_multiplier_from": before_economy_multiplier,
			"economy_multiplier_to": economy_multiplier,
			"gold_base_delta": gold_base_delta,
			"gold_delta": gold_delta,
			"reward_eligible": false,
			"game_over": game_over,
		}
	var post_battle_events := Array(context.get("post_battle_events", [])).duplicate(true)
	if not win:
		post_battle_events = _enrich_failure_events(
			post_battle_events,
			before_hp,
			hero_hp,
			before_castle_line,
			castle_line,
			before_economy_multiplier,
			economy_multiplier
		)
	return {
		"win": win,
		"code": code,
		"grade": String(context.get("grade", "D")),
		"gold": int(context.get("gold", gold_delta)),
		"gold_base_delta": gold_base_delta,
		"gold_delta": gold_delta,
		"gold_from": int(context.get("gold_from", 0)),
		"gold_to": int(context.get("gold_to", 0)),
		"hero_hp_from": before_hp,
		"hero_hp_to": hero_hp,
		"hero_hp_penalty": before_hp - hero_hp,
		"enemy_hero_hp": int(context.get("enemy_hero_hp", 0)),
		"draw": draw,
		"castleLineFrom": before_castle_line,
		"castleLineTo": castle_line,
		"castle_line_from": before_castle_line,
		"castle_line_to": castle_line,
		"economyMultiplierFrom": before_economy_multiplier,
		"economyMultiplierTo": economy_multiplier,
		"economy_multiplier_from": before_economy_multiplier,
		"economy_multiplier_to": economy_multiplier,
		"game_over": game_over,
		"reason": reason,
		"day": int(context.get("day", 1)),
		"node_index": int(context.get("node_index", 0)),
		"battle_round": int(context.get("battle_round", 0)),
		"encounter_id": String(context.get("encounter_id", "")),
		"encounter_name": String(context.get("encounter_name", "路线战斗")),
		"base_reward_pool_id": String(context.get("base_reward_pool_id", "")),
		"reward_pool_id": reward_pool_id,
		"reward_eligible": win and not draw,
		"reward_seed_context": String(context.get("reward_seed_context", "")),
		"post_battle_events": post_battle_events,
		"run_effects": Array(context.get("run_effects", [])).duplicate(true),
		"battle_end_mechanics": Array(context.get("battle_end_mechanics", [])).duplicate(true),
		"extra_rewards": Array(context.get("extra_rewards", [])).duplicate(true),
		"reward_fallback": win and reward_pool_id != event_reward_pool_id,
		"reward_fallback_audit": Dictionary(context.get("reward_fallback_audit", {})).duplicate(true),
		"failure_audit": failure_audit,
		"event_reward_pool_id": event_reward_pool_id,
		"advance_route": true,
	}


func _enrich_failure_events(
	events: Array,
	before_hp: int,
	hero_hp: int,
	before_castle_line: int,
	castle_line: int,
	before_economy_multiplier: float,
	economy_multiplier: float
) -> Array:
	var enriched_events: Array = []
	for event in events:
		var row := Dictionary(event).duplicate(true)
		row["castleLineFrom"] = before_castle_line
		row["castleLineTo"] = castle_line
		row["castle_line_from"] = before_castle_line
		row["castle_line_to"] = castle_line
		row["economyMultiplierFrom"] = before_economy_multiplier
		row["economyMultiplierTo"] = economy_multiplier
		row["economy_multiplier_from"] = before_economy_multiplier
		row["economy_multiplier_to"] = economy_multiplier
		row["playerHeroHpFrom"] = before_hp
		row["playerHeroHpTo"] = hero_hp
		row["playerHeroHpPenalty"] = before_hp - hero_hp
		enriched_events.append(row)
	return enriched_events
