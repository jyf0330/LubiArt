extends "res://tests/helpers/singleplayer_smoke_suite.gd"


func _run() -> void:
	var state := _new_legacy_state()
	var initial_state_hash := String(state.snapshot().get("stateHash", ""))
	_expect(state.dispatch({"type": "PICK_NODE", "nodeId": "node_shop_basic"}), "can pick CSV shop node through public command")
	var state_version_after_shop := int(state.snapshot().get("stateVersion", -1))
	var state_hash_after_shop := String(state.snapshot().get("stateHash", ""))
	_expect(state_version_after_shop > 0, "accepted public command increments browser-style stateVersion")
	_expect(state_hash_after_shop.length() == 16 and state_hash_after_shop != initial_state_hash, "accepted public command changes browser-style stateHash")
	_expect(state.snapshot()["phase"] == "shop", "shop phase active")
	_expect(int(state.snapshot()["node_index"]) == 2, "picking a route node advances to next schedule step")
	var replay_offer_id := _first_buyable_offer_id(state)
	_expect(replay_offer_id != "", "replay fixture reads a buyable shop offer from the current snapshot")
	_expect(state.dispatch({
		"type": "BUY_OFFER",
		"offer_id": replay_offer_id,
		"accepted": true,
		"defaultPayload": {"ignored": true},
		"events": [{"id": "ignored"}],
		"label": "Buy UI label",
		"result": {"debug": true},
		"stateHash": "transient",
		"stateVersion": 999,
		"trace": {"ignored": true},
		"viewModel": {"phase": "shop"},
		"data": {"ignored": true},
		"indexes": {"ignored": true}
	}), "can buy first pet through dispatch")
	var state_version_after_buy := int(state.snapshot().get("stateVersion", -1))
	var state_hash_after_buy := String(state.snapshot().get("stateHash", ""))
	var roster_size_after_buy := Array(state.snapshot().get("roster", [])).size()
	_expect(state_version_after_buy > state_version_after_shop, "later accepted command advances stateVersion again")
	_expect(state_hash_after_buy.length() == 16 and state_hash_after_buy != state_hash_after_shop, "later accepted command advances stateHash again")
	var buy_log_entry := Dictionary(Array(state.snapshot().get("command_log", [])).back())
	_expect(String(buy_log_entry.get("beforeHash", "")) == state_hash_after_shop, "playable command_log records browser-style beforeHash")
	_expect(String(buy_log_entry.get("afterHash", "")) == state_hash_after_buy, "playable command_log records browser-style afterHash")
	_expect(int(buy_log_entry.get("beforeVersion", -1)) == state_version_after_shop, "playable command_log records beforeVersion")
	_expect(int(buy_log_entry.get("afterVersion", -1)) == state_version_after_buy, "playable command_log records afterVersion")
	var buy_replay_command := Dictionary(buy_log_entry.get("command", {}))
	_expect(String(buy_replay_command.get("type", "")) == "BUY_OFFER", "playable command_log stores normalized replayable command type")
	_expect(int(buy_replay_command.get("baseStateVersion", -1)) == state_version_after_shop, "playable command_log fills browser-style baseStateVersion")
	for excluded_key in ["accepted", "defaultPayload", "events", "label", "result", "stateHash", "stateVersion", "trace", "viewModel", "data", "indexes"]:
		_expect(not buy_replay_command.has(excluded_key), "playable command_log strips transient replay key %s" % excluded_key)
	var replay_doc: Dictionary = state.replay_document()
	_expect(String(replay_doc.get("schema", "")) == "ysbzs.replay", "Godot replay document uses browser replay schema")
	_expect(int(replay_doc.get("schemaVersion", 0)) == 2, "Godot replay document uses versioned history schemaVersion")
	_expect(String(replay_doc.get("replayVersion", "")) == "ysbzs_replay_v4_versioned_history", "Godot replay document uses versioned deterministic history format")
	_expect(String(replay_doc.get("checksum", "")) != "", "Godot replay document exposes checksum")
	_expect(Array(replay_doc.get("commandStream", [])).size() == Array(state.snapshot().get("command_log", [])).size(), "Godot replay commandStream mirrors accepted playable commands")
	var replay_last := Dictionary(Array(replay_doc.get("commandStream", [])).back())
	var replay_last_command := Dictionary(replay_last.get("command", {}))
	var replay_last_checkpoint := Dictionary(replay_last.get("checkpoint", {}))
	_expect(String(replay_last_command.get("type", "")) == "BUY_OFFER", "Godot replay commandStream stores replayable command type")
	_expect(int(replay_last_command.get("baseStateVersion", -1)) == state_version_after_shop, "Godot replay commandStream stores baseStateVersion")
	for excluded_key in ["accepted", "defaultPayload", "events", "label", "result", "stateHash", "stateVersion", "trace", "viewModel", "data", "indexes"]:
		_expect(not replay_last_command.has(excluded_key), "Godot replay commandStream strips transient replay key %s" % excluded_key)
	var replay_input_log := Array(replay_doc.get("inputLog", []))
	_expect(replay_input_log.size() == Array(state.snapshot().get("command_log", [])).size(), "Godot replay inputLog mirrors accepted public inputs like browser compatibility replay")
	if not replay_input_log.is_empty():
			var replay_last_input := Dictionary(replay_input_log.back())
			var replay_last_input_payload := Dictionary(replay_last_input.get("payload", {}))
			_expect(String(replay_last_input.get("type", "")) == "BUY_OFFER", "Godot replay inputLog records public input type")
			_expect(String(replay_last_input_payload.get("offer_id", "")) == replay_offer_id, "Godot replay inputLog preserves raw public input payload")
			_expect(bool(replay_last_input_payload.get("accepted", false)), "Godot replay inputLog preserves raw transient input fields outside deterministic commandStream")
	var replay_change_log := Array(replay_doc.get("changeLog", []))
	_expect(replay_change_log.size() == Array(state.snapshot().get("command_log", [])).size(), "Godot replay changeLog mirrors accepted command checkpoints like browser compatibility replay")
	if not replay_change_log.is_empty():
		var replay_last_change := Dictionary(replay_change_log.back())
		var replay_last_change_source := Dictionary(replay_last_change.get("source", {}))
		var replay_last_change_from := Dictionary(replay_last_change.get("from", {}))
		var replay_last_change_to := Dictionary(replay_last_change.get("to", {}))
		_expect(String(replay_last_change.get("type", "")) == "COMMAND_ACCEPTED", "Godot replay changeLog records accepted command changes")
		_expect(String(replay_last_change.get("path", "")) == "state", "Godot replay changeLog records state path")
		_expect(String(replay_last_change.get("phase", "")) == "shop", "Godot replay changeLog records post-command phase")
		_expect(String(replay_last_change_source.get("commandType", "")) == "BUY_OFFER", "Godot replay changeLog records source command type")
		_expect(int(replay_last_change_from.get("stateVersion", -1)) == state_version_after_shop, "Godot replay changeLog records before stateVersion")
		_expect(int(replay_last_change_to.get("stateVersion", -1)) == state_version_after_buy, "Godot replay changeLog records after stateVersion")
	var replay_battle_trace := Array(replay_doc.get("battleTrace", []))
	_expect(replay_battle_trace.size() == replay_change_log.size(), "Godot replay battleTrace mirrors command checkpoint changes like browser compatibility replay")
	if not replay_battle_trace.is_empty():
		var replay_last_trace := Dictionary(replay_battle_trace.back())
		var replay_last_trace_source := Dictionary(replay_last_trace.get("source", {}))
		var replay_last_trace_changes := Array(replay_last_trace.get("changes", []))
		_expect(String(replay_last_trace.get("type", "")) == "COMMAND_ACCEPTED", "Godot replay battleTrace records accepted command event type")
		_expect(String(replay_last_trace.get("phase", "")) == "shop", "Godot replay battleTrace records post-command phase")
		_expect(String(replay_last_trace_source.get("commandType", "")) == "BUY_OFFER", "Godot replay battleTrace records source command type")
		_expect(String(replay_last_trace.get("protocol", "")).begins_with("|COMMAND_ACCEPTED|"), "Godot replay battleTrace exposes browser-style protocol line")
		_expect(replay_last_trace_changes.size() == 1, "Godot replay battleTrace records normalized change payload")
		var replay_last_event_id := String(replay_last_trace.get("eventId", ""))
		_expect(Array(replay_last_checkpoint.get("eventIds", [])).has(replay_last_event_id), "Godot replay checkpoint eventIds reference the matching battleTrace event")
		var replay_command_checkpoints := Array(replay_doc.get("commandCheckpoints", []))
		if not replay_command_checkpoints.is_empty():
			var replay_last_command_checkpoint := Dictionary(replay_command_checkpoints.back())
			var replay_last_command_checkpoint_payload := Dictionary(replay_last_command_checkpoint.get("checkpoint", {}))
			_expect(Array(replay_last_command_checkpoint_payload.get("eventIds", [])).has(replay_last_event_id), "Godot replay commandCheckpoints preserve checkpoint eventIds")
	_expect(int(replay_last_checkpoint.get("beforeVersion", -1)) == state_version_after_shop, "Godot replay checkpoint records beforeVersion")
	_expect(int(replay_last_checkpoint.get("afterVersion", -1)) == state_version_after_buy, "Godot replay checkpoint records afterVersion")
	_expect(String(replay_last_checkpoint.get("beforeHash", "")) == state_hash_after_shop, "Godot replay checkpoint records beforeHash")
	_expect(String(replay_last_checkpoint.get("afterHash", "")) == state_hash_after_buy, "Godot replay checkpoint records afterHash")
	var replay_summary := Dictionary(replay_doc.get("summary", {}))
	_expect(int(replay_summary.get("replayableCommands", -1)) == 2, "Godot replay summary counts replayable commands")
	_expect(int(replay_summary.get("finalStateVersion", -1)) == state_version_after_buy, "Godot replay summary records finalStateVersion")
	_expect(String(replay_summary.get("finalStateHash", "")) == state_hash_after_buy, "Godot replay summary records finalStateHash")
	var replay_final := Dictionary(replay_doc.get("final", {}))
	_expect(int(replay_final.get("stateVersion", -1)) == state_version_after_buy, "Godot replay final records stateVersion")
	_expect(String(replay_final.get("stateHash", "")) == state_hash_after_buy, "Godot replay final records stateHash")
	_expect(String(replay_final.get("phase", "")) == "shop", "Godot replay final records phase")
	var replay_initial := Dictionary(replay_doc.get("initial", {}))
	var replay_initial_hash := str(replay_initial.get("stateHash", ""))
	_expect(replay_initial_hash.length() == 16, "Godot replay initial records browser-style initial stateHash")
	var replay_doc_with_options: Dictionary = state.replay_document({
		"seed": "custom-replay-seed",
		"initialOptions": {
			"seed": "custom-replay-seed",
			"day": 4,
			"period": "夜晚",
			"playerId": "p9",
			"playerName": "测试玩家",
			"mode": "solo",
			"gold": 33,
			"players": [{
				"id": "p9",
				"name": "测试玩家",
				"data": {"ignored": true},
				"indexes": {"ignored": true}
			}],
			"unknownKey": "ignored",
			"data": {"ignored": true},
			"indexes": {"ignored": true}
		}
	})
	var replay_initial_with_options := Dictionary(replay_doc_with_options.get("initial", {}))
	var sanitized_initial_options := Dictionary(replay_initial_with_options.get("options", {}))
	_expect(String(replay_doc_with_options.get("seed", "")) == "custom-replay-seed", "Godot replay top-level seed can come from sanitized initial options")
	_expect(String(replay_initial_with_options.get("seed", "")) == "custom-replay-seed", "Godot replay initial seed can come from sanitized initial options")
	_expect(int(replay_initial_with_options.get("day", -1)) == 4, "Godot replay initial day can come from sanitized initial options")
	_expect(String(replay_initial_with_options.get("period", "")) == "夜晚", "Godot replay initial period can come from sanitized initial options")
	_expect(String(sanitized_initial_options.get("playerName", "")) == "测试玩家", "Godot replay initial options preserve browser whitelisted playerName")
	_expect(int(sanitized_initial_options.get("gold", -1)) == 33, "Godot replay initial options preserve browser whitelisted gold")
	_expect(not sanitized_initial_options.has("unknownKey"), "Godot replay initial options drop keys outside browser whitelist")
	_expect(not sanitized_initial_options.has("data"), "Godot replay initial options drop top-level data")
	_expect(not sanitized_initial_options.has("indexes"), "Godot replay initial options drop top-level indexes")
	var sanitized_players := Array(sanitized_initial_options.get("players", []))
	_expect(sanitized_players.size() == 1, "Godot replay initial options preserve browser whitelisted players")
	if sanitized_players.size() > 0:
		var sanitized_player := Dictionary(sanitized_players[0])
		_expect(not sanitized_player.has("data"), "Godot replay initial options recursively drop player data")
		_expect(not sanitized_player.has("indexes"), "Godot replay initial options recursively drop player indexes")
	var replay_verify: Dictionary = state.verify_replay_document(replay_doc)
	_expect(bool(replay_verify.get("ok", false)), "Godot can verify its own browser-style replay commandStream")
	_expect(str(replay_verify.get("initialHash", "")) == replay_initial_hash, "Godot replay verification reports initialHash like browser verifyReplayDocument")
	_expect(int(replay_verify.get("finalVersion", -1)) == state_version_after_buy, "Godot replay verification reaches final version")
	_expect(String(replay_verify.get("finalHash", "")) == state_hash_after_buy, "Godot replay verification reaches final hash")
	_expect(Array(replay_verify.get("checkpoints", [])).size() == 2, "Godot replay verification checks each replay command")
	var replay_verify_last: Dictionary = Dictionary(Array(replay_verify.get("checkpoints", [])).back())
	_expect(bool(replay_verify_last.get("ok", false)), "Godot replay verification accepts the last checkpoint")
	_expect(String(replay_verify_last.get("type", "")) == "BUY_OFFER", "Godot replay verification reports last command type")
	var tampered_replay: Dictionary = replay_doc.duplicate(true)
	tampered_replay["final"]["stateHash"] = "bad"
	_assert_replay_error(state, tampered_replay, "REPLAY_CHECKSUM_MISMATCH", "Godot replay verification rejects tampered replay checksum")
	var checkpoint_mismatch_replay: Dictionary = replay_doc.duplicate(true)
	checkpoint_mismatch_replay["commandStream"][0]["checkpoint"]["afterHash"] = "bad"
	checkpoint_mismatch_replay["checksum"] = state._replay_checksum(checkpoint_mismatch_replay)
	_assert_replay_error(state, checkpoint_mismatch_replay, "REPLAY_CHECKPOINT_MISMATCH", "Godot replay verification rejects checkpoint mismatch")
	var invalid_schema_replay: Dictionary = replay_doc.duplicate(true)
	invalid_schema_replay["schema"] = "bad.schema"
	invalid_schema_replay["checksum"] = state._replay_checksum(invalid_schema_replay)
	_assert_replay_error(state, invalid_schema_replay, "REPLAY_INVALID_SCHEMA", "Godot replay verification rejects invalid schema")
	var unsupported_schema_version_replay: Dictionary = replay_doc.duplicate(true)
	unsupported_schema_version_replay["schemaVersion"] = 999
	unsupported_schema_version_replay["checksum"] = state._replay_checksum(unsupported_schema_version_replay)
	_assert_replay_error(state, unsupported_schema_version_replay, "REPLAY_UNSUPPORTED_SCHEMA_VERSION", "Godot replay verification rejects unsupported schemaVersion")
	var unsupported_replay_version: Dictionary = replay_doc.duplicate(true)
	unsupported_replay_version["replayVersion"] = "unsupported"
	unsupported_replay_version["checksum"] = state._replay_checksum(unsupported_replay_version)
	_assert_replay_error(state, unsupported_replay_version, "REPLAY_UNSUPPORTED_VERSION", "Godot replay verification rejects unsupported replayVersion")
	_expect(state.save_replay_to_user(), "can write browser-style replay document to user storage")
	var export_version_before := int(state.snapshot().get("stateVersion", -1))
	var export_log_before := Array(state.snapshot().get("command_log", [])).size()
	_expect(state.dispatch({"type": "EXPORT_REPLAY"}), "Godot accepts browser EXPORT_REPLAY public command")
	_expect(int(state.snapshot().get("stateVersion", -1)) == export_version_before, "EXPORT_REPLAY does not advance authoritative stateVersion")
	_expect(Array(state.snapshot().get("command_log", [])).size() == export_log_before, "EXPORT_REPLAY stays out of deterministic command_log")
	var export_replay_result := Dictionary(state.snapshot().get("last_command_result", {}))
	_expect(String(export_replay_result.get("schema", "")) == "ysbzs.replay", "EXPORT_REPLAY stores browser-style replay document as last command result")
	_expect(Array(export_replay_result.get("commandStream", [])).size() == export_log_before, "EXPORT_REPLAY result mirrors commandStream size")
	_expect(state.dispatch({"type": "EXPORT_BATTLE_TRACE"}), "Godot accepts browser EXPORT_BATTLE_TRACE public command")
	_expect(int(state.snapshot().get("stateVersion", -1)) == export_version_before, "EXPORT_BATTLE_TRACE does not advance stateVersion")
	var export_trace_result := Dictionary(state.snapshot().get("last_command_result", {}))
	_expect(Array(export_trace_result.get("events", [])).size() == export_log_before, "EXPORT_BATTLE_TRACE returns current replay battleTrace events")
	_expect(state.dispatch({"type": "REPLAY_BATTLE_TRACE", "events": Array(export_trace_result.get("events", [])).duplicate(true)}), "Godot accepts browser REPLAY_BATTLE_TRACE public command")
	_expect(int(state.snapshot().get("stateVersion", -1)) == export_version_before, "REPLAY_BATTLE_TRACE does not advance stateVersion")
	var replay_trace_result := Dictionary(state.snapshot().get("lastCommandResult", {}))
	_expect(bool(replay_trace_result.get("replayed", false)), "REPLAY_BATTLE_TRACE reports replayed result")
	_expect(Array(replay_trace_result.get("events", [])).size() == export_log_before, "REPLAY_BATTLE_TRACE returns supplied events")
	_expect(roster_size_after_buy > 0, "purchase leaves the current formal roster populated")
	var stale_log_size := Array(state.snapshot().get("command_log", [])).size()
	_expect(not state.dispatch({"type": "EXIT_SHOP", "baseStateVersion": state_version_after_shop}), "stale baseStateVersion command is rejected like browser strictVersion")
	_expect(state.snapshot()["phase"] == "shop", "stale baseStateVersion rejection keeps current phase")
	_expect(int(state.snapshot().get("stateVersion", -1)) == state_version_after_buy, "stale baseStateVersion rejection preserves stateVersion")
	_expect(String(state.snapshot().get("stateHash", "")) == state_hash_after_buy, "stale baseStateVersion rejection preserves stateHash")
	_expect(Array(state.snapshot().get("command_log", [])).size() == stale_log_size, "stale baseStateVersion rejection does not enter playable command_log")
	_expect(_log_contains(state.snapshot()["log_lines"], "STATE_VERSION_MISMATCH"), "stale baseStateVersion rejection is visible in player log")
	var rejected_replay_doc: Dictionary = state.replay_document()
	var rejected_replay_summary := Dictionary(rejected_replay_doc.get("summary", {}))
	var rejected_debug_timeline := Array(rejected_replay_doc.get("debugTimeline", []))
	var rejected_debug_last := Dictionary(rejected_debug_timeline.back())
	_expect(Array(rejected_replay_doc.get("commandStream", [])).size() == stale_log_size, "rejected command stays out of deterministic replay commandStream")
	_expect(int(rejected_replay_summary.get("rejectedCommands", -1)) == 1, "Godot replay summary counts rejected commands like browser debugTimeline")
	_expect(int(rejected_replay_summary.get("timelineEntries", -1)) == stale_log_size + 1, "Godot replay summary includes rejected command in debugTimeline count")
	_expect(not bool(rejected_debug_last.get("accepted", true)), "Godot replay debugTimeline records rejected command as not accepted")
	_expect(not bool(rejected_debug_last.get("replayable", true)), "Godot replay debugTimeline marks rejected command as non-replayable")
	_expect(String(rejected_debug_last.get("type", "")) == "EXIT_SHOP", "Godot replay debugTimeline records rejected command type")
	var rejected_debug_error_value: Variant = rejected_debug_last.get("error", {})
	_expect(typeof(rejected_debug_error_value) == TYPE_DICTIONARY, "Godot replay debugTimeline records structured rejected command error")
	var rejected_debug_error := Dictionary(rejected_debug_error_value if typeof(rejected_debug_error_value) == TYPE_DICTIONARY else {})
	_expect(String(rejected_debug_error.get("code", "")) == "STATE_VERSION_MISMATCH", "Godot replay debugTimeline records rejected command error code")
	_expect(int(rejected_debug_last.get("beforeVersion", -1)) == state_version_after_buy, "rejected debugTimeline records current beforeVersion")
	_expect(int(rejected_debug_last.get("afterVersion", -1)) == state_version_after_buy, "rejected debugTimeline preserves afterVersion")
	_expect(String(rejected_debug_last.get("beforeHash", "")) == state_hash_after_buy, "rejected debugTimeline records current beforeHash")
	_expect(String(rejected_debug_last.get("afterHash", "")) == state_hash_after_buy, "rejected debugTimeline preserves afterHash")
	var protocol := Dictionary(state.snapshot().get("command_protocol", {}))
	var strict_actions := Array(protocol.get("strict_version_actions", []))
	var view_actions := Array(protocol.get("view_state_actions", []))
	var public_aliases := Dictionary(protocol.get("public_aliases", protocol.get("aliases", {})))
	var removed_trial_aliases := Array(protocol.get("removed_trial_aliases", []))
	var automation_aliases := Array(protocol.get("automation_aliases", []))
	var expected_strict_actions := [
		"CHOOSE_ROUTE",
		"PICK_NODE",
		"CLAIM_ROUTE_REWARD",
		"PICK_REWARD",
		"PICK_BATTLE_ENCOUNTER",
		"RUN_ROUTE_FIXED_BATTLE",
		"ENTER_SHOP",
		"BACK_TO_ROUTE",
		"EXIT_SHOP",
		"BUY_OFFER",
		"ROLL_SHOP",
		"APPLY_SHOP_EVENT",
		"APPLY_ROUTE_EVENT",
		"FREEZE_OFFER",
		"UNFREEZE_OFFER",
		"SELL_UNIT",
		"TOGGLE_UNIT_ACTIVE",
		"CONTINUE_AFTER_BATTLE",
		"START_BATTLE",
		"RUN_BATTLE",
		"RUN_FULL_DAY",
		"RUN_FULL_RUN",
		"NEW_RUN",
		"START_NEXT_DAY",
		"START_NEXT_ROUND",
		"RUN_MONSTER_TURN",
		"SELECT_UNIT",
		"SELECT_HERO",
		"SELECT_CELL",
		"SELECT_SLOT",
		"SELECT_ACTION_SLOT",
		"SET_ACTION_DIRECTION",
		"SET_SLOT_DIR",
		"SET_ACTION_AP",
		"SET_QUALITY_MODE",
		"SET_QUALITY_MARK",
		"USE_ACTION_SLOT",
		"USE_SLOT",
		"MOVE_HERO",
		"AUTO_POSITION_HEROES",
		"RUN_PLAYER_ALL_OUT",
		"END_PLAYER_TURN",
		"CLEAR_SELECTION"
	]
	var expected_view_actions := [
		"GENERATE_NODE_OPTIONS",
		"GENERATE_BATTLE_OPTIONS",
		"REWARD_OPTIONS",
		"BUILD_PREVIEW",
		"GET_CELL_DETAIL",
		"PREVIEW_MANUAL_FLOW",
		"EXPORT_REPLAY",
		"EXPORT_BATTLE_TRACE",
		"REPLAY_BATTLE_TRACE"
	]
	_expect(_contains_all_strings(strict_actions, expected_strict_actions), "command protocol lists every authoritative mutating action under strict-version coverage")
	_expect(_contains_all_strings(view_actions, expected_view_actions), "command protocol lists every read-only action outside strict-version coverage")
	_expect(_string_array_intersection(strict_actions, view_actions).is_empty(), "command protocol keeps strict mutating actions separate from view-state actions")
	_expect(_contains_all_strings(removed_trial_aliases, ["setupDay7FireTrial", "runDay7FireTurn1", "runDay7FireTrialAll"]), "command protocol documents removed temporary trial aliases")
	for removed_alias in removed_trial_aliases:
		_expect(not public_aliases.has(String(removed_alias)), "public command aliases exclude removed temporary trial alias %s" % String(removed_alias))
	_expect(_contains_all_strings(automation_aliases, ["runFullDay", "runFullPlayerDayFlow", "runFullRun"]), "command protocol keeps automation aliases auditable separately from trial leftovers")
	for strict_action in strict_actions:
		var stale_state := _new_legacy_state()
		var stale_snapshot := stale_state.snapshot()
		var stale_version := int(stale_snapshot.get("stateVersion", -1))
		var stale_hash := String(stale_snapshot.get("stateHash", ""))
		var stale_command_log_size := Array(stale_snapshot.get("command_log", [])).size()
		var rejected := stale_state.dispatch({"type": String(strict_action), "baseStateVersion": stale_version - 1})
		var rejected_snapshot := stale_state.snapshot()
		_expect(not rejected, "stale strict-version command %s is rejected before gameplay mutation" % String(strict_action))
		_expect(int(rejected_snapshot.get("stateVersion", -1)) == stale_version, "stale strict-version command %s preserves stateVersion" % String(strict_action))
		_expect(String(rejected_snapshot.get("stateHash", "")) == stale_hash, "stale strict-version command %s preserves stateHash" % String(strict_action))
		_expect(Array(rejected_snapshot.get("command_log", [])).size() == stale_command_log_size, "stale strict-version command %s stays out of command_log" % String(strict_action))
		var strict_debug_timeline := Array(stale_state.replay_document().get("debugTimeline", []))
		var strict_debug_last := Dictionary(strict_debug_timeline.back())
		_expect(String(strict_debug_last.get("type", "")) == String(strict_action), "stale strict-version command %s records debugTimeline type" % String(strict_action))
		var strict_debug_error_value: Variant = strict_debug_last.get("error", {})
		var strict_debug_error := Dictionary(strict_debug_error_value if typeof(strict_debug_error_value) == TYPE_DICTIONARY else {})
		_expect(String(strict_debug_error.get("code", "")) == "STATE_VERSION_MISMATCH", "stale strict-version command %s records mismatch error" % String(strict_action))
	_expect(state.save_replay_to_user(), "can write browser-style replay document with rejected debugTimeline to user storage")
	var saved_shop := state.save_document()
	_expect(String(saved_shop["schema"]) == "ysbzs.save", "save document uses browser save schema")
	_expect(int(saved_shop.get("schemaVersion", 0)) == StateScript.SAVE_SCHEMA_VERSION, "save document uses browser schemaVersion field")
	_expect(int(Dictionary(saved_shop["state"]).get("stateVersion", -1)) == state_version_after_buy, "save state preserves browser-style stateVersion")
	_expect(String(saved_shop.get("checksum", "")) != "", "save document exposes browser-style checksum")
	_expect(typeof(saved_shop.get("viewStates", null)) == TYPE_DICTIONARY, "save document exposes browser-compatible viewStates")
	var tampered_shop := saved_shop.duplicate(true)
	tampered_shop["state"]["coins"] = int(tampered_shop["state"]["coins"]) + 99
	_expect(not state.load_document(tampered_shop), "load rejects browser-schema save document with tampered checksum")
	_expect(state.save_to_user(), "can write save document to user storage")
	_expect(state.dispatch({"type": "EXIT_SHOP"}), "can exit shop through public command")
	_expect(int(state.snapshot().get("stateVersion", -1)) > state_version_after_buy, "exit shop advances stateVersion before load")
	_expect(state.snapshot()["phase"] == "route", "exit shop returns to route")
	_expect(state.load_from_user(), "can load save document from user storage")
	_expect(state.snapshot()["phase"] == "shop", "user storage load restores shop phase")
	_expect(int(state.snapshot().get("stateVersion", -1)) == state_version_after_buy, "user storage load restores stateVersion")
	_expect(state.dispatch({"type": "EXIT_SHOP"}), "can exit shop after user storage load")
	_expect(state.load_document(saved_shop), "can restore exported save document")
	_expect(state.snapshot()["phase"] == "shop", "load restores shop phase")
	_expect(state.snapshot()["roster"].size() == roster_size_after_buy, "load restores the exact purchased roster")
	_assert_state_round_trip(_new_legacy_state(), "route phase survives save/load/hash")
	var round_trip_shop_state := _new_legacy_state()
	_expect(round_trip_shop_state.dispatch({"type": "PICK_NODE", "nodeId": "node_shop_basic"}), "round-trip shop fixture can enter shop")
	_assert_state_round_trip(round_trip_shop_state, "shop phase survives save/load/hash")
	var round_trip_reward_state := _new_legacy_state()
	_expect(round_trip_reward_state.dispatch({"type": "PICK_NODE", "nodeId": "node_reward_pet"}), "round-trip reward fixture can enter reward")
	_assert_state_round_trip(round_trip_reward_state, "reward phase survives save/load/hash")
	var round_trip_battle_state := _new_legacy_state()
	_expect(round_trip_battle_state.dispatch({"type": "START_BATTLE"}), "round-trip battle fixture can start battle")
	_assert_state_round_trip(round_trip_battle_state, "battle phase survives save/load/hash")
	var round_trip_day_end_state := _new_legacy_state()
	_drive_current_day_to_end(round_trip_day_end_state)
	_assert_state_round_trip(round_trip_day_end_state, "day_end phase survives save/load/hash")
	_finish("SMOKE_SINGLEPLAYER_PERSISTENCE_OK")
