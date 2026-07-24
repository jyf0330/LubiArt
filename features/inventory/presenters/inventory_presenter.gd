extends "res://features/inventory/controllers/inventory_controller.gd"

## Canonical inventory page model. Pagination is owned here instead of by the
## authored ArtistFlow view adapter.


func page(snapshot: Dictionary, requested_page: int, slot_count: int) -> Dictionary:
	var all_pets := pets(snapshot)
	var safe_slot_count := maxi(1, slot_count)
	var page_count := maxi(1, int(ceil(float(all_pets.size()) / float(safe_slot_count))))
	var page_index := clampi(requested_page, 0, page_count - 1)
	var page_start := page_index * safe_slot_count
	var items: Array = []
	for index in range(page_start, mini(page_start + safe_slot_count, all_pets.size())):
		items.append(Dictionary(all_pets[index]))
	return {
		"items": items,
		"page": page_index,
		"page_count": page_count,
		"total_count": all_pets.size(),
	}
