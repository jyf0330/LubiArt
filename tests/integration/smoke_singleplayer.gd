extends "res://tests/helpers/singleplayer_smoke_suite.gd"

## Short authoritative happy path. Detailed contracts live in the neighboring
## smoke_singleplayer_* suites and focused core/session/feature smokes.


func _run() -> void:
	var state := _new_legacy_state()
	_expect(String(state.snapshot().get("phase", "")) == "route", "single-player E2E starts on the route")

	_expect(state.dispatch({"type": "PICK_NODE", "nodeId": "node_shop_basic"}), "single-player E2E enters the first formal shop")
	_expect(String(state.snapshot().get("phase", "")) == "shop", "single-player E2E reaches shop phase")
	var offer_id := _first_buyable_offer_id(state)
	_expect(offer_id != "", "single-player E2E exposes a buyable shop offer")
	if offer_id != "":
		_expect(state.dispatch({"type": "BUY_OFFER", "offer_id": offer_id}), "single-player E2E buys through the public command")
	_expect(state.dispatch({"type": "EXIT_SHOP"}), "single-player E2E leaves the shop")

	_advance_one_route_node_for_smoke(state, "single-player E2E ordinary route")
	var battle_option := _first_route_option_by_kind(Array(state.snapshot().get("route_options", [])), "battle")
	_expect(not battle_option.is_empty(), "single-player E2E reaches the fixed battle route")
	if not battle_option.is_empty():
		_expect(state.dispatch({
			"type": "RUN_ROUTE_FIXED_BATTLE",
			"optionId": String(battle_option.get("optionId", battle_option.get("id", ""))),
		}), "single-player E2E enters battle through the route command")

	_expect(String(state.snapshot().get("phase", "")) == "battle", "single-player E2E reaches battle phase")
	_clear_battle_to_result(state)
	_expect(String(state.snapshot().get("phase", "")) == "battle_end", "single-player E2E reaches battle result")
	_expect(state.dispatch({"type": "CONTINUE_AFTER_BATTLE"}), "single-player E2E continues after battle")
	_expect(String(state.snapshot().get("phase", "")) == "reward", "single-player E2E reaches reward phase")
	_expect(state.dispatch({"type": "PICK_REWARD", "index": 0}), "single-player E2E claims a reward")
	_expect(String(state.snapshot().get("phase", "")) == "route", "single-player E2E returns to route")

	var command_log := Array(state.snapshot().get("command_log", []))
	for command_type in ["PICK_NODE", "EXIT_SHOP", "RUN_ROUTE_FIXED_BATTLE", "CONTINUE_AFTER_BATTLE", "PICK_REWARD"]:
		_expect(_command_log_contains_type(command_log, command_type), "single-player E2E records %s" % command_type)
	_finish("SMOKE_SINGLEPLAYER_OK route->shop->battle->reward->route")
