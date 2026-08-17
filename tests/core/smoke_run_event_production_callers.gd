extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const RepositoryScript := preload("res://persistence/game_data_repository.gd")

const CURRENT_ASSEMBLY := &"current_assembly"
const PERSISTED_SNAPSHOT := &"persisted_snapshot"
const CONTENT_ROOT := "res://data/content"

var _failed := false
var _modern_content: Dictionary = {}
var _legacy_content: Dictionary = {}


class InvalidRunEventService extends RefCounted:
	func execute(port: RefCounted, event: Dictionary, _context: Dictionary, _operations: Array) -> Dictionary:
		var coins := int(port.current_coins())
		return {
			"ok": false,
			"code": "invalid_operations",
			"event_id": String(event.get("id", "")),
			"coins_from": coins,
			"coins_to": coins,
			"operation_results": [],
			"shop_effect": {},
			"battle_prep_effect": {},
			"outer_run_effect": {},
			"reward_pool_id": "",
			"logs": [],
		}


func _initialize() -> void:
	var repository := RepositoryScript.new()
	_modern_content = Dictionary(repository.read_content_pack(CONTENT_ROOT))
	_legacy_content = _legacy_run_event_content(_modern_content)
	_expect(repository.content_errors().is_empty() and not _modern_content.is_empty(), "production content fixture loads")
	_verify_modern_legacy_caller_parity()
	_verify_insufficient_route_is_atomic()
	_verify_invalid_route_is_atomic()
	_verify_post_battle_projection_chain()
	if _failed:
		quit(1)
		return
	print("SMOKE_RUN_EVENT_PRODUCTION_CALLERS_OK parity=modern+legacy failures=atomic post_battle=chained")
	quit(0)


func _verify_modern_legacy_caller_parity() -> void:
	var modern_route := _route_event_result(false)
	var legacy_route := _route_event_result(true)
	_expect(modern_route == legacy_route, "route-event caller preserves modern and legacy results")
	_expect(bool(modern_route.get("ok", false)), "route event succeeds through the public command")
	_expect(int(modern_route.get("coins", 0)) == 19, "route event spends its typed one-coin cost")
	_expect(String(modern_route.get("pool", "")) != "elem_火", "route context skips shop-only refill")
	_expect(int(modern_route.get("shop_context_roll_count", -1)) == 0, "route context does not consume shop RNG")
	_expect(int(Dictionary(modern_route.get("active_schedule", {})).get("step", 0)) == 2, "successful route event advances to the next schedule")

	var modern_shop := _shop_event_result(false)
	var legacy_shop := _shop_event_result(true)
	_expect(modern_shop == legacy_shop, "shop-event caller preserves modern and legacy results")
	_expect(bool(modern_shop.get("ok", false)) and int(modern_shop.get("coins", 0)) == 19, "shop event spends its typed one-coin cost")
	_expect(String(modern_shop.get("pool", "")) == "elem_火", "shop context executes the targeted refill")
	_expect(int(modern_shop.get("offer_count", 0)) >= 3, "shop refill produces the declared minimum offer count")

	var modern_rest := _rest_result(false)
	var legacy_rest := _rest_result(true)
	_expect(modern_rest == legacy_rest, "rest caller preserves modern and legacy results")
	_expect(bool(modern_rest.get("ok", false)), "rest succeeds through the public command")
	_expect(int(modern_rest.get("hero_hp", 0)) == 24 and int(modern_rest.get("coins", 0)) == 12, "rest uses typed heal four then add two")
	_expect(int(modern_rest.get("hero_hp", 0)) != 80, "rest ignores the source node value=999")

	var modern_post := _post_battle_result(false)
	var legacy_post := _post_battle_result(true)
	_expect(modern_post == legacy_post, "post-battle caller preserves modern and legacy results")
	_expect(String(modern_post.get("reward_pool_id", "")) == "reward_fast_clear", "structured WIN_FAST trigger selects the fast-clear pool")
	var events := Array(modern_post.get("events", []))
	_expect(events.size() == 1 and String(Dictionary(events[0]).get("condition", "")) == "fast_clear_win", "condition_label is projected into the legacy public shape")


func _route_event_result(legacy: bool) -> Dictionary:
	var state := _new_state(legacy)
	state.set("coins", 20)
	state.set("route_options", [{
		"id": "typed-route-event",
		"optionId": "typed-route-event",
		"kind": "event",
		"schedule": {"day": 1, "step": 1},
		"sourceNode": {
			"nodeId": "typed-route-event-node",
			"eventId": "evt_shop_fire",
			"value": 999,
		},
	}])
	var before_version := int(state.get("state_version"))
	var ok := bool(state.dispatch({"type": "CHOOSE_ROUTE", "optionId": "typed-route-event"}))
	return {
		"ok": ok,
		"coins": int(state.get("coins")),
		"pool": String(state.get("active_shop_pool")),
		"offers": Array(state.get("shop_offers")).duplicate(true),
		"shop_roll_count": int(state.get("shop_roll_count")),
		"shop_context_roll_count": int(state.get("shop_context_roll_count")),
		"active_schedule": Dictionary(state.get("active_schedule")).duplicate(true),
		"state_version_delta": int(state.get("state_version")) - before_version,
		"summary": Array(state.get("shop_event_effects")).duplicate(true),
	}


