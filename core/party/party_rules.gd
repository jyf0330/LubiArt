extends RefCounted


static func active_count(roster: Array, skip_index: int = -1) -> int:
	var count := 0
	for index in range(roster.size()):
		if index == skip_index:
			continue
		if bool(Dictionary(roster[index]).get("active", true)):
			count += 1
	return count
