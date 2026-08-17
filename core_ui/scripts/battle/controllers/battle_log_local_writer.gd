extends RefCounted

## Development-only local copy of the same plain-language lines rendered by the
## battle dashboard. Release builds are hard-disabled and cannot opt back in.

const DEFAULT_PATH := "user://battle_logs/latest_battle.txt"
const ENV_ENABLED := "YSBZS_BATTLE_TEXT_LOG"

var output_path := DEFAULT_PATH
var _enabled_override: Variant = null


func is_enabled() -> bool:
	if not OS.is_debug_build():
		return false
	if _enabled_override != null:
		return bool(_enabled_override)
	return enabled_for_build(true, OS.get_environment(ENV_ENABLED))


func enabled_for_build(is_debug_build: bool, environment_value: String = "") -> bool:
	if not is_debug_build:
		return false
	match environment_value.strip_edges().to_lower():
		"0", "false", "no", "off", "quiet":
			return false
	return true


func configure_for_test(path: String, enabled: bool) -> void:
	output_path = path
	_enabled_override = enabled


func write_lines(lines: Array) -> bool:
	if not is_enabled() or lines.is_empty():
		return false
	var absolute_path := ProjectSettings.globalize_path(output_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return false
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_line("战斗过程（开发测试文件）")
	file.store_line("说明：内容来自游戏实际战斗数据，按发生顺序排列。")
	file.store_line("")
	for line_value in lines:
		file.store_line(String(line_value))
	file.close()
	return true
