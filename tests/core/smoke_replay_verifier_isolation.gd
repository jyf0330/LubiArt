extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")
const ReplayVerifierScript := preload("res://persistence/replay_verifier.gd")
const SimulationAuthorityFactoryScript := preload("res://session/simulation_authority_factory.gd")
const SimulationIoGuardScript := preload("res://session/simulation_io_guard.gd")

var failed := false


class IoAttemptFactory extends RefCounted:
	func create(_authority_script: Script, _content_pack: Dictionary, _options: Dictionary = {}) -> Dictionary:
		var guard: RefCounted = SimulationIoGuardScript.new()
		guard.call("write_document", "blocked", {})
		return {
			"schema": "ysbzs.simulation-fork-result.v1",
			"ok": true,
			"authority": null,
			"ioGuard": guard,
			"sourceStateHash": "",
			"forkStateHash": "",
			"errors": [],
		}


func _initialize() -> void:
	var source: RefCounted = StateScript.new()
	_expect(bool(source.call("dispatch", {"type": "START_BATTLE"})), "fixture records one replayable command")
	var replay := Dictionary(source.call("replay_document"))
	var replay_before := replay.duplicate(true)
	var source_payload := AuthoritativeStateCodecScript.capture(source, false)
	var source_hash := String(source.call("_state_hash"))
	var source_version := int(source.get("state_version"))
	var source_history := Dictionary(source.call("run_history_status"))
	var source_content := Dictionary(source.get("game_data")).duplicate(true)
	var user_tree_before := _user_tree("user://")

	var valid := Dictionary(source.call("verify_replay_document", replay))
	_expect(bool(valid.get("ok", false)), "valid replay verifies")
	_expect(Array(valid.get("checkpoints", [])).size() == 1 and bool(Dictionary(Array(valid.get("checkpoints", []))[0]).get("ok", false)), "every command checkpoint is verified")
	_expect(replay == replay_before, "verification leaves replay input unchanged")
	_expect(AuthoritativeStateCodecScript.capture(source, false) == source_payload, "verification leaves source canonical payload unchanged")
	_expect(String(source.call("_state_hash")) == source_hash and int(source.get("state_version")) == source_version, "verification leaves source hash/version unchanged")
	_expect(Dictionary(source.call("run_history_status")) == source_history and Dictionary(source.get("game_data")) == source_content, "verification leaves source history/content unchanged")
	var user_tree_after := _user_tree("user://")
	_expect(user_tree_after == user_tree_before, "verification leaves the isolated user file tree unchanged")

	_assert_error(source, _mutated(replay, "schema", "bad.schema"), "REPLAY_INVALID_SCHEMA")
	_assert_error(source, _mutated(replay, "schemaVersion", 999), "REPLAY_UNSUPPORTED_SCHEMA_VERSION")
	_assert_error(source, _mutated(replay, "replayVersion", "future"), "REPLAY_UNSUPPORTED_VERSION")
	var content_mismatch := replay.duplicate(true)
	content_mismatch["determinism"]["contentHash"] = "future-content"
	_assert_error(source, content_mismatch, "REPLAY_CONTENT_VERSION_MISMATCH")
	var rules_mismatch := replay.duplicate(true)
	rules_mismatch["determinism"]["rulesVersion"] = "future-rules"
	_assert_error(source, rules_mismatch, "REPLAY_RULES_VERSION_MISMATCH")
	var rng_mismatch := replay.duplicate(true)
	rng_mismatch["determinism"]["rngVersion"] = "future-rng"
	_assert_error(source, rng_mismatch, "REPLAY_RNG_VERSION_MISMATCH")
	var checksum_mismatch := replay.duplicate(true)
	checksum_mismatch["final"]["stateHash"] = "checksum-tamper"
	_expect(String(Dictionary(source.call("verify_replay_document", checksum_mismatch)).get("error", "")) == "REPLAY_CHECKSUM_MISMATCH", "checksum mismatch wins before replay execution")
	var invalid_dimensions := replay.duplicate(true)
	invalid_dimensions["initial"]["options"]["boardWidth"] = 0
	invalid_dimensions["initial"]["options"]["boardHeight"] = 7
	_assert_error(source, invalid_dimensions, "REPLAY_INVALID_BOARD_DIMENSIONS")
	var initial_mismatch := replay.duplicate(true)
	initial_mismatch["initial"]["stateHash"] = "bad-initial"
	_assert_error(source, initial_mismatch, "REPLAY_INITIAL_MISMATCH")
	for checkpoint_index in range(Array(replay.get("commandStream", [])).size()):
		var checkpoint_mismatch := replay.duplicate(true)
		checkpoint_mismatch["commandStream"][checkpoint_index]["checkpoint"]["afterHash"] = "bad-checkpoint-%d" % checkpoint_index
		_assert_error(source, checkpoint_mismatch, "REPLAY_CHECKPOINT_MISMATCH")
	var final_mismatch := replay.duplicate(true)
	final_mismatch["final"]["stateHash"] = "bad-final"
	_assert_error(source, final_mismatch, "REPLAY_FINAL_MISMATCH")

	var verifier: RefCounted = ReplayVerifierScript.new()
	var io_result := Dictionary(verifier.call("verify", replay, _context(source, replay), IoAttemptFactory.new()))
	_expect(String(io_result.get("error", "")) == "REPLAY_VERIFICATION_IO_ATTEMPT", "I/O guard attempt has a dedicated fail-closed error")
	var missing_source_context := _context(source, replay)
	missing_source_context.erase("contentSourceKind")
	var missing_source_result := Dictionary(verifier.call("verify", replay, missing_source_context, SimulationAuthorityFactoryScript.new()))
	_expect(String(missing_source_result.get("error", "")) == "REPLAY_INITIAL_MISMATCH", "direct verifier context cannot omit the content source kind")
	var legacy_source: RefCounted = StateScript.new()
	_expect(bool(legacy_source.call("set_board_dimensions", 8, 8)), "legacy replay fixture uses the historical 8x8 board")
	var legacy_replay := Dictionary(legacy_source.call("replay_document"))
	legacy_replay["initial"]["options"].erase("boardWidth")
	legacy_replay["initial"]["options"].erase("boardHeight")
	legacy_replay["checksum"] = legacy_source.call("_replay_checksum", legacy_replay)
	var legacy_result := Dictionary(legacy_source.call("verify_replay_document", legacy_replay))
	_expect(bool(legacy_result.get("ok", false)), "legacy replay without dimensions verifies with the historical default")
	var verifier_source := FileAccess.get_file_as_string("res://persistence/replay_verifier.gd")
	for forbidden in ["FileAccess", "DirAccess", "Time.", "OS.", "user://", "Repository"]:
		_expect(not verifier_source.contains(forbidden), "verifier source excludes external I/O token %s" % forbidden)
	_expect(not verifier_source.contains("var _authority") and not verifier_source.contains("self._authority"), "verifier stores no authority field")
	var facade_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	_expect(not facade_source.contains("func _replay_board_dimensions(") and not facade_source.contains("func _replay_verify_result("), "facade removes verifier helper shells")
	_expect(facade_source.contains("_core_composition.replay_verifier.verify(replay"), "facade keeps a narrow verifier adapter")

	if failed:
		quit(1)
		return
	print("SMOKE_REPLAY_VERIFIER_ISOLATION_OK errors=13 checkpoints=1 io=0 source=unchanged")
	quit(0)


