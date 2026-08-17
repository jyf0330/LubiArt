extends SceneTree

const SaveRepositoryScript := preload("res://persistence/save_repository.gd")
const GameDataRepositoryScript := preload("res://persistence/game_data_repository.gd")

const SAVE_PATTERN := "user://core_boundary_slot_%d.json"
const BACKUP_PATTERN := "user://core_boundary_slot_%d.bak.json"
const TEMP_PATTERN := "user://core_boundary_slot_%d.tmp.json"
const CONTENT_ROOT := "user://core_boundary_content"

var _failed := false


func _initialize() -> void:
	_test_document_repository()
	_test_data_repository()
	_cleanup()
	if _failed:
		quit(1)
		return
	print("SMOKE_CORE_IO_BOUNDARIES_OK")
	quit(0)


func _test_document_repository() -> void:
	var repository := SaveRepositoryScript.new()
	var config := {
		"slotCount": 1,
		"pathPattern": SAVE_PATTERN,
		"backupPattern": BACKUP_PATTERN,
		"tempPattern": TEMP_PATTERN,
		"legacyPaths": []
	}
	var document := {"schema": "boundary", "state": {"coins": 7}}
	var write_result := Dictionary(repository.write_slot(document, 1, config))
	_expect(bool(write_result.get("ok", false)), "repository writes an explicit document")
	var read_result := Dictionary(repository.read_slot(1, config))
	_expect(bool(read_result.get("ok", false)), "repository reads an explicit document")
	var restored := Dictionary(read_result.get("document", {}))
	_expect(
		String(restored.get("schema", "")) == "boundary" \
			and int(Dictionary(restored.get("state", {})).get("coins", -1)) == 7,
		"repository round-trips without authoritative core"
	)
	_expect(String(Dictionary(repository.write_slot(document, 2, config)).get("error", "")) == "INVALID_SLOT", "repository rejects invalid slot without callbacks")


func _test_data_repository() -> void:
	var repository := GameDataRepositoryScript.new()
	_expect(not repository.read_content_pack("res://data/content").is_empty(), "data repository assembles the canonical content pack")
	_expect(repository.content_errors().is_empty(), "canonical content pack has no validation errors")
	_expect(repository.read_dictionary("res://missing-core-boundary.json").is_empty(), "data repository returns an empty result for missing data")
	_write_content_marker(1)
	var first := GameDataRepositoryScript.new()
	_expect(int(Dictionary(first.read_content_pack(CONTENT_ROOT).get("marker", {})).get("value", 0)) == 1, "first repository caches its own assembled content")
	_write_content_marker(2)
	var second := GameDataRepositoryScript.new()
	_expect(int(Dictionary(second.read_content_pack(CONTENT_ROOT).get("marker", {})).get("value", 0)) == 2, "a second repository does not inherit another instance's content cache")


func _write_content_marker(value: int) -> void:
	var absolute_root := ProjectSettings.globalize_path(CONTENT_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var file := FileAccess.open(CONTENT_ROOT.path_join("marker.json"), FileAccess.WRITE)
	if file == null:
		_expect(false, "content-cache fixture opens for writing")
		return
	file.store_string(JSON.stringify({
		"schema": "ysbzs.content-package.v1",
		"package_id": "test.instance_cache",
		"priority": 0,
		"order": 0,
		"operations": [{"op": "set", "path": ["marker"], "value": {"value": value}}],
	}))
	file.close()


func _cleanup() -> void:
	for pattern in [SAVE_PATTERN, BACKUP_PATTERN, TEMP_PATTERN]:
		var path := String(pattern) % 1
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var marker_path := CONTENT_ROOT.path_join("marker.json")
	if FileAccess.file_exists(marker_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path))
	if DirAccess.open(CONTENT_ROOT) != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CONTENT_ROOT))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Smoke failed: %s" % message)
