extends Node

## Local, privacy-preserving production diagnostics. A boot marker detects an
## unclean previous exit; bounded performance samples and explicit application
## errors are written as structured reports that support later opt-in upload.

const SCHEMA := "ysbzs.runtime-diagnostics.v1"
const MAX_REPORTS := 20
const MAX_SAMPLES := 600

var _base_path := "user://diagnostics"
var _session_id := ""
var _started_unix := 0
var _samples: Array = []
var _errors: Array = []
var _sample_accumulator := 0.0
var _active := false


func start(base_path: String = "user://diagnostics") -> Dictionary:
	_base_path = base_path.trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_base_path))
	var previous := _read_json(_marker_path())
	if not previous.is_empty():
		_write_report("unclean-exit", {
			"reason": "previous_session_did_not_close_cleanly",
			"previousSession": previous,
		})
	_started_unix = int(Time.get_unix_time_from_system())
	_session_id = "%d-%d" % [_started_unix, Time.get_ticks_msec()]
	_samples.clear()
	_errors.clear()
	_active = _write_json(_marker_path(), {
		"schema": SCHEMA,
		"sessionId": _session_id,
		"startedAtUnix": _started_unix,
		"gameVersion": ProjectSettings.get_setting("application/config/version", "development"),
		"platform": OS.get_name(),
	})
	set_process(_active)
	_rotate_reports()
	return {"ok": _active, "sessionId": _session_id, "recoveredUncleanExit": not previous.is_empty()}


func record_error(code: String, details: Dictionary = {}) -> void:
	if not _active:
		return
	_errors.append({
		"atMsec": Time.get_ticks_msec(),
		"code": code,
		"details": details.duplicate(true),
	})


func record_performance_sample(sample: Dictionary = {}) -> void:
	if not _active or _samples.size() >= MAX_SAMPLES:
		return
	var normalized := sample.duplicate(true)
	normalized["atMsec"] = Time.get_ticks_msec()
	if not normalized.has("fps"):
		normalized["fps"] = Engine.get_frames_per_second()
	if not normalized.has("staticMemoryBytes"):
		normalized["staticMemoryBytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	if not normalized.has("processTimeSeconds"):
		normalized["processTimeSeconds"] = Performance.get_monitor(Performance.TIME_PROCESS)
	_samples.append(normalized)


func finish(reason: String = "clean_exit") -> Dictionary:
	if not _active:
		return {"ok": false, "error": "DIAGNOSTICS_NOT_ACTIVE"}
	record_performance_sample()
	var report := _write_report("session", {
		"reason": reason,
		"startedAtUnix": _started_unix,
		"finishedAtUnix": int(Time.get_unix_time_from_system()),
		"samples": _samples.duplicate(true),
		"errors": _errors.duplicate(true),
	})
	_active = false
	set_process(false)
	if FileAccess.file_exists(_marker_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_marker_path()))
	return report


func _process(delta: float) -> void:
	_sample_accumulator += delta
	if _sample_accumulator < 1.0:
		return
	_sample_accumulator = fmod(_sample_accumulator, 1.0)
	record_performance_sample()


func _exit_tree() -> void:
	if _active:
		finish()


func _write_report(kind: String, values: Dictionary) -> Dictionary:
	var report := values.duplicate(true)
	report["schema"] = SCHEMA
	report["kind"] = kind
	report["sessionId"] = _session_id
	var report_path := "%s/%d-%s-%s.json" % [
		_base_path,
		int(Time.get_unix_time_from_system()),
		_session_id if _session_id != "" else "recovery",
		kind,
	]
	var ok := _write_json(report_path, report)
	_rotate_reports()
	return {"ok": ok, "path": report_path, "report": report}


func _marker_path() -> String:
	return "%s/active-session.json" % _base_path


func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t", false))
	file.flush()
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return Dictionary(parser.data)


func _rotate_reports() -> void:
	var directory := DirAccess.open(_base_path)
	if directory == null:
		return
	var reports: Array[String] = []
	for file_name in directory.get_files():
		if file_name.ends_with(".json") and file_name != "active-session.json":
			reports.append(file_name)
	reports.sort()
	while reports.size() > MAX_REPORTS:
		var expired: String = reports.pop_front()
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [_base_path, expired]))
