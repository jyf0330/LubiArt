extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const PortScript := preload("res://core/ports/run_event_port.gd")
const ServiceScript := preload("res://core/run/run_event_effect_service.gd")

const CANONICAL_IDS := [
	"noop",
	"spend_coins",
	"add_coins",
	"heal_hero",
	"queue_battle_prep_shield",
	"queue_trap_damage_bonus",
	"queue_reward_gold_multiplier",
	"add_free_refreshes",
	"set_next_discount",
	"upgrade_first_eligible_pet",
	"duplicate_first_pet",
	"refill_shop_pool",
	"select_reward_pool",
]

var _failed := false


func _initialize() -> void:
	_verify_all_canonical_operations()
	_verify_no_target_construction_is_successful()
	_verify_insufficient_coins_rolls_back()
	if _failed:
		quit(1)
		return
	print("SMOKE_RUN_EVENT_OPERATIONS_BEHAVIOR_OK operations=13")
	quit(0)


func _verify_all_canonical_operations() -> void:
	var state: RefCounted = StateScript.new()
	state.coins = 20
	state.hero_hp = max(0, int(state.hero_max_hp) - 5)
	var original_roster := Array(state.roster).duplicate(true)
	var reward_options_before := Array(state.reward_options).duplicate(true)
	var logs_before := Array(state.log_lines).duplicate(true)
	var service: RefCounted = ServiceScript.new()
	var result: Dictionary = Dictionary(service.execute(
		PortScript.new(state),
		_event("evt_all"),
		{"context_kind": "shop_event", "node_id": "node_all"},
		_all_operations()
	))
	_expect(bool(result.get("ok", false)), "all 13 canonical operations execute atomically")
	var results := Array(result.get("operation_results", []))
	_expect(results.size() == 13, "all canonical operations emit one result")
	var executed_ids: Array[String] = []
	for result_value in results:
		executed_ids.append(String(Dictionary(result_value).get("operation", "")))
	for operation_id in CANONICAL_IDS:
		_expect(executed_ids.has(operation_id), "%s executed" % operation_id)
	_expect(int(result.get("coins_from", -1)) == 20 and int(result.get("coins_to", -1)) == 22, "spend 2 then add 4 preserves typed coin math")
	_expect(int(state.hero_hp) == int(state.hero_max_hp), "heal is capped by hero max HP")
	_expect(int(state.shop_free_rolls) == 2, "free refresh operation adds the requested delta")
	_expect(int(state.shop_next_discount) == 0, "refill consumes the pending discount through the legacy shop path")
	_expect(String(state.active_shop_pool) == "fixture_pool", "refill selects the typed target pool")
	_expect(Dictionary(state.active_stall).get("slots", 0) == 3, "refill uses the frozen minimum slot count")
	_expect(Array(state.battle_prep_effects).size() == 2, "shield and trap queue two pending effects")
	var shield := Dictionary(Array(state.battle_prep_effects)[0])
	var trap := Dictionary(Array(state.battle_prep_effects)[1])
	_expect(shield == {
		"effect_id": "prep_%d_%d_evt_all" % [int(state.day), int(state.node_index)],
		"event_id": "evt_all",
		"name": "All Operations",
		"source": "shop_event",
		"node_id": "node_all",
		"type": "shield",
		"shield": 0,
		"bonus_damage": 0,
		"status": "pending",
		"day_queued": int(state.day),
		"step_queued": int(state.node_index),
		"uses_remaining": 1,
	}, "zero shield still queues the exact frozen prep shape")
	_expect(String(trap.get("type", "")) == "trap_damage_bonus" and int(trap.get("bonus_damage", 0)) == 1 and int(trap.get("shield", -1)) == 0, "trap effect keeps typed bonus and zero shield")
	_expect(Array(state.outer_run_effects).size() == 1, "reward multiplier queues one outer-run effect")
	var outer := Dictionary(Array(state.outer_run_effects)[0])
	_expect(int(outer.get("multiplier", 0)) == 90 and int(outer.get("immediate_gold", -1)) == 4, "outer-run effect derives immediate_gold from prior structured add_coins")
	_expect(String(outer.get("source", "")) == "shop_event" and String(outer.get("node_id", "")) == "node_all", "outer-run shape uses structured context")
	_expect(String(result.get("reward_pool_id", "")) == "reward_fixture", "reward pool selection is transient")
	_expect(Array(state.reward_options) == reward_options_before, "reward selection never writes reward_options")
	_expect(Array(state.log_lines) == logs_before, "E0 core never writes authority logs")
	_expect(Array(state.shop_event_effects).size() == 1, "all operations append one consolidated shop summary")
	var summary := Dictionary(Array(state.shop_event_effects)[0])
	_expect(String(summary.get("event_id", "")) == "evt_all" and String(summary.get("targeted_pool_id", "")) == "summary_pool", "summary uses event identity and declared event pool")
	_expect(int(summary.get("free_rolls", 0)) == 2 and int(summary.get("next_discount", 0)) == 50, "summary retains per-event refresh delta and resulting discount before refill")
	_expect(Dictionary(summary.get("construction", {})).get("type", "") == "duplicate_pet", "last construction result is consolidated once")
	_expect(Array(state.roster).size() >= original_roster.size(), "upgrade and duplicate preserve or grow roster")


