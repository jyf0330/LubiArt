extends "res://core_ui/scripts/inventory/controllers/inventory_controller.gd"

## Canonical inventory page model. Pagination is owned here instead of by the
## authored ArtistFlow view adapter.


func page(snapshot: Dictionary, requested_page: int, slot_count: int) -> Dictionary:
	var all_pets := pets(snapshot)
	var safe_slot_count := maxi(1, slot_count)
	var indexed_pets := _indexed_pets_by_bag_slot(all_pets)
	var max_slot := -1
	for entry in indexed_pets:
		max_slot = maxi(max_slot, int(Dictionary(entry).get("slot", -1)))
	var page_count := maxi(1, int(ceil(float(max_slot + 1) / float(safe_slot_count))))
	var page_index := clampi(requested_page, 0, page_count - 1)
	var page_start := page_index * safe_slot_count
	var items: Array = []
	items.resize(safe_slot_count)
	for index in range(items.size()):
		items[index] = {}
	for entry in indexed_pets:
		var pet_slot := int(Dictionary(entry).get("slot", -1))
		if pet_slot < page_start or pet_slot >= page_start + safe_slot_count:
			continue
		items[pet_slot - page_start] = Dictionary(Dictionary(entry).get("pet", {}))
	return {
		"items": items,
		"page": page_index,
		"page_count": page_count,
		"total_count": all_pets.size(),
	}


func _indexed_pets_by_bag_slot(all_pets: Array) -> Array:
	var indexed_pets: Array = []
	var used_slots := {}
	var compact_slot := 0
	for value in all_pets:
		var pet := Dictionary(value)
		var pet_slot := _explicit_bag_slot(pet)
		if pet_slot < 0:
			pet_slot = compact_slot
		while used_slots.has(pet_slot):
			pet_slot += 1
		used_slots[pet_slot] = true
		compact_slot = maxi(compact_slot, pet_slot + 1)
		indexed_pets.append({
			"slot": pet_slot,
			"pet": pet,
		})
	return indexed_pets


func _explicit_bag_slot(pet: Dictionary) -> int:
	if pet.has("bag_slot"):
		return int(pet.get("bag_slot", -1))
	if pet.has("bagSlot"):
		return int(pet.get("bagSlot", -1))
	return -1