func _shop_event_result(legacy: bool) -> Dictionary:
	var state := _new_state(legacy)
	state.set("coins", 20)
	_expect(state.dispatch({"type": "ENTER_SHOP", "poolId": "night_base", "slots": 3}), "shop parity fixture enters shop")
	var before_version := int(state.get("state_version"))
	var ok := bool(state.dispatch({"type": "APPLY_SHOP_EVENT", "eventId": "evt_shop_fire"}))
	return {
		"ok": ok,
		"coins": int(state.get("coins")),
		"pool": String(state.get("active_shop_pool")),
		"offers": Array(state.get("shop_offers")).duplicate(true),
		"offer_count": Array(state.get("shop_offers")).size(),
		"shop_roll_count": int(state.get("shop_roll_count")),
		"shop_context_roll_count": int(state.get("shop_context_roll_count")),
		"state_version_delta": int(state.get("state_version")) - before_version,
		"summary": Array(state.get("shop_event_effects")).duplicate(true),
	}


func _rest_result(legacy: bool) -> Dictionary:
	var state := _new_state(legacy)
	state.set("hero_hp", 20)
	state.set("coins", 10)
	state.set("route_options", [{
		"id": "typed-rest",
		"optionId": "typed-rest",
		"kind": "rest",
		"schedule": {"day": 1, "step": 1},
		"sourceNode": {
			"nodeId": "node_d10_rest_gold",
			"nodeType": "rest",
			"value": 999,
		},
	}])
	var before_version := int(state.get("state_version"))
	var ok := bool(state.dispatch({"type": "CHOOSE_ROUTE", "optionId": "typed-rest"}))
	return {
		"ok": ok,
		"hero_hp": int(state.get("hero_hp")),
		"coins": int(state.get("coins")),
		"active_schedule": Dictionary(state.get("active_schedule")).duplicate(true),
		"state_version_delta": int(state.get("state_version")) - before_version,
	}


func _post_battle_result(legacy: bool) -> Dictionary:
	var state := _new_state(legacy)
	return Dictionary(state.call("_post_battle_events_for_result", "WIN_FAST", "reward_base", "encounter-fixture"))


func _verify_insufficient_route_is_atomic() -> void:
	var state := _new_state(false)
	state.set("coins", 0)
	state.set("active_schedule", {"sentinel": "keep"})
	state.set("route_options", [_route_failure_option()])
	var before := _failure_observation(state)
	var before_logs := Array(state.get("log_lines")).duplicate()
	_expect(not state.dispatch({"type": "CHOOSE_ROUTE", "optionId": "failure-route-event"}), "insufficient route event is rejected")
	var after := _failure_observation(state)
	_expect(after == before, "insufficient route event preserves hash, schedule, route, RNG, stateVersion, command and checkpoint fields")
	var after_logs := Array(state.get("log_lines"))
	_expect(after_logs.size() == before_logs.size() + 2, "insufficient route event appends player and authority rejection logs")
	_expect(String(after_logs[0]).contains("权威状态未改变") and String(after_logs[1]).contains("需要1金币"), "insufficient route event exposes both atomic rejection and player-facing reason")


func _verify_invalid_route_is_atomic() -> void:
	var state := _new_state(false)
	state.configure_core_services({"run_event_effect_service": InvalidRunEventService.new()})
	state.set("coins", 20)
	state.set("active_schedule", {"sentinel": "keep"})
	state.set("route_options", [_route_failure_option()])
	var before := _failure_observation(state)
	var before_logs := Array(state.get("log_lines")).duplicate()
	_expect(not state.dispatch({"type": "CHOOSE_ROUTE", "optionId": "failure-route-event"}), "invalid route operation is rejected")
	_expect(_failure_observation(state) == before, "invalid route operation preserves all gameplay/checkpoint fields")
	var after_logs := Array(state.get("log_lines"))
	_expect(after_logs.size() == before_logs.size() + 1 and String(after_logs[0]).contains("权威状态未改变"), "invalid route operation writes only the authority rejection audit log")


