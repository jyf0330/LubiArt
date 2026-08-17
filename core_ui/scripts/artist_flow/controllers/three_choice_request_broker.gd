extends RefCounted

## Pairs presentation requests with Game-owned responses. This object only owns
## correlation and cancellation; it never calls a Session or enriches commands.

signal command_requested(command: Dictionary, request_id: int)
signal session_operation_requested(operation: StringName, arguments: Dictionary, request_id: int)
signal command_response_received(request_id: int)
signal session_operation_response_received(request_id: int)

const CANCELLED_CODE := "PRESENTATION_REQUEST_CANCELLED"

var _request_sequence := 0
var _command_responses: Dictionary = {}
var _session_operation_responses: Dictionary = {}
var _disposed := false


func request_command(command: Dictionary) -> Dictionary:
	if _disposed:
		return _cancelled_result()
	var request_id := _next_request_id()
	command_requested.emit(command.duplicate(true), request_id)
	while not _disposed and not _command_responses.has(request_id):
		await command_response_received
	if _disposed:
		return _cancelled_result()
	# The producer hands off an immutable command response. Keeping the same
	# reference here avoids cloning the full public Snapshot twice per click.
	var response := Dictionary(_command_responses.get(request_id, {}))
	_command_responses.erase(request_id)
	return response


func request_session_operation(operation: StringName, arguments: Dictionary) -> Dictionary:
	if _disposed:
		return _cancelled_result()
	var request_id := _next_request_id()
	session_operation_requested.emit(operation, arguments.duplicate(true), request_id)
	while not _disposed and not _session_operation_responses.has(request_id):
		await session_operation_response_received
	if _disposed:
		return _cancelled_result()
	var response := Dictionary(_session_operation_responses.get(request_id, {}))
	_session_operation_responses.erase(request_id)
	return response


func complete_command(request_id: int, response: Dictionary) -> void:
	if _disposed or request_id < 0:
		return
	_command_responses[request_id] = response
	command_response_received.emit(request_id)


func complete_session_operation(request_id: int, result: Dictionary) -> void:
	if _disposed or request_id < 0:
		return
	_session_operation_responses[request_id] = result
	session_operation_response_received.emit(request_id)


func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	_command_responses.clear()
	_session_operation_responses.clear()
	command_response_received.emit(-1)
	session_operation_response_received.emit(-1)


func _next_request_id() -> int:
	_request_sequence += 1
	return _request_sequence


func _cancelled_result() -> Dictionary:
	return {
		"accepted": false,
		"cancelled": true,
		"error": {"code": CANCELLED_CODE},
	}
