extends SceneTree

const PortScript := preload("res://core/ports/run_event_port.gd")

const SNAPSHOT_KEYS := [
	"active_shop_pool",
	"active_stall",
	"battle_prep_effects",
	"coins",
	"hero_hp",
	"outer_run_effects",
	"roster",
	"shop_context_roll_count",
	"shop_event_effects",
	"shop_free_rolls",
	"shop_next_discount",
	"shop_offers",
	"shop_roll_count",
	"shop_seed_audit",
	"shop_seen_pet_ids_by_day",
]
const PUBLIC_METHODS := [
	"add_coins",
	"add_free_refreshes",
	"append_shop_event_summary",
	"begin_transaction",
	"commit_transaction",
	"contract_id",
	"current_coins",
	"duplicate_first_pet",
	"heal_hero",
	"queue_battle_prep",
	"queue_outer_run",
	"refill_shop_pool",
	"rollback_transaction",
	"select_reward_pool",
	"set_next_discount",
	"spend_coins",
	"upgrade_first_eligible_pet",
]


class FakeAuthority extends RefCounted:
	var coins := 12
	var hero_hp := 7
	var hero_max_hp := 10
	var roster: Array = [{"pet_id": "pet_a", "nested": {"value": 1}}]
	var shop_free_rolls := 1
	var shop_next_discount := 10
	var shop_offers: Array = [{"id": "offer_a", "frozen": true}]
	var active_shop_pool := "pool_a"
	var active_stall: Dictionary = {"id": "stall_a", "nested": [1]}
	var shop_event_effects: Array = [{"event_id": "old"}]
	var battle_prep_effects: Array = [{"effect_id": "prep_old"}]
	var outer_run_effects: Array = [{"effect_id": "outer_old"}]
	var shop_roll_count := 2
	var shop_context_roll_count := 3
	var shop_seen_pet_ids_by_day: Dictionary = {"1": ["pet_a"]}
	var shop_seed_audit: Array = [{"seed": "old"}]
	var phase := "route"
	var logs: Array = ["old"]
	var state_version := 99


class MissingAuthority extends RefCounted:
	var coins := 1


var _failed := false


func _initialize() -> void:
	_verify_public_contract()
	_verify_exact_deep_transaction_snapshot()
	_verify_transaction_guards_and_coin_errors()
	_verify_summary_projection_and_cap()
	if _failed:
		quit(1)
		return
	print("SMOKE_RUN_EVENT_PORT_TRANSACTION_OK snapshot_keys=15 summary_cap=20")
	quit(0)


func _verify_public_contract() -> void:
	var public_methods: Array[String] = []
	var metadata_port: RefCounted = PortScript.new(FakeAuthority.new())
	var port_script := metadata_port.get_script() as Script
	for method_value in port_script.get_script_method_list():
		var method_name := String(Dictionary(method_value).get("name", ""))
		if method_name == "" or method_name.begins_with("_"):
			continue
		public_methods.append(method_name)
	public_methods.sort()
	_expect(public_methods == PUBLIC_METHODS, "Port exposes exactly the frozen public surface")
	var authority := FakeAuthority.new()
	var port: RefCounted = PortScript.new(authority)
	_expect(port.contract_id() == &"ysbzs.run-event-port.v1", "contract id is frozen")
	_expect(not PortScript.new(MissingAuthority.new()).begin_transaction(), "missing authority fields fail before transaction")


