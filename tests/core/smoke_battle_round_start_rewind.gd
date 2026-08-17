extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")

var _failed := false


func _init() -> void:
	var state: RefCounted = StateScript.new()
	_expect(_accepted(state.run_command({"type": "NEW_RUN", "seed": "round-rewind-smoke"})), "fixture starts a deterministic run")
	_expect(_accepted(state.run_command({"type": "START_BATTLE"})), "fixture enters battle")
	_expect(int(state.get("battle_round")) == 1, "battle starts at round 1")
	_expect(not bool(Dictionary(state.snapshot().get("round_rewind", {})).get("canRewind", true)), "round 1 exposes no previous-round rewind")

	var rejected_hash := String(state.call("_state_hash"))
	var rejected_version := int(state.get("state_version"))
	var rejected := Dictionary(state.run_command({"type": "REWIND_TO_PREVIOUS_ROUND_START"}))
	_expect(not bool(rejected.get("accepted", true)), "rewind is rejected when no previous round exists")
	_expect(String(state.call("_state_hash")) == rejected_hash, "rejected rewind preserves the full authoritative hash")
	_expect(int(state.get("state_version")) == rejected_version, "rejected rewind does not advance stateVersion")

	var round_one_entry := Dictionary(Array(state.get("battle_round_start_checkpoints"))[0])
	var round_one_state := Dictionary(round_one_entry.get("state", {})).duplicate(true)
	_expect(_accepted(state.run_command({"type": "START_NEXT_ROUND"})), "fixture advances to round 2")
	_expect(int(state.get("battle_round")) == 2, "fixture reaches round 2")
	var rewind_availability := Dictionary(state.snapshot().get("round_rewind", {}))
	_expect(bool(rewind_availability.get("canRewind", false)), "round 2 exposes rewind")
	_expect(int(rewind_availability.get("targetRound", 0)) == 1, "round 2 targets round 1 start")
	var version_before_rewind := int(state.get("state_version"))
	var rewind_response := Dictionary(state.run_command({"type": "REWIND_TO_PREVIOUS_ROUND_START"}))
	_expect(_accepted(rewind_response), "round 2 rewinds through the public command")
	_expect(int(state.get("battle_round")) == 1, "rewind restores round 1")
	_expect(int(state.get("state_version")) == version_before_rewind + 1, "accepted rewind keeps stateVersion monotonic")
	_expect(_round_state_without_version(state) == _payload_without_version(round_one_state), "rewind restores every hashed round-start gameplay field")
	var rewind_result := Dictionary(rewind_response.get("result", {}))
	_expect(int(rewind_result.get("fromRound", 0)) == 2 and int(rewind_result.get("targetRound", 0)) == 1, "rewind result identifies its source and target rounds")
	_expect(_latest_command_type(state) == "REWIND_TO_PREVIOUS_ROUND_START", "rewind stays in the authoritative command journal")

	_expect(_accepted(state.run_command({"type": "START_NEXT_ROUND"})), "branch advances again to round 2")
	var round_two_state := Dictionary(Dictionary(Array(state.get("battle_round_start_checkpoints"))[1]).get("state", {})).duplicate(true)
	_expect(_accepted(state.run_command({"type": "START_NEXT_ROUND"})), "branch advances to round 3")
	_expect(Array(state.get("battle_round_start_checkpoints")).size() == 3, "round-start history is bounded and ordered")
	var save_document := Dictionary(state.save_document("round-rewind-smoke"))
	var loaded: RefCounted = StateScript.new()
	_expect(loaded.load_document(save_document), "round-start checkpoints survive save/load")
	_expect(bool(Dictionary(loaded.snapshot().get("round_rewind", {})).get("canRewind", false)), "loaded battle preserves rewind availability")
	var loaded_version := int(loaded.get("state_version"))
	_expect(_accepted(loaded.run_command({"type": "REWIND_TO_PREVIOUS_ROUND_START"})), "loaded round 3 rewinds to round 2")
	_expect(int(loaded.get("battle_round")) == 2, "first consecutive rewind restores round 2")
	_expect(int(loaded.get("state_version")) == loaded_version + 1, "loaded rewind advances stateVersion once")
	_expect(_round_state_without_version(loaded) == _payload_without_version(round_two_state), "loaded rewind restores the saved round 2 checkpoint")
	_expect(_accepted(loaded.run_command({"type": "REWIND_TO_PREVIOUS_ROUND_START"})), "second consecutive rewind reaches round 1")
	_expect(int(loaded.get("battle_round")) == 1, "consecutive rewind reaches the earliest prior round")
	_expect(Array(loaded.get("battle_round_start_checkpoints")).size() == 1, "rewind prunes discarded future checkpoints")
	_expect(_accepted(loaded.run_command({"type": "START_NEXT_ROUND"})), "play can continue after rewind")
	_expect(Array(loaded.get("battle_round_start_checkpoints")).size() == 2, "continued play records a fresh branch checkpoint")

	var replay := Dictionary(loaded.replay_document())
	var replay_result := Dictionary(loaded.verify_replay_document(replay))
	_expect(bool(replay_result.get("ok", false)), "rewind command journal verifies deterministically")
	_expect(String(replay_result.get("finalHash", "")) == String(loaded.call("_state_hash")), "replay reaches the branched post-rewind state hash")

	if _failed:
		print("SMOKE_BATTLE_ROUND_START_REWIND_FAIL")
		quit(1)
		return
	print("SMOKE_BATTLE_ROUND_START_REWIND_OK rounds=3 save_load=true replay=true")
	quit()


func _accepted(response: Dictionary) -> bool:
	return bool(response.get("accepted", false))


func _round_state_without_version(state: RefCounted) -> Dictionary:
	return _payload_without_version(AuthoritativeStateCodecScript.capture_round_start_checkpoint(state))


func _payload_without_version(payload: Dictionary) -> Dictionary:
	var normalized := payload.duplicate(true)
	normalized.erase("stateVersion")
	return normalized


func _latest_command_type(state: RefCounted) -> String:
	var command_log := Array(state.get("command_log"))
	if command_log.is_empty():
		return ""
	return String(Dictionary(command_log.back()).get("type", ""))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_BATTLE_ROUND_START_REWIND_FAIL: %s" % message)
