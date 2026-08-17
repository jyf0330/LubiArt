extends RefCounted

const SessionProtocol := preload("res://session/session_protocol.gd")

## Server-side session boundary. It is the only network-facing object allowed
## to invoke the existing authoritative core.

const DEFAULT_RESPONSE_CACHE_LIMIT := 1024

var _authority: RefCounted = null
var _allowed_actors: Dictionary = {}
var _responses_by_command_id: Dictionary = {}
var _fingerprints_by_command_id: Dictionary = {}
var _response_order: Array[String] = []
var _last_client_tick_by_actor: Dictionary = {}
var _authorization_policy: Callable = Callable()
var _server_tick := 0
var _response_cache_limit := DEFAULT_RESPONSE_CACHE_LIMIT


func _init(authority: RefCounted = null) -> void:
	_authority = authority


func bind_authority(authority: RefCounted) -> void:
	_authority = authority
	clear_idempotency_cache()
	_last_client_tick_by_actor.clear()


func register_actor(actor_id: String, permissions: Dictionary = {}) -> bool:
	if actor_id.is_empty():
		return false
	_allowed_actors[actor_id] = permissions.duplicate(true)
	return true


func unregister_actor(actor_id: String) -> void:
	_allowed_actors.erase(actor_id)
	_last_client_tick_by_actor.erase(actor_id)


func is_actor_registered(actor_id: String) -> bool:
	return _allowed_actors.has(actor_id)


func set_response_cache_limit(limit: int) -> void:
	_response_cache_limit = maxi(limit, 1)
	_trim_response_cache()


func set_authorization_policy(policy: Callable) -> void:
	_authorization_policy = policy


func clear_idempotency_cache() -> void:
	_responses_by_command_id.clear()
	_fingerprints_by_command_id.clear()
	_response_order.clear()


func handle_command(request: Dictionary) -> Dictionary:
	var before_snapshot := _current_snapshot()
	var protocol_error := SessionProtocol.validate_command_request(request)
	if not protocol_error.is_empty():
		return _rejected_response(request, protocol_error, before_snapshot)

	var actor_id := String(request.get("actorId", ""))
	if not is_actor_registered(actor_id):
		return _rejected_response(request, {
			"code": "ACTOR_NOT_AUTHORIZED",
			"message": "Actor is not registered for this authoritative session."
		}, before_snapshot)

	if _authority == null or not _authority.has_method("run_command"):
		return _rejected_response(request, {
			"code": "AUTHORITY_NOT_READY",
			"message": "Authoritative game core is not ready."
		}, before_snapshot)

	var core_command := SessionProtocol.core_command(request)
	var authorization_error := _command_authorization_error(actor_id, core_command, before_snapshot)
	if not authorization_error.is_empty():
		return _rejected_response(request, authorization_error, before_snapshot)

	var command_id := String(request.get("commandId", ""))
	var fingerprint := SessionProtocol.command_fingerprint(request)
	if _responses_by_command_id.has(command_id):
		if String(_fingerprints_by_command_id.get(command_id, "")) != fingerprint:
			return _rejected_response(request, {
				"code": "COMMAND_ID_COLLISION",
				"message": "Command ID was already used with a different payload."
			}, before_snapshot)
		var duplicate_response := Dictionary(_responses_by_command_id[command_id]).duplicate(true)
		duplicate_response["duplicate"] = true
		return duplicate_response

	var client_tick := int(request.get("clientTick", -1))
	var last_client_tick := int(_last_client_tick_by_actor.get(actor_id, -1))
	if client_tick <= last_client_tick:
		return _rejected_response(request, {
			"code": "CLIENT_TICK_REPLAYED",
			"message": "Client tick must advance for each new command."
		}, before_snapshot)
	var baseline_metadata_error := SessionProtocol.validate_command_baseline_metadata(request)
	if not baseline_metadata_error.is_empty():
		return _rejected_response(request, baseline_metadata_error, before_snapshot)
	var baseline_error := SessionProtocol.validate_authoritative_baseline(request, before_snapshot)
	if not baseline_error.is_empty():
		return _rejected_response(request, baseline_error, before_snapshot)

	_server_tick += 1
	_last_client_tick_by_actor[actor_id] = client_tick
	var response := Dictionary(_authority.call("run_command", core_command))
	response["protocolVersion"] = SessionProtocol.PROTOCOL_VERSION
	response["commandId"] = command_id
	response["actorId"] = actor_id
	response["clientTick"] = int(request.get("clientTick", 0))
	response["serverTick"] = _server_tick
	response["duplicate"] = false
	if not response.has("snapshot"):
		response["snapshot"] = _current_snapshot()
	_cache_response(command_id, fingerprint, response)
	return response.duplicate(true)


