extends RefCounted

const ReplayContractScript := preload("res://persistence/replay_contract.gd")
const DocumentCodecScript := preload("res://persistence/save_codec.gd")
const ReplayBuilderScript := preload("res://persistence/replay_builder.gd")
const BattleBoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")

## Deterministic replay verification against a fresh simulation authority.
## The verifier stores no authority and all external capabilities arrive through
## the supplied factory result and its I/O guard.


func verify(replay: Dictionary, context: Dictionary, factory: RefCounted) -> Dictionary:
	var replay_value := replay.duplicate(true)
	var context_value := context.duplicate(true)
	if String(replay_value.get("schema", "")) != ReplayContractScript.SCHEMA:
		return _result(false, "REPLAY_INVALID_SCHEMA", [], 0, "")
	if int(replay_value.get("schemaVersion", 0)) != ReplayContractScript.SCHEMA_VERSION:
		return _result(false, "REPLAY_UNSUPPORTED_SCHEMA_VERSION", [], 0, "")
	if String(replay_value.get("replayVersion", "")) != ReplayContractScript.COMMAND_VERSION:
		return _result(false, "REPLAY_UNSUPPORTED_VERSION", [], 0, "")
	var determinism := Dictionary(replay_value.get("determinism", {}))
	var replay_content_hash := String(determinism.get("contentHash", replay_value.get("dataVersion", "")))
	if replay_content_hash != "" and replay_content_hash != String(context_value.get("contentHash", "")):
		return _result(false, "REPLAY_CONTENT_VERSION_MISMATCH", [], 0, "")
	var replay_rules_version := String(determinism.get("rulesVersion", replay_value.get("rulesVersion", "")))
	if replay_rules_version != "" and replay_rules_version != String(context_value.get("rulesVersion", "")):
		return _result(false, "REPLAY_RULES_VERSION_MISMATCH", [], 0, "")
	var replay_rng_version := String(determinism.get("rngVersion", replay_value.get("rngVersion", "")))
	if replay_rng_version != "" and replay_rng_version != String(context_value.get("rngVersion", "")):
		return _result(false, "REPLAY_RNG_VERSION_MISMATCH", [], 0, "")
	var expected_checksum := String(replay_value.get("checksum", ""))
	if expected_checksum != "" and expected_checksum != DocumentCodecScript.replay_checksum(replay_value):
		return _result(false, "REPLAY_CHECKSUM_MISMATCH", [], 0, "")

	var initial := Dictionary(replay_value.get("initial", {}))
	var options := Dictionary(initial.get("options", {}))
	var dimensions := _board_dimensions(options, context_value)
	if not BattleBoardDimensionsScript.is_valid(dimensions.x, dimensions.y):
		return _result(false, "REPLAY_INVALID_BOARD_DIMENSIONS", [], 0, "")
	var seed := String(initial.get("seed", options.get("seed", replay_value.get("seed", ""))))
	var authority_script: Script = context_value.get("authorityScript") as Script
	var create_result: Dictionary = factory.call("create", authority_script, Dictionary(context_value.get("contentPack", {})).duplicate(true), {
		"seed": seed,
		"boardDimensions": dimensions,
		"contentSourceKind": context_value.get("contentSourceKind", &""),
	})
	var guard := create_result.get("ioGuard") as RefCounted
	if _has_io_attempts(guard):
		return _result(false, "REPLAY_VERIFICATION_IO_ATTEMPT", [], 0, "")
	if not bool(create_result.get("ok", false)):
		if Array(create_result.get("errors", [])).has("SIMULATION_CREATE_BOARD_DIMENSIONS_INVALID"):
			return _result(false, "REPLAY_INVALID_BOARD_DIMENSIONS", [], 0, "")
		return _result(false, "REPLAY_INITIAL_MISMATCH", [], 0, "")
	var authority := create_result.get("authority") as RefCounted
	if authority == null:
		return _result(false, "REPLAY_INITIAL_MISMATCH", [], 0, "")
	var initial_hash := String(create_result.get("forkStateHash", ""))
	var expected_initial_hash := String(initial.get("stateHash", ""))
	if expected_initial_hash != "" and expected_initial_hash != initial_hash:
		return _result(false, "REPLAY_INITIAL_MISMATCH", [], 0, initial_hash)

	var checkpoints: Array = []
	for item_value in Array(replay_value.get("commandStream", [])):
		var item := Dictionary(item_value)
		var command := Dictionary(item.get("command", {})).duplicate(true)
		var checkpoint := Dictionary(item.get("checkpoint", {}))
		var accepted: bool = bool(authority.call("dispatch", command))
		if _has_io_attempts(guard):
			return _result(false, "REPLAY_VERIFICATION_IO_ATTEMPT", checkpoints, int(authority.get("state_version")), String(authority.call("_state_hash")), initial_hash)
		var snapshot := Dictionary(authority.call("snapshot"))
		var actual_version := int(snapshot.get("stateVersion", -1))
		var actual_hash := String(snapshot.get("stateHash", ""))
		var expected_version := int(checkpoint.get("afterVersion", checkpoint.get("stateVersion", -1)))
		var expected_hash := String(checkpoint.get("afterHash", checkpoint.get("stateHash", "")))
		var command_type := String(command.get("type", ""))
		var checkpoint_ok := accepted
		if expected_version >= 0 and actual_version != expected_version:
			checkpoint_ok = false
		if expected_hash != "" and actual_hash != expected_hash:
			checkpoint_ok = false
		checkpoints.append({
			"index": int(item.get("index", checkpoints.size() + 1)),
			"type": command_type,
			"ok": checkpoint_ok,
			"expectedVersion": expected_version,
			"actualVersion": actual_version,
			"expectedHash": expected_hash,
			"actualHash": actual_hash,
		})
		if not checkpoint_ok:
			return _result(false, "REPLAY_CHECKPOINT_MISMATCH", checkpoints, actual_version, actual_hash, initial_hash)

	if _has_io_attempts(guard):
		return _result(false, "REPLAY_VERIFICATION_IO_ATTEMPT", checkpoints, int(authority.get("state_version")), String(authority.call("_state_hash")), initial_hash)
	var final_snapshot := Dictionary(authority.call("snapshot"))
	var final_version := int(final_snapshot.get("stateVersion", -1))
	var final_hash := String(final_snapshot.get("stateHash", ""))
	var final := Dictionary(replay_value.get("final", {}))
	var expected_final_version := int(final.get("stateVersion", -1))
	var expected_final_hash := String(final.get("stateHash", ""))
	if (
		(expected_final_version >= 0 and final_version != expected_final_version)
		or (expected_final_hash != "" and final_hash != expected_final_hash)
	):
		return _result(false, "REPLAY_FINAL_MISMATCH", checkpoints, final_version, final_hash, initial_hash)
	return _result(true, "", checkpoints, final_version, final_hash, initial_hash)


func _board_dimensions(options: Dictionary, context: Dictionary) -> Vector2i:
	var default_value: Variant = context.get("defaultBoardDimensions", BattleBoardDimensionsScript.legacy_defaults())
	var legacy_default: Vector2i = Vector2i(default_value) if default_value is Vector2i else BattleBoardDimensionsScript.legacy_defaults()
	if not options.has("boardWidth") and not options.has("boardHeight"):
		return legacy_default
	return Vector2i(
		int(options.get("boardWidth", BattleBoardDimensionsScript.DEFAULT_WIDTH)),
		int(options.get("boardHeight", BattleBoardDimensionsScript.DEFAULT_HEIGHT))
	)


func _has_io_attempts(guard: RefCounted) -> bool:
	return guard != null and guard.has_method(&"attempts") and not Array(guard.call("attempts")).is_empty()


func _result(ok: bool, error: String, checkpoints: Array, final_version: int, final_hash: String, initial_hash: String = "") -> Dictionary:
	return ReplayBuilderScript.verify_result(ok, error, checkpoints, final_version, final_hash, initial_hash)
