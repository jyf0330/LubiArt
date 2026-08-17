extends RefCounted

## Creates a disposable developer Session over a simulation authority. All
## persistence repositories are deny/record guards, so fixture experiments
## cannot pollute saves, replays, operation logs, or run history.

const YsbzsStateScript := preload("res://core/state/game_state.gd")
const SimulationAuthorityFactoryScript := preload("res://session/simulation_authority_factory.gd")
const LocalGameSessionScript := preload("res://session/local_game_session.gd")

const RESULT_SCHEMA := "ysbzs.developer-scenario-session-result.v1"


static func create_result(options: Dictionary = {}) -> Dictionary:
	var source: RefCounted = YsbzsStateScript.new()
	var source_initialization := Dictionary(source.call("initialization_result"))
	if not bool(source.call("is_initialized")):
		return _result(false, null, null, source_initialization, "", ["DEVELOPER_SCENARIO_SOURCE_INIT_FAILED"])
	var simulation_factory: RefCounted = SimulationAuthorityFactoryScript.new()
	var create_options := {
		"seed": String(options.get("run_seed", "ysbzs-developer-scenario")),
		"contentSourceKind": source.call("content_source_kind"),
	}
	if options.has("board_dimensions"):
		create_options["boardDimensions"] = options.get("board_dimensions")
	var created := Dictionary(simulation_factory.call(
		"create",
		YsbzsStateScript,
		Dictionary(source.get("game_data")).duplicate(true),
		create_options
	))
	var guard := created.get("ioGuard") as RefCounted
	if not bool(created.get("ok", false)):
		return _result(false, null, guard, source_initialization, String(source.call("_content_hash")), Array(created.get("errors", [])))
	var authority := created.get("authority") as RefCounted
	authority.set("history_recording_enabled", false)
	authority.set("_history_suspended", true)
	var session: RefCounted = LocalGameSessionScript.new(authority, "developer")
	if not Array(guard.call("attempts")).is_empty():
		return _result(false, null, guard, source_initialization, String(source.call("_content_hash")), ["DEVELOPER_SCENARIO_SESSION_IO_ATTEMPT"])
	return _result(true, session, guard, Dictionary(authority.call("initialization_result")), String(source.call("_content_hash")), [])


static func _result(ok: bool, session: RefCounted, guard: RefCounted, initialization: Dictionary, content_hash: String, errors: Array) -> Dictionary:
	var copied_errors: Array[String] = []
	for value in errors:
		copied_errors.append(String(value))
	return {
		"schema": RESULT_SCHEMA,
		"ok": ok,
		"session": session,
		"ioGuard": guard,
		"initialization": initialization.duplicate(true),
		"contentHash": content_hash,
		"persistencePolicy": "deny",
		"errors": copied_errors,
	}
