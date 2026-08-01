extends "res://core_ui/scripts/shop/controllers/shop_controller.gd"

## Canonical shop presentation model.


func cards(snapshot: Dictionary) -> Array:
	var result: Array = []
	for value in offers(snapshot):
		var offer := Dictionary(value)
		var availability_model := availability(snapshot, offer)
		result.append({
			"record": offer,
			"available": bool(availability_model.get("listed", false)),
			"affordable": bool(availability_model.get("affordable", false)),
			"purchasable": bool(availability_model.get("purchasable", false)),
			"availability": availability_model,
			"command": buy_command(offer),
		})
	return result
