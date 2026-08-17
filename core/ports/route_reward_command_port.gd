extends RefCounted

const CONTRACT_ID := &"ysbzs.route-reward-command-port.v1"

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func choose_route(option_id: String) -> bool:
	return bool(_authority.call("choose_route", option_id))


func pick_reward(action: Dictionary) -> bool:
	return bool(_authority.call("pick_reward", action))


func start_route_battle(action: Dictionary) -> bool:
	return bool(_authority.call("_start_route_battle_from_action", action))


func apply_route_event(event_id: String) -> bool:
	return bool(_authority.call("apply_route_event", event_id))
