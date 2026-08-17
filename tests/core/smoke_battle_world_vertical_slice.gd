extends SceneTree

const BattleWorldScript := preload("res://core/battle/world/battle_world.gd")
const BattleWorldAdapterScript := preload("res://core/battle/world/battle_world_adapter.gd")
const BattleSystemScript := preload("res://core/battle/world/battle_system.gd")
const BattleScheduleScript := preload("res://core/battle/world/battle_schedule.gd")
const DamageSystemScript := preload("res://core/battle/world/systems/damage_system.gd")
const DeathSystemScript := preload("res://core/battle/world/systems/death_system.gd")
const LegacyDamageResolverScript := preload("res://core/battle/damage_resolver.gd")
const BATTLE_WORLD_PATHS := [
	"res://core/battle/world/battle_world.gd",
	"res://core/battle/world/battle_world_adapter.gd",
	"res://core/battle/world/battle_system.gd",
	"res://core/battle/world/battle_schedule.gd",
	"res://core/battle/world/systems/damage_system.gd",
	"res://core/battle/world/systems/death_system.gd",
]
const FORBIDDEN_DEPENDENCIES := [
	"res://art/",
	"res://core_ui/",
	"res://persistence/",
	"res://session/",
	"res://core/state/game_state.gd",
]

var _failed := false


class DamagePort:
	extends RefCounted

	func contract_id() -> StringName: return &"ysbzs.damage-resolution-port.v2"
	func leader_guard_active(_target: Dictionary) -> bool: return false
	func leader_guarded_damage_packet(_target: Dictionary, amount: int) -> int: return amount
	func before_damage(_target: Dictionary, _source: Dictionary, amount: int, _element: String, _props: Dictionary) -> Dictionary: return {"damage": amount, "logs": []}
	func stat_value(unit: Dictionary, stat_id: String, _context: Dictionary, fallback: int) -> int: return int(unit.get(stat_id, fallback))
	func apply_stat_semantics(_event_id: String, context: Dictionary) -> Dictionary: return context.duplicate(true)
	func is_boss(_unit: Dictionary) -> bool: return false
	func heal_source(_source: Dictionary, amount: int) -> int: return amount
	func sync_leader_hp(_target: Dictionary) -> void: pass
	func record_trace(_source: Dictionary, _target: Dictionary, _raw: int, _shield: int, _hp_damage: int, _hp_before: int, _hp_after: int, _shield_before: int, _shield_after: int, _element: String, _context: Dictionary) -> void: pass
	func on_shield_break(_target: Dictionary, _source: Dictionary) -> Array: return []
	func after_damage(_target: Dictionary, _source: Dictionary, _amount: int, _props: Dictionary) -> Array: return []
	func after_hit(_target: Dictionary, _source: Dictionary, _amount: int, _props: Dictionary) -> Array: return []


class SameStageVitalsReader:
	extends "res://core/battle/world/battle_system.gd"

	func system_name() -> StringName:
		return &"same_stage_vitals_reader"

	func stage() -> int:
		return 300

	func reads() -> Array[StringName]:
		return [&"vitals"]


