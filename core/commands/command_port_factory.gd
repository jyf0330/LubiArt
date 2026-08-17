extends RefCounted

const QueryReplayCommandPortScript := preload("res://core/ports/query_replay_command_port.gd")
const RouteRewardCommandPortScript := preload("res://core/ports/route_reward_command_port.gd")
const ShopInventoryCommandPortScript := preload("res://core/ports/shop_inventory_command_port.gd")
const RunFlowCommandPortScript := preload("res://core/ports/run_flow_command_port.gd")
const BattleCommandPortScript := preload("res://core/ports/battle_command_port.gd")


func create(domain: StringName, authority: Object) -> RefCounted:
	if authority == null:
		return null
	match domain:
		&"query_replay":
			return QueryReplayCommandPortScript.new(authority)
		&"route_reward":
			return RouteRewardCommandPortScript.new(authority)
		&"shop_inventory":
			return ShopInventoryCommandPortScript.new(authority)
		&"run_flow":
			return RunFlowCommandPortScript.new(authority)
		&"battle":
			return BattleCommandPortScript.new(authority)
		_:
			return null
