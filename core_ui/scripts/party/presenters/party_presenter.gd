extends "res://core_ui/scripts/party/controllers/party_controller.gd"

## Canonical fixed-slot party presentation model.


func slots(snapshot: Dictionary, slot_count: int) -> Array:
	var by_slot := pets_by_slot(snapshot, slot_count)
	var result: Array = []
	for index in range(slot_count):
		result.append(Dictionary(by_slot.get(index, {})))
	return result
