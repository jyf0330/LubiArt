extends SceneTree

const DamageResolverScript := preload("res://core/battle/damage_resolver.gd")
const DamageDeathServiceScript := preload("res://core/battle/mechanics/damage_death_service.gd")

var failed := false


class FakeDamagePort extends RefCounted:
	var outgoing_multiplier := 1
	var order: Array[String] = []
	var hook_props: Array[Dictionary] = []

	func contract_id() -> StringName: return &"ysbzs.damage-resolution-port.v2"
	func leader_guard_active(_target: Dictionary) -> bool: return false
	func leader_guarded_damage_packet(_target: Dictionary, amount: int) -> int: return amount
	func before_damage(_target: Dictionary, _source: Dictionary, amount: int, _element: String, damage_props: Dictionary) -> Dictionary:
		order.append("before_damage")
		hook_props.append(damage_props.duplicate(true))
		return {"damage": amount, "logs": []}
	func stat_value(unit: Dictionary, stat_id: String, _context: Dictionary, fallback: int) -> int:
		return int(unit.get(stat_id, fallback))
	func apply_stat_semantics(event_id: String, context: Dictionary) -> Dictionary:
		order.append(event_id)
		var result := context.duplicate(true)
		if event_id == "damage_outgoing":
			result["amount"] = int(result.get("amount", 0)) * outgoing_multiplier
		return result
	func is_boss(_unit: Dictionary) -> bool: return false
	func heal_source(_source: Dictionary, amount: int) -> int: return amount
	func sync_leader_hp(_target: Dictionary) -> void: pass
	func record_trace(
		_source: Dictionary,
		_target: Dictionary,
		_raw_damage: int,
		_shield_damage: int,
		_hp_damage: int,
		_hp_before: int,
		_hp_after: int,
		_shield_before: int,
		_shield_after: int,
		_element: String,
		_trace_context: Dictionary
	) -> void:
		order.append("trace")
	func on_shield_break(_target: Dictionary, _source: Dictionary) -> Array:
		order.append("shield_break")
		return []
	func after_damage(_target: Dictionary, _source: Dictionary, _amount: int, damage_props: Dictionary) -> Array:
		order.append("after_damage")
		hook_props.append(damage_props.duplicate(true))
		return []
	func after_hit(_target: Dictionary, _source: Dictionary, _amount: int, damage_props: Dictionary) -> Array:
		order.append("after_hit")
		hook_props.append(damage_props.duplicate(true))
		return []


class FakeDamagePreviewPort extends FakeDamagePort:
	func contract_id() -> StringName: return &"ysbzs.damage-preview-port.v1"


class FakeDeathPort extends RefCounted:
	var order: Array[String] = []

	func contract_id() -> StringName: return &"ysbzs.damage-death-port.v1"
	func should_die(target: Dictionary) -> bool: return int(target.get("hp", 0)) <= 0
	func on_death(_target: Dictionary, _source: Dictionary) -> Array:
		order.append("on_death")
		return ["death"]
	func after_ally_death(_target: Dictionary) -> Array:
		order.append("after_ally_death")
		return ["ally"]
	func attacker_after_kill(_source: Dictionary, _target: Dictionary) -> Array:
		order.append("attacker_after_kill")
		return ["kill"]
	func publish_defeated(_source: Dictionary, _target: Dictionary) -> void:
		order.append("publish_defeated")


func _initialize() -> void:
	_test_default_packet_and_phase_order()
	_test_composable_props()
	_test_calculation_kind_is_independent_from_element_attribution()
	_test_rich_overkill_result_and_preview()
	_test_death_safe_point_is_stable_and_one_shot()
	if failed:
		quit(1)
		return
	print("SMOKE_STS2_DAMAGE_PIPELINE_OK")
	quit(0)


