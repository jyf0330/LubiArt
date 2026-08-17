extends RefCounted

const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")
const SimulationIoGuardScript := preload("res://session/simulation_io_guard.gd")
const RESULT_SCHEMA := "ysbzs.simulation-fork-result.v1"
const CURRENT_ASSEMBLY := &"current_assembly"
const PERSISTED_SNAPSHOT := &"persisted_snapshot"


func create(authority_script: Script, content_pack: Dictionary, options: Dictionary = {}) -> Dictionary:
	var guard: RefCounted = SimulationIoGuardScript.new()
	if authority_script == null:
		return _result(false, null, guard, "", "", ["SIMULATION_CREATE_SCRIPT_INVALID"])
	var option_errors: Array[String] = []
	for key_value in options.keys():
		var key := String(key_value)
		if not ["seed", "boardDimensions", "contentSourceKind"].has(key):
			option_errors.append("SIMULATION_CREATE_OPTION_UNSUPPORTED:%s" % key)
	if options.has("seed") and typeof(options.get("seed")) != TYPE_STRING:
		option_errors.append("SIMULATION_CREATE_SEED_INVALID")
	if options.has("boardDimensions") and not (options.get("boardDimensions") is Vector2i):
		option_errors.append("SIMULATION_CREATE_BOARD_DIMENSIONS_INVALID")
	var source_kind := CURRENT_ASSEMBLY
	if not options.has("contentSourceKind"):
		option_errors.append("SIMULATION_CREATE_CONTENT_SOURCE_KIND_REQUIRED")
	else:
		var source_kind_value: Variant = options.get("contentSourceKind")
		if not [TYPE_STRING, TYPE_STRING_NAME].has(typeof(source_kind_value)):
			option_errors.append("SIMULATION_CREATE_CONTENT_SOURCE_KIND_INVALID")
		else:
			source_kind = StringName(String(source_kind_value))
			if not [CURRENT_ASSEMBLY, PERSISTED_SNAPSHOT].has(source_kind):
				option_errors.append("SIMULATION_CREATE_CONTENT_SOURCE_KIND_INVALID")
	if not option_errors.is_empty():
		option_errors.sort()
		return _result(false, null, guard, "", "", option_errors)
	var core_overrides := _guarded_overrides(guard)
	var authority_value: Variant = authority_script.new({
		"mode": "simulation",
		"content_pack": content_pack.duplicate(true),
		"content_source_kind": source_kind,
		"core_overrides": core_overrides,
	})
	if not (authority_value is RefCounted):
		return _result(false, null, guard, "", "", ["SIMULATION_CREATE_INIT_FAILED"])
	var authority := authority_value as RefCounted
	if not bool(authority.call("is_initialized")):
		var initialization := Dictionary(authority.call("initialization_result"))
		var errors: Array[String] = ["SIMULATION_CREATE_INIT_FAILED"]
		for value in Array(initialization.get("errors", [])):
			errors.append(String(value))
		return _result(false, null, guard, "", "", errors)
	if options.has("boardDimensions"):
		var dimensions := Vector2i(options.get("boardDimensions"))
		if not bool(authority.call("set_board_dimensions", dimensions.x, dimensions.y)):
			return _result(false, null, guard, "", "", ["SIMULATION_CREATE_BOARD_DIMENSIONS_INVALID"])
	if options.has("seed"):
		authority.call("set_run_seed", String(options.get("seed", "")))
	var state_hash := String(authority.call("_state_hash"))
	if not Array(guard.call("attempts")).is_empty():
		return _result(false, null, guard, "", state_hash, ["SIMULATION_CONSTRUCTION_IO_ATTEMPT"])
	return _result(true, authority, guard, "", state_hash, [])


func fork(source: Object, options: Dictionary = {}) -> Dictionary:
	if not _valid_source(source):
		var invalid_guard: RefCounted = SimulationIoGuardScript.new()
		return _result(false, null, invalid_guard, "", "", ["SIMULATION_SOURCE_INVALID"])
	if not options.is_empty():
		var invalid_guard: RefCounted = SimulationIoGuardScript.new()
		var errors: Array[String] = []
		for key_value in options.keys():
			errors.append("SIMULATION_FORK_OPTION_UNSUPPORTED:%s" % String(key_value))
		errors.sort()
		return _result(false, null, invalid_guard, "", "", errors)
	var source_hash := String(source.call("_state_hash"))
	var payload := AuthoritativeStateCodecScript.capture(source, false)
	var content_pack := Dictionary(source.get("game_data")).duplicate(true)
	var source_script: Script = source.get_script()
	var create_result := create(source_script, content_pack, {
		"contentSourceKind": StringName(source.call("content_source_kind")),
	})
	var guard := create_result.get("ioGuard") as RefCounted
	if not bool(create_result.get("ok", false)):
		var errors: Array[String] = []
		for value in Array(create_result.get("errors", [])):
			var error := String(value)
			errors.append("SIMULATION_FORK_INIT_FAILED" if error == "SIMULATION_CREATE_INIT_FAILED" else error)
		return _result(false, null, guard, source_hash, String(create_result.get("forkStateHash", "")), errors)
	var authority := create_result.get("authority") as RefCounted

	AuthoritativeStateCodecScript.restore(authority, payload)
	authority.set("history_recording_enabled", false)
	authority.set("_history_suspended", true)
	authority.set("history_run_id", "")
	authority.set("history_branch_id", "")
	authority.set("history_parent_run_id", "")
	authority.set("history_parent_checkpoint_id", "")
	authority.set("history_command_index", 0)
	authority.set("history_content_revision", 0)
	authority.set("history_content_path", "")
	var fork_hash := String(authority.call("_state_hash"))
	if fork_hash != source_hash:
		return _result(false, null, guard, source_hash, fork_hash, ["SIMULATION_FORK_HASH_MISMATCH"])
	if not Array(guard.call("attempts")).is_empty():
		return _result(false, null, guard, source_hash, fork_hash, ["SIMULATION_CONSTRUCTION_IO_ATTEMPT"])
	return _result(true, authority, guard, source_hash, fork_hash, [])


func _guarded_overrides(guard: RefCounted) -> Dictionary:
	return {
		"save_repository": guard,
		"replay_repository": guard,
		"run_history_repository": guard,
		"game_data_repository": guard,
		"operation_log_repository": guard,
	}


func _valid_source(source: Object) -> bool:
	if source == null:
		return false
	for method_name in [&"is_initialized", &"initialization_result", &"_state_hash", &"content_source_kind"]:
		if not source.has_method(method_name):
			return false
	if not bool(source.call("is_initialized")):
		return false
	if not _has_property(source, &"game_data"):
		return false
	var source_script: Script = source.get_script()
	return source_script != null


func _has_property(source: Object, property_name: StringName) -> bool:
	for property_value in source.get_property_list():
		if StringName(Dictionary(property_value).get("name", "")) == property_name:
			return true
	return false


func _result(ok: bool, authority: RefCounted, guard: RefCounted, source_hash: String, fork_hash: String, errors: Array) -> Dictionary:
	var copied_errors: Array[String] = []
	for value in errors:
		copied_errors.append(String(value))
	return {
		"schema": RESULT_SCHEMA,
		"ok": ok,
		"authority": authority,
		"ioGuard": guard,
		"sourceStateHash": source_hash,
		"forkStateHash": fork_hash,
		"errors": copied_errors,
	}
