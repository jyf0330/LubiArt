extends RefCounted

const ValidatorScript := preload("res://persistence/content_pack_validator.gd")
const SemanticVersionScript := preload("res://persistence/semantic_version.gd")
const CURRENT_GAME_VERSION := "1.0.0"

var _validator: RefCounted = ValidatorScript.new()


func register(packages: Array, context: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = []
	var by_id := {}
	for package_value in packages:
		var package := Dictionary(package_value)
		errors.append_array(_validator.validate(package))
		var package_id := String(package.get("package_id", ""))
		if package_id == "":
			continue
		if by_id.has(package_id):
			errors.append("DUPLICATE_PACKAGE_ID:%s" % package_id)
		else:
			by_id[package_id] = package
	_validate_graph(by_id, context, errors)
	if not errors.is_empty():
		return {"ok": false, "packages": [], "errors": errors}
	var sort_result := _topological_sort(by_id)
	if not bool(sort_result.get("ok", false)):
		return sort_result
	var ordered: Array = Array(sort_result.get("packages", []))
	return {"ok": true, "packages": ordered, "errors": []}


func _validate_graph(by_id: Dictionary, context: Dictionary, errors: Array[String]) -> void:
	var current_game_version := String(context.get("gameVersion", CURRENT_GAME_VERSION))
	for package_id_value in by_id.keys():
		var package_id := String(package_id_value)
		var package := Dictionary(by_id[package_id])
		var minimum_game_version := String(package.get("min_game_version", ""))
		if current_game_version != "" and minimum_game_version != "" \
				and SemanticVersionScript.compare(current_game_version, minimum_game_version) < 0:
			errors.append("GAME_VERSION_UNSUPPORTED:%s:%s:%s" % [package_id, minimum_game_version, current_game_version])
		for conflict_value in Array(package.get("conflicts", [])):
			var conflict_id := String(conflict_value)
			if by_id.has(conflict_id):
				errors.append("PACKAGE_CONFLICT:%s:%s" % [package_id, conflict_id])
		for dependency_value in Array(package.get("dependencies", [])):
			var dependency := Dictionary(dependency_value)
			var dependency_id := String(dependency.get("id", ""))
			if not by_id.has(dependency_id):
				errors.append("MISSING_DEPENDENCY:%s:%s" % [package_id, dependency_id])
				continue
			var min_version := String(dependency.get("min_version", ""))
			var dependency_version := String(Dictionary(by_id[dependency_id]).get("version", "0.0.0"))
			if min_version != "" and SemanticVersionScript.compare(dependency_version, min_version) < 0:
				errors.append("DEPENDENCY_VERSION_UNSUPPORTED:%s:%s:%s:%s" % [package_id, dependency_id, min_version, dependency_version])
	errors.sort()


func _topological_sort(by_id: Dictionary) -> Dictionary:
	var indegree := {}
	var dependents := {}
	for package_id_value in by_id.keys():
		var package_id := String(package_id_value)
		indegree[package_id] = 0
		dependents[package_id] = []
	for package_id_value in by_id.keys():
		var package_id := String(package_id_value)
		var package := Dictionary(by_id[package_id])
		var predecessors: Array[String] = []
		for dependency_value in Array(package.get("dependencies", [])):
			var dependency_id := String(Dictionary(dependency_value).get("id", ""))
			if dependency_id != "" and not predecessors.has(dependency_id):
				predecessors.append(dependency_id)
		for predecessor_value in Array(package.get("load_after", [])):
			var predecessor := String(predecessor_value)
			if by_id.has(predecessor) and not predecessors.has(predecessor):
				predecessors.append(predecessor)
		for predecessor in predecessors:
			indegree[package_id] = int(indegree[package_id]) + 1
			Array(dependents[predecessor]).append(package_id)
	var ready: Array = []
	for package_id_value in by_id.keys():
		if int(indegree[package_id_value]) == 0:
			ready.append(by_id[package_id_value])
	ready.sort_custom(_package_before)
	var ordered: Array = []
	while not ready.is_empty():
		var package := Dictionary(ready.pop_front())
		ordered.append(package)
		var package_id := String(package.get("package_id", ""))
		var next_ids: Array = Array(dependents.get(package_id, [])).duplicate()
		next_ids.sort()
		for dependent_id_value in next_ids:
			var dependent_id := String(dependent_id_value)
			indegree[dependent_id] = int(indegree[dependent_id]) - 1
			if int(indegree[dependent_id]) == 0:
				ready.append(by_id[dependent_id])
		ready.sort_custom(_package_before)
	if ordered.size() != by_id.size():
		var cycle_ids: Array[String] = []
		for package_id_value in by_id.keys():
			if int(indegree[package_id_value]) > 0:
				cycle_ids.append(String(package_id_value))
		cycle_ids.sort()
		return {"ok": false, "packages": [], "errors": ["DEPENDENCY_CYCLE:%s" % ",".join(cycle_ids)]}
	return {"ok": true, "packages": ordered, "errors": []}


func _package_before(left_value: Variant, right_value: Variant) -> bool:
	var left := Dictionary(left_value)
	var right := Dictionary(right_value)
	var left_priority := int(left.get("priority", 0))
	var right_priority := int(right.get("priority", 0))
	if left_priority != right_priority:
		return left_priority < right_priority
	var left_order := int(left.get("order", 0))
	var right_order := int(right.get("order", 0))
	if left_order != right_order:
		return left_order < right_order
	return String(left.get("package_id", "")) < String(right.get("package_id", ""))
