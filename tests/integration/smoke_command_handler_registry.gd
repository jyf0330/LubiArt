extends SceneTree

const CommandContractScript := preload("res://core/commands/command_contract.gd")
const CommandHandlerRegistryScript := preload("res://core/commands/handlers/command_handler_registry.gd")
const CommandPortFactoryScript := preload("res://core/commands/command_port_factory.gd")
const StateScript := preload("res://core/state/game_state.gd")

const EXPECTED_DOMAIN_ACTIONS := {
	"query_replay": [
		"GET_DEVELOPER_OBJECT_CATALOG", "GET_DEBUG_PET_CATALOG", "BUILD_PREVIEW", "GET_CELL_DETAIL", "PREVIEW_MANUAL_FLOW",
		"EXPORT_REPLAY", "EXPORT_BATTLE_TRACE", "REPLAY_BATTLE_TRACE",
		"GENERATE_NODE_OPTIONS", "GENERATE_BATTLE_OPTIONS", "REWARD_OPTIONS",
	],
	"route_reward": [
		"CHOOSE_ROUTE", "PICK_NODE", "CLAIM_ROUTE_REWARD", "PICK_REWARD",
		"PICK_BATTLE_ENCOUNTER", "RUN_ROUTE_FIXED_BATTLE", "APPLY_ROUTE_EVENT",
	],
	"shop_inventory": [
		"ENTER_SHOP", "BACK_TO_ROUTE", "EXIT_SHOP", "BUY_OFFER", "DROP_ITEM_ON_TARGET",
		"ROLL_SHOP", "APPLY_SHOP_EVENT", "FREEZE_OFFER", "UNFREEZE_OFFER",
		"SELL_UNIT", "TOGGLE_UNIT_ACTIVE",
	],
	"run_flow": [
		"CONTINUE_AFTER_BATTLE", "START_BATTLE", "START_DEVELOPER_SCENARIO", "START_DEBUG_FIRST_BATTLE", "RUN_BATTLE", "RUN_FULL_DAY", "RUN_FULL_RUN",
		"NEW_RUN", "SET_DIFFICULTY", "SET_BOARD_DIMENSIONS", "START_NEXT_DAY",
	],
	"battle": [
		"START_NEXT_ROUND", "RUN_MONSTER_TURN", "SELECT_UNIT", "SELECT_HERO", "SELECT_CELL",
		"SELECT_ACTION_SLOT", "SELECT_SLOT", "SET_ACTION_DIRECTION", "SET_SLOT_DIR", "SET_ACTION_AP",
		"SET_SKILL_CONTROL_ORDER", "SET_QUALITY_MODE", "SET_QUALITY_MARK", "USE_ACTION_SLOT", "USE_SLOT", "CLEAR_SELECTION",
		"MOVE_HERO", "AUTO_POSITION_HEROES", "RUN_PLAYER_ALL_OUT", "RUN_COMBAT_ROUND",
		"RESET_PETS", "END_PLAYER_TURN",
	],
}

const EXPECTED_DOMAIN_PORTS := {
	"query_replay": &"ysbzs.query-replay-command-port.v1",
	"route_reward": &"ysbzs.route-reward-command-port.v1",
	"shop_inventory": &"ysbzs.shop-inventory-command-port.v1",
	"run_flow": &"ysbzs.run-flow-command-port.v1",
	"battle": &"ysbzs.battle-command-port.v1",
}

const DOMAIN_HANDLER_PATHS := {
	"query_replay": "res://core/commands/handlers/query_replay_command_handler.gd",
	"route_reward": "res://core/commands/handlers/route_reward_command_handler.gd",
	"shop_inventory": "res://core/commands/handlers/shop_inventory_command_handler.gd",
	"run_flow": "res://core/commands/handlers/run_flow_command_handler.gd",
	"battle": "res://core/commands/handlers/battle_command_handler.gd",
}


class InvalidPort extends RefCounted:
	func contract_id() -> StringName:
		return &"invalid.command-port.v1"


