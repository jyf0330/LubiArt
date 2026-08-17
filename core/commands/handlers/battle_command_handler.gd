extends RefCounted

const ACTION_TYPES: Array[String] = [
	"START_NEXT_ROUND", "REWIND_TO_PREVIOUS_ROUND_START", "RUN_MONSTER_TURN", "SELECT_UNIT", "SELECT_HERO", "SELECT_CELL",
	"SELECT_ACTION_SLOT", "SELECT_SLOT", "SET_ACTION_DIRECTION", "SET_SLOT_DIR", "SET_ACTION_AP",
	"SET_SKILL_CONTROL_ORDER", "SET_QUALITY_MODE", "SET_QUALITY_MARK", "USE_ACTION_SLOT", "USE_SLOT", "CLEAR_SELECTION",
	"MOVE_HERO", "AUTO_POSITION_HEROES", "RUN_PLAYER_ALL_OUT", "RUN_COMBAT_ROUND",
	"RESET_PETS", "END_PLAYER_TURN"
]
const PORT_CONTRACT_ID := &"ysbzs.battle-command-port.v1"


func action_types() -> Array[String]:
	return ACTION_TYPES.duplicate()


func execute(port: RefCounted, action_type: String, action: Dictionary) -> bool:
	if not _accepts(port):
		return false
	match action_type:
		"START_NEXT_ROUND":
			return port.start_next_round()
		"REWIND_TO_PREVIOUS_ROUND_START":
			return port.rewind_to_previous_round_start()
		"RUN_MONSTER_TURN":
			return port.run_monster_turn()
		"SELECT_UNIT", "SELECT_HERO":
			return port.select_unit(String(action.get("unitId", action.get("heroId", action.get("id", "")))))
		"SELECT_CELL":
			return port.select_cell(_action_x(action), _action_y(action), action.has("ap"), _action_ap(action))
		"SELECT_ACTION_SLOT", "SELECT_SLOT":
			return port.select_action_slot(_action_slot_index(action))
		"SET_ACTION_DIRECTION", "SET_SLOT_DIR":
			_select_requested_unit(port, action)
			return port.set_action_direction(_selected_or_requested_unit(port, action), _action_slot_index(action), String(action.get("dir", action.get("direction", "right"))))
		"SET_ACTION_AP":
			_select_requested_unit(port, action)
			return port.set_action_ap(_selected_or_requested_unit(port, action), _action_slot_index(action), _action_ap(action))
		"SET_SKILL_CONTROL_ORDER":
			return port.set_skill_control_order(
				Array(action.get("orderedEntryIds", action.get("ordered_entry_ids", [])))
			)
		"SET_QUALITY_MODE":
			_select_requested_unit(port, action)
			return port.set_quality_mode(_selected_or_requested_unit(port, action), String(action.get("mode", action.get("qualityMode", action.get("quality_mode", "")))))
		"SET_QUALITY_MARK":
			_select_requested_unit(port, action)
			return port.set_quality_mark(_selected_or_requested_unit(port, action), _action_x(action), _action_y(action))
		"USE_ACTION_SLOT", "USE_SLOT":
			_select_requested_unit(port, action)
			return port.use_action_slot(
				_action_slot_index(action),
				_action_ap(action),
				String(action.get("targetId", action.get("target_id", ""))),
				action.has("x") or action.has("cell") or action.has("to"),
				_action_x(action),
				_action_y(action)
			)
		"CLEAR_SELECTION":
			return port.clear_selection()
		"MOVE_HERO":
			return port.move_hero(_action_x(action), _action_y(action), String(action.get("unitId", action.get("heroId", ""))))
		"AUTO_POSITION_HEROES":
			return port.auto_position_heroes()
		"RUN_PLAYER_ALL_OUT":
			return port.run_player_all_out()
		"RUN_COMBAT_ROUND":
			return port.run_combat_round()
		"RESET_PETS":
			return port.reset_pets()
		"END_PLAYER_TURN":
			return port.end_player_turn()
		_:
			return false


func _select_requested_unit(port: RefCounted, action: Dictionary) -> void:
	if action.has("unitId") or action.has("heroId"):
		port.select_unit(String(action.get("unitId", action.get("heroId", ""))))


func _selected_or_requested_unit(port: RefCounted, action: Dictionary) -> String:
	return String(action.get("unitId", action.get("heroId", port.selected_unit_id())))


func _action_x(action: Dictionary) -> int:
	if action.has("x"):
		return int(action["x"])
	if action.has("c"):
		return int(action["c"])
	if action.has("col"):
		return int(action["col"])
	var cell := Dictionary(action.get("cell", {}))
	if cell.is_empty():
		cell = Dictionary(action.get("to", {}))
	return int(cell.get("c", cell.get("x", -1)))


func _action_y(action: Dictionary) -> int:
	if action.has("y"):
		return int(action["y"])
	if action.has("r"):
		return int(action["r"])
	if action.has("row"):
		return int(action["row"])
	var cell := Dictionary(action.get("cell", {}))
	if cell.is_empty():
		cell = Dictionary(action.get("to", {}))
	return int(cell.get("r", cell.get("y", -1)))


func _action_slot_index(action: Dictionary) -> int:
	return int(action.get("slotId", action.get("slot_id", action.get("slotIndex", action.get("slot_index", action.get("index", 0))))))


func _action_ap(action: Dictionary) -> int:
	return int(action.get("ap", action.get("actionAp", action.get("action_ap", 0))))


func _accepts(port: RefCounted) -> bool:
	return port != null and port.has_method(&"contract_id") and StringName(port.contract_id()) == PORT_CONTRACT_ID