func _mutated(replay: Dictionary, key: String, value: Variant) -> Dictionary:
	var result := replay.duplicate(true)
	result[key] = value
	return result


func _assert_error(source: RefCounted, replay: Dictionary, error: String) -> void:
	replay["checksum"] = source.call("_replay_checksum", replay)
	var result := Dictionary(source.call("verify_replay_document", replay))
	_expect(String(result.get("error", "")) == error, "%s remains the first error" % error)


func _context(source: RefCounted, replay: Dictionary) -> Dictionary:
	return {
		"authorityScript": source.get_script(),
		"contentPack": Dictionary(source.get("game_data")).duplicate(true),
		"contentHash": String(source.call("_content_hash")),
		"contentSourceKind": source.call("content_source_kind"),
		"rulesVersion": StateScript.RULES_VERSION,
		"rngVersion": String(replay.get("rngVersion", "")),
		"defaultBoardDimensions": Vector2i(8, 8),
	}


func _user_tree(path: String) -> Array:
	var rows: Array = []
	var directory := DirAccess.open(path)
	if directory == null:
		return rows
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := path.path_join(name)
			if directory.current_is_dir():
				if not (path == "user://" and ["logs", "shader_cache"].has(name)):
					for nested in _user_tree(child):
						rows.append(nested)
			else:
				rows.append({"path": child, "bytes": FileAccess.get_file_as_bytes(child)})
		name = directory.get_next()
	directory.list_dir_end()
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("path", "")) < String(right.get("path", "")))
	return rows


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_REPLAY_VERIFIER_ISOLATION_FAIL: %s" % message)
