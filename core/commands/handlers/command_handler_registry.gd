extends RefCounted

const QueryReplayHandlerScript := preload("res://core/commands/handlers/query_replay_command_handler.gd")
const RouteRewardHandlerScript := preload("res://core/commands/handlers/route_reward_command_handler.gd")
const ShopInventoryHandlerScript := preload("res://core/commands/handlers/shop_inventory_command_handler.gd")
const RunFlowHandlerScript := preload("res://core/commands/handlers/run_flow_command_handler.gd")
const BattleHandlerScript := preload("res://core/commands/handlers/battle_command_handler.gd")

var _handlers: Dictionary = {}
var _domains: Dictionary = {}


func _init() -> void:
	_register_domain(&"query_replay", QueryReplayHandlerScript.new())
	_register_domain(&"route_reward", RouteRewardHandlerScript.new())
	_register_domain(&"shop_inventory", ShopInventoryHandlerScript.new())
	_register_domain(&"run_flow", RunFlowHandlerScript.new())
	_register_domain(&"battle", BattleHandlerScript.new())


func _register_domain(domain: StringName, handler: RefCounted) -> void:
	for action_type in Array(handler.call("action_types")):
		var key := String(action_type)
		assert(not _handlers.has(key), "Duplicate command registration: %s" % key)
		_handlers[key] = handler
		_domains[key] = domain


func handler_for(action_type: String) -> RefCounted:
	return _handlers.get(action_type) as RefCounted


func domain_for(action_type: String) -> StringName:
	return StringName(_domains.get(action_type, &""))


func registered_actions() -> Array[String]:
	var actions: Array[String] = []
	for action_type in _handlers.keys():
		actions.append(String(action_type))
	actions.sort()
	return actions
