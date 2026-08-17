extends RefCounted

const CommandContractScript := preload("res://core/commands/command_contract.gd")
const PreviewHorizonScript := preload("res://core/commands/preview_horizon.gd")

## Pure, detached projections for the human-readable player operation log.
## Callers provide values only; this service never reads authority, time, paths,
## files, or repositories.


func state_summary(context: Dictionary) -> Dictionary:
	var source := context.duplicate(true)
	var unit_rows: Array = []
	for unit_value in Array(source.get("units", [])):
		var unit := Dictionary(unit_value)
		unit_rows.append({
			"id": String(unit.get("id", "")),
			"name": String(unit.get("name", "")),
			"side": String(unit.get("side", "")),
			"x": int(unit.get("x", -1)),
			"y": int(unit.get("y", -1)),
			"hp": int(unit.get("hp", 0)),
			"shield": int(unit.get("shield", 0)),
			"ap": int(unit.get("ap", 0)),
			"active": bool(unit.get("active", true)),
		})
	var board_width := int(source.get("boardWidth", 0))
	var board_height := int(source.get("boardHeight", 0))
	return {
		"phase": String(source.get("phase", "")),
		"day": int(source.get("day", 0)),
		"nodeIndex": int(source.get("nodeIndex", 0)),
		"battleRound": int(source.get("battleRound", 0)),
		"battlePeriod": String(source.get("battlePeriod", "")),
		"difficulty": String(source.get("difficulty", "")),
		"boardWidth": board_width,
		"boardHeight": board_height,
		"boardLabel": "%dx%d" % [board_width, board_height],
		"stateVersion": int(source.get("stateVersion", 0)),
		"selectedUnitId": String(source.get("selectedUnitId", "")),
		"selectedActionSlotIndex": int(source.get("selectedActionSlotIndex", -1)),
		"ap": int(source.get("ap", 0)),
		"coins": int(source.get("coins", 0)),
		"heroHp": int(source.get("heroHp", 0)),
		"units": unit_rows,
	}


func event_summaries(events: Array, defaults: Dictionary) -> Array:
	var source_events := events.duplicate(true)
	var source_defaults := defaults.duplicate(true)
	var summaries: Array = []
	for event_value in source_events:
		var event := Dictionary(event_value)
		var actor := Dictionary(event.get("actor", {}))
		var target := Dictionary(event.get("target", {}))
		var payload := Dictionary(event.get("payload", {}))
		summaries.append({
			"eventId": String(event.get("eventId", "")),
			"type": String(event.get("type", event.get("kind", ""))),
			"round": int(event.get("round", source_defaults.get("round", 0))),
			"phase": String(event.get("phase", source_defaults.get("phase", ""))),
			"actorId": String(actor.get("id", "")),
			"actorName": String(actor.get("name", "")),
			"targetId": String(target.get("id", "")),
			"targetName": String(target.get("name", "")),
			"sourceType": String(payload.get("sourceType", "")),
			"causedById": String(payload.get("causedById", "")),
			"causedByName": String(payload.get("causedByName", "")),
			"from": _detached_variant(payload.get("from", {})),
			"to": _detached_variant(payload.get("to", {})),
			"finalDamage": int(payload.get("finalDamage", 0)),
			"shieldDamage": int(payload.get("shieldDamage", 0)),
			"hpDamage": int(payload.get("hpDamage", 0)),
			"hpFrom": int(payload.get("hpFrom", 0)),
			"hpTo": int(payload.get("hpTo", 0)),
			"shieldFrom": int(payload.get("shieldFrom", 0)),
			"shieldTo": int(payload.get("shieldTo", 0)),
			"text": String(event.get("text", "")),
		})
	return summaries


func result_summary(value: Variant) -> Variant:
	var safe_value: Variant = CommandContractScript.replay_json_safe(value)
	if typeof(safe_value) == TYPE_ARRAY and Array(safe_value).size() > 32:
		return {
			"itemCount": Array(safe_value).size(),
			"firstItems": Array(safe_value).slice(0, 32),
		}
	return safe_value


func preview_summary(snapshot: Dictionary, manual_flow_preview: Dictionary) -> Dictionary:
	var manual := manual_flow_preview.duplicate(true)
	if manual.is_empty():
		return {}
	return {
		"schema": PreviewHorizonScript.SUMMARY_SCHEMA,
		"immediateAction": _immediate_action_summary(snapshot),
		"manualRoundFlow": _manual_round_flow_summary(manual),
	}


func new_logs(before_logs: Array, after_logs: Array) -> Array:
	var before := before_logs.duplicate(true)
	var after := after_logs.duplicate(true)
	if after.is_empty():
		return []
	var max_overlap := mini(before.size(), after.size())
	var overlap := 0
	for candidate in range(max_overlap, -1, -1):
		var matches := true
		for index in range(candidate):
			if String(after[after.size() - candidate + index]) != String(before[index]):
				matches = false
				break
		if matches:
			overlap = candidate
			break
	var new_count := after.size() - overlap
	return after.slice(0, new_count)


