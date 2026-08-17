extends SceneTree

const WriterScript := preload("res://core_ui/scripts/battle/controllers/battle_log_local_writer.gd")
const TEST_PATH := "user://smoke_battle_log_local_file/latest_battle.txt"

var failed := false


func _init() -> void:
	_run()
	_cleanup()
	if failed:
		quit(1)
		return
	print("SMOKE_BATTLE_LOG_LOCAL_FILE_OK")
	quit(0)


func _run() -> void:
	_cleanup()
	var writer := WriterScript.new()
	_expect(not writer.enabled_for_build(false), "Release build keeps battle text files disabled")
	_expect(not writer.enabled_for_build(false, "on"), "Release cannot opt back into battle text files")
	_expect(writer.enabled_for_build(true), "Debug build enables battle text files by default")
	_expect(not writer.enabled_for_build(true, "off"), "Debug environment switch can disable battle text files")
	_expect(writer.output_path == "user://battle_logs/latest_battle.txt", "Debug writer uses the stable latest-battle path")

	writer.configure_for_test(TEST_PATH, false)
	_expect(not writer.write_lines(["不应写入"]), "disabled writer reports no write")
	_expect(not FileAccess.file_exists(TEST_PATH), "disabled writer creates no file")

	writer.configure_for_test(TEST_PATH, true)
	var lines := [
		"第1回合 · 自动布置：焰牙从第6行第1列移动到第2行第1列",
		"第1回合 · 我方焰牙攻击敌方焰牙：14点伤害（生命46→32）",
	]
	_expect(writer.write_lines(lines), "enabled Debug writer saves plain-language battle text")
	var text := FileAccess.get_file_as_string(TEST_PATH)
	_expect(text.contains("开发测试文件"), "local file clearly identifies development-only purpose")
	_expect(text.find(String(lines[0])) < text.find(String(lines[1])), "local file keeps chronological event order")
	_expect(not text.contains("R2C1") and not text.contains("HP "), "local file uses player-readable language")


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var directory := ProjectSettings.globalize_path(TEST_PATH).get_base_dir()
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_BATTLE_LOG_LOCAL_FILE_FAIL: %s" % message)
