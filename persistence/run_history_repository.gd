extends RefCounted

## Append-only run history storage.
##
## A run references one shared immutable content revision and owns one JSONL
## command journal plus non-overwriting checkpoint documents. Direct day restore
## reads only run.json, one deterministic day pointer, and one checkpoint. The
## repository never becomes gameplay authority; checkpoints are hydrated back
## into the one YsbzsState authority.

const MANIFEST_FILE := "manifest.json"
const RUN_HEADER_FILE := "run.json"
const CONTENT_FILE := "content_pack.json"
const COMMANDS_FILE := "commands.jsonl"
const CHECKPOINTS_DIR := "checkpoints"
const DAY_INDEX_DIR := "day_index"
const CONTENT_REVISIONS_DIR := "_content_revisions"
const CONTENT_INDEX_FILE := "index.json"
const CONTENT_PACKS_DIR := "packs"
const CONTENT_INDEX_SCHEMA := "ysbzs.content-revisions"
const CONTENT_INDEX_SCHEMA_VERSION := 1


func ensure_content_revision(root: String, content_hash: String, content_pack: Dictionary) -> Dictionary:
	if content_hash == "" or content_pack.is_empty():
		return {}
	var index_path := root.path_join(CONTENT_REVISIONS_DIR).path_join(CONTENT_INDEX_FILE)
	var index := _read_json(index_path)
	if index.is_empty():
		index = {
			"schema": CONTENT_INDEX_SCHEMA,
			"schemaVersion": CONTENT_INDEX_SCHEMA_VERSION,
			"latestRevision": 0,
			"byHash": {},
			"byRevision": {}
		}
	var by_hash := Dictionary(index.get("byHash", {})).duplicate(true)
	if by_hash.has(content_hash):
		var existing := Dictionary(by_hash[content_hash]).duplicate(true)
		var existing_path := String(existing.get("contentPath", ""))
		if not _is_content_relative_path(existing_path):
			return {}
		if not FileAccess.file_exists(root.path_join(existing_path)):
			if not _write_json_compressed_atomic(root.path_join(existing_path), content_pack):
				return {}
		return existing
	var revision := int(index.get("latestRevision", 0)) + 1
	var relative_path := "%s/%s/content_%s.jsonc" % [
		CONTENT_REVISIONS_DIR,
		CONTENT_PACKS_DIR,
		content_hash
	]
	if not _write_json_compressed_atomic(root.path_join(relative_path), content_pack):
		return {}
	var entry := {
		"revision": revision,
		"contentHash": content_hash,
		"contentPath": relative_path,
		"createdAt": Time.get_datetime_string_from_system(true, true)
	}
	by_hash[content_hash] = entry
	var by_revision := Dictionary(index.get("byRevision", {})).duplicate(true)
	by_revision[str(revision)] = entry
	index["latestRevision"] = revision
	index["byHash"] = by_hash
	index["byRevision"] = by_revision
	if not _write_json_atomic(index_path, index):
		return {}
	return entry.duplicate(true)


func read_content_reference(root: String, reference: Dictionary) -> Dictionary:
	var relative_path := String(reference.get("contentPath", ""))
	if not _is_content_relative_path(relative_path):
		return {}
	return _read_json_auto(root.path_join(relative_path))


func create_run(root: String, run_id: String, manifest: Dictionary, content_pack: Dictionary) -> bool:
	var run_dir := _run_dir(root, run_id)
	if not _ensure_dir(run_dir.path_join(CHECKPOINTS_DIR)):
		return false
	if not _ensure_dir(run_dir.path_join(DAY_INDEX_DIR)):
		return false
	var determinism := Dictionary(manifest.get("determinism", {}))
	if int(determinism.get("contentRevision", 0)) <= 0:
		if not _write_json_atomic(run_dir.path_join(CONTENT_FILE), content_pack):
			return false
	var stored := manifest.duplicate(true)
	stored["runId"] = run_id
	stored["checkpoints"] = Array(stored.get("checkpoints", [])).duplicate(true)
	stored["checkpointIndex"] = Dictionary(stored.get("checkpointIndex", {})).duplicate(true)
	stored["dayIndex"] = Dictionary(stored.get("dayIndex", {})).duplicate(true)
	var header := stored.duplicate(true)
	header.erase("checkpoints")
	header.erase("checkpointIndex")
	header.erase("dayIndex")
	if not _write_json_atomic(run_dir.path_join(RUN_HEADER_FILE), header):
		return false
	return _write_json_atomic(run_dir.path_join(MANIFEST_FILE), stored)


func append_command(root: String, run_id: String, entry: Dictionary) -> bool:
	var path := _run_dir(root, run_id).path_join(COMMANDS_FILE)
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.flush()
	return true


