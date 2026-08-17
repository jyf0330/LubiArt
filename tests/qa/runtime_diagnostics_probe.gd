extends SceneTree

const RuntimeDiagnosticsScript := preload("res://diagnostics/runtime_diagnostics.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var base_path := "user://runtime-diagnostics-probe"
	var first := RuntimeDiagnosticsScript.new()
	root.add_child(first)
	var first_start := Dictionary(first.start(base_path))
	_expect(bool(first_start.get("ok", false)), "diagnostics session starts")
	first.record_error("PROBE_ERROR", {"safe": true})
	first.record_performance_sample({"fps": 60.0, "staticMemoryBytes": 1024})
	var first_finish := Dictionary(first.finish("probe_complete"))
	_expect(bool(first_finish.get("ok", false)), "clean session report is written")
	_expect(not FileAccess.file_exists("%s/active-session.json" % base_path), "clean finish removes boot marker")
	var report := Dictionary(first_finish.get("report", {}))
	_expect(Array(report.get("errors", [])).size() == 1, "explicit errors are retained")
	_expect(Array(report.get("samples", [])).size() >= 2, "performance samples are retained")
	first.queue_free()

	var abandoned := RuntimeDiagnosticsScript.new()
	root.add_child(abandoned)
	abandoned.start(base_path)
	abandoned.set_process(false)
	# Leave the marker in place while preventing _exit_tree from treating this
	# intentionally abandoned probe as a clean session.
	abandoned.set("_active", false)
	abandoned.queue_free()
	var recovery := RuntimeDiagnosticsScript.new()
	root.add_child(recovery)
	var recovered := Dictionary(recovery.start(base_path))
	_expect(bool(recovered.get("recoveredUncleanExit", false)), "next boot reports an unclean previous exit")
	recovery.finish("recovery_probe_complete")
	recovery.queue_free()

	if failed:
		quit(1)
		return
	print("RUNTIME_DIAGNOSTICS_PROBE_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("RUNTIME_DIAGNOSTICS_PROBE_FAIL: %s" % message)
