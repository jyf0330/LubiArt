extends SceneTree

const CommandContractScript := preload("res://core/commands/command_contract.gd")
const DocumentCodecScript := preload("res://persistence/save_codec.gd")
const StateScript := preload("res://core/state/game_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if CommandContractScript.normalize_action_type("startBattle") != "START_BATTLE":
		_fail("Command aliases must stay canonical after extraction.")
		return
	if CommandContractScript.normalize_action_type("CUSTOM_COMMAND") != "CUSTOM_COMMAND":
		_fail("Unknown command types must pass through unchanged.")
		return
	if CommandContractScript.base_state_version_mismatch({}, 4):
		_fail("Commands without a base version must remain compatible.")
		return
	if not CommandContractScript.base_state_version_mismatch({"base_state_version": 3}, 4):
		_fail("Snake-case stale versions must still be rejected.")
		return

	var raw_command := {
		"type": "startBattle",
		"command_id": "kernel-smoke",
		"base_state_version": 7,
		"base_state_hash": "before-hash",
		"events": [{"type": "must_be_removed"}],
		"nested": {"value": 2, "data": {"large": true}}
	}
	var envelope := CommandContractScript.command_envelope("START_BATTLE", raw_command, 7, "fallback-hash")
	var payload := Dictionary(envelope.get("payload", {}))
	if String(envelope.get("type", "")) != "START_BATTLE" or String(envelope.get("rawType", "")) != "startBattle":
		_fail("Command envelope type fields drifted.")
		return
	if int(envelope.get("baseStateVersion", -1)) != 7 or String(envelope.get("baseStateHash", "")) != "before-hash":
		_fail("Command envelope version/hash fields drifted.")
		return
	if payload.has("events") or payload.has("base_state_version") or Dictionary(payload.get("nested", {})).has("data"):
		_fail("Replay-safe command payload must remove response and generated-data fields.")
		return
	if int(payload.get("baseStateVersion", -1)) != 7 or String(payload.get("type", "")) != "START_BATTLE":
		_fail("Replay-safe command payload lost its canonical command/version.")
		return
	if CommandContractScript.is_view_state_action("SELECT_UNIT") or not CommandContractScript.STRICT_VERSION_ACTIONS.has("SELECT_UNIT"):
		_fail("Authoritative selection command classification drifted.")
		return
	if not CommandContractScript.is_read_only_action("EXPORT_REPLAY") or CommandContractScript.is_read_only_action("START_BATTLE"):
		_fail("Read-only command classification drifted.")
		return

	var stable_a := DocumentCodecScript.stable_json({"z": 1.0, "a": [2, {"b": true}]})
	var stable_b := DocumentCodecScript.stable_json({"a": [2.0, {"b": true}], "z": 1})
	if stable_a != stable_b or stable_a != "{\"a\":[2,{\"b\":true}],\"z\":1}":
		_fail("Stable JSON ordering/whole-number normalization drifted: %s" % stable_a)
		return

	var state := StateScript.new()
	var meta := {
		"createdAt": "kernel-smoke",
		"gameVersion": "test-version",
		"sessionId": "session-1",
		"viewStates": {"p1": {"selected": "pal_001"}}
	}
	var state_document := state.save_document("p1", meta)
	var rebuilt_document := DocumentCodecScript.build_save_document(
		StateScript.SAVE_SCHEMA,
		StateScript.SAVE_SCHEMA_VERSION,
		state._save_state_payload(),
		"p1",
		meta,
		state._save_summary_from_state(state._save_state_payload())
	)
	rebuilt_document["determinism"] = Dictionary(state_document.get("determinism", {})).duplicate(true)
	rebuilt_document["history"] = Dictionary(state_document.get("history", {})).duplicate(true)
	rebuilt_document["checksum"] = DocumentCodecScript.save_checksum(rebuilt_document)
	if state_document != rebuilt_document:
		_fail("YsbzsState save_document must remain a facade over the codec plus canonical determinism/history metadata.")
		return
	if String(state_document.get("checksum", "")) != DocumentCodecScript.save_checksum(state_document):
		_fail("Save checksum delegation drifted.")
		return
	var tampered := state_document.duplicate(true)
	Dictionary(tampered.get("state", {}))["coins"] = int(Dictionary(tampered.get("state", {})).get("coins", 0)) + 1
	if DocumentCodecScript.save_checksum(tampered) == String(state_document.get("checksum", "")):
		_fail("Save checksum must detect state mutation.")
		return

	var snapshot := state.snapshot()
	var protocol := Dictionary(snapshot.get("command_protocol", {}))
	if Dictionary(protocol.get("aliases", {})) != CommandContractScript.ACTION_ALIASES:
		_fail("Snapshot command protocol aliases drifted after extraction.")
		return

	print("SMOKE_CORE_KERNEL_MODULES_OK aliases=%d view_actions=%d save_checksum=%s" % [
		CommandContractScript.ACTION_ALIASES.size(),
		CommandContractScript.VIEW_STATE_ACTIONS.size(),
		String(state_document.get("checksum", ""))
	])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
