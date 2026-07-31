extends "res://session/game_session.gd"
class_name MockGameSession

## Offline replay of public snapshots captured from the production
## LocalGameSession. This project does not calculate combat outcomes.

signal snapshot_changed(snapshot: Dictionary, event: Dictionary)

const CAPTURE_PATH := "res://data/mock_battle_snapshot.json"
const DAMAGE_PREVIEW_TEMPLATES_KEY := "mock_damage_preview_templates_by_actor"
const INCOMING_DAMAGE_PREVIEW_TEMPLATE_KEY := "mock_incoming_damage_preview_template"

var _capture_source: Dictionary = {}
var _presentation_bootstrap_snapshot: Dictionary = {}
var _snapshot: Dictionary = {}
var _steps: Array = []
var _step_index := 0


func _init(_options: Dictionary = {}) -> void:
	reset(false)
	_publish_initial_snapshot_after_ui_ready()


func get_authority() -> RefCounted:
	return null


func connect_session() -> bool:
	return not _snapshot.is_empty()


func is_session_connected() -> bool:
	return not _snapshot.is_empty()


func current_snapshot() -> Dictionary:
	if _snapshot.is_empty():
		reset(false)
	return _snapshot.duplicate(true)


func capture_source() -> Dictionary:
	return _capture_source.duplicate(true)


func presentation_bootstrap_snapshot() -> Dictionary:
	return _presentation_bootstrap_snapshot.duplicate(true)


func replay_step_count() -> int:
	return _steps.size()


func replay_step_index() -> int:
	return _step_index


func submit_command(command: Dictionary) -> Dictionary:
	var requested_type := String(command.get("type", "")).strip_edges().to_upper()
	var command_type := _canonical_command_type(requested_type)
	if command_type == "RESET_MOCK":
		reset(false)
		return _accepted_projection(
			command,
			command_type,
			{"type": "RESET_MOCK", "ok": true, "message": "已回到正式运行数据起点"}
		)
	if command_type in ["GET_CELL_DETAIL", "SELECT_UNIT"]:
		return _accepted_projection(
			command,
			command_type,
			_projection_result(command_type, command)
		)
	if command_type == "SET_ACTION_DIRECTION":
		return _project_action_direction(command)
	return _replay_captured_command(command, command_type)


func submit_command_and_wait(command: Dictionary) -> Dictionary:
	return submit_command(command)


func persistence_slot_count() -> int:
	# Preserve the production RunTools geometry without enabling persistence.
	# The standalone Mock still cannot read or write formal-project saves.
	return 3