func _test_default_packet_and_phase_order() -> void:
	var resolver := DamageResolverScript.new()
	var port := FakeDamagePort.new()
	var source := {"id": "source", "side": "player"}
	var target := {"id": "target", "side": "enemy", "hp": 10, "shield": 3, "def": 1}
	var result := Dictionary(resolver.resolve(port, source, target, 8))
	_expect(int(target.get("hp", -1)) == 6 and int(target.get("shield", -1)) == 0, "one packet passes through defense, shield, then HP")
	_expect(int(result.get("blocked_damage", -1)) == 3 and int(result.get("unblocked_damage", -1)) == 4, "result exposes blocked and unblocked portions")
	_expect(int(result.get("total_damage", -1)) == 7 and int(result.get("actual_damage", -1)) == 7, "result exposes total and actual damage")
	_expect(bool(result.get("was_block_broken", false)) and not bool(result.get("was_fully_blocked", true)), "result exposes block outcomes")
	_expect(String(result.get("schema", "")) == "ysbzs.damage-result" and int(result.get("schema_version", 0)) == 1, "damage result has a stable transient schema")
	_expect(port.order.find("trace") < port.order.find("damage_after"), "trace/history is written before after-damage semantics")
	_expect(port.order.find("damage_after") < port.order.find("after_damage") and port.order.find("after_damage") < port.order.find("after_hit"), "after hooks keep deterministic order")
	var blocked_target := {"id": "blocked", "hp": 10, "shield": 5, "def": 0}
	var fully_blocked := Dictionary(resolver.resolve(FakeDamagePort.new(), source, blocked_target, 3))
	_expect(bool(fully_blocked.get("was_fully_blocked", false)) and not bool(fully_blocked.get("was_block_broken", true)), "result distinguishes a fully blocked packet from block break")


func _test_composable_props() -> void:
	var resolver := DamageResolverScript.new()
	var powered_port := FakeDamagePort.new()
	powered_port.outgoing_multiplier = 2
	var powered_target := {"id": "powered", "hp": 30, "shield": 0, "def": 0}
	var powered := Dictionary(resolver.resolve(powered_port, {"id": "source"}, powered_target, 5))
	_expect(int(powered.get("unblocked_damage", -1)) == 10, "powered packet consumes outgoing stat semantics")

	var unpowered_port := FakeDamagePort.new()
	unpowered_port.outgoing_multiplier = 2
	var unpowered_target := {"id": "unpowered", "hp": 30, "shield": 0, "def": 0}
	var unpowered := Dictionary(resolver.resolve(unpowered_port, {"id": "source"}, unpowered_target, 5, "", true, {}, ["Unpowered", "SkipHurtAnim"]))
	_expect(int(unpowered.get("unblocked_damage", -1)) == 5, "unpowered skips only outgoing power semantics")
	_expect(bool(Dictionary(unpowered.get("props", {})).get("unpowered", false)) and bool(Dictionary(unpowered.get("props", {})).get("skip_hurt_anim", false)), "orthogonal props compose and normalize aliases")
	_expect(not unpowered_port.order.has("damage_outgoing") and unpowered_port.order.has("damage_incoming"), "unpowered keeps receiver-side damage stages")
	_expect(unpowered_port.hook_props.size() == 3 and unpowered_port.hook_props.all(func(props: Dictionary) -> bool: return bool(props.get("unpowered", false)) and bool(props.get("skip_hurt_anim", false))), "before/after hooks receive the same normalized props as the resolver")

	var unblockable_target := {"id": "unblockable", "hp": 10, "shield": 5, "def": 0}
	var unblockable := Dictionary(resolver.resolve(FakeDamagePort.new(), {"id": "source"}, unblockable_target, 3, "", true, {}, {"Unblockable": true, "Move": true}))
	_expect(int(unblockable_target.get("shield", -1)) == 5 and int(unblockable_target.get("hp", -1)) == 7, "unblockable bypasses shield without becoming a separate damage formula")
	_expect(int(unblockable.get("blocked_damage", -1)) == 0 and bool(Dictionary(unblockable.get("props", {})).get("move", false)), "result preserves composed packet props")


