extends RefCounted

## Factory for public shop offer snapshots. It does not own catalog or Session state.


func create(source: Dictionary, slot_index: int, store: Dictionary, context: Dictionary) -> Dictionary:
	var offer: Dictionary = source.duplicate(true)
	var pool_id := String(store.get("pool_id", store.get("id", "")))
	var discount: int = clampi(int(context.get("discount", 0)), 0, 100)
	var offer_id := "shop_%03d" % slot_index
	var base_price: int = max(1, int(offer.get("price", offer.get("default_price", 2))))
	offer["id"] = offer_id
	offer["offer_id"] = offer_id
	offer["pool_id"] = pool_id
	offer["source_store_id"] = String(store.get("location_id", pool_id))
	offer["source_stall_id"] = String(store.get("source_stall_id", store.get("stall_id", "")))
	offer["source_location_id"] = String(store.get("location_id", pool_id))
	offer["base_price"] = base_price
	offer["price"] = max(0, int(ceil(float(base_price) * float(100 - discount) / 100.0)))
	if discount > 0:
		offer["discount"] = discount
	offer["sold"] = false
	return offer
