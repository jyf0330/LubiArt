extends RefCounted

## Converts the current battle ViewModel selection into public core commands.

const BattleSnapshotView := preload("res://core_ui/scripts/battle/controllers/battle_snapshot_view.gd")


func build(command_type: String, snapshot: Dictionary) -> Dictionary:
	var unit_id := selected_unit_id(snapshot)
	var slot_index := selected_slot_index(snapshot)
	match command_type:
		"SELECT_ACTION_SLOT":
			var slots := BattleSnapshotView.selected_action_slots(snapshot)
			return {
				"type": "SELECT_ACTION_SLOT",
				"slotId": (slot_index + 1) % maxi(1, slots.size()),
			}
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
		"END_PLAYER_TURN", "RUN_MONSTER_TURN", "AUTO_POSITION_HEROES", \
				"RESET_PETS", "RUN_COMBAT_ROUND", \
				"REWIND_TO_PREVIOUS_ROUND_START":
			return {"type": command_type}
	return {}


func select_cell(grid: Vector2i) -> Dictionary:
	return {"type": "SELECT_CELL", "x": grid.x, "y": grid.y}


func get_cell_detail(grid: Vector2i) -> Dictionary:
	return {"type": "GET_CELL_DETAIL", "x": grid.x, "y": grid.y}


func move_hero(unit_id: String, target: Vector2i) -> Dictionary:
	return {
		"type": "MOVE_HERO",
		"unitId": unit_id,
		"x": target.x,
		"y": target.y,
	}


func set_difficulty(difficulty: String) -> Dictionary:
	return {
		"type": "SET_DIFFICULTY",
		"difficulty": "easy" if difficulty == "easy" else "normal",
	}


func set_skill_control_order(ordered_entry_ids: Array) -> Dictionary:
	return {
		"type": "SET_SKILL_CONTROL_ORDER",
		"orderedEntryIds": ordered_entry_ids.duplicate(),
	}


func selected_unit_id(snapshot: Dictionary) -> String:
	return BattleSnapshotView.selected_unit_id(snapshot)


func selected_slot_index(snapshot: Dictionary) -> int:
	return BattleSnapshotView.selected_slot_index(snapshot)


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
	return BattleSnapshotView.unit_by_id(snapshot, selected_unit_id(snapshot))
