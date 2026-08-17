extends RefCounted

## Collection-level roster identity, lookup, normalization, and battle projection.
## Slot allocation policy remains in roster_slot_rules.gd.


static func index_for_pet(roster: Array, pet_id: String, pet_key: Callable) -> int:
	for index in range(roster.size()):
		if String(pet_key.call(Dictionary(roster[index]))) == pet_id:
			return index
	return -1


static func index_for_pet_quality(
	roster: Array,
	pet_id: String,
	quality: String,
	pet_key: Callable,
	normalize_quality: Callable
) -> int:
	var wanted_quality := String(normalize_quality.call(quality))
	for index in range(roster.size()):
		var row := Dictionary(roster[index])
		if (
			String(pet_key.call(row)) == pet_id
			and String(normalize_quality.call(String(row.get("quality", "青铜")))) == wanted_quality
		):
			return index
	return -1


static func instance_id_exists(roster: Array, instance_id: String) -> bool:
	for item in roster:
		if typeof(item) == TYPE_DICTIONARY and String(Dictionary(item).get("id", "")) == instance_id:
			return true
	return false


static func next_instance_id(
	roster: Array,
	pet_id: String,
	quality_key: String,
	preferred: String = ""
) -> String:
	var wanted := preferred.strip_edges()
	if wanted != "" and not instance_id_exists(roster, wanted):
		return wanted
	var base := "%s__%s" % [pet_id, quality_key]
	var suffix := 1
	while instance_id_exists(roster, "%s_%d" % [base, suffix]):
		suffix += 1
	return "%s_%d" % [base, suffix]


static func index_for_ref(roster: Array, ref: String, pet_key: Callable) -> int:
	var wanted := ref.strip_edges()
	if wanted == "":
		return -1
	for index in range(roster.size()):
		var row := Dictionary(roster[index])
		if (
			String(row.get("id", "")) == wanted
			or String(row.get("pet_id", "")) == wanted
			or String(pet_key.call(row)) == wanted
		):
			return index
	return -1


static func normalize_active_slots(roster: Array, maximum: int) -> void:
	var used_slots := {}
	var active_count := 0
	for index in range(roster.size()):
		var pet := Dictionary(roster[index]).duplicate(true)
		var active := bool(pet.get("active", active_count < maximum))
		if active and active_count < maximum:
			var slot := int(pet.get("slot", 0))
			if slot < 1 or slot > maximum or used_slots.has(slot):
				slot = _first_free_slot(used_slots, maximum)
			if slot < 1:
				active = false
			else:
				pet["active"] = true
				pet["slot"] = slot
				pet["bag_slot"] = 0
				used_slots[slot] = true
				active_count += 1
		else:
			pet["active"] = false
			pet["slot"] = 0
		roster[index] = pet
	if active_count > 0 or roster.is_empty():
		return
	for index in range(min(roster.size(), maximum)):
		var pet := Dictionary(roster[index]).duplicate(true)
		pet["active"] = true
		pet["slot"] = index + 1
		pet["bag_slot"] = 0
		roster[index] = pet


static func normalize_bag_slots(roster: Array, maximum: int) -> void:
	var used_slots := {}
	for index in range(roster.size()):
		var pet := Dictionary(roster[index]).duplicate(true)
		if bool(pet.get("active", false)):
			pet["bag_slot"] = 0
			roster[index] = pet
			continue
		var slot := int(pet.get("bag_slot", pet.get("bagSlot", 0)))
		if slot < 1 or slot > maximum or used_slots.has(slot):
			slot = _first_free_slot(used_slots, maximum)
		pet["active"] = false
		pet["slot"] = 0
		pet["bag_slot"] = slot
		if slot > 0:
			used_slots[slot] = true
		roster[index] = pet


static func active_for_battle(roster: Array, maximum: int, pet_key: Callable) -> Array:
	var active_roster: Array = []
	for item in roster:
		var row := Dictionary(item)
		if bool(row.get("active", false)):
			active_roster.append(row)
	active_roster.sort_custom(func(a, b):
		var slot_a := int(Dictionary(a).get("slot", maximum + 1))
		var slot_b := int(Dictionary(b).get("slot", maximum + 1))
		if slot_a == slot_b:
			return String(pet_key.call(Dictionary(a))) < String(pet_key.call(Dictionary(b)))
		return slot_a < slot_b
	)
	if active_roster.size() > maximum:
		active_roster = active_roster.slice(0, maximum)
	return active_roster


static func _first_free_slot(used_slots: Dictionary, maximum: int) -> int:
	for candidate in range(1, maximum + 1):
		if not used_slots.has(candidate):
			return candidate
	return 0
