extends RefCounted

## Pure active-team and bag-slot allocation rules.


static func normalize_drop_type(value: Variant) -> String:
	match String(value).strip_edges().to_lower():
		"shop", "offer", "store":
			return "shop"
		"party", "team", "active", "field":
			return "party"
		"bag", "bench", "inventory":
			return "bag"
		"sell", "trash":
			return "sell"
	return ""


static func active_slot_available(roster: Array, slot: int, maximum: int, skip_index: int = -1) -> bool:
	if slot < 1 or slot > maximum:
		return false
	for index in range(roster.size()):
		if index == skip_index:
			continue
		var row := Dictionary(roster[index])
		if bool(row.get("active", true)) and int(row.get("slot", 0)) == slot:
			return false
	return true


static func next_active_slot(roster: Array, maximum: int, skip_index: int = -1) -> int:
	var used := {}
	var active_count := 0
	for index in range(roster.size()):
		if index == skip_index:
			continue
		var row := Dictionary(roster[index])
		if bool(row.get("active", true)):
			used[int(row.get("slot", 0))] = true
			active_count += 1
	for slot in range(1, maximum + 1):
		if not used.has(slot):
			return slot
	return active_count + 1


static func target_active_slot(roster: Array, target_index: int, maximum: int, skip_index: int = -1) -> int:
	var requested := target_index + 1
	if active_slot_available(roster, requested, maximum, skip_index):
		return requested
	return next_active_slot(roster, maximum, skip_index)


static func requested_active_slot(roster: Array, target_index: int, maximum: int) -> int:
	var requested := target_index + 1
	return requested if requested >= 1 and requested <= maximum else next_active_slot(roster, maximum)


static func index_for_active_slot(roster: Array, slot: int, maximum: int, skip_index: int = -1) -> int:
	if slot < 1 or slot > maximum:
		return -1
	for index in range(roster.size()):
		if index == skip_index:
			continue
		var row := Dictionary(roster[index])
		if bool(row.get("active", false)) and int(row.get("slot", 0)) == slot:
			return index
	return -1


static func bag_slot_available(roster: Array, slot: int, maximum: int, skip_index: int = -1) -> bool:
	if slot < 1 or slot > maximum:
		return false
	for index in range(roster.size()):
		if index == skip_index:
			continue
		var row := Dictionary(roster[index])
		if not bool(row.get("active", false)) and int(row.get("bag_slot", 0)) == slot:
			return false
	return true


static func next_bag_slot(roster: Array, maximum: int, skip_index: int = -1) -> int:
	var used := {}
	var bench_count := 0
	for index in range(roster.size()):
		if index == skip_index:
			continue
		var row := Dictionary(roster[index])
		if not bool(row.get("active", false)):
			used[int(row.get("bag_slot", 0))] = true
			bench_count += 1
	for slot in range(1, maximum + 1):
		if not used.has(slot):
			return slot
	return bench_count + 1


static func target_bag_slot(roster: Array, target_index: int, maximum: int, skip_index: int = -1) -> int:
	var requested := target_index + 1
	if bag_slot_available(roster, requested, maximum, skip_index):
		return requested
	return next_bag_slot(roster, maximum, skip_index)


static func requested_bag_slot(roster: Array, target_index: int, maximum: int) -> int:
	var requested := target_index + 1
	return requested if requested >= 1 and requested <= maximum else next_bag_slot(roster, maximum)


static func index_for_bag_slot(roster: Array, slot: int, maximum: int, skip_index: int = -1) -> int:
	if slot < 1 or slot > maximum:
		return -1
	for index in range(roster.size()):
		if index == skip_index:
			continue
		var row := Dictionary(roster[index])
		if not bool(row.get("active", false)) and int(row.get("bag_slot", 0)) == slot:
			return index
	return -1
