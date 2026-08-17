extends RefCounted

const ViewModelSchemaScript := preload("res://session/view_model_schema.gd")

## Pure CQRS query projector. It receives an already immutable snapshot payload
## and creates the public ViewModel without reading or writing authoritative state.


func project(snap: Dictionary, player_side: String, enemy_side: String) -> Dictionary:
	var all_units := Array(snap.get("units", []))
	var heroes: Array = []
	var enemies: Array = []
	for unit_value in all_units:
		var unit := Dictionary(unit_value).duplicate(true)
		unit["unitId"] = String(unit.get("id", unit.get("unit_id", "")))
		unit["unitSide"] = String(unit.get("side", ""))
		unit["unitName"] = String(unit.get("name", ""))
		if String(unit.get("side", "")) == player_side:
			heroes.append(unit)
		elif String(unit.get("side", "")) == enemy_side:
			enemies.append(unit)
	var selected := {
		"unitId": String(snap.get("selected_unit_id", "")),
		"unit_id": String(snap.get("selected_unit_id", "")),
		"actionSlotIndex": int(snap.get("selected_action_slot_index", 0)),
		"action_slot_index": int(snap.get("selected_action_slot_index", 0)),
		"actionAp": int(snap.get("selected_action_ap", 0)),
		"action_ap": int(snap.get("selected_action_ap", 0)),
		"actionCells": Array(snap.get("selected_action_cells", [])).duplicate(true),
		"actionSkill": Dictionary(snap.get("selected_skill", {})).duplicate(true)
	}
	var route_options := Array(snap.get("route_options", []))
	var battle_options: Array = []
	for option_value in route_options:
		var option := Dictionary(option_value)
		if String(option.get("kind", "")) == "battle":
			battle_options.append(option.duplicate(true))
	var day_route := {
		"day": int(snap.get("day", 1)),
		"nodeIndex": int(snap.get("node_index", 1)),
		"node_index": int(snap.get("node_index", 1)),
		"options": route_options.duplicate(true),
		"battleOptions": battle_options,
		"activeSchedule": Dictionary(snap.get("active_schedule", {})).duplicate(true),
		"activeEncounter": Dictionary(snap.get("active_encounter", {})).duplicate(true),
		"runPlan": Dictionary(snap.get("run_plan", {})).duplicate(true),
		"runPlanHash": String(snap.get("runPlanHash", snap.get("run_plan_hash", "")))
	}
	var shop_view := {
		"offers": Array(snap.get("shop_offers", [])).duplicate(true),
		"events": Array(snap.get("shop_events", [])).duplicate(true),
		"activePool": String(snap.get("active_shop_pool", "")),
		"activeStall": Dictionary(snap.get("active_stall", {})).duplicate(true),
		"refreshState": Dictionary(snap.get("shop_refresh", {})).duplicate(true),
		"dailySeenPetIds": Array(snap.get("shop_seen_pet_ids", [])).duplicate(true),
		"dailySeenCount": Array(snap.get("shop_seen_pet_ids", [])).size(),
		"seedAudit": Array(snap.get("shop_seed_audit", [])).duplicate(true)
	}
	var view_model := {
		"phase": String(snap.get("phase", "")),
		"stateVersion": int(snap.get("stateVersion", 0)),
		"stateHash": String(snap.get("stateHash", "")),
		"day": int(snap.get("day", 1)),
		"gold": int(snap.get("coins", 0)),
		"coins": int(snap.get("coins", 0)),
		"heroHp": int(snap.get("hero_hp", 0)),
		"hero_hp": int(snap.get("hero_hp", 0)),
		"heroMaxHp": int(snap.get("heroMaxHp", snap.get("hero_max_hp", snap.get("hero_hp", 0)))),
		"hero_max_hp": int(snap.get("hero_max_hp", snap.get("heroMaxHp", snap.get("hero_hp", 0)))),
		"castleLine": int(snap.get("castleLine", snap.get("castle_line", 0))),
		"economyMultiplier": float(snap.get("economyMultiplier", snap.get("economy_multiplier", 1.0))),
		"ap": int(snap.get("ap", 0)),
		"round": int(snap.get("battle_round", 0)),
		"battleRound": int(snap.get("battle_round", 0)),
		"period": String(snap.get("battle_period", "")),
		"battlePeriod": String(snap.get("battle_period", "")),
		"maxRounds": int(snap.get("maxRounds", 0)),
		"dayRoute": day_route,
		"shop": shop_view,
		"teamPlacementPreview": Dictionary(snap.get("teamPlacementPreview", snap.get("team_placement_preview", {}))).duplicate(true),
		"rewards": Array(snap.get("reward_options", [])).duplicate(true),
		"inventory": Dictionary(snap.get("inventory", {})).duplicate(true),
		"buildCore": Dictionary(snap.get("build_core", {})).duplicate(true),
		"skillCatalog": Dictionary(snap.get("skill_catalog", {})).duplicate(true),
		"leaders": Dictionary(snap.get("leaders", {})).duplicate(true),
		"heroes": heroes,
		"enemies": enemies,
		"units": all_units.duplicate(true),
		"board": Dictionary(snap.get("board", {})).duplicate(true),
		"actionPreviewByUnit": Dictionary(snap.get("action_preview_by_unit", {})).duplicate(true),
		"actionBlockRangesByUnit": Dictionary(snap.get("action_block_ranges_by_unit", {})).duplicate(true),
		"action_block_ranges_by_unit": Dictionary(snap.get("action_block_ranges_by_unit", {})).duplicate(true),
		"selected": selected,
		"nextActions": Array(snap.get("nextActions", [])).duplicate(true),
		"next_actions": Array(snap.get("next_actions", [])).duplicate(true),
		"battleResult": Dictionary(snap.get("battle_result", {})).duplicate(true),
		"battleTrace": Array(snap.get("battleTrace", [])).duplicate(true),
		"commandLog": Array(snap.get("command_log", [])).duplicate(true),
		"logLines": Array(snap.get("log_lines", [])).duplicate(true)
	}
	return ViewModelSchemaScript.normalize(view_model)
