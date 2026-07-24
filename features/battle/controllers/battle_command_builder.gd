extends RefCounted

## Converts the current battle ViewModel selection into public core commands.


func build(command_type: String, snapshot: Dictionary) -> Dictionary:
	var unit_id := selected_unit_id(snapshot)
	var slot_index := selected_slot_index(snapshot)
	match command_type:
		"SELECT_ACTION_SLOT":
			return {"type": "SELECT_ACTION_SLOT", "slotId": slot_index, "index": slot_index}
		"SET_ACTION_DIRECTION":
			return {
				"type": "SET_ACTION_DIRECTION",
				"unitId": unit_id,
				"slotId": slot_index,
				"dir": next_direction(snapshot),
			}
		"SET_ACTION_AP":
			return {
				"type": "SET_ACTION_AP",
				"unitId": unit_id,
				"slotId": slot_index,
				"ap": next_action_ap(snapshot),
			}
		"USE_ACTION_SLOT":
			return {
				"type": "USE_ACTION_SLOT",
				"unitId": unit_id,
				"slotId": slot_index,
				"ap": selected_action_ap(snapshot),
			}
		"RUN_PLAYER_ALL_OUT", "END_PLAYER_TURN", "RUN_MONSTER_TURN", "RUN_BATTLE", "AUTO_POSITION_HEROES":
			return {"type": command_type}
	return {}


func selected_unit_id(snapshot: Dictionary) -> String:
	return String(snapshot.get("selected_unit_id", snapshot.get("selectedUnitId", "")))


func selected_slot_index(snapshot: Dictionary) -> int:
	return int(snapshot.get("selected_action_slot_index", snapshot.get("selectedActionSlotIndex", 0)))


func selected_action_ap(snapshot: Dictionary) -> int:
	var selected := selected_unit(snapshot)
	var slot_index := selected_slot_index(snapshot)
	var slots := Array(selected.get("action_slots", selected.get("actionSlots", [])))
	if slot_index >= 0 and slot_index < slots.size():
		var slot := Dictionary(slots[slot_index])
		return int(slot.get("selected_ap", slot.get("selectedAp", 1)))
	return int(snapshot.get("ap", 1))


func next_action_ap(snapshot: Dictionary) -> int:
	var ap_left: int = max(1, int(snapshot.get("ap", 1)))
	var current := selected_action_ap(snapshot)
	return 1 if current >= ap_left else current + 1


func next_direction(snapshot: Dictionary) -> String:
	var selected := selected_unit(snapshot)
	var slot_index := selected_slot_index(snapshot)
	var slots := Array(selected.get("action_slots", selected.get("actionSlots", [])))
	var current := "right"
	if slot_index >= 0 and slot_index < slots.size():
		current = String(Dictionary(slots[slot_index]).get("direction", "right"))
	var directions: Array[String] = ["right", "down", "left", "up"]
	var index := directions.find(current)
	return "right" if index < 0 else String(directions[(index + 1) % directions.size()])


func selected_unit(snapshot: Dictionary) -> Dictionary:
	var selected_id := selected_unit_id(snapshot)
	if selected_id == "":
		return {}
	for value in Array(snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", "")) == selected_id:
			return unit
	return {}
