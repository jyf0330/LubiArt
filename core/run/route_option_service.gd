extends RefCounted

## Deterministic route-option projection. It receives immutable run context and
## never mutates the authoritative run state.

const RouteRulesScript := preload("res://core/route/route_rules.gd")
const SeededSelectorScript := preload("res://core/run/seeded_selector.gd")


func options_for_schedule(schedule: Dictionary, context: Dictionary) -> Array:
	match String(schedule.get("kind", "")):
		"node_choice":
			return _node_options(schedule, context)
		"fixed_battle":
			return _fixed_battle_entry_options(schedule, context)
		"battle_choice":
			return _battle_options(schedule, context)
	return []


func battle_option_for_node_choice(schedule: Dictionary, context: Dictionary) -> Dictionary:
	var schedule_day := int(schedule.get("day", context.get("day", 1)))
	var pool_id := String(schedule.get("encounterPoolId", "")).strip_edges()
	if pool_id == "":
		pool_id = "enc_pool_d%02d_midday" % schedule_day
	var candidates := _formal_encounters(pool_id, schedule_day, context)
	if candidates.is_empty():
		return {}
	var battle_schedule := schedule.duplicate(true)
	battle_schedule["encounterPoolId"] = pool_id
	var picked := _weighted_unique(candidates, 1, ["encounterId"], _route_seed(battle_schedule, "node_battle", context))
	return {} if picked.is_empty() else _battle_option(Dictionary(picked[0]), battle_schedule, 1, context)


func _fixed_battle_entry_options(schedule: Dictionary, context: Dictionary) -> Array:
	var shared_option := _battle_option(_encounter_for_schedule(schedule, context), schedule, 1, context)
	if shared_option.is_empty():
		return []
	var options: Array = []
	for entry_index in range(3):
		var entry := shared_option.duplicate(true)
		entry["optionId"] = "%s_entry_%d" % [String(shared_option.get("optionId", "battle")), entry_index + 1]
		entry["entryIndex"] = entry_index + 1
		entry["entryCount"] = 3
		options.append(entry)
	return options


func _node_options(schedule: Dictionary, context: Dictionary) -> Array:
	var schedule_day := int(schedule.get("day", context.get("day", 1)))
	var schedule_step := int(schedule.get("step", context.get("nodeIndex", 1)))
	var candidates: Array = []
	for item in Array(Dictionary(context.get("routeData", {})).get("node_pool", [])):
		if not item is Dictionary:
			continue
		var node := Dictionary(item)
		if String(node.get("nodePoolId", "")) != String(schedule.get("poolId", "")):
			continue
		if int(node.get("unlockDay", 1)) > schedule_day or not _is_formal(node):
			continue
		candidates.append(node)
	var count: int = min(candidates.size(), max(1, int(schedule.get("choiceCount", 3))))
	var picked := _weighted_unique(candidates, count, ["nodeId"], _route_seed(schedule, "node", context))
	var options: Array = []
	for index in range(picked.size()):
		var node := Dictionary(picked[index])
		var node_type := String(node.get("nodeType", "event"))
		options.append({
			"id": String(node.get("nodeId", "")),
			"optionId": "node_%d_%d_%s" % [schedule_step, index + 1, String(node.get("nodeId", ""))],
			"nodeId": String(node.get("nodeId", "")),
			"title": String(node.get("name", node.get("nodeId", "节点"))),
			"desc": _node_description(node, context),
			"kind": RouteRulesScript.option_kind(node_type),
			"nodeType": node_type,
			"schedule": schedule.duplicate(true),
			"sourceNode": node.duplicate(true),
		})
	return options


func _battle_options(schedule: Dictionary, context: Dictionary) -> Array:
	var schedule_day := int(schedule.get("day", context.get("day", 1)))
	var candidates := _formal_encounters(String(schedule.get("encounterPoolId", "")), schedule_day, context)
	var count: int = min(candidates.size(), max(1, int(schedule.get("choiceCount", 3))))
	var picked := _weighted_unique(candidates, count, ["encounterId"], _route_seed(schedule, "encounter", context))
	var options: Array = []
	for index in range(picked.size()):
		options.append(_battle_option(Dictionary(picked[index]), schedule, index + 1, context))
	return options


