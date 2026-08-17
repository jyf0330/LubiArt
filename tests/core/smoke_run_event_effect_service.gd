extends SceneTree

const ServiceScript := preload("res://core/run/run_event_effect_service.gd")

const ENVELOPE_KEYS := [
	"battle_prep_effect",
	"code",
	"coins_from",
	"coins_to",
	"event_id",
	"logs",
	"ok",
	"operation_results",
	"outer_run_effect",
	"reward_pool_id",
	"shop_effect",
]


class FakeHandler extends RefCounted:
	var operation_id := ""

	func _init(value: String) -> void:
		operation_id = value

	func execute(port: RefCounted, _event: Dictionary, _context: Dictionary, params: Dictionary) -> Variant:
		match operation_id:
			"spend_coins":
				return port.spend_coins(int(params.get("amount", 0)))
			"add_coins":
				return port.add_coins(int(params.get("amount", 0)))
			"handler_failure":
				return {"ok": false, "code": "forced_failure"}
			"invalid_result":
				return ["not", "a", "Dictionary"]
			"invalid_ok_type":
				return {"ok": "true", "code": "ok"}
			"valid_logs":
				return {"ok": true, "code": "ok", "logs": ["first", "second"]}
			"invalid_logs_type":
				return {"ok": true, "code": "ok", "logs": "not-an-array"}
			"invalid_logs_item":
				return {"ok": true, "code": "ok", "logs": [""]}
		return {"ok": true, "code": "ok"}


class FakeRegistry extends RefCounted:
	var _handlers := {}

	func _init() -> void:
		for operation_id in [
			"noop", "spend_coins", "add_coins", "handler_failure", "invalid_result", "invalid_ok_type",
			"valid_logs", "invalid_logs_type", "invalid_logs_item",
		]:
			_handlers[operation_id] = FakeHandler.new(operation_id)

	func is_valid() -> bool:
		return true

	func validation_errors() -> Array[String]:
		return []

	func handler_for(operation_id: String) -> RefCounted:
		return _handlers.get(operation_id) as RefCounted

	func validate_params(_operation_id: String, params: Dictionary) -> Array[String]:
		return ["forced invalid params"] if bool(params.get("invalid", false)) else []


class FakePort extends RefCounted:
	var coins := 10
	var begin_count := 0
	var commit_count := 0
	var rollback_count := 0
	var execution_log: Array[String] = []
	var summaries: Array = []
	var _active := false
	var _snapshot := 0

	func contract_id() -> StringName:
		return &"ysbzs.run-event-port.v1"

	func begin_transaction() -> bool:
		begin_count += 1
		if _active:
			return false
		_snapshot = coins
		_active = true
		return true

	func commit_transaction() -> bool:
		commit_count += 1
		if not _active:
			return false
		_active = false
		return true

	func rollback_transaction() -> bool:
		rollback_count += 1
		if not _active:
			return false
		coins = _snapshot
		_active = false
		return true

	func current_coins() -> int:
		return coins

	func spend_coins(amount: int) -> Dictionary:
		execution_log.append("spend:%d" % amount)
		if amount < 0:
			return {"ok": false, "code": "invalid_amount"}
		if coins < amount:
			return {"ok": false, "code": "insufficient_coins"}
		var before := coins
		coins -= amount
		return {"ok": true, "code": "ok", "coins_from": before, "coins_to": coins}

	func add_coins(amount: int) -> Dictionary:
		execution_log.append("add:%d" % amount)
		var before := coins
		coins += amount
		return {"ok": true, "code": "ok", "coins_from": before, "coins_to": coins}

	func heal_hero(_amount: int) -> Dictionary:
		return {"ok": true, "code": "ok"}

	func queue_battle_prep(_event: Dictionary, _context: Dictionary, _effect_type: String, _value: int) -> Dictionary:
		return {"ok": true, "code": "ok"}

	func queue_outer_run(_event: Dictionary, _context: Dictionary, _effect_type: String, _value: int) -> Dictionary:
		return {"ok": true, "code": "ok"}

	func add_free_refreshes(_amount: int) -> Dictionary:
		return {"ok": true, "code": "ok"}

	func set_next_discount(_percent: int) -> Dictionary:
		return {"ok": true, "code": "ok"}

	func upgrade_first_eligible_pet(_event: Dictionary) -> Dictionary:
		return {"ok": true, "code": "ok", "construction": {}}

	func duplicate_first_pet(_event: Dictionary) -> Dictionary:
		return {"ok": true, "code": "ok", "construction": {}}

	func refill_shop_pool(_pool_id: String, _minimum_slots: int, _context: Dictionary) -> Dictionary:
		return {"ok": true, "code": "ok"}

	func select_reward_pool(pool_id: String) -> Dictionary:
		return {"ok": true, "code": "ok", "reward_pool_id": pool_id}

	func append_shop_event_summary(summary: Dictionary) -> Dictionary:
		execution_log.append("summary")
		summaries.append(summary.duplicate(true))
		return {"ok": true, "code": "ok", "shop_effect": summary.duplicate(true)}