func _init() -> void:
	var ok := true
	var registry: RefCounted = CommandHandlerRegistryScript.new()
	var registered: Array = registry.call("registered_actions")
	var expected: Dictionary = {}
	for action_type in CommandContractScript.ACTION_ALIASES.values():
		expected[String(action_type)] = true
	for action_type in CommandContractScript.STRICT_VERSION_ACTIONS:
		expected[String(action_type)] = true
	for action_type in CommandContractScript.VIEW_STATE_ACTIONS:
		expected[String(action_type)] = true
	ok = _expect(registered.size() == expected.size(), "registry and canonical protocol have the same command count") and ok
	for action_type in expected.keys():
		ok = _expect(registered.has(String(action_type)), "registry covers %s" % action_type) and ok
	var domains: Dictionary = {}
	for action_type in registered:
		ok = _expect(expected.has(String(action_type)), "registry has no command outside the canonical protocol: %s" % action_type) and ok
		var domain := StringName(registry.call("domain_for", String(action_type)))
		ok = _expect(domain != &"", "registered command has one non-empty domain: %s" % action_type) and ok
		domains[String(domain)] = true
	var actual_domain_names: Array = domains.keys()
	actual_domain_names.sort()
	var expected_domain_names: Array = EXPECTED_DOMAIN_ACTIONS.keys()
	expected_domain_names.sort()
	ok = _expect(actual_domain_names == expected_domain_names, "registry retains the exact five command domains") and ok
	for domain_name in EXPECTED_DOMAIN_ACTIONS:
		for action_type in EXPECTED_DOMAIN_ACTIONS[domain_name]:
			ok = _expect(
				StringName(registry.call("domain_for", String(action_type))) == StringName(domain_name),
				"%s remains owned by the %s domain" % [action_type, domain_name]
			) and ok
	ok = _expect(CommandContractScript.STRICT_VERSION_ACTIONS.has("SET_BOARD_DIMENSIONS"), "board-dimension writes require strict stateVersion") and ok
	ok = _expect(CommandContractScript.STRICT_VERSION_ACTIONS.has("START_DEBUG_FIRST_BATTLE"), "debug battle setup is a strict authoritative write") and ok
	ok = _expect(CommandContractScript.STRICT_VERSION_ACTIONS.has("START_DEVELOPER_SCENARIO"), "generic Scenario setup is a strict authoritative write") and ok

	ok = _expect(StringName(registry.call("domain_for", "BUY_OFFER")) == &"shop_inventory", "shop command resolves to shop domain") and ok
	ok = _expect(StringName(registry.call("domain_for", "RUN_COMBAT_ROUND")) == &"battle", "battle command resolves to battle domain") and ok
	ok = _expect(StringName(registry.call("domain_for", "EXPORT_REPLAY")) == &"query_replay", "query command resolves to query domain") and ok
	ok = _expect(StringName(registry.call("domain_for", "GET_DEBUG_PET_CATALOG")) == &"query_replay", "debug catalog reuses the query domain") and ok
	ok = _expect(StringName(registry.call("domain_for", "GET_DEVELOPER_OBJECT_CATALOG")) == &"query_replay", "typed developer catalog reuses the query domain") and ok
	ok = _expect(StringName(registry.call("domain_for", "START_DEVELOPER_SCENARIO")) == &"run_flow", "generic Scenario start reuses the run-flow domain") and ok
	ok = _expect(StringName(registry.call("domain_for", "START_DEBUG_FIRST_BATTLE")) == &"run_flow", "debug battle start reuses the run-flow domain") and ok

	var versioned_state: RefCounted = StateScript.new()
	var before_width := int(versioned_state.get("board_width"))
	var before_height := int(versioned_state.get("board_height"))
	var before_version := int(versioned_state.get("state_version"))
	var stale_dimensions: Dictionary = versioned_state.call("run_command", {
		"type": "SET_BOARD_DIMENSIONS",
		"width": 9,
		"height": 8,
		"baseStateVersion": before_version - 1,
	})
	ok = _expect(not bool(stale_dimensions.get("accepted", true)), "stale board-dimension command is rejected") and ok
	ok = _expect(String(Dictionary(stale_dimensions.get("error", {})).get("code", "")) == "STATE_VERSION_MISMATCH", "stale board-dimension command reports the version error") and ok
	ok = _expect(int(versioned_state.get("board_width")) == before_width, "stale board-dimension command preserves width exactly") and ok
	ok = _expect(int(versioned_state.get("board_height")) == before_height, "stale board-dimension command preserves height exactly") and ok
	ok = _expect(int(versioned_state.get("state_version")) == before_version, "stale board-dimension command preserves state version exactly") and ok

	var state: RefCounted = StateScript.new()
	var port_factory: RefCounted = CommandPortFactoryScript.new()
	for domain_name in EXPECTED_DOMAIN_PORTS:
		var port: RefCounted = port_factory.create(StringName(domain_name), state)
		ok = _expect(port != null, "%s resolves one command capability Port" % domain_name) and ok
		if port != null:
			ok = _expect(StringName(port.contract_id()) == EXPECTED_DOMAIN_PORTS[domain_name], "%s exposes its versioned Port contract" % domain_name) and ok
		var handler_source := FileAccess.get_file_as_string(String(DOMAIN_HANDLER_PATHS[domain_name]))
		ok = _expect(not handler_source.contains("func execute(core"), "%s handler never receives the complete core" % domain_name) and ok
		ok = _expect(not handler_source.contains("core."), "%s handler cannot probe or mutate the complete core" % domain_name) and ok
	var battle_handler: RefCounted = registry.handler_for("CLEAR_SELECTION")
	ok = _expect(not bool(battle_handler.execute(InvalidPort.new(), "CLEAR_SELECTION", {})), "handler rejects the wrong versioned Port") and ok
	ok = _expect(bool(state.call("dispatch", {"type": "GET_CELL_DETAIL", "x": 0, "y": 0})), "query handler executes through registry") and ok
	ok = _expect(bool(state.call("dispatch", {"type": "ENTER_SHOP", "poolId": "night_base", "slots": 3})), "shop handler executes through registry") and ok
	ok = _expect(bool(state.call("dispatch", {"type": "EXIT_SHOP"})), "shop exit returns through run core") and ok
	ok = _expect(bool(state.call("dispatch", {"type": "START_BATTLE"})), "run handler starts battle") and ok
	ok = _expect(bool(state.call("dispatch", {"type": "CLEAR_SELECTION"})), "battle handler executes") and ok
	ok = _expect(not bool(state.call("dispatch", {"type": "NOT_REGISTERED"})), "unknown command is rejected centrally") and ok

	var projection_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	var dispatch_source := _function_source(projection_source, "_dispatch_action")
	ok = _expect(dispatch_source.contains("_command_handler_registry.handler_for(action_type)"), "dispatch resolves the registered domain handler") and ok
	ok = _expect(dispatch_source.contains("_command_port_factory.create(_command_handler_registry.domain_for(action_type), self)"), "dispatch creates the matching narrow domain Port") and ok
	ok = _expect(dispatch_source.contains('handler.call("execute", port, action_type, action)'), "dispatch gives handlers only their domain Port") and ok
	ok = _expect(not dispatch_source.contains('handler.call("execute", self'), "dispatch never exposes the complete authoritative state to handlers") and ok

	print("SMOKE_COMMAND_HANDLER_REGISTRY_%s actions=%d" % ["OK" if ok else "FAIL", registered.size()])
	quit(0 if ok else 1)


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Failed: %s" % label)
	return condition


func _function_source(source: String, method_name: String) -> String:
	var start := source.find("func %s(" % method_name)
	if start < 0:
		return ""
	var next_method := source.find("\nfunc ", start + 1)
	return source.substr(start) if next_method < 0 else source.substr(start, next_method - start)
