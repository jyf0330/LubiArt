extends SceneTree

const GameLogScript := preload("res://core/logging/game_log.gd")
const StateScript := preload("res://core/state/game_state.gd")

const TEST_OPERATION_PATH := "user://smoke_game_log_operations.jsonl"


func _init() -> void:
	if not _run():
		quit(1)
		return
	print("SMOKE_GAME_LOG_OK")
	quit(0)


func _run() -> bool:
	if GameLogScript.enabled_for_build(false):
		return _fail("Release 构建必须默认关闭运行日志。")
	if not GameLogScript.enabled_for_build(true):
		return _fail("Debug 构建必须默认开启运行日志。")
	if not GameLogScript.enabled_for_build(false, "on"):
		return _fail("Release 必须允许用 YSBZS_LOG=on 显式开启日志。")
	if GameLogScript.enabled_for_build(true, "off"):
		return _fail("Debug 必须允许用 YSBZS_LOG=off 显式关闭日志。")
	if not GameLogScript.enabled_for_build(false, "", ["--ysbzs-log"]):
		return _fail("命令行参数必须能显式开启日志。")
	if GameLogScript.enabled_for_build(true, "", ["--no-ysbzs-log"]):
		return _fail("命令行参数必须能显式关闭日志。")

	var line := GameLogScript.format_line("信息", "战斗/开始行动", "本回合结算完成", {
		"成功": true,
		"回合": 5,
		"阶段": "battle"
	}, "12:34:56")
	var expected := "[12:34:56][信息][战斗/开始行动] 本回合结算完成 | 回合=5 · 成功=是 · 阶段=battle"
	if line != expected:
		return _fail("人类可读日志格式不稳定：%s" % line)

	_remove_test_operation_log()
	var state := StateScript.new()
	state.player_operation_log_path = TEST_OPERATION_PATH
	GameLogScript.set_operation_log_override(false)
	if bool(state.call("_append_player_operation", {"kind": "disabled"})):
		return _fail("关闭持久日志时不应报告写入成功。")
	if FileAccess.file_exists(TEST_OPERATION_PATH):
		return _fail("关闭持久日志时不应创建 JSONL 文件。")
	GameLogScript.set_operation_log_override(true)
	if not bool(state.call("_append_player_operation", {"kind": "enabled"})):
		return _fail("显式开启持久日志后应该可以写入。")
	if not FileAccess.file_exists(TEST_OPERATION_PATH):
		return _fail("显式开启持久日志后没有创建 JSONL 文件。")
	var saved_text := FileAccess.get_file_as_string(TEST_OPERATION_PATH)
	if "\"kind\":\"enabled\"" not in saved_text:
		return _fail("持久日志没有保存预期的人类操作记录。")
	_remove_test_operation_log()
	GameLogScript.reset_overrides()
	return true


func _remove_test_operation_log() -> void:
	if FileAccess.file_exists(TEST_OPERATION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_OPERATION_PATH))


func _fail(message: String) -> bool:
	_remove_test_operation_log()
	GameLogScript.reset_overrides()
	push_error("SMOKE_GAME_LOG_FAIL: %s" % message)
	return false
