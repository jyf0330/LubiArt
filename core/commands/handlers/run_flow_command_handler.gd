extends RefCounted

const ACTION_TYPES: Array[String] = [
	"CONTINUE_AFTER_BATTLE", "START_BATTLE", "START_DEVELOPER_SCENARIO", "START_DEBUG_FIRST_BATTLE", "RUN_BATTLE", "RUN_FULL_DAY", "RUN_FULL_RUN",
	"NEW_RUN", "SET_DIFFICULTY", "SET_BOARD_DIMENSIONS", "START_NEXT_DAY"
]
const PORT_CONTRACT_ID := &"ysbzs.run-flow-command-port.v1"


func action_types() -> Array[String]:
	return ACTION_TYPES.duplicate()


func execute(port: RefCounted, action_type: String, action: Dictionary) -> bool:
	if not _accepts(port):
		return false
	match action_type:
		"CONTINUE_AFTER_BATTLE":
			return port.continue_after_battle()
		"START_BATTLE":
			return port.start_battle(action)
		"START_DEVELOPER_SCENARIO":
			return port.start_developer_scenario(action)
		"START_DEBUG_FIRST_BATTLE":
			return port.start_debug_first_battle(action)
		"RUN_BATTLE":
			return port.run_battle()
		"RUN_FULL_DAY":
			return port.run_full_day()
		"RUN_FULL_RUN":
			return port.run_full_run()
		"NEW_RUN":
			return port.new_run(action)
		"SET_DIFFICULTY":
			return port.set_difficulty(action)
		"SET_BOARD_DIMENSIONS":
			return port.set_board_dimensions(action)
		"START_NEXT_DAY":
			return port.start_next_day(action)
		_:
			return false


func _accepts(port: RefCounted) -> bool:
	return port != null and port.has_method(&"contract_id") and StringName(port.contract_id()) == PORT_CONTRACT_ID