func _detached_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return Dictionary(value).duplicate(true)
	if value is Array:
		return Array(value).duplicate(true)
	return value


func _immediate_action_summary(snapshot: Dictionary) -> Dictionary:
	var targets: Array = []
	var board := Dictionary(snapshot.get("board", {}))
	for cell_value in Array(board.get("cells", [])):
		if not cell_value is Dictionary:
			continue
		var cell := Dictionary(cell_value)
		var preview_value = cell.get("action_preview_data", cell.get("actionPreviewData", {}))
		if not preview_value is Dictionary or Dictionary(preview_value).is_empty():
			continue
		var preview := Dictionary(preview_value)
		if String(preview.get("previewHorizon", "")) != PreviewHorizonScript.IMMEDIATE_ACTION:
			continue
		targets.append({
			"previewHorizon": PreviewHorizonScript.IMMEDIATE_ACTION,
			"previewId": String(preview.get("previewId", "")),
			"actorId": String(preview.get("actorId", "")),
			"actorName": String(preview.get("actorName", "")),
			"targetId": String(preview.get("targetId", "")),
			"targetName": String(preview.get("targetName", "")),
			"x": int(cell.get("x", cell.get("c", -1))),
			"y": int(cell.get("y", cell.get("r", -1))),
			"predictedDamage": int(preview.get("predictedDamage", 0)),
			"predictedActionDamage": int(preview.get("predictedActionDamage", 0)),
			"predictedSettlementDamage": int(preview.get("predictedSettlementDamage", 0)),
			"predictedHpDamage": int(preview.get("predictedHpDamage", 0)),
			"predictedShieldDamage": int(preview.get("predictedShieldDamage", 0)),
			"predictedHpFrom": int(preview.get("predictedHpFrom", 0)),
			"predictedHpTo": int(preview.get("predictedHpTo", 0)),
			"predictedShieldFrom": int(preview.get("predictedShieldFrom", 0)),
			"predictedShieldTo": int(preview.get("predictedShieldTo", 0)),
			"predictedKill": bool(preview.get("predictedKill", false)),
		})
	return {
		"previewHorizon": PreviewHorizonScript.IMMEDIATE_ACTION,
		"targetCount": targets.size(),
		"targets": targets,
	}


func _manual_round_flow_summary(preview: Dictionary) -> Dictionary:
	var damage_by_unit := {}
	var source_damage := Dictionary(preview.get("damageByUnit", {}))
	var unit_ids := PackedStringArray(source_damage.keys())
	unit_ids.sort()
	for unit_id in unit_ids:
		var value = source_damage.get(String(unit_id), null)
		if not value is Dictionary:
			continue
		var damage := Dictionary(value)
		damage_by_unit[String(unit_id)] = {
			"previewHorizon": PreviewHorizonScript.MANUAL_ROUND_FLOW,
			"source": String(damage.get("source", "manual_flow_preview")),
			"unitId": String(damage.get("unitId", unit_id)),
			"totalDamage": int(damage.get("totalDamage", damage.get("damage", 0))),
			"rawDamage": int(damage.get("rawDamage", 0)),
			"hpDamage": int(damage.get("hpDamage", 0)),
			"shieldDamage": int(damage.get("shieldDamage", 0)),
			"hpFrom": int(damage.get("hpFrom", 0)),
			"hpTo": int(damage.get("hpTo", 0)),
			"shieldFrom": int(damage.get("shieldFrom", 0)),
			"shieldTo": int(damage.get("shieldTo", 0)),
			"lethal": bool(damage.get("lethal", false)),
			"hitCount": Array(damage.get("hits", [])).size(),
		}
	var commands: Array = []
	for command_value in Array(preview.get("commands", [])):
		if not command_value is Dictionary:
			continue
		var command := Dictionary(command_value)
		commands.append({
			"type": String(command.get("type", "")),
			"accepted": bool(command.get("accepted", command.get("ok", false))),
			"phase": String(command.get("phase", "")),
			"round": int(command.get("round", 0)),
		})
	var simulation := Dictionary(preview.get("simulation", {}))
	return {
		"previewHorizon": PreviewHorizonScript.MANUAL_ROUND_FLOW,
		"stateVersion": int(preview.get("stateVersion", 0)),
		"stateHash": String(preview.get("stateHash", "")),
		"projectedStateHash": String(preview.get("projectedStateHash", "")),
		"rolledBack": bool(preview.get("rolledBack", false)),
		"phaseBefore": String(preview.get("phaseBefore", "")),
		"phaseAfter": String(preview.get("phaseAfter", "")),
		"roundBefore": int(preview.get("roundBefore", 0)),
		"roundAfter": int(preview.get("roundAfter", 0)),
		"commands": commands,
		"damageByUnit": damage_by_unit,
		"simulation": {
			"schema": String(simulation.get("schema", "")),
			"isolated": bool(simulation.get("isolated", false)),
			"ioAttempts": int(simulation.get("ioAttempts", 0)),
		},
	}
