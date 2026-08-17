extends SceneTree

const SessionTokenScript := preload("res://session/auth/session_token.gd")


func _initialize() -> void:
	var values := {}
	for arg_value in OS.get_cmdline_user_args():
		var arg := String(arg_value)
		if arg.begins_with("--") and arg.contains("="):
			var parts := arg.trim_prefix("--").split("=", false, 1)
			values[String(parts[0])] = String(parts[1])
	var secret := OS.get_environment("YSBZS_SESSION_SECRET")
	var token := SessionTokenScript.issue(
		secret,
		String(values.get("actor", "")),
		String(values.get("session", OS.get_environment("YSBZS_SESSION_ID"))),
		int(values.get("ttl", "300")),
		String(values.get("scope", "player"))
	)
	if token == "":
		push_error("TOKEN_ISSUE_FAILED: require a 32+ byte environment secret, actor and session")
		quit(64)
		return
	print(token)
	quit(0)
