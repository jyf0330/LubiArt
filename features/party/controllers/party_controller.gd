extends RefCounted

## Projects active roster entries into stable authored party slots.


func pets_by_slot(snapshot: Dictionary, slot_count: int) -> Dictionary:
	var placed := {}
	var fallback: Array = []
	for value in Array(snapshot.get("roster", [])):
		var pet := Dictionary(value)
		if not bool(pet.get("active", false)):
			continue
		var slot_index := int(pet.get("slot", 0)) - 1
		if slot_index >= 0 and slot_index < slot_count and not placed.has(slot_index):
			placed[slot_index] = pet
		else:
			fallback.append(pet)
	for value in fallback:
		for slot_index in range(slot_count):
			if not placed.has(slot_index):
				placed[slot_index] = Dictionary(value)
				break
	return placed
