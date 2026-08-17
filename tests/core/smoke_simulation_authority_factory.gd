extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")
const SimulationIoGuardScript := preload("res://session/simulation_io_guard.gd")
const SimulationAuthorityFactoryScript := preload("res://session/simulation_authority_factory.gd")

var _failed := false


func _initialize() -> void:
	_test_guard_contract()
	_test_fresh_create()
	_test_canonical_fork_isolation()
	_test_invalid_source()

	if _failed:
		quit(1)
		return
	print("SMOKE_SIMULATION_AUTHORITY_FACTORY_OK repositories=5 hash=equal io=0")
	quit(0)


func _test_guard_contract() -> void:
	var guard: RefCounted = SimulationIoGuardScript.new()
	var required_methods := [
		"write_slot", "read_slot", "read_first", "valid_slot", "slot_path", "write_text", "read_document", "remove_path",
		"write_document",
		"ensure_content_revision", "read_content_reference", "create_run", "append_command", "write_checkpoint",
		"list_runs", "list_checkpoints", "checkpoint_for_day", "read_manifest", "read_run_header", "read_content_pack",
		"read_checkpoint", "read_checkpoint_item", "command_count",
		"read_dictionary", "content_errors", "append",
	]
	for method_name in required_methods:
		_expect(guard.has_method(StringName(method_name)), "guard covers repository API %s" % method_name)
	var write_result := Dictionary(guard.call("write_slot", {}, 1, {}))
	_expect(not bool(write_result.get("ok", true)) and String(write_result.get("error", "")) == "SIMULATION_IO_FORBIDDEN", "guard fails a write closed")
	_expect(Array(guard.call("attempts")).size() == 1, "guard records every attempted repository call")
	guard.call("clear")
	_expect(Array(guard.call("attempts")).is_empty(), "guard clear removes diagnostics without external state")


func _test_canonical_fork_isolation() -> void:
	var source: RefCounted = StateScript.new()
	source.set("defeated_units", [{"id": "fork_defeated", "side": "enemy", "hp": 0}])
	source.set("reward_fallback_audit", [{"seed": "fork-audit", "reason": "fixture"}])
	source.set("history_recording_enabled", true)
	source.set("history_run_id", "source-run")
	source.set("history_branch_id", "source-branch")
	source.set("history_parent_run_id", "source-parent")
	source.set("history_parent_checkpoint_id", "source-checkpoint")
	source.set("history_command_index", 7)
	source.set("history_content_revision", 3)
	source.set("history_content_path", "source-content")
	var source_capture := AuthoritativeStateCodecScript.capture(source, false)
	var source_hash := String(source.call("_state_hash"))
	var source_history := Dictionary(source.call("run_history_status"))

	var factory: RefCounted = SimulationAuthorityFactoryScript.new()
	var result := Dictionary(factory.call("fork", source))
	_expect(bool(result.get("ok", false)), "factory creates a simulation fork from an initialized authority")
	_expect(String(result.get("schema", "")) == "ysbzs.simulation-fork-result.v1", "factory returns the stable fork result schema")
	_expect(String(result.get("sourceStateHash", "")) == source_hash and String(result.get("forkStateHash", "")) == source_hash, "source and fork hashes are equal")
	var guard := result.get("ioGuard") as RefCounted
	_expect(guard != null and Array(guard.call("attempts")).is_empty(), "simulation construction performs zero repository calls")
	var fork := result.get("authority") as RefCounted
	_expect(fork != null, "successful fork returns an authority only inside the result boundary")
	if fork == null:
		return
	_expect(AuthoritativeStateCodecScript.capture(fork, false) == source_capture, "canonical codec payload is preserved exactly")
	_expect(Array(fork.get("defeated_units")) == Array(source.get("defeated_units")), "defeated_units survives the canonical fork")
	_expect(Array(fork.get("reward_fallback_audit")) == Array(source.get("reward_fallback_audit")), "non-hash canonical audits survive the fork")
	_expect(not bool(fork.get("history_recording_enabled")) and bool(fork.get("_history_suspended")), "fork history recording is disabled and suspended")
	_expect(String(fork.get("history_run_id")) == "" and String(fork.get("history_branch_id")) == "" and int(fork.get("history_command_index")) == 0, "fork clears history identity and index")
	_expect(Dictionary(source.call("run_history_status")) == source_history, "factory leaves source history metadata unchanged")
	_expect(AuthoritativeStateCodecScript.capture(source, false) == source_capture and String(source.call("_state_hash")) == source_hash, "factory leaves source canonical state unchanged")
	var fork_roster := Array(fork.get("roster")).duplicate(true)
	if not fork_roster.is_empty():
		var first := Dictionary(fork_roster[0]).duplicate(true)
		first["name"] = "fork-only mutation"
		fork_roster[0] = first
		fork.set("roster", fork_roster)
	_expect(AuthoritativeStateCodecScript.capture(source, false) == source_capture, "fork mutations cannot alias back into source")


