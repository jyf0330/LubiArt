extends RefCounted

## File-system repository for primary/backup/temp save slots. It accepts and
## returns documents; state serialization, hydration, migration, and logging stay
## outside this boundary.


func write_slot(document: Dictionary, slot: int, config: Dictionary) -> Dictionary:
	if not valid_slot(slot, int(config.get("slotCount", 3))):
		return {"ok": false, "error": "INVALID_SLOT"}
	var primary_path := slot_path(slot, String(config.get("pathPattern", "")))
	var backup_path := slot_path(slot, String(config.get("backupPattern", "")))
	var temp_path := slot_path(slot, String(config.get("tempPattern", "")))
	var text := JSON.stringify(document, "\t", false)
	if not write_text(temp_path, text):
		return {"ok": false, "error": "TEMP_WRITE_FAILED"}
	if FileAccess.file_exists(primary_path):
		remove_path(backup_path)
		var backup_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(primary_path), ProjectSettings.globalize_path(backup_path))
		if backup_error != OK:
			remove_path(temp_path)
			return {"ok": false, "error": "BACKUP_UPDATE_FAILED"}
		remove_path(primary_path)
	var replace_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(primary_path))
	if replace_error != OK:
		return {"ok": false, "error": "PRIMARY_REPLACE_FAILED"}
	return {"ok": true, "document": document.duplicate(true), "source": "primary", "path": primary_path}


func read_slot(slot: int, config: Dictionary) -> Dictionary:
	if not valid_slot(slot, int(config.get("slotCount", 3))):
		return {"ok": false, "error": "INVALID_SLOT"}
	var primary_path := slot_path(slot, String(config.get("pathPattern", "")))
	var backup_path := slot_path(slot, String(config.get("backupPattern", "")))
	if FileAccess.file_exists(primary_path):
		var primary_doc := read_document(primary_path)
		if bool(primary_doc.get("ok", false)):
			return {"ok": true, "document": Dictionary(primary_doc.get("doc", {})), "source": "primary", "path": primary_path}
	if FileAccess.file_exists(backup_path):
		var backup_doc := read_document(backup_path)
		if bool(backup_doc.get("ok", false)):
			return {"ok": true, "document": Dictionary(backup_doc.get("doc", {})), "source": "backup", "path": backup_path}
	if slot == 1:
		var legacy := read_first(Array(config.get("legacyPaths", [])))
		if bool(legacy.get("ok", false)):
			return legacy
	return {"ok": false, "error": "SAVE_NOT_FOUND"}


func read_first(paths: Array) -> Dictionary:
	for path_value in paths:
		var path := String(path_value)
		if not FileAccess.file_exists(path):
			continue
		var legacy_doc := read_document(path)
		if bool(legacy_doc.get("ok", false)):
			return {"ok": true, "document": Dictionary(legacy_doc.get("doc", {})), "source": "legacy", "path": path}
	return {"ok": false, "error": "SAVE_NOT_FOUND"}


func valid_slot(slot: int, slot_count: int) -> bool:
	return slot >= 1 and slot <= slot_count


func slot_path(slot: int, pattern: String) -> String:
	return pattern % slot


func write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	return true


func read_document(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false, "error": "JSON_INVALID"}
	var parsed = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "JSON_INVALID"}
	return {"ok": true, "doc": Dictionary(parsed)}


func remove_path(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
