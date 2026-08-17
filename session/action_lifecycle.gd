extends RefCounted

## Thin orchestration state for submitted commands and choice pauses. It keeps
## command intent and lifecycle metadata only; authoritative gameplay data stays
## in YsbzsState and its immutable Snapshots.

signal changed(action: Dictionary)

const QUEUED := &"queued"
const AWAITING_CHOICE := &"awaiting_choice"
const EXECUTING := &"executing"
const CANCELLED := &"cancelled"
const COMPLETED := &"completed"
const REJECTED := &"rejected"

const TERMINAL_STATES := [CANCELLED, COMPLETED, REJECTED]
const ALLOWED_TRANSITIONS := {
	QUEUED: [AWAITING_CHOICE, EXECUTING, CANCELLED, REJECTED],
	AWAITING_CHOICE: [EXECUTING, CANCELLED, REJECTED],
	EXECUTING: [AWAITING_CHOICE, CANCELLED, COMPLETED, REJECTED],
}

var _actions: Dictionary = {}
var _order: Array[String] = []
var _sequence := 0


func queue(command: Dictionary, preferred_id: String = "") -> Dictionary:
	var action_id := preferred_id.strip_edges()
	if action_id == "":
		_sequence += 1
		action_id = "action-%06d" % _sequence
	if _actions.has(action_id):
		return snapshot(action_id)
	var action := {
		"id": action_id,
		"command": command.duplicate(true),
		"commandType": String(command.get("type", "")),
		"state": String(QUEUED),
		"previousState": "",
		"choiceRequest": {},
		"choice": {},
		"result": {},
		"reason": "",
		"revision": 1,
	}
	_actions[action_id] = action
	_order.append(action_id)
	changed.emit(action.duplicate(true))
	return action.duplicate(true)


func start(action_id: String) -> bool:
	return _transition(action_id, EXECUTING)


func await_choice(action_id: String, request: Dictionary = {}) -> bool:
	return _transition(action_id, AWAITING_CHOICE, {"choiceRequest": request.duplicate(true)})


func resume(action_id: String, choice: Dictionary = {}) -> bool:
	return _transition(action_id, EXECUTING, {"choice": choice.duplicate(true)})


func cancel(action_id: String, reason: String = "") -> bool:
	return _transition(action_id, CANCELLED, {"reason": reason})


func complete(action_id: String, response: Dictionary = {}) -> bool:
	return _transition(action_id, COMPLETED, {"result": _response_metadata(response)})


func reject(action_id: String, response: Dictionary = {}) -> bool:
	var error := Dictionary(response.get("error", {}))
	return _transition(action_id, REJECTED, {
		"result": _response_metadata(response),
		"reason": String(error.get("message", error.get("code", "rejected"))),
	})


func snapshot(action_id: String) -> Dictionary:
	return Dictionary(_actions.get(action_id, {})).duplicate(true)


func recent(limit: int = 20) -> Array:
	var out: Array = []
	var first: int = max(0, _order.size() - max(0, limit))
	for index in range(first, _order.size()):
		out.append(snapshot(_order[index]))
	return out


func active_count() -> int:
	var count := 0
	for action_id in _order:
		if not TERMINAL_STATES.has(StringName(String(snapshot(action_id).get("state", "")))):
			count += 1
	return count


func _transition(action_id: String, next_state: StringName, metadata: Dictionary = {}) -> bool:
	if not _actions.has(action_id):
		return false
	var action := Dictionary(_actions[action_id]).duplicate(true)
	var current := StringName(String(action.get("state", "")))
	if current == next_state:
		return true
	if not Array(ALLOWED_TRANSITIONS.get(current, [])).has(next_state):
		return false
	action["previousState"] = String(current)
	action["state"] = String(next_state)
	action["revision"] = int(action.get("revision", 0)) + 1
	for key in metadata.keys():
		action[key] = metadata[key]
	_actions[action_id] = action
	changed.emit(action.duplicate(true))
	return true


func _response_metadata(response: Dictionary) -> Dictionary:
	var result := {
		"accepted": bool(response.get("accepted", false)),
		"status": String(response.get("status", "")),
		"command": String(response.get("command", "")),
		"commandId": String(response.get("commandId", "")),
		"stateVersion": int(response.get("stateVersion", -1)),
		"stateHash": String(response.get("stateHash", "")),
	}
	var error := Dictionary(response.get("error", {}))
	if not error.is_empty():
		result["error"] = error.duplicate(true)
	return result