class IncompletePort extends RefCounted:
	var begin_count := 0

	func contract_id() -> StringName:
		return &"ysbzs.run-event-port.v1"

	func begin_transaction() -> bool:
		begin_count += 1
		return true

	func current_coins() -> int:
		return 10


var _failed := false


func _initialize() -> void:
	_verify_context_contract_and_full_prevalidation()
	_verify_spend_first_and_stable_order()
	_verify_failure_rollbacks()
	_verify_descriptor_and_port_preflight()
	_verify_logs_commit_boundary()
	_verify_shop_summary_boundary()
	if _failed:
		quit(1)
		return
	print("SMOKE_RUN_EVENT_EFFECT_SERVICE_OK")
	quit(0)


func _verify_context_contract_and_full_prevalidation() -> void:
	var service: RefCounted = ServiceScript.new(FakeRegistry.new())
	for invalid_context in [{}, {"context_kind": ""}, {"context_kind": "unknown"}, {"context_kind": 7}]:
		var port := FakePort.new()
		var result: Dictionary = Dictionary(service.execute(port, _event(), invalid_context, [_operation("valid", "noop", 0, {})]))
		_expect(not bool(result.get("ok", true)), "missing, wrong-type, and unknown context_kind fail closed")
		_expect(port.begin_count == 0, "invalid context fails before begin")

	var invalid_context_lists := [
		[],
		["shop_event", "shop_event"],
		["unknown"],
		[7],
		"shop_event",
	]
	for invalid_contexts in invalid_context_lists:
		var port := FakePort.new()
		var operation := _operation("context_bad", "noop", 0, {})
		operation["contexts"] = invalid_contexts
		var result: Dictionary = Dictionary(service.execute(port, _event(), {"context_kind": "shop_event"}, [operation]))
		_expect(not bool(result.get("ok", true)), "empty, duplicate, wrong-type, and unknown contexts fail closed")
		_expect(port.begin_count == 0, "invalid contexts fail before begin")

	var filtered_invalid_port := FakePort.new()
	var filtered_invalid := _operation("filtered_bad", "noop", 0, {"invalid": true})
	filtered_invalid["contexts"] = ["route_event"]
	var filtered_invalid_result: Dictionary = Dictionary(service.execute(
		filtered_invalid_port,
		_event(),
		{"context_kind": "shop_event"},
		[filtered_invalid]
	))
	_expect(not bool(filtered_invalid_result.get("ok", true)), "filtered operation params are still validated")
	_expect(filtered_invalid_port.begin_count == 0, "filtered invalid params fail before transaction")
	var filtered_unknown_port := FakePort.new()
	var filtered_unknown := _operation("filtered_unknown", "unknown_handler", 0, {})
	filtered_unknown["contexts"] = ["route_event"]
	var filtered_unknown_result: Dictionary = Dictionary(service.execute(
		filtered_unknown_port,
		_event(),
		{"context_kind": "shop_event"},
		[filtered_unknown]
	))
	_expect(not bool(filtered_unknown_result.get("ok", true)), "filtered unknown handler is still resolved and rejected")
	_expect(filtered_unknown_port.begin_count == 0, "filtered unknown handler fails before transaction")

	var filtered_port := FakePort.new()
	var filtered := _operation("filtered_good", "add_coins", 0, {"amount": 99})
	filtered["contexts"] = ["route_event"]
	var unfiltered := _operation("all_contexts", "add_coins", 1, {"amount": 2})
	var filtered_result: Dictionary = Dictionary(service.execute(filtered_port, _event("event"), {"context_kind": "shop_event"}, [filtered, unfiltered]))
	_expect(bool(filtered_result.get("ok", false)), "valid filtered descriptor succeeds")
	_expect(filtered_port.coins == 12, "missing contexts executes everywhere while mismatched contexts is skipped")
	_expect(Array(filtered_result.get("operation_results", [])).size() == 1, "filtered operation emits no execution result")


