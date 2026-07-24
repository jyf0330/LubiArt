extends RefCounted

## Pure shop ViewModel/command adapter.


func offers(snapshot: Dictionary) -> Array:
	return Array(snapshot.get("shop_offers", [])).duplicate(true)


func buy_command(offer: Dictionary) -> Dictionary:
	return {"type": "BUY_OFFER", "offer_id": String(offer.get("id", ""))}


func is_available(offer: Dictionary) -> bool:
	return not offer.is_empty() and not bool(offer.get("sold", false))
