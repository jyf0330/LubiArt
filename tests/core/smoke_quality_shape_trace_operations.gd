extends SceneTree

const BoardTraceScript := preload("res://core/battle/quality/quality_board_trace.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const QualityContextScript := preload("res://core/battle/quality/quality_effect_context.gd")
const QualityOperationRegistryScript := preload("res://core/battle/quality/quality_operation_registry.gd")
const ShapeMutatorScript := preload("res://core/battle/quality/quality_shape_mutator.gd")

const TRACE_IDS := [
	"fire_trace",
	"water_trace",
	"wind_trace",
	"earth_trace",
	"metal_trace",
	"wood_trace",
	"buddha_trace",
	"sand_trace",
	"demon_trace",
	"talisman_trace",
]

var _damage_calls: Array = []
var _failed := false
var _traces: Dictionary = {}
var _units: Array = []


func _initialize() -> void:
	var registry: RefCounted = QualityOperationRegistryScript.new()
	_expect(registry.is_valid(), "production quality operation registry is valid")
	_test_shape_operations(registry)
	_test_trace_operations(registry)
	if _failed:
		quit(1)
		return
	print("SMOKE_QUALITY_SHAPE_TRACE_OPERATIONS_OK shapes=8 traces=10")
	quit(0)


func _test_shape_operations(registry: RefCounted) -> void:
	var unit := {"x": 2, "y": 2}
	var base := [{"x": 3, "y": 2}]
	var expected := {
		"extend_end": {"x": 4, "y": 2, "delta": null},
		"back_sweep": {"x": 1, "y": 2, "delta": -2},
		"mirror": {"x": 1, "y": 2, "delta": 0},
		"diagonal_copy": {"x": 4, "y": 1, "delta": 0},
		"double_ends": {"x": 4, "y": 2, "delta": -2},
		"pierce_end": {"x": 4, "y": 2, "delta": -1},
	}
	for mutation_value in expected.keys():
		var mutation := String(mutation_value)
		var result := ShapeMutatorScript.apply(
			mutation,
			"source_%s" % mutation,
			unit,
			"right",
			base,
			8,
			8,
			registry
		)
		var target := Dictionary(expected[mutation])
		var appended := _cell_at(result, int(target["x"]), int(target["y"]))
		_expect(result.size() == 2 and not appended.is_empty(), "%s appends its typed cell" % mutation)
		if target["delta"] != null:
			_expect(
				int(appended.get("quality_damage_delta", 999)) == int(target["delta"])
				and String(appended.get("quality_source", "")) == "source_%s" % mutation,
				"%s preserves damage delta and source" % mutation
			)
	_expect(base == [{"x": 3, "y": 2}], "shape operations do not mutate caller cells")

	var corner_base := [{"x": 3, "y": 2}, {"x": 4, "y": 2}, {"x": 3, "y": 3}]
	var corner_result := ShapeMutatorScript.apply(
		"fill_corner", "corner", unit, "right", corner_base, 8, 8, registry
	)
	var corner := _cell_at(corner_result, 4, 3)
	_expect(
		corner_result.size() == 4
		and int(corner.get("quality_damage_delta", 999)) == -2
		and String(corner.get("quality_source", "")) == "corner",
		"fill_corner appends the missing corner"
	)

	var ordered := [{"x": 3, "y": 2}, {"x": 4, "y": 2}]
	var reversed := ShapeMutatorScript.apply(
		"reverse", "reverse", unit, "right", ordered, 8, 8, registry
	)
	_expect(int(Dictionary(reversed[0]).get("x", -1)) == 4, "reverse changes only result order")
	var unknown := ShapeMutatorScript.apply(
		"unknown", "unknown", unit, "right", ordered, 8, 8, registry
	)
	Dictionary(unknown[0])["x"] = 99
	_expect(int(Dictionary(ordered[0]).get("x", -1)) == 3, "unknown shape fails closed with a deep copy")

	for operation_id in [
		"shape_extend_end",
		"shape_back_sweep",
		"shape_mirror",
		"shape_diagonal_copy",
		"shape_double_ends",
		"shape_fill_corner",
		"shape_pierce_end",
		"shape_reverse",
	]:
		var handler: RefCounted = registry.handler_for(operation_id)
		var profile := Dictionary(handler.profile({})) if handler != null else {}
		_expect(
			handler != null
			and bool(profile.get("changes_shape_name", false))
			and String(profile.get("shape_mutation", "")) == String(operation_id).trim_prefix("shape_"),
			"%s exposes the legacy shape profile" % operation_id
		)


func _test_trace_operations(registry: RefCounted) -> void:
	for trace_id in TRACE_IDS:
		var handler: RefCounted = registry.handler_for(trace_id)
		var profile := Dictionary(handler.profile({})) if handler != null else {}
		var board_trace := Dictionary(profile.get("board_trace", {}))
		_expect(
			handler != null and String(board_trace.get("handler_id", "")) == trace_id,
			"%s exposes a typed trace profile" % trace_id
		)

	var context := QualityContextScript.new().configure({
		"heal_unit": Callable(self, "_heal"),
		"deal_damage": Callable(self, "_deal_damage"),
		"add_incoming_damage_bonus": Callable(self, "_add_incoming_bonus"),
		"unit_at": Callable(self, "_unit_at"),
		"set_board_trace": Callable(self, "_set_board_trace"),
	})
	var attacker := _unit("tracer", "player", 2, 2, 20, 20)
	attacker["quality_upgrade"] = {"id": "D21", "name": "火痕品质"}
	var enemy := _unit("enemy", "enemy", 3, 2, 10, 10)
	_units = [attacker, enemy]
	_traces.clear()
	_damage_calls.clear()
	var fire_logs := BoardTraceScript.apply_after_attack(
		context,
		attacker,
		{"cells": [{"x": 3, "y": 2}]},
		{"handler_id": "fire_trace", "params": {}, "duration": 1, "persistent": false},
		registry
	)
	var fire_trace := Dictionary(Array(_traces.get("3,2", []))[0])
	var stored_keys: Array[String] = []
	for key_value in fire_trace.keys():
		stored_keys.append(String(key_value))
	stored_keys.sort()
	_expect(
		stored_keys == ["duration", "handler_id", "id", "name", "params", "persistent"],
		"placed trace stores only the frozen typed keys"
	)
	BoardTraceScript.apply_after_attack(
		context,
		attacker,
		{"cells": [{"x": 4, "y": 2}]},
		{"kind": "fire_trace", "duration": 1},
		registry
	)
	var legacy_trace := Dictionary(Array(_traces.get("4,2", []))[0])
	var legacy_keys: Array[String] = []
	for key_value in legacy_trace.keys():
		legacy_keys.append(String(key_value))
	legacy_keys.sort()
	_expect(
		legacy_keys == ["duration", "id", "kind", "name"],
		"legacy placement preserves the pre-Q0 physical trace keys"
	)
	_expect(
		fire_logs.size() == 2
		and String(fire_logs[0]) == "火痕品质：留下1个战斗痕迹。"
		and String(fire_logs[1]) == "enemy 触发火痕品质：受到3点火伤害。",
		"placement log remains before immediate trace-enter log"
	)
	var fire_damage := Dictionary(_damage_calls[0])
	_expect(
		int(enemy.get("hp", 0)) == 7
		and int(fire_damage.get("amount", 0)) == 3
		and String(fire_damage.get("element", "")) == "火"
		and bool(fire_damage.get("consume", false))
		and not DamagePropsScript.is_move(fire_damage.get("damage_props", {}))
		and not DamagePropsScript.is_powered(fire_damage.get("damage_props", {})),
		"fire trace preserves non-move unpowered damage"
	)

	var ally := _unit("ally", "player", 4, 2, 5, 20)
	BoardTraceScript.apply_to_unit(context, ally, {"handler_id": "water_trace", "name": "水痕", "params": {}}, registry)
	_expect(int(ally.get("hp", 0)) == 10, "water trace heals ally by 5")
	BoardTraceScript.apply_to_unit(context, ally, {"handler_id": "wind_trace", "name": "风痕", "params": {}}, registry)
	_expect(int(ally.get("quality_next_damage_bonus", 0)) == 2, "wind trace raises next damage to at least 2")
	BoardTraceScript.apply_to_unit(context, ally, {"handler_id": "earth_trace", "name": "地痕", "params": {}}, registry)
	_expect(int(ally.get("shield", 0)) == 8, "earth trace grants 8 shield")
	BoardTraceScript.apply_to_unit(context, enemy, {"handler_id": "metal_trace", "name": "金痕", "params": {}}, registry)
	_expect(int(enemy.get("incoming_damage_bonus", 0)) == 2, "metal trace adds 2 incoming damage")
	BoardTraceScript.apply_to_unit(context, ally, {"handler_id": "buddha_trace", "name": "佛痕", "params": {}}, registry)
	_expect(int(ally.get("hp", 0)) == 16, "buddha trace heals ally by 6")

	enemy["hp"] = 10
	enemy["incoming_damage_bonus"] = 0
	_damage_calls.clear()
	BoardTraceScript.apply_to_unit(context, enemy, {"handler_id": "sand_trace", "name": "沙痕", "params": {}}, registry)
	var sand_damage := Dictionary(_damage_calls[0])
	_expect(
		int(enemy.get("hp", 0)) == 8
		and int(enemy.get("incoming_damage_bonus", 0)) == 2
		and String(sand_damage.get("element", "")) == "地"
		and not bool(sand_damage.get("consume", true)),
		"sand trace deals 2 earth damage without consuming and adds incoming 2"
	)
	enemy["incoming_damage_bonus"] = 0
	BoardTraceScript.apply_to_unit(context, enemy, {"handler_id": "demon_trace", "name": "魔痕", "params": {}}, registry)
	_expect(int(enemy.get("incoming_damage_bonus", 0)) == 4, "demon trace adds 4 incoming damage")

	ally["hp"] = 5
	BoardTraceScript.apply_round_start(
		context,
		ally,
		[{"kind": "wood_trace", "name": "木痕"}],
		registry
	)
	_expect(int(ally.get("hp", 0)) == 9, "persisted legacy wood trace heals 4 at round start")
	_expect(
		BoardTraceScript.element_apply_bonus([
			{"kind": "talisman_trace"},
			{"handler_id": "talisman_trace", "params": {}},
		], registry) == 1,
		"talisman traces add exactly one element application"
	)
	var grouped_ally := _unit("grouped_ally", "player", 5, 2, 1, 20)
	BoardTraceScript.apply_round_start(context, grouped_ally, [
		{"handler_id": "wood_trace", "name": "small", "params": {"amount": 1}},
		{"handler_id": "wood_trace", "name": "large", "params": {"amount": 9}},
	], registry)
	_expect(int(grouped_ally.get("hp", 0)) == 11, "same trace handler keeps distinct canonical params groups")
	_expect(
		BoardTraceScript.element_apply_bonus([
			{"handler_id": "talisman_trace", "params": {"amount": 2}},
			{"handler_id": "talisman_trace", "params": {"amount": 2}},
			{"handler_id": "talisman_trace", "params": {"amount": 5}},
		], registry) == 7,
		"same params merge once while distinct params remain independent"
	)


func _unit(id: String, side: String, x: int, y: int, hp: int, max_hp: int) -> Dictionary:
	return {
		"id": id,
		"name": id,
		"side": side,
		"x": x,
		"y": y,
		"hp": hp,
		"max_hp": max_hp,
		"shield": 0,
	}


func _cell_at(cells: Array, x: int, y: int) -> Dictionary:
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		if int(cell.get("x", -1)) == x and int(cell.get("y", -1)) == y:
			return cell
	return {}


func _heal(unit: Dictionary, amount: int) -> int:
	var before := int(unit.get("hp", 0))
	unit["hp"] = min(int(unit.get("max_hp", before)), before + amount)
	return int(unit.get("hp", 0)) - before


func _deal_damage(
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String,
	consume_incoming_bonus: bool,
	trace_context: Dictionary = {},
	damage_props: Variant = {}
) -> Dictionary:
	_damage_calls.append({
		"source": source.duplicate(true),
		"target": String(target.get("id", "")),
		"amount": amount,
		"element": element,
		"consume": consume_incoming_bonus,
		"trace_context": trace_context.duplicate(true),
		"damage_props": Dictionary(damage_props).duplicate(true),
	})
	target["hp"] = max(0, int(target.get("hp", 0)) - amount)
	return {"final": amount}


func _add_incoming_bonus(unit: Dictionary, amount: int) -> int:
	unit["incoming_damage_bonus"] = int(unit.get("incoming_damage_bonus", 0)) + amount
	return int(unit.get("incoming_damage_bonus", 0))


func _unit_at(x: int, y: int) -> Dictionary:
	for unit_value in _units:
		var unit := Dictionary(unit_value)
		if int(unit.get("x", -1)) == x and int(unit.get("y", -1)) == y:
			return unit
	return {}


func _set_board_trace(x: int, y: int, trace: Dictionary) -> bool:
	var key := "%d,%d" % [x, y]
	var rows := Array(_traces.get(key, []))
	rows.append(trace.duplicate(true))
	_traces[key] = rows
	return true


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_QUALITY_SHAPE_TRACE_OPERATIONS_FAIL: %s" % label)
