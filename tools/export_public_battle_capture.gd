extends SceneTree

const SessionFactoryScript := preload("res://session/session_factory.gd")

const LOAD_SLOT := 2
const MAX_BATTLE_CYCLES := 40
const PRESENTATION_RUN_SEED := "ysbzs-test-play-20260715-v1"


func _initialize() -> void:
	var output_path := _output_path()
	var use_fresh_fixed_seed := _has_user_arg("--fresh-fixed-seed")
	var first_round_only := _has_user_arg("--first-round-only")
	var max_battle_cycles := 1 if first_round_only else MAX_BATTLE_CYCLES
	if output_path == "":
		push_error("PUBLIC_BATTLE_CAPTURE_FAIL: pass --output=<path>")
		quit(2)
		return

	var creation := Dictionary(SessionFactoryScript.create_local_result({
		"run_seed": PRESENTATION_RUN_SEED,
		"command_scope": "developer",
	}))
	if not bool(creation.get("ok", false)):
		print("PUBLIC_BATTLE_CAPTURE_INIT_FAILED:%s" % JSON.stringify(creation.get("initialization", {})))
		quit(3)
		return
	var session := creation.get("session") as RefCounted
	if session == null or not bool(session.call("connect_session")):
		push_error("PUBLIC_BATTLE_CAPTURE_FAIL: LocalGameSession is unavailable")
		quit(3)
		return
	var presentation_bootstrap_snapshot := Dictionary(
		session.call("current_snapshot")
	).duplicate(true)
	var loaded_snapshot := presentation_bootstrap_snapshot.duplicate(true)
	var bootstrap_command := "FRESH_FIXED_SEED_THEN_START_BATTLE"
	var source_load_slot := -1
	if not use_fresh_fixed_seed:
		if not bool(session.call("supports_persistence")) \
				or not bool(session.call("load_from_slot", LOAD_SLOT)):
			push_error("PUBLIC_BATTLE_CAPTURE_FAIL: cannot load formal save slot %d" % LOAD_SLOT)
			quit(4)
			return
		loaded_snapshot = Dictionary(session.call("current_snapshot")).duplicate(true)
		bootstrap_command = "LOAD_SLOT_2_THEN_START_BATTLE_IF_NEEDED"
		source_load_slot = LOAD_SLOT
	if String(loaded_snapshot.get("phase", "")) != "battle":
		var start_response := Dictionary(session.call("submit_command", {"type": "START_BATTLE"}))
		if not bool(start_response.get("accepted", false)):
			push_error("PUBLIC_BATTLE_CAPTURE_FAIL: START_BATTLE rejected after load slot %d: %s" % [
				LOAD_SLOT,
				JSON.stringify(start_response),
			])
			quit(5)
			return

	var initial_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	if String(initial_snapshot.get("phase", "")) != "battle":
		push_error("PUBLIC_BATTLE_CAPTURE_FAIL: load slot %d did not reach battle" % LOAD_SLOT)
		quit(6)
		return

	var steps: Array = []
	var previous_snapshot := initial_snapshot
	var battle_cycles := 0
	while String(previous_snapshot.get("phase", "")) == "battle" \
			and battle_cycles < max_battle_cycles:
		var positioned_snapshot := _capture_step(
			session,
			{"type": "AUTO_POSITION_HEROES"},
			steps,
			previous_snapshot
		)
		if positioned_snapshot.is_empty():
			quit(7)
			return
		var resolved_snapshot := _capture_step(
			session,
			{"type": "RUN_COMBAT_ROUND"},
			steps,
			positioned_snapshot
		)
		if resolved_snapshot.is_empty():
			quit(8)
			return
		previous_snapshot = resolved_snapshot
		battle_cycles += 1
	if String(previous_snapshot.get("phase", "")) == "battle" and not first_round_only:
		push_error("PUBLIC_BATTLE_CAPTURE_FAIL: battle did not settle within %d cycles" % MAX_BATTLE_CYCLES)
		quit(9)
		return

	var board := Dictionary(initial_snapshot.get("board", {}))
	var capture := {
		"capture_schema_version": 1,
		"source": {
			"project": "godot-latest",
			"session": "LocalGameSession",
			"snapshot_method": "current_snapshot",
			"load_slot": source_load_slot,
			"loaded_snapshot_identity": {
				"stateVersion": int(loaded_snapshot.get("stateVersion", -1)),
				"stateHash": String(loaded_snapshot.get("stateHash", "")),
				"phase": String(loaded_snapshot.get("phase", "")),
				"day": int(loaded_snapshot.get("day", 0)),
				"nodeIndex": int(loaded_snapshot.get("node_index", 0)),
			},
			"run_seed": String(initial_snapshot.get("run_seed", "")),
			"board": {
				"width": int(board.get("width", initial_snapshot.get("boardWidth", 0))),
				"height": int(board.get("height", initial_snapshot.get("boardHeight", 0))),
			},
			"bootstrap_command": bootstrap_command,
			"button_cycle": ["AUTO_POSITION_HEROES", "RUN_COMBAT_ROUND"],
			"capture_scope": "first_round_only" if first_round_only else "repeat_two_buttons_until_battle_end",
		},
		"presentation_bootstrap_snapshot": presentation_bootstrap_snapshot,
		"initial_snapshot": initial_snapshot,
		"steps": steps,
	}
	if not _write_json(output_path, capture):
		quit(10)
		return

	print("PUBLIC_BATTLE_CAPTURE_OK output=%s loadSlot=%d bootstrap=%s loadedVersion=%d loadedHash=%s cycles=%d steps=%d initialVersion=%d initialHash=%s finalVersion=%d finalHash=%s phase=%s" % [
		output_path,
		source_load_slot,
		bootstrap_command,
		int(loaded_snapshot.get("stateVersion", -1)),
		String(loaded_snapshot.get("stateHash", "")),
		battle_cycles,
		steps.size(),
		int(initial_snapshot.get("stateVersion", -1)),
		String(initial_snapshot.get("stateHash", "")),
		int(previous_snapshot.get("stateVersion", -1)),
		String(previous_snapshot.get("stateHash", "")),
		String(previous_snapshot.get("phase", "")),
	])
	quit()