func _test_calculation_kind_is_independent_from_element_attribution() -> void:
	var resolver := DamageResolverScript.new()
	var source := {"id": "source"}
	var target := {
		"id": "typed",
		"hp": 30,
		"shield": 0,
		"def": 0,
		"physical_taken_permille": 500,
		"element_taken_permille": 2000,
		"fire_resistance_permille": 500,
	}
	var physical := Dictionary(resolver.resolve(FakeDamagePort.new(), source, target, 10, "火", false, {"calculationKind": "physical"}))
	_expect(int(physical.get("final", -1)) == 5, "physical calculation uses physical taken even when the packet carries element attribution")
	var elemental_target := target.duplicate(true)
	elemental_target["hp"] = 30
	var elemental := Dictionary(resolver.resolve(FakeDamagePort.new(), source, elemental_target, 10, "火", false, {"calculationKind": "elemental"}))
	_expect(int(elemental.get("final", -1)) == 10, "elemental calculation uses elemental taken and matching resistance")
	var preview_target := target.duplicate(true)
	preview_target["hp"] = 30
	var preview := Dictionary(resolver.preview(FakeDamagePreviewPort.new(), source, preview_target, 10, "火", {"calculationKind": "physical"}))
	_expect(int(preview.get("final", -1)) == 5, "preview and mutation share the explicit calculation kind")


func _test_rich_overkill_result_and_preview() -> void:
	var resolver := DamageResolverScript.new()
	var target := {"id": "fragile", "name": "Fragile", "side": "enemy", "hp": 4, "shield": 0, "def": 0}
	var result := Dictionary(resolver.resolve(FakeDamagePort.new(), {"id": "source"}, target, 10))
	_expect(int(result.get("unblocked_damage", -1)) == 4 and int(result.get("hp_lost", -1)) == 4 and int(result.get("overkill_damage", -1)) == 6, "actual unblocked loss and overkill are explicit instead of inferred later")
	_expect(int(result.get("total_damage", -1)) == 4 and int(result.get("hp_damage", -1)) == 10 and int(result.get("final", -1)) == 10, "rich totals follow actual loss while legacy packet keys stay compatible")
	_expect(bool(result.get("pending_death", false)) and not bool(result.get("was_target_killed", true)), "primitive marks death pending but does not settle it")
	_expect(String(Dictionary(result.get("receiver", {})).get("id", "")) == "fragile", "result identifies the receiver")

	var preview_target := {"id": "preview", "hp": 8, "shield": 2, "def": 0}
	var preview := Dictionary(resolver.preview(FakeDamagePreviewPort.new(), {"id": "source"}, preview_target, 5, "", {}, {"unblockable": true}))
	_expect(int(preview.get("unblocked_damage", -1)) == 5 and int(preview_target.get("hp", -1)) == 8 and int(preview_target.get("shield", -1)) == 2, "preview uses the same props without mutating authority state")


func _test_death_safe_point_is_stable_and_one_shot() -> void:
	var service := DamageDeathServiceScript.new()
	var port := FakeDeathPort.new()
	var source := {"id": "source", "side": "player"}
	var target := {"id": "target", "side": "enemy", "hp": 0}
	var first_result := {"pending_death": true, "was_target_killed": false}
	var duplicate_result := {"pending_death": true, "was_target_killed": false}
	var logs := service.resolve(port, [
		{"source": source, "target": target, "result": first_result},
		{"source": source, "target": target, "result": duplicate_result},
	])
	_expect(port.order == ["on_death", "after_ally_death", "attacker_after_kill", "publish_defeated"], "death safe point preserves hook and publication order")
	_expect(logs == ["death", "ally", "kill"], "one target settles once even if a batch contains duplicate lethal packets")
	_expect(not bool(first_result.get("pending_death", true)) and bool(first_result.get("was_target_killed", false)), "death settlement enriches the original damage result")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
