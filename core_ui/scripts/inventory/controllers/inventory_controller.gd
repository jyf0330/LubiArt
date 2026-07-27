extends RefCounted

## Projects inactive roster entries into the authored bag order.


func pets(snapshot: Dictionary) -> Array:
	var result: Array = []
	for value in Array(snapshot.get("roster", [])):
		var pet := Dictionary(value)
		if not bool(pet.get("active", false)):
			result.append(pet)
	result.sort_custom(func(left, right):
		return int(Dictionary(left).get("bag_slot", Dictionary(left).get("bagSlot", 999))) < int(Dictionary(right).get("bag_slot", Dictionary(right).get("bagSlot", 999)))
	)
	return result
