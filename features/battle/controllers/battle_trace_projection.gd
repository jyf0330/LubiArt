extends RefCounted

## Owns the temporary board projection used while ordered battle VFX are playing.

const UNIT_KEYS := ["unit_id", "unitId", "pet_id", "petId", "unitSide", "side", "unitName", "name", "hp", "shield", "atk", "leaderId"]


func new_events(snapshot: Dictionary, rendered_trace_count: int) -> Array:
	var events := Array(snapshot.get("battleTrace", snapshot.get("battle_trace", [])))
	if rendered_trace_count < 0 or events.size() <= rendered_trace_count:
		return []
	var result: Array = []
	for index in range(rendered_trace_count, events.size()):
		result.append(Dictionary(events[index]))
	return result


func pending_reset_unit_ids(events: Array) -> Dictionary:
	var pending := {}
	for event_value in events:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) != "PETS_RESET":
			continue
		for unit_value in Array(Dictionary(event.get("payload", {})).get("units", [])):
			var unit_id := String(Dictionary(unit_value).get("id", ""))
			if unit_id != "":
				pending[unit_id] = true
	return pending


func collect_enemy_move_final_cells(cells: Array, events: Array) -> Dictionary:
	var moved_unit_ids := _enemy_move_unit_ids(events)
	var final_cells := {}
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		if moved_unit_ids.has(unit_id):
			final_cells[unit_id] = cell.duplicate(true)
	return final_cells


func defer_enemy_move_projection(cells: Array, events: Array) -> Dictionary:
	var final_cells := collect_enemy_move_final_cells(cells, events)
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		if final_cells.has(unit_id):
			clear_cell_unit_projection(cell)
	for event_value in events:
		var event := Dictionary(event_value)
		if not _is_enemy_move(event):
			continue
		var unit_id := String(event.get("unitId", Dictionary(event.get("actor", {})).get("id", "")))
		var final_cell := Dictionary(final_cells.get(unit_id, {}))
		if final_cell.is_empty():
			continue
		var from := Dictionary(event.get("from", Dictionary(event.get("payload", {})).get("from", {})))
		var from_cell := _cell_at(cells, int(from.get("x", from.get("c", -1))), int(from.get("y", from.get("r", -1))))
		if not from_cell.is_empty():
			copy_cell_unit_projection(final_cell, from_cell)
	return final_cells


func clear_cell_unit_projection(cell: Dictionary) -> void:
	for key in ["unit_id", "unitId", "pet_id", "petId", "unitSide", "side", "unitName", "name"]:
		cell[key] = ""
	cell["hp"] = 0
	cell["shield"] = 0
	cell["atk"] = 0
	cell["leaderId"] = null


func copy_cell_unit_projection(source: Dictionary, target: Dictionary) -> void:
	for key in UNIT_KEYS:
		target[key] = source.get(key, null)


func _enemy_move_unit_ids(events: Array) -> Dictionary:
	var result := {}
	for event_value in events:
		var event := Dictionary(event_value)
		if not _is_enemy_move(event):
			continue
		var actor := Dictionary(event.get("actor", {}))
		var unit_id := String(event.get("unitId", actor.get("id", "")))
		if unit_id != "":
			result[unit_id] = true
	return result


func _is_enemy_move(event: Dictionary) -> bool:
	return String(event.get("type", "")) == "MOVE_MONSTER" and String(Dictionary(event.get("actor", {})).get("side", "")) == "enemy"


func _cell_at(cells: Array, x: int, y: int) -> Dictionary:
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		if int(cell.get("x", cell.get("c", -1))) == x and int(cell.get("y", cell.get("r", -1))) == y:
			return cell
	return {}
