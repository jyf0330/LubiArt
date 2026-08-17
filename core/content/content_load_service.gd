extends RefCounted

## Fail-closed content bootstrap. Production reads through the injected repository;
## simulation and test modes consume only an explicitly injected immutable pack.

const DocumentCodecScript := preload("res://persistence/save_codec.gd")
const RESULT_SCHEMA := "ysbzs.init-result.v1"
const SUPPORTED_MODES := ["production", "simulation", "test"]


func load(input: Dictionary, repository: RefCounted) -> Dictionary:
	var options := input.duplicate(true)
	var mode := String(options.get("mode", ""))
	if not SUPPORTED_MODES.has(mode):
		return _result(false, "production", "", {}, ["INIT_MODE_UNSUPPORTED"])
	if mode == "simulation" or mode == "test":
		var injected_value: Variant = options.get("contentPack", {})
		var injected := Dictionary(injected_value).duplicate(true) if typeof(injected_value) == TYPE_DICTIONARY else {}
		if injected.is_empty():
			return _result(false, mode, "injected", {}, ["CONTENT_PACK_REQUIRED"])
		return _result(true, mode, "injected", injected, [])

	var content_path := String(options.get("contentPath", ""))
	var supplement_path := String(options.get("supplementPath", ""))
	if not _repository_supports(repository, supplement_path != ""):
		return _result(false, mode, content_path, {}, ["CONTENT_REPOSITORY_UNAVAILABLE"])
	var content_value: Variant = repository.call("read_content_pack", content_path)
	var content_pack := Dictionary(content_value).duplicate(true) if typeof(content_value) == TYPE_DICTIONARY else {}
	var repository_errors := _strings(Array(repository.call("content_errors")))
	if not repository_errors.is_empty():
		return _result(false, mode, content_path, {}, repository_errors)
	if content_pack.is_empty():
		return _result(false, mode, content_path, {}, ["CONTENT_PACK_EMPTY"])
	if supplement_path != "":
		var supplement_value: Variant = repository.call("read_dictionary", supplement_path)
		if typeof(supplement_value) != TYPE_DICTIONARY or Dictionary(supplement_value).is_empty():
			return _result(false, mode, content_path, {}, ["CONTENT_SUPPLEMENT_INVALID"])
		content_pack = _merge_bazaar_day1_catalog(content_pack, Dictionary(supplement_value))
	return _result(true, mode, content_path, content_pack, [])


func _repository_supports(repository: RefCounted, needs_supplement: bool) -> bool:
	if repository == null:
		return false
	if not repository.has_method(&"read_content_pack") or not repository.has_method(&"content_errors"):
		return false
	return not needs_supplement or repository.has_method(&"read_dictionary")


func _merge_bazaar_day1_catalog(content_pack: Dictionary, supplement: Dictionary) -> Dictionary:
	var merged := content_pack.duplicate(true)
	var route := Dictionary(merged.get("route", {})).duplicate(true)
	var nodes := Array(route.get("node_pool", [])).duplicate(true)
	_append_unique_catalog_rows(nodes, Array(supplement.get("nodes", [])), "nodeId")
	route["node_pool"] = nodes
	merged["route"] = route
	return merged


func _append_unique_catalog_rows(target: Array, additions: Array, id_key: String) -> void:
	var seen := {}
	for value in target:
		if typeof(value) == TYPE_DICTIONARY:
			seen[String(Dictionary(value).get(id_key, ""))] = true
	for value in additions:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(value)
		var row_id := String(row.get(id_key, ""))
		if row_id == "" or seen.has(row_id):
			continue
		target.append(row.duplicate(true))
		seen[row_id] = true


func _result(ok: bool, mode: String, source: String, content_pack: Dictionary, errors: Array) -> Dictionary:
	var copied_pack := content_pack.duplicate(true)
	return {
		"schema": RESULT_SCHEMA,
		"ok": ok,
		"mode": mode,
		"source": source,
		"contentHash": _content_hash(copied_pack) if ok else "",
		"errors": _strings(errors),
		"contentPack": copied_pack,
	}


func _content_hash(content_pack: Dictionary) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return DocumentCodecScript.checksum(content_pack)
	context.update(DocumentCodecScript.stable_json(content_pack).to_utf8_buffer())
	return context.finish().hex_encode()


func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