func _verify_no_target_construction_is_successful() -> void:
	for construction_operation in ["upgrade_first_eligible_pet", "duplicate_first_pet"]:
		var state: RefCounted = StateScript.new()
		state.roster = []
		state.coins = 10
		state.shop_event_effects = []
		var result: Dictionary = Dictionary(ServiceScript.new().execute(
			PortScript.new(state),
			_event("evt_no_target"),
			{"context_kind": "route_event", "node_id": "manual_no_target"},
			[
				_operation("spend", "spend_coins", 0, {"amount": 4}),
				_operation("construct", construction_operation, 10, {}),
			]
		))
		_expect(bool(result.get("ok", false)), "%s no-target is a successful no-op" % construction_operation)
		_expect(int(state.coins) == 6, "%s no-target keeps the committed spend" % construction_operation)
		_expect(Array(state.shop_event_effects).size() == 1, "%s no-target still appends summary" % construction_operation)
		_expect(Dictionary(Dictionary(Array(state.shop_event_effects)[0]).get("construction", {})).is_empty(), "%s no-target summary has empty construction" % construction_operation)


func _verify_insufficient_coins_rolls_back() -> void:
	var state: RefCounted = StateScript.new()
	state.coins = 1
	state.shop_event_effects = []
	var before := {
		"coins": state.coins,
		"effects": Array(state.shop_event_effects).duplicate(true),
		"free_rolls": state.shop_free_rolls,
	}
	var result: Dictionary = Dictionary(ServiceScript.new().execute(
		PortScript.new(state),
		_event("evt_insufficient"),
		{"context_kind": "shop_event"},
		[
			_operation("spend", "spend_coins", 100, {"amount": 2}),
			_operation("refresh", "add_free_refreshes", 0, {"amount": 2}),
		]
	))
	_expect(not bool(result.get("ok", true)) and String(result.get("code", "")) == "insufficient_coins", "insufficient spend fails with frozen code")
	_expect(state.coins == before["coins"] and Array(state.shop_event_effects) == before["effects"] and state.shop_free_rolls == before["free_rolls"], "insufficient spend rolls back every captured mutation")
	_expect(Array(result.get("logs", ["dirty"])).is_empty(), "failed transaction exposes no logs")


func _all_operations() -> Array:
	return [
		_operation("01_noop", "noop", 0, {}),
		_operation("02_spend", "spend_coins", 900, {"amount": 2}),
		_operation("03_add", "add_coins", 10, {"amount": 4}),
		_operation("04_heal", "heal_hero", 20, {"amount": 5}),
		_operation("05_shield", "queue_battle_prep_shield", 30, {"amount": 0}),
		_operation("06_trap", "queue_trap_damage_bonus", 40, {"amount": 1}),
		_operation("07_outer", "queue_reward_gold_multiplier", 50, {"percent": 90}),
		_operation("08_refresh", "add_free_refreshes", 60, {"amount": 2}),
		_operation("09_discount", "set_next_discount", 70, {"percent": 50}),
		_operation("10_upgrade", "upgrade_first_eligible_pet", 80, {}),
		_operation("11_duplicate", "duplicate_first_pet", 90, {}),
		_operation("12_refill", "refill_shop_pool", 100, {"pool_id": "fixture_pool", "minimum_slots": 3}),
		_operation("13_reward", "select_reward_pool", 110, {"pool_id": "reward_fixture"}),
	]


func _event(event_id: String) -> Dictionary:
	return {
		"id": event_id,
		"name": "All Operations",
		"layer": "shop_phase",
		"shop_pool_id": "summary_pool",
		"value": 999,
	}


func _operation(id: String, operation: String, priority: int, params: Dictionary) -> Dictionary:
	return {"id": id, "operation": operation, "priority": priority, "params": params}


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_RUN_EVENT_OPERATIONS_BEHAVIOR_FAIL: %s" % label)
