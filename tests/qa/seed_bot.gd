extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const CONFIG_PATH := "res://qa/seed_matrix.json"

var _failed := false
var _results: Array[Dictionary] = []
var _failures: Array[Dictionary] = []
var _output_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = _argument_value("--qa-output=", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var config := _load_config()
	var requested_count := int(_argument_value("--qa-seed-count=", "0"))
	var fixed_seeds := Array(config.get("fixedSeeds", []))
	var seed_count: int = requested_count if requested_count > 0 else maxi(1, fixed_seeds.size())
	var dimensions := Array(config.get("dimensions", [{"width": 8, "height": 7}]))
	var difficulties := Array(config.get("difficulties", ["normal"]))
	var max_case_ms := int(config.get("maxCaseMilliseconds", 45000))
	var minimum_commands := int(config.get("minimumCommands", 2))
	var max_commands := int(config.get("maxCommands", 400))

	for index in range(seed_count):
		var seed := String(fixed_seeds[index]) if index < fixed_seeds.size() else "qa-generated-%04d" % index
		var dimension := Dictionary(dimensions[index % dimensions.size()])
		var difficulty := String(difficulties[index % difficulties.size()])
		var result := _run_case(
			index,
			seed,
			int(dimension.get("width", 8)),
			int(dimension.get("height", 7)),
			difficulty,
			max_case_ms,
			minimum_commands,
			max_commands
		)
		_results.append(result)

	var report := {
		"schema": "ysbzs.qa.seed-bot.v1",
		"flow": "RUN_FULL_DAY",
		"status": "failed" if _failed else "passed",
		"caseCount": _results.size(),
		"failureCount": _failures.size(),
		"results": _results,
		"failures": _failures
	}
	_expect(_write_json(_output_dir.path_join("seed_bot_results.json"), report), "seed bot report can be written")
	if _failed:
		print("QA_SEED_BOT_FAIL cases=%d failures=%d output=%s" % [_results.size(), _failures.size(), _output_dir])
		quit(1)
		return
	print("QA_SEED_BOT_OK cases=%d output=%s" % [_results.size(), _output_dir])
	quit(0)


func _run_case(
	index: int,
	seed: String,
	width: int,
	height: int,
	difficulty: String,
	max_case_ms: int,
	minimum_commands: int,
	max_commands: int
) -> Dictionary:
	var state: RefCounted = StateScript.new()
	var case_failures: Array[String] = []
	var started := Time.get_ticks_msec()
	_case_expect(
			bool(state.call("dispatch", {
				"type": "NEW_RUN",
				"seed": seed,
				"boardWidth": width,
				"boardHeight": height
			})),
		"NEW_RUN is accepted",
		case_failures
	)
	_case_expect(
			bool(state.call("dispatch", {"type": "SET_DIFFICULTY", "difficulty": difficulty})),
		"difficulty is accepted",
		case_failures
	)
	_case_expect(
		bool(state.call("dispatch", {"type": "RUN_FULL_DAY"})),
		"virtual player completes one full game day",
		case_failures
	)
	var elapsed_ms := Time.get_ticks_msec() - started
	var snapshot := Dictionary(state.call("snapshot"))
	var replay := Dictionary(state.call("replay_document"))
	var command_count := Array(replay.get("commandStream", [])).size()

	_case_expect(
		String(snapshot.get("phase", "")) in ["day_end", "game_over"],
		"final phase is day_end or game_over",
		case_failures
	)
	_case_expect(
		int(snapshot.get("boardWidth", snapshot.get("board_width", 0))) == width,
		"board width remains stable",
		case_failures
	)
	_case_expect(
		int(snapshot.get("boardHeight", snapshot.get("board_height", 0))) == height,
		"board height remains stable",
		case_failures
	)
	_case_expect(
		String(snapshot.get("stateHash", "")).length() == 16,
		"final state hash is present",
		case_failures
	)
	_case_expect(
		command_count >= minimum_commands and command_count <= max_commands,
		"command count stays within the configured budget",
		case_failures
	)
	_case_expect(
		elapsed_ms <= max_case_ms,
		"case finishes inside the performance budget",
		case_failures
	)
	_case_expect(
		_no_duplicate_living_positions(snapshot, width, height),
		"living units have unique in-bounds positions",
		case_failures
	)
	_case_expect(
		int(snapshot.get("heroHp", snapshot.get("hero_hp", 0))) >= 0,
		"player hero HP is non-negative",
		case_failures
	)
	_case_expect(
		int(snapshot.get("enemyHeroHp", snapshot.get("enemy_hero_hp", 0))) >= 0,
		"enemy hero HP is non-negative",
		case_failures
	)

	var replay_result := Dictionary(state.call("verify_replay_document", replay))
	_case_expect(bool(replay_result.get("ok", false)), "deterministic replay verifies every checkpoint", case_failures)
	var save_document := Dictionary(state.call("save_document", "qa-seed-bot"))
	var restored: RefCounted = StateScript.new()
	_case_expect(bool(restored.call("load_document", save_document)), "save document reloads", case_failures)
	var restored_snapshot := Dictionary(restored.call("snapshot"))
	_case_expect(
		String(restored_snapshot.get("stateHash", "")) == String(snapshot.get("stateHash", "")),
		"save/load preserves the final state hash",
		case_failures
	)

	var result := {
		"index": index,
		"seed": seed,
		"board": {"width": width, "height": height},
		"difficulty": difficulty,
		"status": "failed" if not case_failures.is_empty() else "passed",
		"elapsedMilliseconds": elapsed_ms,
		"commandCount": command_count,
		"phase": String(snapshot.get("phase", "")),
		"day": int(snapshot.get("day", 0)),
		"stateVersion": int(snapshot.get("stateVersion", -1)),
		"stateHash": String(snapshot.get("stateHash", "")),
		"staticMemoryBytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"failures": case_failures
	}
	if not case_failures.is_empty():
		_failed = true
		_failures.append(result)
		var case_name := "%03d_%s_%dx%d_%s" % [index, _safe_name(seed), width, height, difficulty]
		_write_json(_output_dir.path_join(case_name + ".replay.json"), replay)
		_write_json(_output_dir.path_join(case_name + ".save.json"), save_document)
		for message in case_failures:
			push_error("QA_SEED_BOT_CASE_FAIL [%s]: %s" % [case_name, message])
	return result


func _no_duplicate_living_positions(snapshot: Dictionary, width: int, height: int) -> bool:
	var occupied := {}
	for value in Array(snapshot.get("units", [])):
		var unit := Dictionary(value)
		if int(unit.get("hp", 0)) <= 0:
			continue
		var x := int(unit.get("x", -1))
		var y := int(unit.get("y", -1))
		if x < 0 or x >= width or y < 0 or y >= height:
			return false
		var key := "%d,%d" % [x, y]
		if occupied.has(key):
			return false
		occupied[key] = String(unit.get("id", ""))
	return true


func _load_config() -> Dictionary:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		_expect(false, "seed matrix can be opened")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_expect(false, "seed matrix is a JSON object")
		return {}
	return Dictionary(parsed)


func _argument_value(prefix: String, fallback: String) -> String:
	for value in OS.get_cmdline_user_args():
		var argument := String(value)
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _safe_name(value: String) -> String:
	var result := ""
	for character in value:
		result += character if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-" else "_"
	return result.left(64)


func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t", false))
	file.flush()
	return true


func _case_expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("QA_SEED_BOT_FAIL: %s" % message)
