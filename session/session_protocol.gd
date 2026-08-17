extends RefCounted

## JSON-safe wire envelope shared by remote clients and authoritative hosts.

const ViewModelSchemaScript := preload("res://session/view_model_schema.gd")
const CommandContractScript := preload("res://core/commands/command_contract.gd")
const PROTOCOL_VERSION := 1


static func validate_command_intent(command: Dictionary, scope: String = "player") -> Dictionary:
	return CommandContractScript.validate_intent(command, scope)


static func make_authoritative_command(
	command: Dictionary,
	confirmed_snapshot: Dictionary,
	command_id: String
) -> Dictionary:
	var authoritative_command := command.duplicate(true)
	authoritative_command["type"] = CommandContractScript.normalize_action_type(String(command.get("type", "")))
	authoritative_command["commandId"] = command_id
	authoritative_command["baseStateVersion"] = int(confirmed_snapshot.get("stateVersion", 0))
	authoritative_command["baseStateHash"] = String(confirmed_snapshot.get("stateHash", ""))
	for alias_key in ["command_id", "base_state_version", "base_state_hash"]:
		authoritative_command.erase(alias_key)
	return authoritative_command


static func make_incremental_authoritative_command(
	command: Dictionary,
	confirmed_version: int,
	command_id: String
) -> Dictionary:
	var authoritative_command := command.duplicate(true)
	authoritative_command["type"] = CommandContractScript.normalize_action_type(String(command.get("type", "")))
	authoritative_command["commandId"] = command_id
	authoritative_command["baseStateVersion"] = confirmed_version
	# High-frequency local commands use optimistic concurrency by revision. The
	# full content hash remains mandatory for complete snapshots and wire requests.
	authoritative_command.erase("baseStateHash")
	for alias_key in ["command_id", "base_state_version", "base_state_hash"]:
		authoritative_command.erase(alias_key)
	return authoritative_command


static func make_command_request(
	command: Dictionary,
	confirmed_snapshot: Dictionary,
	actor_id: String,
	client_tick: int,
	session_id: String,
	sequence: int
) -> Dictionary:
	var command_id := "%s:%s:%d" % [session_id, actor_id, sequence]
	var request := make_authoritative_command(command, confirmed_snapshot, command_id)
	request["protocolVersion"] = PROTOCOL_VERSION
	request["actorId"] = actor_id
	request["clientTick"] = client_tick
	request["sessionId"] = session_id
	return request


static func validate_command_request(request: Dictionary) -> Dictionary:
	if int(request.get("protocolVersion", -1)) != PROTOCOL_VERSION:
		return _error("PROTOCOL_VERSION_UNSUPPORTED", "Unsupported session protocol version.")
	if String(request.get("type", "")).is_empty():
		return _error("COMMAND_TYPE_REQUIRED", "Command type is required.")
	if String(request.get("commandId", "")).is_empty():
		return _error("COMMAND_ID_REQUIRED", "Command ID is required.")
	if String(request.get("actorId", "")).is_empty():
		return _error("ACTOR_ID_REQUIRED", "Actor ID is required.")
	if String(request.get("sessionId", "")).is_empty():
		return _error("SESSION_ID_REQUIRED", "Session ID is required.")
	if int(request.get("clientTick", -1)) < 0:
		return _error("CLIENT_TICK_INVALID", "Client tick must be non-negative.")
	return {}


static func validate_command_baseline_metadata(request: Dictionary) -> Dictionary:
	if not request.has("baseStateVersion") or int(request.get("baseStateVersion", -1)) < 0:
		return _error("BASE_STATE_VERSION_REQUIRED", "Authoritative baseStateVersion is required.")
	if String(request.get("baseStateHash", "")).is_empty():
		return _error("BASE_STATE_HASH_REQUIRED", "Authoritative baseStateHash is required.")
	return {}


static func validate_authoritative_baseline(request: Dictionary, snapshot: Dictionary) -> Dictionary:
	return CommandContractScript.baseline_error(
		request,
		int(snapshot.get("stateVersion", -1)),
		String(snapshot.get("stateHash", ""))
	)


static func validate_request_intent(request: Dictionary, scope: String) -> Dictionary:
	return validate_command_intent(intent_command(request), scope)


static func validate_snapshot(snapshot: Dictionary) -> Dictionary:
	if not snapshot.has("stateVersion") or int(snapshot.get("stateVersion", -1)) < 0:
		return _error("SNAPSHOT_VERSION_INVALID", "Authoritative snapshot has no valid stateVersion.")
	if String(snapshot.get("stateHash", "")).is_empty():
		return _error("SNAPSHOT_HASH_REQUIRED", "Authoritative snapshot has no stateHash.")
	if snapshot.has("viewModel"):
		var view_model_error := ViewModelSchemaScript.validate(Dictionary(snapshot.get("viewModel", {})))
		if not view_model_error.is_empty():
			return view_model_error
	return {}


static func command_fingerprint(request: Dictionary) -> String:
	return JSON.stringify(_canonicalize(request))


static func core_command(request: Dictionary) -> Dictionary:
	var command := request.duplicate(true)
	for key in ["protocolVersion", "actorId", "clientTick", "sessionId"]:
		command.erase(key)
	return command


static func intent_command(request: Dictionary) -> Dictionary:
	var command := core_command(request)
	for key in ["commandId", "baseStateVersion", "baseStateHash"]:
		command.erase(key)
	return command


static func _canonicalize(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var array_out: Array = []
		for item in Array(value):
			array_out.append(_canonicalize(item))
		return array_out
	if typeof(value) == TYPE_DICTIONARY:
		var source := Dictionary(value)
		var keys: Array[String] = []
		for raw_key in source.keys():
			keys.append(String(raw_key))
		keys.sort()
		var dictionary_out: Dictionary = {}
		for key in keys:
			dictionary_out[key] = _canonicalize(source.get(key))
		return dictionary_out
	return value


static func _error(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message}