func _formal_encounters(pool_id: String, schedule_day: int, context: Dictionary) -> Array:
	var candidates: Array = []
	if pool_id == "":
		return candidates
	for item in Array(Dictionary(context.get("routeData", {})).get("encounters", [])):
		if not item is Dictionary:
			continue
		var encounter := Dictionary(item)
		if String(encounter.get("encounterPoolId", "")) == pool_id and int(encounter.get("unlockDay", 1)) <= schedule_day and _is_formal(encounter):
			candidates.append(encounter)
	return candidates


func _encounter_for_schedule(schedule: Dictionary, context: Dictionary) -> Dictionary:
	var encounter_id := String(schedule.get("encounterId", ""))
	for item in Array(Dictionary(context.get("routeData", {})).get("encounters", [])):
		if item is Dictionary and String(Dictionary(item).get("encounterId", "")) == encounter_id:
			return Dictionary(item)
	return {
		"encounterId": encounter_id,
		"name": String(schedule.get("label", encounter_id)),
		"wavePeriod": "下午",
		"battleIndex": 1,
		"phaseLabel": String(schedule.get("phaseLabel", "固定战")),
		"status": "正式",
	}


func _battle_option(encounter: Dictionary, schedule: Dictionary, index: int, context: Dictionary) -> Dictionary:
	var encounter_id := String(encounter.get("encounterId", schedule.get("encounterId", "")))
	var phase_label := String(encounter.get("phaseLabel", schedule.get("phaseLabel", "战斗")))
	var wave_period := String(encounter.get("wavePeriod", "上午"))
	var schedule_step := int(schedule.get("step", context.get("nodeIndex", 1)))
	return {
		"id": encounter_id if encounter_id != "" else String(schedule.get("id", "battle")),
		"optionId": "enc_%d_%d_%s" % [schedule_step, index, encounter_id],
		"encounterId": encounter_id,
		"title": String(encounter.get("name", schedule.get("label", "路线战斗"))),
		"desc": "%s：%s双人对战，进入 %s 棋盘战斗。" % [phase_label, wave_period, String(context.get("boardLabel", "8x8"))],
		"kind": "battle",
		"wavePeriod": wave_period,
		"schedule": schedule.duplicate(true),
		"encounter": encounter.duplicate(true),
	}


func _node_description(node: Dictionary, context: Dictionary) -> String:
	match String(node.get("nodeType", "event")):
		"shop":
			var slots := RouteRulesScript.normalized_shop_slots(
				int(node.get("slots", 0)),
				int(context.get("maxShopOffers", 10))
			)
			return "商店池 %s，货架 %d 格。" % [String(node.get("shopPoolId", "night_base")), slots]
		"reward":
			return "奖励池 %s，生成 %d 个候选。" % [String(node.get("rewardPoolId", "reward_pT1")), int(node.get("slots", 3))]
		"rest":
			return "休整补给，恢复并获得金币。"
	var note := String(node.get("note", ""))
	return note if note != "" else "路线事件，选择后立即结算。"


func _weighted_unique(items: Array, count: int, id_keys: Array, seed: String) -> Array:
	return SeededSelectorScript.weighted_unique(
		items,
		count,
		id_keys,
		seed,
		func(row): return int(Dictionary(row).get("weight", 1))
	)


func _route_seed(schedule: Dictionary, kind: String, context: Dictionary) -> String:
	var pool_id := String(schedule.get("poolId", schedule.get("encounterPoolId", "pool")))
	return "route:%s:%s:%d:%d:%s" % [
		kind,
		String(context.get("runSeed", "ysbzs-local")),
		int(schedule.get("day", context.get("day", 1))),
		int(schedule.get("step", context.get("nodeIndex", 1))),
		pool_id,
	]


func _is_formal(row: Dictionary) -> bool:
	return String(row.get("status", "")).strip_edges() == "正式"