func _initialize() -> void:
	_expect_world_dependencies_are_isolated()
	var units: Array = [
		{
			"id": "player_pet",
			"side": "player",
			"x": 1,
			"y": 2,
			"hp": 10,
			"max_hp": 10,
			"shield": 0,
			"def": 0,
			"alive": true,
			"active": true
		},
		{
			"id": "enemy_pet",
			"side": "enemy",
			"x": 5,
			"y": 2,
			"hp": 7,
			"max_hp": 7,
			"shield": 2,
			"def": 0,
			"alive": true,
			"active": true
		}
	]
	var world: RefCounted = BattleWorldAdapterScript.import_units(units)
	_expect(world.entity_count() == 2, "adapter imports two stable entities")
	_expect(world.entity_for_source("player_pet") == 0, "first source keeps stable EntityId 0")
	_expect(world.entity_for_source("enemy_pet") == 1, "second source keeps stable EntityId 1")
	_expect(
		world.query(BattleWorldScript.COMPONENT_POSITION | BattleWorldScript.COMPONENT_VITALS) == [0, 1],
		"component query order is deterministic"
	)
	_expect(world.spawn("enemy_pet") == BattleWorldScript.INVALID_ENTITY, "duplicate source ids are rejected")

	var source_entity: int = world.entity_for_source("player_pet")
	var target_entity: int = world.entity_for_source("enemy_pet")
	_expect(
		world.queue_resolved_damage(source_entity, target_entity, 9, "fire", {"sourceType": "action"}),
		"resolved damage packet enters the world resource queue"
	)
	var schedule := BattleScheduleScript.new()
	_expect(schedule.add_system(DeathSystemScript.new()), "death system registers")
	_expect(schedule.add_system(DamageSystemScript.new()), "damage system registers")
	_expect(schedule.ordered_system_names() == [&"damage", &"death"], "stage order is independent of registration order")
	var run_result := schedule.run(world)
	_expect(bool(run_result.get("ok", false)), "damage and death schedule completes")
	var events := Array(run_result.get("events", []))
	_expect(events.size() == 2, "vertical slice emits damage then death")
	if events.size() == 2:
		_expect(String(Dictionary(events[0]).get("type", "")) == "DAMAGE_APPLIED", "damage event is first")
		_expect(String(Dictionary(events[1]).get("type", "")) == "UNIT_DEFEATED", "death event is second")
		_expect(
			String(Dictionary(Dictionary(events[1]).get("actor", {})).get("id", "")) == "player_pet",
			"death event preserves the direct damage source"
		)

	var new_vitals := Dictionary(world.vitals(target_entity))
	var legacy_target := Dictionary(units[1]).duplicate(true)
	var legacy_result := LegacyDamageResolverScript.new().resolve(
		DamagePort.new(),
		Dictionary(units[0]).duplicate(true),
		legacy_target,
		9,
		"fire"
	)
	_expect(int(new_vitals.get("hp", -1)) == int(legacy_target.get("hp", -2)), "world hp matches legacy resolver")
	_expect(int(new_vitals.get("shield", -1)) == int(legacy_target.get("shield", -2)), "world shield matches legacy resolver")
	_expect(
		int(new_vitals.get("roundDamageTaken", -1)) == int(legacy_target.get("roundDamageTaken", -2)),
		"world round damage matches legacy resolver"
	)
	_expect(
		int(Dictionary(Dictionary(events[0]).get("payload", {})).get("final", -1))
			== int(legacy_result.get("final", -2)),
		"world damage result matches legacy resolver"
	)
	_expect(not bool(new_vitals.get("alive", true)), "death system removes Alive after hp reaches zero")

	_expect(BattleWorldAdapterScript.write_back_vitals(world, units) == 2, "adapter explicitly writes component results back")
	_expect(
		int(Dictionary(units[1]).get("hp", -1)) == 0
			and int(Dictionary(units[1]).get("shield", -1)) == 0
			and not bool(Dictionary(units[1]).get("alive", true)),
		"write-back updates only authoritative vitality fields"
	)

	var conflicting_schedule := BattleScheduleScript.new()
	_expect(conflicting_schedule.add_system(DamageSystemScript.new()), "conflict probe damage system registers")
	_expect(conflicting_schedule.add_system(SameStageVitalsReader.new()), "conflict probe reader registers")
	var conflict := conflicting_schedule.validate()
	_expect(
		not bool(conflict.get("ok", true))
			and String(conflict.get("error", "")) == "AMBIGUOUS_SYSTEM_ACCESS"
			and Array(conflict.get("resources", [])).has("vitals"),
		"same-stage read/write ambiguity is rejected"
	)

	var mirror: RefCounted = BattleWorldAdapterScript.import_units([
		Dictionary(units[0]).duplicate(true),
		{
			"id": "enemy_pet",
			"side": "enemy",
			"x": 5,
			"y": 2,
			"hp": 0,
			"max_hp": 7,
			"shield": 0,
			"def": 0,
			"roundDamageTaken": 7,
			"alive": false,
			"active": true
		}
	])
	_expect(
		Array(Dictionary(world.data_snapshot()).get("entities", []))
			== Array(Dictionary(mirror.data_snapshot()).get("entities", [])),
		"component snapshots are deterministic and revision-independent"
	)

	if _failed:
		quit(1)
		return
	print("SMOKE_BATTLE_WORLD_VERTICAL_SLICE_OK entities=%d events=%d systems=%s" % [
		world.entity_count(),
		events.size(),
		schedule.ordered_system_names()
	])
	quit(0)


func _expect_world_dependencies_are_isolated() -> void:
	for world_path in BATTLE_WORLD_PATHS:
		var source := FileAccess.get_file_as_string(world_path)
		_expect(not source.is_empty(), "BattleWorld module exists: %s" % world_path)
		for forbidden_dependency in FORBIDDEN_DEPENDENCIES:
			_expect(
				not source.contains(forbidden_dependency),
				"BattleWorld stays independent of %s" % forbidden_dependency
			)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Smoke failed: %s" % message)
