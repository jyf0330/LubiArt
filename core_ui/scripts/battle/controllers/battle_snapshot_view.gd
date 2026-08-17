extends RefCounted

## Canonical read-only access to the public battle Snapshot. Compatibility
## aliases belong here so presentation nodes do not each reinterpret the wire
## format. Returned Arrays and Dictionaries are references and must stay read-only.


static func phase(snapshot: Dictionary) -> String:
	return String(snapshot.get("phase", ""))


static func trace_events(snapshot: Dictionary) -> Array:
	return Array(snapshot.get("battleTrace", snapshot.get("battle_trace", [])))


static func command_log(snapshot: Dictionary) -> Array:
	return Array(snapshot.get("command_log", snapshot.get("commandLog", [])))


static func state_version(snapshot: Dictionary) -> int:
	return int(snapshot.get("stateVersion", snapshot.get("state_version", -1)))


static func battle_round(snapshot: Dictionary) -> int:
	return int(snapshot.get("battleRound", snapshot.get("battle_round", 0)))


static func board_cells(snapshot: Dictionary) -> Array:
	return Array(Dictionary(snapshot.get("board", {})).get("cells", []))


static func selected_unit_id(snapshot: Dictionary) -> String:
	var selected_id := String(snapshot.get(
		"selected_unit_id",
		snapshot.get("selectedUnitId", "")
	))
	if selected_id != "":
		return selected_id
	var selected := Dictionary(snapshot.get("selected", {}))
	return unit_id(selected)


static func selected_slot_index(snapshot: Dictionary) -> int:
	return int(snapshot.get(
		"selected_action_slot_index",
		snapshot.get("selectedActionSlotIndex", 0)
	))


static func selected_action_slots(snapshot: Dictionary) -> Array:
	return Array(snapshot.get(
		"selected_action_slots",
		snapshot.get("selectedActionSlots", [])
	))


static func skill_control_bar(snapshot: Dictionary) -> Array:
	return Array(snapshot.get("skillControlBar", snapshot.get("skill_control_bar", [])))


static func player_reset_state(snapshot: Dictionary) -> Dictionary:
	return Dictionary(Dictionary(snapshot.get("pet_reset", {})).get("player", {}))


static func round_rewind_state(snapshot: Dictionary) -> Dictionary:
	return Dictionary(snapshot.get("round_rewind", snapshot.get("roundRewind", {})))


static func unit_id(data: Dictionary) -> String:
	return String(data.get(
		"unitId",
		data.get("unit_id", data.get("id", data.get("pet_id", "")))
	))


static func unit_side(data: Dictionary) -> String:
	return String(data.get("side", data.get("unitSide", data.get("camp", ""))))


static func grid(data: Dictionary, fallback: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	return Vector2i(
		int(data.get("x", data.get("c", fallback.x))),
		int(data.get("y", data.get("r", fallback.y)))
	)


static func max_hp(data: Dictionary, fallback: int = 0) -> int:
	return int(data.get("max_hp", data.get("maxHp", data.get("hp", fallback))))


static func unit_by_id(snapshot: Dictionary, requested_unit_id: String) -> Dictionary:
	if requested_unit_id == "":
		return {}
	for value in Array(snapshot.get("units", [])):
		var unit := Dictionary(value)
		if unit_id(unit) == requested_unit_id:
			return unit
	return {}


static func units_by_id(snapshot: Dictionary, required_side: String = "") -> Dictionary:
	var result := {}
	for value in Array(snapshot.get("units", [])):
		var unit := Dictionary(value)
		if required_side != "" and unit_side(unit) != required_side:
			continue
		var id := unit_id(unit)
		if id != "":
			result[id] = unit
	return result