func write_checkpoint(
	root: String,
	run_id: String,
	checkpoint_id: String,
	document: Dictionary,
	summary: Dictionary
) -> bool:
	var run_dir := _run_dir(root, run_id)
	var checkpoint_path := run_dir.path_join(CHECKPOINTS_DIR).path_join("%s.jsonc" % _safe_id(checkpoint_id))
	if not FileAccess.file_exists(checkpoint_path) and not _write_json_compressed_atomic(checkpoint_path, document):
		return false
	var manifest := read_manifest(root, run_id)
	if manifest.is_empty():
		return false
	var checkpoints := Array(manifest.get("checkpoints", [])).duplicate(true)
	var checkpoint_index := Dictionary(manifest.get("checkpointIndex", {})).duplicate(true)
	if checkpoint_index.has(checkpoint_id):
		return _write_day_pointer(run_dir, Dictionary(checkpoint_index[checkpoint_id]))
	for value in checkpoints:
		var legacy_item := Dictionary(value)
		if String(legacy_item.get("checkpointId", "")) != checkpoint_id:
			continue
		checkpoint_index[checkpoint_id] = legacy_item
		var legacy_day_index := Dictionary(manifest.get("dayIndex", {})).duplicate(true)
		legacy_day_index["%03d:%s" % [
			int(legacy_item.get("day", 0)),
			String(legacy_item.get("kind", ""))
		]] = checkpoint_id
		manifest["checkpointIndex"] = checkpoint_index
		manifest["dayIndex"] = legacy_day_index
		if not _write_day_pointer(run_dir, legacy_item):
			return false
		return _write_json_atomic(run_dir.path_join(MANIFEST_FILE), manifest)
	var item := summary.duplicate(true)
	item["checkpointId"] = checkpoint_id
	item["path"] = "%s/%s.jsonc" % [CHECKPOINTS_DIR, _safe_id(checkpoint_id)]
	checkpoints.append(item)
	checkpoint_index[checkpoint_id] = item
	var day_index := Dictionary(manifest.get("dayIndex", {})).duplicate(true)
	day_index["%03d:%s" % [int(item.get("day", 0)), String(item.get("kind", ""))]] = checkpoint_id
	manifest["checkpoints"] = checkpoints
	manifest["checkpointIndex"] = checkpoint_index
	manifest["dayIndex"] = day_index
	manifest["updatedAt"] = Time.get_datetime_string_from_system(true, true)
	if not _write_day_pointer(run_dir, item):
		return false
	return _write_json_atomic(run_dir.path_join(MANIFEST_FILE), manifest)


func list_runs(root: String) -> Array:
	var absolute_root := ProjectSettings.globalize_path(root)
	var dir := DirAccess.open(absolute_root)
	if dir == null:
		return []
	var runs: Array = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			var manifest := read_manifest(root, name)
			if not manifest.is_empty():
				runs.append(manifest)
		name = dir.get_next()
	dir.list_dir_end()
	runs.sort_custom(func(a, b):
		return String(Dictionary(a).get("createdAt", "")) > String(Dictionary(b).get("createdAt", ""))
	)
	return runs


func list_checkpoints(root: String, run_id: String) -> Array:
	return Array(read_manifest(root, run_id).get("checkpoints", [])).duplicate(true)


func checkpoint_for_day(root: String, run_id: String, day: int, kind: String = "start") -> Dictionary:
	var run_dir := _run_dir(root, run_id)
	var pointer_path := run_dir.path_join(DAY_INDEX_DIR).path_join(_day_pointer_filename(day, kind))
	var direct := _read_json(pointer_path)
	if not direct.is_empty():
		return direct
	var manifest := read_manifest(root, run_id)
	var day_key := "%03d:%s" % [day, kind]
	var checkpoint_id := String(Dictionary(manifest.get("dayIndex", {})).get(day_key, ""))
	if checkpoint_id != "":
		return Dictionary(Dictionary(manifest.get("checkpointIndex", {})).get(checkpoint_id, {})).duplicate(true)
	# Legacy manifests did not have direct indices.
	for value in Array(manifest.get("checkpoints", [])):
		var item := Dictionary(value)
		if int(item.get("day", 0)) == day and String(item.get("kind", "")) == kind:
			return item.duplicate(true)
	return {}


func read_manifest(root: String, run_id: String) -> Dictionary:
	return _read_json(_run_dir(root, run_id).path_join(MANIFEST_FILE))


func read_run_header(root: String, run_id: String) -> Dictionary:
	var header := _read_json(_run_dir(root, run_id).path_join(RUN_HEADER_FILE))
	return header if not header.is_empty() else read_manifest(root, run_id)


func read_content_pack(root: String, run_id: String) -> Dictionary:
	return _read_json(_run_dir(root, run_id).path_join(CONTENT_FILE))


