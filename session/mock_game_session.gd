extends "res://session/game_session.gd"
class_name MockGameSession

## Offline replay of public snapshots captured from the production
## LocalGameSession. This project does not calculate combat outcomes.

signal snapshot_changed(snapshot: Dictionary, event: Dictionary)

const CAPTURE_PATH := "res://data/mock_battle_snapshot.json"

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
	if command_type == "SELECT_CELL":
		var selection := _projection_result(command_type, command)
		if bool(selection.get("ok", false)):
			return _accepted_projection(command, command_type, selection)
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
	_ensure_action_block_ranges_projection()
	_steps = Array(capture.get("steps", [])).duplicate(true)
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
	_ensure_action_block_ranges_projection()


func _ensure_action_block_ranges_projection() -> void:
	var previews := Dictionary(_snapshot.get("action_preview_by_unit", {}))
	var ranges_by_unit := {}
	for unit_id_value in previews.keys():
		var unit_id := String(unit_id_value)
		var preview := Dictionary(previews[unit_id_value])
		var ranges: Array[Dictionary] = []
		for slot_index in range(3):
			ranges.append({
				"slotIndex": slot_index,
				"origin": Dictionary(preview.get("origin", {})).duplicate(true),
				"direction": String(preview.get("direction", "")),
				"available": bool(preview.get("available", true)),
				"cells": Array(preview.get("cells", [])).duplicate(true),
			})
		ranges_by_unit[unit_id] = ranges
	_snapshot["action_block_ranges_by_unit"] = ranges_by_unit


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
	var unit := _unit_by_id(String(cell.get("unitId", cell.get("unit_id", ""))))
	if command_type == "SELECT_CELL":
		var side := String(unit.get("side", cell.get("side", "")))
		var selected_unit_id := ""
		if side in ["player", "hero", "hero_leader"]:
			selected_unit_id = String(unit.get("id", unit.get("unitId", "")))
		if selected_unit_id == "":
			return {
				"type": "SELECT_CELL",
				"ok": false,
				"x": x,
				"y": y,
				"unit_id": "",
				"unit": unit,
			}
		_snapshot["selected_unit_id"] = selected_unit_id
		if _snapshot.has("selectedUnitId"):
			_snapshot["selectedUnitId"] = selected_unit_id
		_snapshot["selected"] = {
			"unitId": selected_unit_id,
			"x": x,
			"y": y,
		}
		return {
			"type": "SELECT_CELL",
			"ok": selected_unit_id != "",
			"x": x,
			"y": y,
			"unit_id": selected_unit_id,
			"unit": unit,
		}
	return {
		"type": "GET_CELL_DETAIL",
		"ok": not cell.is_empty(),
		"x": x,
		"y": y,
		"c": x,
		"r": y,
		"elements": Dictionary(cell.get("elements", {})).duplicate(true),
		"unit": unit,
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
