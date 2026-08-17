extends RefCounted

## File-system boundary for replay and battle-trace exports.


func write_document(path: String, document: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(document, "\t", false))
	file.flush()
	return true