func _verify_post_battle_projection_chain() -> void:
	var content := _modern_content.duplicate(true)
	var economy := Dictionary(content.get("economy", {})).duplicate(true)
	var events := Array(economy.get("events", [])).duplicate(true)
	var source_event: Dictionary = {}
	for event_value in events:
		if String(Dictionary(event_value).get("id", "")) == "evt_battle_bonus":
			source_event = Dictionary(event_value).duplicate(true)
			break
	_expect(not source_event.is_empty(), "post-battle chain fixture finds the formal source event")
	if source_event.is_empty():
		return
	source_event["id"] = "fixture_post_battle_second"
	source_event["name"] = "fixture second selector"
	source_event["event_operations"] = [{
		"id": "fixture_post_battle_second.select",
		"operation": "select_reward_pool",
		"priority": 100,
		"params": {"pool_id": "reward_none"},
	}]
	source_event["event_triggers"] = [{
		"id": "fixture_post_battle_second.trigger",
		"hook": "post_battle",
		"priority": 101,
		"conditions": {"result_codes": ["WIN_FAST"]},
		"condition_label": "fixture_second",
	}]
	events.append(source_event)
	economy["events"] = events
	content["economy"] = economy
	var state := StateScript.new({
		"mode": "test",
		"content_pack": content,
		"content_source_kind": CURRENT_ASSEMBLY,
	})
	_expect(state.is_initialized(), "multiple post-battle trigger fixture binds")
	if not state.is_initialized():
		return
	var result := Dictionary(state.call("_post_battle_events_for_result", "WIN_FAST", "reward_base", "encounter-chain"))
	var projected := Array(result.get("events", []))
	_expect(projected.size() == 2, "multiple post-battle triggers execute in stable order")
	if projected.size() != 2:
		return
	_expect(String(Dictionary(projected[0]).get("reward_pool_from", "")) == "reward_base", "first trigger starts at the base pool")
	_expect(String(Dictionary(projected[0]).get("reward_pool_to", "")) == "reward_fast_clear", "first trigger selects the fast-clear pool")
	_expect(String(Dictionary(projected[1]).get("reward_pool_from", "")) == "reward_fast_clear", "second trigger chains from the prior selection")
	_expect(String(Dictionary(projected[1]).get("reward_pool_to", "")) == "reward_none", "second trigger selects its declared pool")


func _route_failure_option() -> Dictionary:
	return {
		"id": "failure-route-event",
		"optionId": "failure-route-event",
		"kind": "event",
		"schedule": {"day": 1, "step": 1, "sentinel": "must-not-write"},
		"sourceNode": {
			"nodeId": "failure-route-node",
			"eventId": "evt_shop_fire",
		},
	}


func _failure_observation(state: RefCounted) -> Dictionary:
	return {
		"state_hash": String(state.call("_state_hash")),
		"state_version": int(state.get("state_version")),
		"coins": int(state.get("coins")),
		"hero_hp": int(state.get("hero_hp")),
		"roster": Array(state.get("roster")).duplicate(true),
		"shop_offers": Array(state.get("shop_offers")).duplicate(true),
		"active_shop_pool": String(state.get("active_shop_pool")),
		"active_schedule": Dictionary(state.get("active_schedule")).duplicate(true),
		"node_index": int(state.get("node_index")),
		"route_options": Array(state.get("route_options")).duplicate(true),
		"shop_roll_count": int(state.get("shop_roll_count")),
		"shop_context_roll_count": int(state.get("shop_context_roll_count")),
		"shop_seen": Dictionary(state.get("shop_seen_pet_ids_by_day")).duplicate(true),
		"shop_seed_audit": Array(state.get("shop_seed_audit")).duplicate(true),
		"battle_prep_effects": Array(state.get("battle_prep_effects")).duplicate(true),
		"outer_run_effects": Array(state.get("outer_run_effects")).duplicate(true),
		"command_log_size": Array(state.get("command_log")).size(),
		"history_command_index": int(state.get("history_command_index")),
	}


func _new_state(legacy: bool) -> RefCounted:
	return StateScript.new({
		"mode": "test",
		"content_pack": (_legacy_content if legacy else _modern_content).duplicate(true),
		"content_source_kind": PERSISTED_SNAPSHOT if legacy else CURRENT_ASSEMBLY,
	})


func _legacy_run_event_content(modern_content: Dictionary) -> Dictionary:
	var result := modern_content.duplicate(true)
	var economy := Dictionary(result.get("economy", {})).duplicate(true)
	economy.erase("runtime_schema_version")
	var events: Array = []
	for event_value in Array(economy.get("events", [])):
		var event := Dictionary(event_value).duplicate(true)
		event.erase("event_operations")
		event.erase("event_triggers")
		events.append(event)
	economy["events"] = events
	result["economy"] = economy
	var route := Dictionary(result.get("route", {})).duplicate(true)
	var nodes: Array = []
	for node_value in Array(route.get("node_pool", [])):
		var node := Dictionary(node_value).duplicate(true)
		node.erase("event_operations")
		nodes.append(node)
	route["node_pool"] = nodes
	result["route"] = route
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_RUN_EVENT_PRODUCTION_CALLERS_FAIL: %s" % message)