func _verify_exact_deep_transaction_snapshot() -> void:
	var authority := FakeAuthority.new()
	var before := _capture(authority)
	var port: RefCounted = PortScript.new(authority)
	_expect(port.begin_transaction(), "complete authority begins transaction")
	_expect(not port.begin_transaction(), "nested transaction fails without replacing snapshot")
	for key in SNAPSHOT_KEYS:
		authority.set(key, _mutated_value(authority.get(key)))
	authority.phase = "battle"
	authority.logs.append("during transaction")
	authority.state_version = 100
	_expect(port.rollback_transaction(), "active transaction rolls back")
	_expect(_capture(authority) == before, "rollback restores exactly all 15 captured fields")
	_expect(authority.phase == "battle" and authority.logs == ["old", "during transaction"] and authority.state_version == 100, "rollback does not restore phase, logs, or state version")
	var roster := authority.roster
	Dictionary(roster[0])["nested"] = {"value": 999}
	_expect(Dictionary(Dictionary(before.get("roster", [])[0]).get("nested", {})).get("value", 0) == 1, "snapshot comparison source is deep detached")
	_expect(not port.rollback_transaction(), "rollback without active transaction fails")


func _verify_transaction_guards_and_coin_errors() -> void:
	var authority := FakeAuthority.new()
	var port: RefCounted = PortScript.new(authority)
	var outside: Dictionary = Dictionary(port.add_coins(4))
	_expect(not bool(outside.get("ok", true)) and authority.coins == 12, "mutator outside transaction fails without mutation")
	_expect(port.begin_transaction(), "coin transaction begins")
	var negative: Dictionary = Dictionary(port.spend_coins(-1))
	_expect(not bool(negative.get("ok", true)) and String(negative.get("code", "")) == "invalid_amount", "negative spend uses frozen invalid_amount code")
	var insufficient: Dictionary = Dictionary(port.spend_coins(13))
	_expect(not bool(insufficient.get("ok", true)) and String(insufficient.get("code", "")) == "insufficient_coins", "insufficient spend uses frozen code")
	_expect(bool(port.add_coins(3).get("ok", false)) and authority.coins == 15, "valid add mutates inside transaction")
	_expect(port.commit_transaction(), "successful commit keeps mutation")
	_expect(authority.coins == 15, "commit preserves changed authority")
	_expect(not port.commit_transaction(), "commit without active transaction fails")


func _verify_summary_projection_and_cap() -> void:
	var authority := FakeAuthority.new()
	authority.shop_event_effects = []
	var port: RefCounted = PortScript.new(authority)
	_expect(port.begin_transaction(), "summary transaction begins")
	for index in range(22):
		var result: Dictionary = Dictionary(port.append_shop_event_summary({
			"event_id": "evt_%02d" % index,
			"name": "Event %02d" % index,
			"source": "shop_event",
			"node_id": "node_%02d" % index,
			"free_rolls": index,
			"next_discount": index,
			"targeted_pool_id": "pool_%02d" % index,
			"construction": {"index": index},
			"foreign": "must be dropped",
		}))
		_expect(bool(result.get("ok", false)), "summary %d appends" % index)
	_expect(port.commit_transaction(), "summary transaction commits")
	_expect(authority.shop_event_effects.size() == 20, "summary FIFO keeps exactly 20")
	_expect(String(Dictionary(authority.shop_event_effects[0]).get("event_id", "")) == "evt_02", "summary FIFO drops oldest rows")
	_expect(String(Dictionary(authority.shop_event_effects[19]).get("event_id", "")) == "evt_21", "summary FIFO retains newest row")
	for summary_value in authority.shop_event_effects:
		var keys := Dictionary(summary_value).keys()
		keys.sort()
		_expect(keys == ["construction", "event_id", "free_rolls", "name", "next_discount", "node_id", "source", "targeted_pool_id"], "summary projection contains exactly eight keys")


func _capture(authority: FakeAuthority) -> Dictionary:
	var result := {}
	for key in SNAPSHOT_KEYS:
		var value: Variant = authority.get(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func _mutated_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return int(value) + 100
		TYPE_STRING:
			return "%s_mutated" % String(value)
		TYPE_ARRAY:
			return [{"mutated": true}]
		TYPE_DICTIONARY:
			return {"mutated": true}
	return null


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_RUN_EVENT_PORT_TRANSACTION_FAIL: %s" % label)