func _capture_step(
	session: RefCounted,
	command: Dictionary,
	steps: Array,
	before_snapshot: Dictionary
) -> Dictionary:
	var raw_response := Dictionary(session.call("submit_command", command.duplicate(true))).duplicate(true)
	if not bool(raw_response.get("accepted", false)):
		push_error("PUBLIC_BATTLE_CAPTURE_FAIL: %s rejected: %s" % [
			String(command.get("type", "")),
			JSON.stringify(raw_response),
		])
		return {}
	var response := {
		"accepted": bool(raw_response.get("accepted", false)),
		"pending": bool(raw_response.get("pending", false)),
		"status": String(raw_response.get("status", "")),
		"ok": bool(raw_response.get("ok", false)),
		"stateVersion": int(raw_response.get("stateVersion", -1)),
		"stateHash": String(raw_response.get("stateHash", "")),
		"result": Dictionary(raw_response.get("result", {})).duplicate(true),
		"timing": Dictionary(raw_response.get("timing", {})).duplicate(true),
	}
	var after_snapshot := Dictionary(session.call("current_snapshot")).duplicate(true)
	steps.append({
		"command": command.duplicate(true),
		"response": response,
		"snapshot_delta": _top_level_snapshot_delta(before_snapshot, after_snapshot),
		"snapshot_identity": {
			"stateVersion": int(after_snapshot.get("stateVersion", -1)),
			"stateHash": String(after_snapshot.get("stateHash", "")),
			"phase": String(after_snapshot.get("phase", "")),
			"battleRound": int(after_snapshot.get("battle_round", 0)),
		},
	})
	return after_snapshot


func _top_level_snapshot_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var set_values := {}
	var removed_keys: Array = []
	for key_value in before.keys():
		var key := String(key_value)
		if not after.has(key):
			removed_keys.append(key)
	for key_value in after.keys():
		var key := String(key_value)
		if not before.has(key) or before[key] != after[key]:
			set_values[key] = after[key]
	removed_keys.sort()
	return {
		"set": set_values,
		"remove": removed_keys,
	}


func _output_path() -> String:
	for arg_value in OS.get_cmdline_user_args():
		var arg := String(arg_value)
		if arg.begins_with("--output="):
			return arg.trim_prefix("--output=").strip_edges()
	return ""


func _has_user_arg(expected: String) -> bool:
	for arg_value in OS.get_cmdline_user_args():
		if String(arg_value) == expected:
			return true
	return false


func _write_json(path: String, value: Dictionary) -> bool:
	var parent := path.get_base_dir()
	if parent != "" and not DirAccess.dir_exists_absolute(parent):
		var error := DirAccess.make_dir_recursive_absolute(parent)
		if error != OK:
			push_error("PUBLIC_BATTLE_CAPTURE_FAIL: cannot create %s (error %d)" % [parent, error])
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("PUBLIC_BATTLE_CAPTURE_FAIL: cannot open %s for writing" % path)
		return false
	file.store_string(JSON.stringify(value, "", false) + "\n")
	return true