func _test_fresh_create() -> void:
	var source: RefCounted = StateScript.new()
	var content_pack := Dictionary(source.get("game_data")).duplicate(true)
	var content_before := content_pack.duplicate(true)
	var factory: RefCounted = SimulationAuthorityFactoryScript.new()
	var result := Dictionary(factory.call("create", StateScript, content_pack, {
		"seed": "fresh-create-seed",
		"boardDimensions": Vector2i(6, 5),
		"contentSourceKind": source.call("content_source_kind"),
	}))
	_expect(bool(result.get("ok", false)), "factory creates a fresh simulation authority")
	_expect(content_pack == content_before, "fresh create leaves the supplied content pack unchanged")
	var guard := result.get("ioGuard") as RefCounted
	_expect(guard != null and Array(guard.call("attempts")).is_empty(), "fresh construction performs zero repository calls")
	var authority := result.get("authority") as RefCounted
	_expect(authority != null and String(result.get("forkStateHash", "")) == String(authority.call("_state_hash")), "fresh result reports the created authority hash")
	if authority != null:
		var board := Dictionary(Dictionary(authority.call("snapshot")).get("board", {}))
		_expect(int(board.get("width", 0)) == 6 and int(board.get("height", 0)) == 5, "fresh create applies dimensions before returning")
		_expect(String(authority.get("run_seed")) == "fresh-create-seed", "fresh create applies the requested seed")
	var invalid_dimensions := Dictionary(factory.call("create", StateScript, content_pack, {
		"boardDimensions": Vector2i(0, 5),
		"contentSourceKind": source.call("content_source_kind"),
	}))
	_expect(not bool(invalid_dimensions.get("ok", true)) and Array(invalid_dimensions.get("errors", [])).has("SIMULATION_CREATE_BOARD_DIMENSIONS_INVALID"), "fresh create rejects invalid dimensions")
	var invalid_option := Dictionary(factory.call("create", StateScript, content_pack, {
		"authority": source,
		"contentSourceKind": source.call("content_source_kind"),
	}))
	_expect(not bool(invalid_option.get("ok", true)) and Array(invalid_option.get("errors", [])).has("SIMULATION_CREATE_OPTION_UNSUPPORTED:authority"), "fresh create rejects authority-bearing options")
	var missing_source_kind := Dictionary(factory.call("create", StateScript, content_pack, {}))
	_expect(not bool(missing_source_kind.get("ok", true)) and Array(missing_source_kind.get("errors", [])) == ["SIMULATION_CREATE_CONTENT_SOURCE_KIND_REQUIRED"], "fresh create rejects an implicit content source kind")
	var invalid_source_kind := Dictionary(factory.call("create", StateScript, content_pack, {"contentSourceKind": &"guessed_from_content"}))
	_expect(not bool(invalid_source_kind.get("ok", true)) and Array(invalid_source_kind.get("errors", [])) == ["SIMULATION_CREATE_CONTENT_SOURCE_KIND_INVALID"], "fresh create rejects an unknown content source kind")
	var invalid_source_kind_type := Dictionary(factory.call("create", StateScript, content_pack, {"contentSourceKind": 1}))
	_expect(not bool(invalid_source_kind_type.get("ok", true)) and Array(invalid_source_kind_type.get("errors", [])) == ["SIMULATION_CREATE_CONTENT_SOURCE_KIND_INVALID"], "fresh create rejects a non-string content source kind")
	var fork_option := Dictionary(factory.call("fork", source, {"contentSourceKind": source.call("content_source_kind")}))
	_expect(not bool(fork_option.get("ok", true)) and Array(fork_option.get("errors", [])) == ["SIMULATION_FORK_OPTION_UNSUPPORTED:contentSourceKind"], "fork inherits source kind and rejects caller overrides")


func _test_invalid_source() -> void:
	var result := Dictionary(SimulationAuthorityFactoryScript.new().call("fork", RefCounted.new()))
	_expect(not bool(result.get("ok", true)) and result.get("authority") == null, "invalid source returns no authority")
	_expect(Array(result.get("errors", [])) == ["SIMULATION_SOURCE_INVALID"], "invalid source uses a stable error code")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_SIMULATION_AUTHORITY_FACTORY_FAIL: %s" % message)
