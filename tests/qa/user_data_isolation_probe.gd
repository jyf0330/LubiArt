extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var token := _argument_value("--qa-probe=", "probe")
	var output_dir := _argument_value("--qa-output=", "")
	var user_dir := OS.get_user_data_dir()
	_expect(user_dir.contains("YSBZS_QA"), "user:// must use the isolated QA namespace")
	_expect(not user_dir.contains("YSBZS Godot Singleplayer"), "QA must not use the player's real save directory")

	var marker_path := "user://qa_isolation_%s.json" % _safe_name(token)
	var marker := {
		"schema": "ysbzs.qa.user-isolation.v1",
		"token": token,
		"userDataDir": user_dir
	}
	_expect(_write_json(marker_path, marker), "probe can write its isolated user:// marker")
	_expect(FileAccess.file_exists(marker_path), "probe marker exists in isolated user://")
	if output_dir != "":
		_expect(
			_write_json(output_dir.path_join("user_data_probe.json"), marker),
			"probe result is copied to the explicit evidence directory"
		)

	if _failed:
		quit(1)
		return
	print("QA_USER_DATA_ISOLATION_OK token=%s dir=%s" % [token, user_dir])
	quit(0)


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
	return result


func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t", false))
	file.flush()
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("QA_USER_DATA_ISOLATION_FAIL: %s" % message)