func _verify_spend_first_and_stable_order() -> void:
	var service: RefCounted = ServiceScript.new(FakeRegistry.new())
	var port := FakePort.new()
	var operations := [
		_operation("add_late", "add_coins", 20, {"amount": 2}),
		_operation("spend_even_if_high_priority", "spend_coins", 999, {"amount": 4}),
		_operation("add_first_same_priority", "add_coins", 10, {"amount": 3}),
		_operation("add_second_same_priority", "add_coins", 10, {"amount": 5}),
	]
	var result: Dictionary = Dictionary(service.execute(port, _event("event"), {"context_kind": "route_event"}, operations))
	_expect(bool(result.get("ok", false)), "valid operation batch commits")
	_expect(port.execution_log == ["spend:4", "add:3", "add:5", "add:2"], "spend runs first and equal priority keeps source order")
	_expect(port.coins == 16, "ordered operations mutate transactionally")
	_expect(port.begin_count == 1 and port.commit_count == 1 and port.rollback_count == 0, "success begins and commits once")
	_expect(_sorted_keys(result) == ENVELOPE_KEYS, "success returns the fixed transient envelope")
	var operation_results := Array(result.get("operation_results", []))
	_expect(String(Dictionary(operation_results[0]).get("id", "")) == "spend_even_if_high_priority", "results preserve actual spend-first order")
	_expect(String(Dictionary(operation_results[1]).get("id", "")) == "add_first_same_priority", "results preserve stable tuple order")


func _verify_failure_rollbacks() -> void:
	var service: RefCounted = ServiceScript.new(FakeRegistry.new())
	for failing_operation in ["handler_failure", "invalid_result", "invalid_ok_type"]:
		var port := FakePort.new()
		var result: Dictionary = Dictionary(service.execute(port, _event("event"), {"context_kind": "route_event"}, [
			_operation("spend", "spend_coins", 0, {"amount": 3}),
			_operation("failure", failing_operation, 1, {}),
		]))
		_expect(not bool(result.get("ok", true)), "%s fails the batch" % failing_operation)
		_expect(port.coins == 10, "%s restores coins" % failing_operation)
		_expect(port.begin_count == 1 and port.commit_count == 0 and port.rollback_count == 1, "%s rolls back exactly once" % failing_operation)
		_expect(Array(result.get("logs", ["dirty"])).is_empty(), "%s failure exposes no logs" % failing_operation)
		_expect(int(result.get("coins_to", -1)) == 10, "%s envelope reports rolled-back coins" % failing_operation)
		_expect(_sorted_keys(result) == ENVELOPE_KEYS, "%s failure returns the fixed envelope" % failing_operation)


func _verify_descriptor_and_port_preflight() -> void:
	var service: RefCounted = ServiceScript.new(FakeRegistry.new())
	var invalid_operations := [
		{"id": "foreign", "operation": "noop", "priority": 0, "params": {}, "foreign": true},
		_operation("unknown", "unknown_handler", 0, {}),
		{"id": "wrong_params", "operation": "noop", "priority": 0, "params": []},
		_operation("duplicate", "noop", 0, {}),
	]
	var duplicate_operations := [
		_operation("same", "noop", 0, {}),
		_operation("same", "noop", 1, {}),
	]
	for operations in [[], [invalid_operations[0]], [invalid_operations[1]], [invalid_operations[2]], duplicate_operations]:
		var port := FakePort.new()
		var result: Dictionary = Dictionary(service.execute(port, _event(), {"context_kind": "shop_event"}, operations))
		_expect(not bool(result.get("ok", true)), "foreign, unknown, wrong params, and duplicate descriptor fail closed")
		_expect(port.begin_count == 0, "invalid descriptor fails before transaction")

	var incomplete := IncompletePort.new()
	var incomplete_result: Dictionary = Dictionary(service.execute(
		incomplete,
		_event(),
		{"context_kind": "shop_event"},
		[_operation("valid", "noop", 0, {})]
	))
	_expect(not bool(incomplete_result.get("ok", true)) and String(incomplete_result.get("code", "")) == "invalid_port_contract", "missing Port capability fails closed")
	_expect(incomplete.begin_count == 0, "missing Port capability fails before begin")


