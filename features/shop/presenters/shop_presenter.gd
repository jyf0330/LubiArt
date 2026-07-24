extends "res://features/shop/controllers/shop_controller.gd"

## Canonical shop presentation model.


func cards(snapshot: Dictionary) -> Array:
	var result: Array = []
	for value in offers(snapshot):
		var offer := Dictionary(value)
		result.append({
			"record": offer,
			"available": is_available(offer),
			"command": buy_command(offer),
		})
	return result
