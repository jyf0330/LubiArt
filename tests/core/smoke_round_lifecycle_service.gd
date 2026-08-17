extends SceneTree

const RoundLifecycleServiceScript := preload("res://core/battle/round_lifecycle_service.gd")

var failed := false


class FakeRoundLifecyclePort extends RefCounted:
	var contract: StringName = &"ysbzs.round-lifecycle-port.v1"
	var events: Array[String] = []
	var units: Array = [
		{"id": "living", "name": "living", "side": "player", "hp": 3, "shield": 0, "mechanics": ["mech_shield_regen", "mech_hatch_after_rounds"]},
		{"id": "dead", "side": "player", "hp": 0},
		{"id": "enemy", "side": "enemy", "hp": 3},
	]

	func contract_id() -> StringName:
		return contract

	func units_for_side(side: String, living_only: bool) -> Array:
		var result: Array = []
		for unit_value in units:
			var unit := Dictionary(unit_value)
			if String(unit.get("side", "")) != side:
				continue
			if living_only and int(unit.get("hp", 0)) <= 0:
				continue
			result.append(unit)
		return result

	func tick_skill_cooldowns(unit: Dictionary) -> void:
		events.append("cooldown:%s" % String(unit.get("id", "")))

	func execute_attribute_hook(unit: Dictionary, hook: StringName) -> void:
		events.append("attribute:%s:%s" % [hook, String(unit.get("id", ""))])

	func mechanic_ids(unit: Dictionary) -> Array:
		events.append("mechanic_scan:%s" % String(unit.get("id", "")))
		return Array(unit.get("mechanics", []))

	func mechanism(mechanism_id: String) -> Dictionary:
		return {"id": mechanism_id}

	func mechanic_param_int(_unit: Dictionary, _definition: Dictionary, _key: String, fallback: int) -> int:
		return fallback

	func mechanic_param_string(_unit: Dictionary, _definition: Dictionary, _key: String, fallback: String) -> String:
		return fallback

	func battle_round() -> int:
		return 1

	func first_adjacent_empty_cell(_unit: Dictionary) -> Dictionary:
		return {}

	func first_empty_cell() -> Dictionary:
		return {}

	func summon_unit_on_cell(_caster: Dictionary, _mechanism: Dictionary, _cell: Dictionary, _summon_id: String, _name: String, _hp: int, _atk: int) -> Dictionary:
		return {}

	func apply_cross_damage(_unit: Dictionary, _source: Dictionary, _damage: int, _element: String, _label: String, _trace_context: Dictionary) -> Dictionary:
		return {"logs": ["cross-log"], "hit_count": 1}

	func advance_status_round(unit: Dictionary) -> void:
		events.append("status:%s" % String(unit.get("id", "")))

	func log_lines(lines: Array) -> void:
		for line in lines:
			events.append("log:%s" % String(line))


class IncompleteRoundLifecyclePort extends RefCounted:
	func contract_id() -> StringName:
		return &"ysbzs.round-lifecycle-port.v1"


func _initialize() -> void:
	var service := RoundLifecycleServiceScript.new()
	var port := FakeRoundLifecyclePort.new()
	_expect(service.run_start(port, "player"), "v1 port is accepted for round start")
	_expect(port.events == [
		"cooldown:living",
		"cooldown:dead",
		"attribute:round_start:living",
		"mechanic_scan:living",
		"log:living 回合开始触发护盾恢复：护盾 0→3。",
	], "round start preserves cooldown -> attribute -> mechanic order and living filters")
	port.events.clear()
	_expect(service.run_end(port, "player"), "v1 port is accepted for round end")
	_expect(port.events == [
		"mechanic_scan:living",
		"log:living 孵化倒计时 1/3。",
		"attribute:round_end:living",
		"status:living",
		"status:dead",
	], "round end preserves mechanic -> attribute -> status order and living filters")
	port.units = [{
		"id": "mixed",
		"name": "mixed",
		"side": "player",
		"hp": 3,
		"flags": {"selfDestructTicks": 1},
		"mechanics": ["mech_hatch_after_rounds", "mech_self_destruct"],
	}]
	port.events.clear()
	_expect(service.run_end(port, "player"), "mixed round-end mechanics are accepted")
	_expect(port.events == [
		"mechanic_scan:mixed",
		"log:mixed 自爆，造成 8 点伤害。",
		"log:mixed 孵化倒计时 1/3。",
		"log:cross-log",
		"status:mixed",
	], "typed front log entries preserve self-destruct push_front order across earlier handlers")
	port.events.clear()
	port.contract = &"ysbzs.round-lifecycle-port.v2"
	_expect(not service.run_start(port, "player"), "unknown port versions fail closed")
	_expect(port.events.is_empty(), "rejected port versions perform no partial mutation")
	_expect(not service.run_start(IncompleteRoundLifecyclePort.new(), "player"), "matching version without required capabilities fails closed")
	if failed:
		quit(1)
		return
	print("SMOKE_ROUND_LIFECYCLE_SERVICE_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