func _verify_logs_commit_boundary() -> void:
	var service: RefCounted = ServiceScript.new(FakeRegistry.new())
	var valid_port := FakePort.new()
	var valid: Dictionary = Dictionary(service.execute(
		valid_port,
		_event("event"),
		{"context_kind": "route_event"},
		[_operation("logs", "valid_logs", 0, {})]
	))
	_expect(bool(valid.get("ok", false)) and Array(valid.get("logs", [])) == ["first", "second"], "valid handler logs aggregate in execution order after commit")
	_expect(valid_port.commit_count == 1 and valid_port.rollback_count == 0, "valid logs are exposed only after commit")
	for handler_id in ["invalid_logs_type", "invalid_logs_item"]:
		var port := FakePort.new()
		var invalid: Dictionary = Dictionary(service.execute(
			port,
			_event("event"),
			{"context_kind": "route_event"},
			[
				_operation("spend", "spend_coins", 0, {"amount": 2}),
				_operation("logs", handler_id, 1, {}),
			]
		))
		_expect(not bool(invalid.get("ok", true)) and String(invalid.get("code", "")) == "invalid_handler_logs", "%s fails typed log validation" % handler_id)
		_expect(port.coins == 10 and port.rollback_count == 1 and port.commit_count == 0, "%s rolls back prior mutation" % handler_id)
		_expect(Array(invalid.get("logs", ["dirty"])).is_empty(), "%s failure exposes no partial logs" % handler_id)


func _verify_shop_summary_boundary() -> void:
	var service: RefCounted = ServiceScript.new(FakeRegistry.new())
	var shop_port := FakePort.new()
	var result: Dictionary = Dictionary(service.execute(shop_port, _event("shop_phase"), {
		"context_kind": "shop_event",
		"node_id": "node_shop",
	}, [
		_operation("add", "add_coins", 0, {"amount": 1}),
	]))
	_expect(bool(result.get("ok", false)), "shop-phase event succeeds")
	_expect(shop_port.execution_log == ["add:1", "summary"], "summary is appended after all operations")
	_expect(shop_port.summaries.size() == 1, "shop-phase appends exactly one summary")
	var summary := Dictionary(shop_port.summaries[0])
	_expect(_sorted_keys(summary) == ["construction", "event_id", "free_rolls", "name", "next_discount", "node_id", "source", "targeted_pool_id"], "shop summary has exactly eight frozen keys")
	_expect(String(summary.get("source", "")) == "shop_event" and String(summary.get("node_id", "")) == "node_shop", "shop summary uses structured context")

	for layer in ["event", "pre_battle", "post_battle", ""]:
		var port := FakePort.new()
		var non_shop: Dictionary = Dictionary(service.execute(port, _event(layer), {"context_kind": "route_event"}, [_operation("noop", "noop", 0, {})]))
		_expect(bool(non_shop.get("ok", false)), "non-shop layer %s succeeds" % layer)
		_expect(port.summaries.is_empty(), "non-shop layer %s never appends a shop summary" % layer)


func _event(layer: String = "shop_phase") -> Dictionary:
	return {
		"id": "evt_fixture",
		"name": "Fixture Event",
		"layer": layer,
		"shop_pool_id": "fixture_pool",
	}


func _operation(id: String, operation: String, priority: int, params: Dictionary) -> Dictionary:
	return {
		"id": id,
		"operation": operation,
		"priority": priority,
		"params": params,
	}


func _sorted_keys(value: Dictionary) -> Array:
	var keys := value.keys()
	keys.sort()
	return keys


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_RUN_EVENT_EFFECT_SERVICE_FAIL: %s" % label)
