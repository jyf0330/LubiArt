extends RefCounted

## Stateless resolver for source-accurate Bazaar merchant/trainer Type Objects.

const SeededSelectorScript := preload("res://core/run/seeded_selector.gd")


func has_location(mappings: Array, location_id: String) -> bool:
	for value in mappings:
		if typeof(value) == TYPE_DICTIONARY and String(Dictionary(value).get("local_shop_id", "")) == location_id:
			return true
	return false


func open_stalls(mappings: Array, location_id: String, current_day: int) -> Array:
	var stalls: Array = []
	for value in mappings:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var mapping := Dictionary(value)
		if String(mapping.get("local_shop_id", "")) != location_id:
			continue
		if not _is_open(mapping, current_day):
			continue
		stalls.append(mapping.duplicate(true))
	stalls.sort_custom(func(a, b):
		return String(Dictionary(a).get("id", "")) < String(Dictionary(b).get("id", ""))
	)
	return stalls


func resolve(
	location: Dictionary,
	mappings: Array,
	current_day: int,
	seed: String,
	preferred_stall_id: String = ""
) -> Dictionary:
	var location_id := String(location.get("id", location.get("pool_id", "")))
	var candidates := open_stalls(mappings, location_id, current_day)
	if candidates.is_empty():
		if not has_location(mappings, location_id):
			return {}
		return _unavailable_snapshot(location, preferred_stall_id)
	var selected := Dictionary(candidates[0])
	if preferred_stall_id != "":
		var preferred_found := false
		for value in candidates:
			var candidate := Dictionary(value)
			if String(candidate.get("id", "")) == preferred_stall_id:
				selected = candidate
				preferred_found = true
				break
		if not preferred_found:
			return _unavailable_snapshot(location, preferred_stall_id)
	elif candidates.size() > 1:
		var random := SeededSelectorScript.rng("%s|location:%s|day:%d" % [seed, location_id, current_day])
		var index: int = mini(candidates.size() - 1, int(floor(SeededSelectorScript.next(random) * candidates.size())))
		selected = Dictionary(candidates[index])
	return _stall_snapshot(location, selected)


func _is_open(mapping: Dictionary, current_day: int) -> bool:
	if current_day < int(mapping.get("unlock_day", 1)):
		return false
	var close_day := int(mapping.get("close_day", 0))
	if close_day > 0 and current_day > close_day:
		return false
	if current_day >= 1 and current_day <= 3:
		var status := String(mapping.get("day%d_status" % current_day, "")).strip_edges()
		if status != "" and status != "开放":
			return false
	return true


func _stall_snapshot(location: Dictionary, mapping: Dictionary) -> Dictionary:
	var location_id := String(location.get("id", location.get("pool_id", "")))
	var location_name := String(location.get("name", location_id))
	var source_name := String(mapping.get("source_name", mapping.get("id", "")))
	var stall := location.duplicate(true)
	stall["id"] = String(mapping.get("id", ""))
	stall["stall_id"] = stall["id"]
	stall["source_stall_id"] = stall["id"]
	stall["pool_id"] = location_id
	stall["location_id"] = location_id
	stall["location_name"] = location_name
	stall["name"] = "%s · %s" % [location_name, source_name]
	stall["source_name"] = source_name
	stall["source_slug"] = String(mapping.get("source_slug", ""))
	stall["source_node_type"] = String(mapping.get("source_node_type", ""))
	stall["source_rule"] = String(mapping.get("source_rule", ""))
	stall["source_object_count"] = int(mapping.get("source_object_count", 0))
	stall["slots"] = int(mapping.get("offer_slots", location.get("default_slots", 3)))
	stall["free_rerolls"] = int(mapping.get("free_rerolls", 0))
	stall["unlock_day"] = int(mapping.get("unlock_day", 1))
	stall["close_day"] = int(mapping.get("close_day", 0))
	stall["available"] = true
	return stall


func _unavailable_snapshot(location: Dictionary, requested_stall_id: String) -> Dictionary:
	var location_id := String(location.get("id", location.get("pool_id", "")))
	var location_name := String(location.get("name", location_id))
	return {
		"id": requested_stall_id if requested_stall_id != "" else location_id,
		"stall_id": requested_stall_id,
		"source_stall_id": requested_stall_id,
		"pool_id": location_id,
		"location_id": location_id,
		"location_name": location_name,
		"name": location_name,
		"available": false,
		"slots": 0,
		"free_rerolls": 0,
	}
