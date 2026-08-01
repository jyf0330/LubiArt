extends RefCounted

## Pure shop ViewModel/command adapter.


func offers(snapshot: Dictionary) -> Array:
	return Array(snapshot.get("shop_offers", [])).duplicate(true)


func buy_command(offer: Dictionary) -> Dictionary:
	return {"type": "BUY_OFFER", "offer_id": String(offer.get("id", ""))}


func is_available(offer: Dictionary) -> bool:
	return not offer.is_empty() and not bool(offer.get("sold", false))


func availability(snapshot: Dictionary, offer: Dictionary) -> Dictionary:
	var listed: bool = is_available(offer)
	var price: int = max(0, int(offer.get("price", 0)))
	var coins: int = max(0, int(snapshot.get("coins", 0)))
	var affordable: bool = listed and coins >= price
	return {
		"listed": listed,
		"affordable": affordable,
		"purchasable": listed and affordable,
		"price": price,
		"coins": coins,
		"shortfall": max(0, price - coins),
		"reason": "sold" if not listed else ("available" if affordable else "insufficient_coins"),
	}
