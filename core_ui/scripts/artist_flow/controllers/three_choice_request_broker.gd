extends RefCounted

## Pairs presentation requests with Game-owned responses. This object only owns
## correlation and cancellation; it never calls a Session or enriches commands.

signal command_requested(command: Dictionary, request_id: int)
signal command_response_received(request_id: int)

const CANCELLED_CODE := "PRESENTATION_REQUEST_CANCELLED"
const TIMEOUT_CODE := "PRESENTATION_REQUEST_TIMEOUT"
const COMMAND_WAIT_FRAME_LIMIT := 300

var _request_sequence := 0
var _command_responses: Dictionary = {}
var _pending_command_ids: Dictionary = {}
var _disposed := false


func request_command(command: Dictionary) -> Dictionary:
	if _disposed:
		return _cancelled_result()
	var request_id := _next_request_id()
	_pending_command_ids[request_id] = true
	command_requested.emit(command.duplicate(true), request_id)
	for _frame in range(COMMAND_WAIT_FRAME_LIMIT):
		if _disposed or _command_responses.has(request_id):
			break
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			break
		await tree.process_frame
	if _disposed:
		_pending_command_ids.erase(request_id)
		return _cancelled_result()
	if not _command_responses.has(request_id):
		_pending_command_ids.erase(request_id)
		return _timeout_result()
	var response := Dictionary(_command_responses.get(request_id, {})).duplicate(true)
	_command_responses.erase(request_id)
	_pending_command_ids.erase(request_id)
	return response


func complete_command(request_id: int, response: Dictionary) -> void:
	if _disposed or request_id < 0 or not _pending_command_ids.has(request_id):
		return
	_command_responses[request_id] = response.duplicate(true)
	command_response_received.emit(request_id)


func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	_command_responses.clear()
	_pending_command_ids.clear()
	command_response_received.emit(-1)


func _next_request_id() -> int:
	_request_sequence += 1
	return _request_sequence


func _cancelled_result() -> Dictionary:
	return {
		"accepted": false,
		"cancelled": true,
		"error": {"code": CANCELLED_CODE},
	}


func _timeout_result() -> Dictionary:
	return {
		"accepted": false,
		"timed_out": true,
		"error": {"code": TIMEOUT_CODE},
	}
