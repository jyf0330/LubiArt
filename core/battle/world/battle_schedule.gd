extends RefCounted

## Deterministic, stage-ordered schedule. Same-stage systems may run together
## only when their declared access sets do not conflict.

var _systems: Array[RefCounted] = []


func add_system(system: RefCounted) -> bool:
	if system == null:
		return false
	for required_method in [&"system_name", &"stage", &"reads", &"writes", &"run"]:
		if not system.has_method(required_method):
			return false
	var candidate_name := StringName(system.call("system_name"))
	for existing in _systems:
		if StringName(existing.call("system_name")) == candidate_name:
			return false
	_systems.append(system)
	return true


func ordered_system_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for system in _ordered_systems():
		result.append(StringName(system.call("system_name")))
	return result


func validate() -> Dictionary:
	var ordered := _ordered_systems()
	for left_index in range(ordered.size()):
		var left: RefCounted = ordered[left_index]
		for right_index in range(left_index + 1, ordered.size()):
			var right: RefCounted = ordered[right_index]
			if int(left.call("stage")) != int(right.call("stage")):
				break
			var conflicts := _access_conflicts(left, right)
			if not conflicts.is_empty():
				return {
					"ok": false,
					"error": "AMBIGUOUS_SYSTEM_ACCESS",
					"stage": int(left.call("stage")),
					"left": String(left.call("system_name")),
					"right": String(right.call("system_name")),
					"resources": conflicts
				}
	return {"ok": true}


func run(world: RefCounted, context: Dictionary = {}) -> Dictionary:
	var validation := validate()
	if not bool(validation.get("ok", false)):
		return validation
	var start_event_count: int = int(world.call("event_count"))
	var results: Array = []
	for system in _ordered_systems():
		var result: Dictionary = Dictionary(system.call("run", world, context))
		results.append({
			"system": String(system.call("system_name")),
			"stage": int(system.call("stage")),
			"result": result
		})
		if not bool(result.get("ok", false)):
			return {
				"ok": false,
				"error": "SYSTEM_FAILED",
				"system": String(system.call("system_name")),
				"systems": results,
				"events": world.call("events_since", start_event_count)
			}
	return {
		"ok": true,
		"systems": results,
		"events": world.call("events_since", start_event_count)
	}


func _ordered_systems() -> Array[RefCounted]:
	var result := _systems.duplicate()
	result.sort_custom(func(left: RefCounted, right: RefCounted) -> bool:
		var left_stage := int(left.call("stage"))
		var right_stage := int(right.call("stage"))
		if left_stage != right_stage:
			return left_stage < right_stage
		return String(left.call("system_name")) < String(right.call("system_name"))
	)
	return result


func _access_conflicts(left: RefCounted, right: RefCounted) -> Array[String]:
	var left_reads := _string_set(Array(left.call("reads")))
	var left_writes := _string_set(Array(left.call("writes")))
	var right_reads := _string_set(Array(right.call("reads")))
	var right_writes := _string_set(Array(right.call("writes")))
	var conflicts: Array[String] = []
	for resource in left_writes.keys():
		if right_reads.has(resource) or right_writes.has(resource):
			conflicts.append(String(resource))
	for resource in right_writes.keys():
		if left_reads.has(resource) and not conflicts.has(String(resource)):
			conflicts.append(String(resource))
	conflicts.sort()
	return conflicts


func _string_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[String(value)] = true
	return result
