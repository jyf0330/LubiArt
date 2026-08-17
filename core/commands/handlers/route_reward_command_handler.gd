extends RefCounted

const ACTION_TYPES: Array[String] = [
	"CHOOSE_ROUTE", "PICK_NODE", "CLAIM_ROUTE_REWARD", "PICK_REWARD",
	"PICK_BATTLE_ENCOUNTER", "RUN_ROUTE_FIXED_BATTLE", "APPLY_ROUTE_EVENT"
]
const PORT_CONTRACT_ID := &"ysbzs.route-reward-command-port.v1"


func action_types() -> Array[String]:
	return ACTION_TYPES.duplicate()


func execute(port: RefCounted, action_type: String, action: Dictionary) -> bool:
	if not _accepts(port):
		return false
	match action_type:
		"CHOOSE_ROUTE":
			return port.choose_route(String(action.get("option_id", action.get("optionId", ""))))
		"PICK_NODE":
			return port.choose_route(_route_option_id(action))
		"CLAIM_ROUTE_REWARD", "PICK_REWARD":
			return port.pick_reward(action)
		"PICK_BATTLE_ENCOUNTER", "RUN_ROUTE_FIXED_BATTLE":
			return port.start_route_battle(action)
		"APPLY_ROUTE_EVENT":
			return port.apply_route_event(String(action.get("eventId", action.get("event_id", action.get("id", "")))))
		_:
			return false


func _route_option_id(action: Dictionary) -> String:
	return String(action.get("option_id", action.get("optionId", action.get("nodeId", action.get("node_id", action.get("encounterId", action.get("encounter_id", "")))))))


func _accepts(port: RefCounted) -> bool:
	return port != null and port.has_method(&"contract_id") and StringName(port.contract_id()) == PORT_CONTRACT_ID
