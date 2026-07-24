extends RefCounted

class_name GameLog

const ENV_LOG := "YSBZS_LOG"
const ENV_OPERATION_LOG := "YSBZS_OPERATION_LOG"
const ARG_ENABLE := "--ysbzs-log"
const ARG_DISABLE := "--no-ysbzs-log"

static var _enabled_override: Variant = null
static var _operation_log_override: Variant = null


static func is_enabled() -> bool:
	if _enabled_override != null:
		return bool(_enabled_override)
	return enabled_for_build(OS.is_debug_build(), OS.get_environment(ENV_LOG), OS.get_cmdline_user_args())


static func operation_log_enabled() -> bool:
	if _operation_log_override != null:
		return bool(_operation_log_override)
	var environment_value := OS.get_environment(ENV_OPERATION_LOG)
	if environment_value != "":
		return _parse_switch(environment_value, is_enabled())
	return is_enabled()


static func enabled_for_build(is_debug_build: bool, environment_value: String = "", arguments: Array = []) -> bool:
	if ARG_DISABLE in arguments:
		return false
	if ARG_ENABLE in arguments:
		return true
	if environment_value != "":
		return _parse_switch(environment_value, is_debug_build)
	return is_debug_build


static func set_enabled_override(value: Variant) -> void:
	_enabled_override = value


static func set_operation_log_override(value: Variant) -> void:
	_operation_log_override = value


static func reset_overrides() -> void:
	_enabled_override = null
	_operation_log_override = null


static func debug(area: String, message: String, context: Dictionary = {}) -> void:
	_write("调试", area, message, context)


static func info(area: String, message: String, context: Dictionary = {}) -> void:
	_write("信息", area, message, context)


static func warning(area: String, message: String, context: Dictionary = {}) -> void:
	_write("警告", area, message, context)


static func error(area: String, message: String, context: Dictionary = {}) -> void:
	_write("错误", area, message, context)


static func format_line(level: String, area: String, message: String, context: Dictionary = {}, timestamp: String = "") -> String:
	var resolved_timestamp := timestamp if timestamp != "" else Time.get_time_string_from_system()
	var line := "[%s][%s][%s] %s" % [resolved_timestamp, level, area, message]
	var context_text := _format_context(context)
	if context_text != "":
		line += " | " + context_text
	return line


static func _write(level: String, area: String, message: String, context: Dictionary) -> void:
	if not is_enabled():
		return
	print(format_line(level, area, message, context))


static func _format_context(context: Dictionary) -> String:
	var keys := context.keys()
	keys.sort_custom(func(left, right): return String(left) < String(right))
	var parts: Array[String] = []
	for key_value in keys:
		var key := String(key_value)
		parts.append("%s=%s" % [key, _human_value(context[key_value])])
	return " · ".join(parts)


static func _human_value(value: Variant) -> String:
	if value == null:
		return "无"
	if value is String or value is StringName:
		return String(value).replace("\n", "\\n")
	if value is bool:
		return "是" if bool(value) else "否"
	if value is Vector2i:
		return "(%d,%d)" % [value.x, value.y]
	if value is Vector2:
		return "(%.1f,%.1f)" % [value.x, value.y]
	if value is Dictionary or value is Array:
		return JSON.stringify(value, "", false)
	return str(value)


static func _parse_switch(value: String, fallback: bool) -> bool:
	match value.strip_edges().to_lower():
		"1", "true", "yes", "on", "debug", "verbose":
			return true
		"0", "false", "no", "off", "release", "quiet":
			return false
	return fallback