func reset(emit_change: bool = true) -> void:
	var file := FileAccess.open(CAPTURE_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open production battle capture: %s" % CAPTURE_PATH)
		_snapshot = {}
		_steps = []
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Production battle capture is not a JSON object: %s" % CAPTURE_PATH)
		_snapshot = {}
		_steps = []
		return
	var capture := Dictionary(parsed)
	if int(capture.get("capture_schema_version", 0)) != 1:
		push_error("Unsupported production battle capture schema")
		_snapshot = {}
		_steps = []
		return
	_capture_source = Dictionary(capture.get("source", {})).duplicate(true)
	_presentation_bootstrap_snapshot = Dictionary(
		capture.get("presentation_bootstrap_snapshot", {})
	).duplicate(true)
	_snapshot = Dictionary(capture.get("initial_snapshot", {})).duplicate(true)
	_steps = Array(capture.get("steps", [])).duplicate(true)
	_snapshot[DAMAGE_PREVIEW_TEMPLATES_KEY] = _collect_damage_preview_templates(capture)
	_snapshot[INCOMING_DAMAGE_PREVIEW_TEMPLATE_KEY] = \
		_collect_incoming_damage_preview_template(capture)
	_step_index = 0
	if emit_change:
		_emit_snapshot(
			{"type": "RESET_MOCK", "ok": true, "message": "已重新载入正式运行数据"},
			"reset"
		)


func _publish_initial_snapshot_after_ui_ready() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	_emit_snapshot(
		{"type": "CAPTURE_READY", "ok": true, "message": "正式战斗运行数据已就绪"},
		"capture_ready"
	)


func _canonical_command_type(command_type: String) -> String:
	match command_type:
		"AUTO_POSITION":
			return "AUTO_POSITION_HEROES"
		"RUN_PLAYER_ALL_OUT", "END_PLAYER_TURN", "RUN_MONSTER_TURN", "RUN_BATTLE":
			return "RUN_COMBAT_ROUND"
	return command_type


func _replay_captured_command(command: Dictionary, command_type: String) -> Dictionary:
	if _step_index >= _steps.size():
		return _rejected_response(
			command,
			command_type,
			"CAPTURE_FINISHED",
			"正式项目的双按钮循环数据已经回放完毕"
		)
	var record := Dictionary(_steps[_step_index])
	var expected_command := String(Dictionary(record.get("command", {})).get("type", "")).to_upper()
	if command_type != expected_command:
		return _rejected_response(
			command,
			command_type,
			"CAPTURE_SEQUENCE_MISMATCH",
			"下一步正式运行数据要求先执行 %s" % expected_command
		)

	_apply_snapshot_delta(Dictionary(record.get("snapshot_delta", {})))
	var identity := Dictionary(record.get("snapshot_identity", {}))
	if int(_snapshot.get("stateVersion", -1)) != int(identity.get("stateVersion", -2)) \
			or String(_snapshot.get("stateHash", "")) != String(identity.get("stateHash", "")):
		return _rejected_response(
			command,
			command_type,
			"CAPTURE_IDENTITY_MISMATCH",
			"正式 Snapshot 增量校验失败"
		)
	_step_index += 1

	var response := Dictionary(record.get("response", {})).duplicate(true)
	response["command"] = command_type
	response["snapshot"] = current_snapshot()
	response["captureStep"] = _step_index
	command_completed.emit(command.duplicate(true), response.duplicate(true))
	command_settled.emit(response.duplicate(true))
	_emit_snapshot(
		Dictionary(response.get("result", {})),
		"formal_capture_replay",
		command_type
	)
	return response


func _apply_snapshot_delta(delta: Dictionary) -> void:
	for key_value in Array(delta.get("remove", [])):
		_snapshot.erase(String(key_value))
	for key_value in Dictionary(delta.get("set", {})).keys():
		var key := String(key_value)
		_snapshot[key] = Dictionary(delta.get("set", {}))[key_value]
	_snapshot = _snapshot.duplicate(true)


func _accepted_projection(
	command: Dictionary,
	command_type: String,
	result: Dictionary
) -> Dictionary:
	var response := {
		"accepted": true,
		"pending": false,
		"status": "completed",
		"ok": true,
		"command": command_type,
		"result": result.duplicate(true),
		"snapshot": current_snapshot(),
		"stateVersion": int(_snapshot.get("stateVersion", -1)),
		"stateHash": String(_snapshot.get("stateHash", "")),
	}
	command_completed.emit(command.duplicate(true), response.duplicate(true))
	command_settled.emit(response.duplicate(true))
	snapshot_received.emit(current_snapshot(), {
		"asynchronous": false,
		"source": "formal_snapshot_projection",
		"command": command_type,
	})
	snapshot_changed.emit(current_snapshot(), result.duplicate(true))
	return response


func _project_action_direction(command: Dictionary) -> Dictionary:
	var unit_id := String(command.get("unitId", command.get("unit_id", "")))
	var slot_index := int(command.get("slotId", command.get("slot_id", -1)))
	var direction := String(command.get("dir", command.get("direction", ""))).to_lower()
	if _unit_by_id(unit_id).is_empty() or slot_index < 0 or slot_index >= 3 \
			or direction not in ["up", "right", "down", "left"]:
		return _rejected_response(
			command,
			"SET_ACTION_DIRECTION",
			"INVALID_DIRECTION_PREVIEW",
			"攻击方向预览参数无效"
		)
	var action_dirs := Dictionary(_snapshot.get("action_dirs", _snapshot.get("actionDirs", {}))).duplicate(true)
	action_dirs["%s:slot%d" % [unit_id, slot_index]] = direction
	_snapshot["action_dirs"] = action_dirs
	return _accepted_projection(command, "SET_ACTION_DIRECTION", {
		"type": "SET_ACTION_DIRECTION",
		"ok": true,
		"unitId": unit_id,
		"slotId": slot_index,
		"dir": direction,
		"previewOnly": true,
	})


func _collect_damage_preview_templates(capture: Dictionary) -> Dictionary:
	var templates := {}
	_collect_damage_preview_templates_from_snapshot(
		Dictionary(capture.get("initial_snapshot", {})),
		templates
	)
	for step_value in Array(capture.get("steps", [])):
		var step := Dictionary(step_value)
		var snapshot_set := Dictionary(Dictionary(step.get("snapshot_delta", {})).get("set", {}))
		_collect_damage_preview_templates_from_snapshot(snapshot_set, templates)
	return templates


func _collect_damage_preview_templates_from_snapshot(
	snapshot: Dictionary,
	templates: Dictionary
) -> void:
	var board := Dictionary(snapshot.get("board", {}))
	for cell_value in Array(board.get("cells", [])):
		var cell := Dictionary(cell_value)
		var candidates: Array = []
		for key in ["action_preview_data", "actionPreviewData", "preview"]:
			var candidate = cell.get(key, null)
			if candidate is Dictionary and not Dictionary(candidate).is_empty():
				candidates.append(candidate)
		for preview_value in Array(cell.get("previews", [])):
			if preview_value is Dictionary:
				candidates.append(preview_value)
		for candidate in candidates:
			var preview := Dictionary(candidate)
			if not bool(preview.get("hitEnemy", preview.get("hit_enemy", false))):
				continue
			var actor_id := String(preview.get(
				"actorId",
				preview.get("actor_id", preview.get("unitId", preview.get("unit_id", "")))
			))
			var damage := int(preview.get("predictedDamage", preview.get("predicted_damage", 0)))
			if actor_id == "" or damage <= 0:
				continue
			var existing := Dictionary(templates.get(actor_id, {}))
			var existing_damage := int(existing.get(
				"predictedDamage",
				existing.get("predicted_damage", -1)
			))
			if existing.is_empty() or damage > existing_damage:
				templates[actor_id] = preview.duplicate(true)


func _collect_incoming_damage_preview_template(capture: Dictionary) -> Dictionary:
	var friendly_unit_ids := {}
	var snapshots: Array[Dictionary] = [Dictionary(capture.get("initial_snapshot", {}))]
	for step_value in Array(capture.get("steps", [])):
		var step := Dictionary(step_value)
		snapshots.append(Dictionary(Dictionary(step.get("snapshot_delta", {})).get("set", {})))
	for snapshot in snapshots:
		var board := Dictionary(snapshot.get("board", {}))
		for cell_value in Array(board.get("cells", [])):
			var cell := Dictionary(cell_value)
			var side := String(cell.get("side", cell.get("unitSide", ""))).to_lower()
			var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
			if unit_id != "" and side in ["player", "ally"]:
				friendly_unit_ids[unit_id] = true
	var best_preview := {}
	var best_damage := -1
	for snapshot in snapshots:
		var damage_by_unit := Dictionary(snapshot.get(
			"placement_damage_by_unit",
			snapshot.get("placementDamageByUnit", {})
		))
		for unit_id_value in damage_by_unit.keys():
			var unit_id := String(unit_id_value)
			if not friendly_unit_ids.has(unit_id):
				continue
			var preview := Dictionary(damage_by_unit[unit_id_value])
			var damage := int(preview.get(
				"totalDamage",
				preview.get("damage", preview.get("threat", 0))
			))
			if damage > best_damage:
				best_damage = damage
				best_preview = preview.duplicate(true)
	return best_preview


func _rejected_response(
	command: Dictionary,
	command_type: String,
	code: String,
	message: String
) -> Dictionary:
	var response := {
		"accepted": false,
		"pending": false,
		"status": "rejected",
		"ok": false,
		"command": command_type,
		"error": {"code": code, "message": message},
		"snapshot": current_snapshot(),
		"stateVersion": int(_snapshot.get("stateVersion", -1)),
		"stateHash": String(_snapshot.get("stateHash", "")),
	}
	command_rejected.emit(command.duplicate(true), response.duplicate(true))
	command_settled.emit(response.duplicate(true))
	return response


func _projection_result(command_type: String, command: Dictionary) -> Dictionary:
	if command_type == "SELECT_UNIT":
		var unit_id := String(command.get("unit_id", command.get("unitId", "")))
		var unit := _unit_by_id(unit_id)
		return {
			"type": "SELECT_UNIT",
			"ok": not unit.is_empty(),
			"unit_id": unit_id,
			"unit": unit,
		}
	var cell_arg := Dictionary(command.get("cell", {}))
	var x := int(command.get("x", command.get("c", cell_arg.get("x", cell_arg.get("c", -1)))))
	var y := int(command.get("y", command.get("r", cell_arg.get("y", cell_arg.get("r", -1)))))
	var cell := _board_cell(x, y)
	return {
		"type": "GET_CELL_DETAIL",
		"ok": not cell.is_empty(),
		"x": x,
		"y": y,
		"c": x,
		"r": y,
		"elements": Dictionary(cell.get("elements", {})).duplicate(true),
		"unit": _unit_by_id(String(cell.get("unitId", cell.get("unit_id", "")))),
	}


func _board_cell(x: int, y: int) -> Dictionary:
	var board := Dictionary(_snapshot.get("board", {}))
	for value in Array(board.get("cells", [])):
		var cell := Dictionary(value)
		if int(cell.get("x", cell.get("c", -1))) == x \
				and int(cell.get("y", cell.get("r", -1))) == y:
			return cell.duplicate(true)
	return {}


func _unit_by_id(unit_id: String) -> Dictionary:
	if unit_id == "":
		return {}
	for value in Array(_snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", unit.get("unitId", ""))) == unit_id:
			return unit.duplicate(true)
	return {}


func _emit_snapshot(
	event: Dictionary,
	source: String,
	command_type: String = ""
) -> void:
	var snapshot := current_snapshot()
	var metadata := {
		"asynchronous": false,
		"source": source,
		"command": command_type,
		"captureStep": _step_index,
	}
	snapshot_received.emit(snapshot, metadata)
	snapshot_changed.emit(snapshot, event.duplicate(true))
