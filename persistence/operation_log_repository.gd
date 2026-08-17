extends RefCounted

## Append-only JSONL sink for player-operation diagnostics.


func append(path: String, entry: Dictionary) -> bool:
	if path == "":
		return false
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file := FileAccess.open(path, mode)
	if file == null:
		return false
	if mode == FileAccess.READ_WRITE:
		file.seek_end()
	file.store_line(JSON.stringify(entry, "", false))
	file.flush()
	return true
