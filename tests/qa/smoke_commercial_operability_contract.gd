extends SceneTree

const REQUIRED_FAULTS := [
	"atomic_replace", "corrupt_primary", "tampered_checksum", "impossible_phase",
	"legacy_schema", "future_schema", "slot_isolation", "out_of_range_slot",
]


func _initialize() -> void:
	var ok := true
	var budgets := _json("res://qa/performance_budgets.json")
	var values := Dictionary(budgets.get("budgets", {}))
	ok = _expect(String(budgets.get("schema", "")) == "ysbzs.qa.performance-budgets.v1", "performance budget schema is explicit") and ok
	ok = _expect(int(values.get("auto_position_search_precision_ms", 0)) == 3500, "auto-position latency budget remains blocking") and ok
	ok = _expect(int(values.get("minimum_runtime_fps", 0)) >= 30, "runtime FPS floor is commercial") and ok
	for path_value in Array(budgets.get("blockingTests", [])):
		ok = _expect(FileAccess.file_exists("res://" + String(path_value)), "budget evidence exists: %s" % path_value) and ok
	var matrix := _json("res://qa/save_fault_matrix.json")
	var ids: Array[String] = []
	for case_value in Array(matrix.get("cases", [])):
		var row := Dictionary(case_value)
		ids.append(String(row.get("id", "")))
		ok = _expect(FileAccess.file_exists("res://" + String(row.get("test", ""))), "save fault test exists: %s" % row.get("id", "")) and ok
	for required_id in REQUIRED_FAULTS:
		ok = _expect(ids.has(required_id), "save fault matrix covers %s" % required_id) and ok
	print("SMOKE_COMMERCIAL_OPERABILITY_CONTRACT_%s" % ["OK" if ok else "FAIL"])
	quit(0 if ok else 1)


func _json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return Dictionary(value) if typeof(value) == TYPE_DICTIONARY else {}


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("SMOKE_COMMERCIAL_OPERABILITY_CONTRACT_FAIL: %s" % message)
	return condition
