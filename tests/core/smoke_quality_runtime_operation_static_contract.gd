extends SceneTree

const QUALITY_ROOT := "res://core/battle/quality"
const LEGACY_CATALOG := "res://core/battle/quality/legacy_quality_runtime_catalog.gd"
const CENTRAL_FILES := [
	"res://core/battle/quality/quality_effect_strategy.gd",
	"res://core/battle/quality/quality_board_trace.gd",
	"res://core/battle/quality/quality_shape_mutator.gd",
]

var _failed := false


func _initialize() -> void:
	var concrete_id_pattern := RegEx.new()
	concrete_id_pattern.compile("\\\"[SGD][0-9]{2}\\\"")
	for path in _gd_files(QUALITY_ROOT):
		var source := FileAccess.get_file_as_string(path)
		if path != LEGACY_CATALOG:
			_expect(concrete_id_pattern.search(source) == null, "%s contains no concrete quality content id" % path)
		if path.begins_with("%s/operations/" % QUALITY_ROOT):
			_expect(not source.contains("YsbzsState") and not source.contains("core/state/game_state.gd"), "%s has no authority dependency" % path)
			_expect(not source.contains("FileAccess") and not source.contains("DirAccess"), "%s has no I/O or discovery side channel" % path)
	for path in CENTRAL_FILES:
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.contains("match "), "%s has no central business match" % path)
	var registry_source := FileAccess.get_file_as_string("res://core/battle/quality/quality_effect_registry.gd")
	_expect(not registry_source.contains("func _register") and not registry_source.contains("_merge_metadata"), "effect registry contains no hand registration table")
	_expect(registry_source.contains("LegacyCatalogScript.upgrades()"), "Q0 init compiles the frozen legacy bootstrap")
	_expect(registry_source.contains("prepare_configuration") and registry_source.contains("commit_configuration"), "registry exposes two-stage atomic configuration")
	_expect(FileAccess.file_exists(LEGACY_CATALOG), "legacy catalog is the explicit compatibility source")
	for old_path in [
		"res://core/battle/quality/effects/silver_shield_effect.gd",
		"res://core/battle/quality/effects/silver_heal_effect.gd",
		"res://core/battle/quality/effects/silver_vitality_effect.gd",
		"res://core/battle/quality/effects/gold_stance_effect.gd",
	]:
		_expect(not FileAccess.file_exists(old_path), "%s migrated into stateless primitive operations" % old_path)
	if _failed:
		quit(1)
		return
	print("SMOKE_QUALITY_RUNTIME_OPERATION_STATIC_CONTRACT_OK")
	quit(0)


func _gd_files(root: String) -> Array[String]:
	var result: Array[String] = []
	var directories: Array[String] = [root]
	while not directories.is_empty():
		var current := String(directories.pop_front())
		var directory := DirAccess.open(current)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry := directory.get_next()
		while entry != "":
			if entry != "." and entry != "..":
				var path := "%s/%s" % [current, entry]
				if directory.current_is_dir():
					directories.append(path)
				elif entry.ends_with(".gd"):
					result.append(path)
			entry = directory.get_next()
		directory.list_dir_end()
	result.sort()
	return result


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_QUALITY_RUNTIME_OPERATION_STATIC_CONTRACT_FAIL: %s" % label)
