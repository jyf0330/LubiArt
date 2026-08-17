extends RefCounted

const YsbzsStateScript := preload("res://core/state/game_state.gd")
const LocalGameSessionScript := preload("res://session/local_game_session.gd")
const BoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")
const DeveloperScenarioSessionFactoryScript := preload("res://session/developer_scenario_session_factory.gd")


static func create_local_result(options: Dictionary = {}) -> Dictionary:
	var content_pack_value: Variant = options.get("content_pack", {})
	var core_overrides_value: Variant = options.get("core_overrides", {})
	var authority = YsbzsStateScript.new({
		"mode": String(options.get("mode", "production")),
		"content_pack": Dictionary(content_pack_value).duplicate(true) if typeof(content_pack_value) == TYPE_DICTIONARY else {},
		"core_overrides": Dictionary(core_overrides_value).duplicate(true) if typeof(core_overrides_value) == TYPE_DICTIONARY else core_overrides_value,
	})
	var initialization := Dictionary(authority.call("initialization_result"))
	if not bool(authority.call("is_initialized")):
		return {"ok": false, "session": null, "initialization": initialization}
	var run_seed := String(options.get("run_seed", "")).strip_edges()
	if run_seed != "":
		authority.set_run_seed(run_seed)
	var dimensions := _dimensions_from_value(options.get("board_dimensions", Vector2i.ZERO))
	if dimensions.x > 0 and dimensions.y > 0:
		authority.set_board_dimensions(dimensions.x, dimensions.y)
	# Per-command run-history persistence is an explicit diagnostics mode. Normal
	# play relies on manual/periodic saves and keeps click handling in memory.
	if bool(options.get("run_history", false)) and authority.has_method("enable_run_history"):
		authority.call("enable_run_history", true)
	return {
		"ok": true,
		"session": LocalGameSessionScript.new(authority, String(options.get("command_scope", "player"))),
		"initialization": initialization,
	}


static func create_local(options: Dictionary = {}) -> RefCounted:
	var result := create_local_result(options)
	if bool(result.get("ok", false)):
		return result.get("session") as RefCounted
	push_error("LOCAL_GAME_SESSION_INIT_FAILED:%s" % JSON.stringify(result.get("initialization", {})))
	return null


static func create_isolated_developer_result(options: Dictionary = {}) -> Dictionary:
	return Dictionary(DeveloperScenarioSessionFactoryScript.create_result(options))


static func wrap_local_authority(authority: RefCounted, command_scope: String = "player") -> RefCounted:
	if authority != null and authority.has_method("is_initialized") and not bool(authority.call("is_initialized")):
		push_error("LOCAL_GAME_SESSION_AUTHORITY_NOT_INITIALIZED:%s" % JSON.stringify(authority.call("initialization_result")))
		return null
	return LocalGameSessionScript.new(authority, command_scope)


static func command_line_board_dimensions(args: PackedStringArray = OS.get_cmdline_user_args()) -> Vector2i:
	for arg_value in args:
		var arg := String(arg_value).strip_edges()
		if not arg.begins_with("--board=") and not arg.begins_with("--board-size="):
			continue
		var raw := arg.split("=", false, 1)[1].to_lower().replace("×", "x")
		var parts := raw.split("x", false)
		if parts.size() == 2:
			return BoardDimensionsScript.normalized(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO


static func _dimensions_from_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value as Vector2i
	if typeof(value) == TYPE_DICTIONARY:
		var row := Dictionary(value)
		return BoardDimensionsScript.normalized(
			int(row.get("width", row.get("x", 0))),
			int(row.get("height", row.get("y", 0)))
		)
	return Vector2i.ZERO
