extends RefCounted

## Filesystem adapter for modular content packages.


func read(root_path: String) -> Dictionary:
	var files: Array[String] = []
	var errors: Array[String] = []
	_collect_json_files(root_path, files, errors)
	files.sort()
	var packages: Array = []
	for path in files:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			errors.append("INVALID_JSON:%s" % path)
			continue
		var package := Dictionary(parsed)
		package["_source_path"] = path
		packages.append(package)
	return {"ok": errors.is_empty(), "packages": packages, "files": files, "errors": errors}


func _collect_json_files(path: String, output: Array[String], errors: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		errors.append("MISSING_CONTENT_ROOT:%s" % path)
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name.begins_with("."):
			name = directory.get_next()
			continue
		var child := path.path_join(name)
		if directory.current_is_dir():
			_collect_json_files(child, output, errors)
		elif name.get_extension().to_lower() == "json":
			output.append(child)
		name = directory.get_next()
	directory.list_dir_end()