func handle_snapshot_request(actor_id: String) -> Dictionary:
	var snapshot := _current_snapshot()
	if not is_actor_registered(actor_id):
		return _rejected_response({"actorId": actor_id}, {
			"code": "ACTOR_NOT_AUTHORIZED",
			"message": "Actor is not registered for this authoritative session."
		}, snapshot)
	return {
		"accepted": true,
		"protocolVersion": SessionProtocol.PROTOCOL_VERSION,
		"actorId": actor_id,
		"serverTick": _server_tick,
		"fullSnapshot": true,
		"snapshot": snapshot
	}


func _current_snapshot() -> Dictionary:
	if _authority == null or not _authority.has_method("snapshot"):
		return {}
	return Dictionary(_authority.call("snapshot"))


func _command_authorization_error(actor_id: String, command: Dictionary, snapshot: Dictionary) -> Dictionary:
	var permissions := Dictionary(_allowed_actors.get(actor_id, {}))
	var declared_scope := String(permissions.get("scope", permissions.get("role", "player")))
	var scope := "developer" if declared_scope == "developer" else "player"
	var intent_error := SessionProtocol.validate_request_intent(command, scope)
	if not intent_error.is_empty():
		return intent_error
	if not _authorization_policy.is_valid():
		return {}
	var decision: Variant = _authorization_policy.call(
		actor_id,
		command.duplicate(true),
		snapshot.duplicate(true),
		permissions.duplicate(true)
	)
	if typeof(decision) == TYPE_BOOL:
		if bool(decision):
			return {}
		return {"code": "COMMAND_NOT_AUTHORIZED", "message": "Actor cannot execute this command."}
	if typeof(decision) == TYPE_DICTIONARY:
		var result := Dictionary(decision)
		if bool(result.get("allowed", false)):
			return {}
		return Dictionary(result.get("error", {
			"code": "COMMAND_NOT_AUTHORIZED",
			"message": "Actor cannot execute this command."
		}))
	return {"code": "AUTHORIZATION_POLICY_INVALID", "message": "Authorization policy returned an invalid decision."}


func _rejected_response(request: Dictionary, error: Dictionary, snapshot: Dictionary) -> Dictionary:
	return {
		"accepted": false,
		"protocolVersion": SessionProtocol.PROTOCOL_VERSION,
		"command": String(request.get("type", "")),
		"commandId": String(request.get("commandId", "")),
		"actorId": String(request.get("actorId", "")),
		"clientTick": int(request.get("clientTick", -1)),
		"serverTick": _server_tick,
		"duplicate": false,
		"error": error.duplicate(true),
		"snapshot": snapshot.duplicate(true)
	}


func _cache_response(command_id: String, fingerprint: String, response: Dictionary) -> void:
	_responses_by_command_id[command_id] = response.duplicate(true)
	_fingerprints_by_command_id[command_id] = fingerprint
	_response_order.append(command_id)
	_trim_response_cache()


func _trim_response_cache() -> void:
	while _response_order.size() > _response_cache_limit:
		var expired_id: String = _response_order.pop_front()
		_responses_by_command_id.erase(expired_id)
		_fingerprints_by_command_id.erase(expired_id)