func read_checkpoint(root: String, run_id: String, checkpoint_id: String) -> Dictionary:
	var manifest := read_manifest(root, run_id)
	var checkpoint_index := Dictionary(manifest.get("checkpointIndex", {}))
	if checkpoint_index.has(checkpoint_id):
		var indexed_item := Dictionary(checkpoint_index[checkpoint_id])
		return _read_json_auto(_run_dir(root, run_id).path_join(String(indexed_item.get("path", ""))))
	# Legacy manifests only had the ordered array.
	for value in Array(manifest.get("checkpoints", [])):
		var item := Dictionary(value)
		if String(item.get("checkpointId", "")) != checkpoint_id:
			continue
		return _read_json_auto(_run_dir(root, run_id).path_join(String(item.get("path", ""))))
	return {}


func read_checkpoint_item(root: String, run_id: String, item: Dictionary) -> Dictionary:
	var relative_path := String(item.get("path", ""))
	if not relative_path.begins_with("%s/" % CHECKPOINTS_DIR) or relative_path.contains(".."):
		return {}
	return _read_json_auto(_run_dir(root, run_id).path_join(relative_path))


func command_count(root: String, run_id: String) -> int:
	var path := _run_dir(root, run_id).path_join(COMMANDS_FILE)
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var count := 0
	while not file.eof_reached():
		if file.get_line().strip_edges() != "":
			count += 1
	return count


func _run_dir(root: String, run_id: String) -> String:
	return root.path_join(_safe_id(run_id))


func _safe_id(value: String) -> String:
	var safe := value.strip_edges()
	if safe == "":
		return "unknown"
	for invalid in ["/", "\\", ":", "..", "\n", "\r", "\t"]:
		safe = safe.replace(invalid, "_")
	return safe


func _is_content_relative_path(path: String) -> bool:
	var expected_prefix := "%s/%s/" % [CONTENT_REVISIONS_DIR, CONTENT_PACKS_DIR]
	return path.begins_with(expected_prefix) and not path.contains("..")


func _write_day_pointer(run_dir: String, item: Dictionary) -> bool:
	return _write_json_atomic(
		run_dir.path_join(DAY_INDEX_DIR).path_join(_day_pointer_filename(
			int(item.get("day", 0)),
			String(item.get("kind", ""))
		)),
		item
	)


func _day_pointer_filename(day: int, kind: String) -> String:
	return "day_%03d_%s.json" % [day, _safe_id(kind)]


func _ensure_dir(path: String) -> bool:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)) == OK


func _write_json_atomic(path: String, document: Dictionary) -> bool:
	if not _ensure_dir(path.get_base_dir()):
		return false
	var temp_path := "%s.tmp" % path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(document, "\t", false))
	file.flush()
	file.close()
	return _replace_temp_atomic(path, temp_path)


func _write_json_compressed_atomic(path: String, document: Dictionary) -> bool:
	if not _ensure_dir(path.get_base_dir()):
		return false
	var temp_path := "%s.tmp" % path
	var file := FileAccess.open_compressed(
		temp_path,
		FileAccess.WRITE,
		FileAccess.COMPRESSION_GZIP
	)
	if file == null:
		return false
	file.store_string(JSON.stringify(document))
	file.flush()
	file.close()
	return _replace_temp_atomic(path, temp_path)


func _replace_temp_atomic(path: String, temp_path: String) -> bool:
	var backup_path := "%s.replace_backup" % path
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if not FileAccess.file_exists(path) and FileAccess.file_exists(backup_path):
		if DirAccess.rename_absolute(absolute_backup, absolute_path) != OK:
			return false
	elif FileAccess.file_exists(path) and FileAccess.file_exists(backup_path):
		if DirAccess.remove_absolute(absolute_backup) != OK:
			return false
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(path):
		if DirAccess.rename_absolute(absolute_path, absolute_backup) != OK:
			return false
	if DirAccess.rename_absolute(absolute_temp, absolute_path) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return false
	if FileAccess.file_exists(backup_path):
		return DirAccess.remove_absolute(absolute_backup) == OK
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return Dictionary(parsed) if typeof(parsed) == TYPE_DICTIONARY else {}


func _read_json_auto(path: String) -> Dictionary:
	if path.ends_with(".jsonc"):
		if not FileAccess.file_exists(path):
			return {}
		var file := FileAccess.open_compressed(
			path,
			FileAccess.READ,
			FileAccess.COMPRESSION_GZIP
		)
		if file == null:
			return {}
		var text := file.get_as_text()
		file.close()
		var parsed: Variant = JSON.parse_string(text)
		return Dictionary(parsed) if typeof(parsed) == TYPE_DICTIONARY else {}
	return _read_json(path)
