extends SceneTree

const RegistryScript := preload("res://core/battle/quality/quality_effect_registry.gd")
const LegacyCatalogScript := preload("res://core/battle/quality/legacy_quality_runtime_catalog.gd")
const ContextScript := preload("res://core/battle/quality/quality_effect_context.gd")
const BoardTraceScript := preload("res://core/battle/quality/quality_board_trace.gd")

var _failed := false
var _units: Array = []
var _traces: Dictionary = {}
var _damage_calls: Array = []


func _initialize() -> void:
	var registry := _legacy_registry()
	var context := ContextScript.new().configure({
		"heal_unit": Callable(self, "_heal"),
		"deal_damage": Callable(self, "_deal_damage"),
		"add_incoming_damage_bonus": Callable(self, "_add_incoming_bonus"),
		"unit_at": Callable(self, "_unit_at"),
		"units_in_option": Callable(self, "_units_in_option"),
		"friendly_units_in_option": Callable(self, "_friendly_units_in_option"),
		"direction_delta": Callable(self, "_direction_delta"),
		"core_cell_index": Callable(self, "_core_cell_index"),
		"option_cell_index": Callable(self, "_option_cell_index"),
		"mark_matches_unit": Callable(self, "_mark_matches_unit"),
		"lowest_low_hp_enemy": Callable(self, "_lowest_low_hp_enemy"),
		"adjacent_enemies": Callable(self, "_adjacent_enemies"),
		"nearest_enemy": Callable(self, "_nearest_enemy"),
		"set_board_trace": Callable(self, "_set_board_trace"),
		"board_traces_at": Callable(self, "_board_traces_at"),
		"cell_elements_at": Callable(self, "_cell_elements_at"),
	})

	_test_registry_complete(registry)
	_test_damage_rules(registry)
	_test_element_and_shape_hooks(registry, context)
	_test_attack_hooks(registry, context)
	_test_target_and_option_hooks(registry)
	_test_board_trace_hooks(registry, context)

	if _failed:
		quit(1)
		return
	print("SMOKE_QUALITY_EFFECT_FULL_HOOKS_OK")
	quit(0)


func _legacy_registry() -> QualityEffectRegistry:
	var registry: QualityEffectRegistry = RegistryScript.new()
	var prepared := registry.prepare_configuration(
		LegacyCatalogScript.upgrades(),
		0,
		RegistryScript.PERSISTED_SNAPSHOT
	)
	_expect(bool(prepared.get("ok", false)), "legacy fixture configuration prepares")
	registry.commit_configuration(Dictionary(prepared.get("candidate", {})))
	_expect(registry.is_configured(), "legacy fixture configuration commits")
	return registry


func _test_registry_complete(registry: QualityEffectRegistry) -> void:
	for index in range(1, 9):
		var effect_id := "S%02d" % index
		_expect(registry.effect_for_id(effect_id).effect_id == effect_id, "%s registered" % effect_id)
	for prefix in ["G", "D"]:
		for index in range(1, 31):
			var effect_id := "%s%02d" % [prefix, index]
			_expect(registry.effect_for_id(effect_id).effect_id == effect_id, "%s registered" % effect_id)


func _test_damage_rules(registry: QualityEffectRegistry) -> void:
	var cases := [
		["S05", {"damage": 10, "last_hit": true}, 20],
		["G01", {"damage": 10, "mode_is_guard": false}, 12],
		["G02", {"damage": 10, "mode": "爆", "first_hit": true}, 14],
		["G03", {"damage": 10, "core_cell": true}, 13],
		["G06", {"damage": 10, "core_cell": true}, 12],
		["G07", {"damage": 10, "farthest_cell": true}, 13],
		["G09", {"damage": 10, "off_axis": true}, 11],
		["G10", {"damage": 10, "farthest_cell": true}, 14],
		["G11", {"damage": 10, "target_count": 1}, 15],
		["G13", {"damage": 10, "distance": 2}, 14],
		["G14", {"damage": 10, "mode_is_stable": false}, 16],
		["G15", {"damage": 10, "target_hp": 8}, 18],
		["G17", {"damage": 10, "has_mark": true, "marked_match": true}, 15],
		["G18", {"damage": 10, "target_count": 2, "hit_index": 1}, 14],
		["G19", {"damage": 10, "target_count": 2}, 12],
		["G20", {"damage": 10, "farthest_cell": true}, 14],
		["G21", {"damage": 10, "first_cell": true}, 12],
		["G22", {"damage": 10, "has_mark": true, "marked_match": true}, 14],
		["G23", {"damage": 10, "target_count": 2, "hit_index": 1}, 13],
		["G24", {"damage": 10, "mode_is_same": false, "first_hit": true}, 14],
		["G25", {"damage": 10, "core_cell": true}, 13],
		["G26", {"damage": 10, "target_count": 2}, 11],
		["G27", {"damage": 10, "farthest_cell": true}, 13],
		["G28", {"damage": 10, "g28_active": true}, 12],
		["G29", {
			"damage": 10,
			"farthest_positive": true,
			"farthest_cell": true,
			"first_target_exists": true,
		}, 14],
		["G30", {"damage": 10, "has_mark": false, "core_cell": true}, 13],
		["D07", {"damage": 10, "target_count": 1}, 16],
		["D08", {"damage": 10, "target_count": 2}, 12],
		["D12", {"damage": 10, "last_hit": true}, 15],
		["D16", {"damage": 10, "target_count": 1}, 20],
		["D17", {"damage": 10}, 15],
	]
	for case_value in cases:
		var case := Array(case_value)
		var effect_id := String(case[0])
		var actual := registry.effect_for_id(effect_id).modify_hit_damage(Dictionary(case[1]))
		_expect(actual == int(case[2]), "%s damage rule" % effect_id)
	_expect(
		registry.effect_for_id("G03").modify_hit_damage({
			"damage": 10,
			"core_cell": true,
			"preview": true,
		}) == 13,
		"G03 keeps existing preview bonus"
	)
	_expect(
		registry.effect_for_id("S05").modify_hit_damage({
			"damage": 10,
			"last_hit": true,
			"preview": true,
		}) == 10,
		"S05 keeps existing preview boundary"
	)

	var chain_attacker := {"quality_runtime": {}}
	var chain := registry.effect_for_id("S06")
	var first := chain.modify_hit_damage({
		"damage": 10,
		"attacker": chain_attacker,
		"first_hit": true,
	})
	var second := chain.modify_hit_damage({
		"damage": 10,
		"attacker": chain_attacker,
		"first_hit": false,
	})
	_expect(first == 5 and second == 10, "S06 chain damage state")


func _test_element_and_shape_hooks(
	registry: QualityEffectRegistry,
	context: QualityEffectContext
) -> void:
	_traces["2,2"] = [{"kind": "talisman_trace"}]
	_expect(
		registry.effect_for_id("S04").element_application_count(context, {"x": 2, "y": 2}) == 3,
		"S04 and talisman application counts compose"
	)
	_expect(
		registry.effect_for_id("S08").element_layers({"element": "火"}, "火", 2) == 4,
		"S08 doubles matching element layers"
	)

	var unit := {"x": 2, "y": 2}
	var base := [{"x": 3, "y": 2}]
	var expected_sizes := {
		"D01": 2,
		"D02": 2,
		"D03": 2,
		"D04": 2,
		"D06": 2,
		"D10": 2,
	}
	for effect_id in expected_sizes:
		var cells := registry.effect_for_id(effect_id).mutate_shape(
			unit,
			"right",
			base,
			8,
			8
		)
		_expect(cells.size() == int(expected_sizes[effect_id]), "%s shape mutation" % effect_id)
	var corner_cells := [{"x": 3, "y": 2}, {"x": 4, "y": 2}, {"x": 3, "y": 3}]
	_expect(
		registry.effect_for_id("D09").mutate_shape(
			unit,
			"right",
			corner_cells,
			8,
			8
		).size() == 4,
		"D09 fills missing corner"
	)
	var reversed := registry.effect_for_id("D20").mutate_shape(
		unit,
		"right",
		[{"x": 3, "y": 2}, {"x": 4, "y": 2}],
		8,
		8
	)
	_expect(int(Dictionary(reversed[0]).get("x", 0)) == 4, "D20 reverses settlement order")


func _test_attack_hooks(
	registry: QualityEffectRegistry,
	context: QualityEffectContext
) -> void:
	var attacker := _unit("attacker", "player", 2, 2, "G08")
	var ally := _unit("ally", "player", 1, 2)
	_units = [attacker, ally]
	registry.effect_for_unit(attacker).on_before_attack(
		context,
		attacker,
		{"direction": "right", "cells": [{"x": 3, "y": 2}]}
	)
	_expect(int(ally.get("shield", 0)) == 10, "G08 shields ally behind attacker")

	var core_ally := _unit("core_ally", "player", 4, 2)
	core_ally["hp"] = 5
	core_ally["max_hp"] = 20
	_units = [attacker, core_ally]
	var core_option := {"cells": [{"x": 3, "y": 2}, {"x": 4, "y": 2}, {"x": 5, "y": 2}]}
	var healer := _unit("healer", "player", 2, 2, "G05")
	registry.effect_for_unit(healer).on_after_attack(context, healer, core_option, [])
	_expect(int(core_ally.get("hp", 0)) == 11, "G05 heals core ally")

	var grower := _unit("grower", "player", 2, 2, "S07")
	grower["atk"] = 3
	grower["quality_runtime"] = {"killCount": 4}
	registry.effect_for_unit(grower).on_after_attack(
		context,
		grower,
		core_option,
		[{"hp": 0}]
	)
	_expect(int(grower.get("atk", 0)) == 4, "S07 converts fifth kill to attack")

	var debuffer := _unit("debuffer", "player", 2, 2, "G12")
	var enemy_a := _unit("enemy_a", "enemy", 3, 2)
	var enemy_b := _unit("enemy_b", "enemy", 4, 2)
	registry.effect_for_unit(debuffer).on_after_attack(
		context,
		debuffer,
		core_option,
		[enemy_a, enemy_b]
	)
	_expect(
		int(enemy_a.get("incoming_damage_bonus", 0)) == 3
				and int(enemy_b.get("incoming_damage_bonus", 0)) == 3,
		"G12 marks every target"
	)

	_damage_calls.clear()
	var splasher := _unit("splasher", "player", 2, 2, "D05")
	var hit := _unit("hit", "enemy", 4, 2)
	var adjacent := _unit("adjacent", "enemy", 5, 2)
	_units = [splasher, hit, adjacent]
	registry.effect_for_unit(splasher).on_after_hit(context, splasher, hit)
	_expect(_damage_calls.size() == 1, "D05 applies adjacent splash")

	_damage_calls.clear()
	var burst := _unit("burst", "player", 2, 2, "D18")
	_traces["4,2"] = []
	hit["elements"] = {"火": 3}
	registry.effect_for_unit(burst).on_before_hit(context, burst, hit, "火")
	_expect(
		_damage_calls.size() == 1 and int(Dictionary(_damage_calls[0]).get("amount", 0)) == 6,
		"D18 settles triangular element burst before hit"
	)


func _test_target_and_option_hooks(registry: QualityEffectRegistry) -> void:
	var targets := [
		{"id": "high", "hp": 10, "x": 3, "y": 2},
		{"id": "low", "hp": 2, "x": 4, "y": 2},
	]
	var option := {"cells": [{"x": 3, "y": 2}, {"x": 4, "y": 2}]}
	registry.effect_for_id("D19").sort_targets(targets, option)
	_expect(String(Dictionary(targets[0]).get("id", "")) == "low", "D19 sorts lowest hp first")

	var attacker := _unit("heavy", "player", 2, 2, "G14")
	attacker["quality_runtime"] = {"mode": "重"}
	var narrowed := registry.effect_for_unit(attacker).attack_option_for_target(
		attacker,
		Dictionary(targets[0]),
		option
	)
	_expect(Array(narrowed.get("cells", [])).size() == 1, "G14 heavy mode narrows action")


func _test_board_trace_hooks(
	registry: QualityEffectRegistry,
	context: QualityEffectContext
) -> void:
	var expected_kinds := [
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
	for index in range(expected_kinds.size()):
		var effect_id := "D%02d" % (index + 21)
		_expect(
			String(registry.effect_for_id(effect_id).board_trace.get("kind", ""))
					== String(expected_kinds[index]),
			"%s legacy board trace registered" % effect_id
		)

	_traces.clear()
	var tracer := _unit("tracer", "player", 2, 2, "D21")
	var enemy := _unit("trace_enemy", "enemy", 3, 2)
	enemy["hp"] = 10
	enemy["max_hp"] = 10
	_units = [tracer, enemy]
	_damage_calls.clear()
	registry.effect_for_unit(tracer).on_after_attack(
		context,
		tracer,
		{"cells": [{"x": 3, "y": 2}]},
		[enemy]
	)
	_expect(_damage_calls.size() == 1, "D21 fire trace triggers occupied enemy")

	var wood_unit := _unit("wood_target", "player", 4, 2)
	wood_unit["hp"] = 5
	wood_unit["max_hp"] = 20
	BoardTraceScript.apply_round_start(
		context,
		wood_unit,
		[{"kind": "wood_trace", "name": "木痕"}]
	)
	_expect(int(wood_unit.get("hp", 0)) == 9, "D26 wood trace heals at round start")


func _unit(
	id: String,
	side: String,
	x: int,
	y: int,
	effect_id: String = ""
) -> Dictionary:
	return {
		"id": id,
		"name": id,
		"side": side,
		"x": x,
		"y": y,
		"hp": 10,
		"max_hp": 10,
		"atk": 3,
		"shield": 0,
		"quality_upgrade": {
			"id": effect_id,
			"name": effect_id,
		},
		"quality_runtime": {},
	}


func _heal(unit: Dictionary, amount: int) -> int:
	var before := int(unit.get("hp", 0))
	var after: int = min(int(unit.get("max_hp", before)), before + amount)
	unit["hp"] = after
	return after - before


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
		"source": source,
		"target": target,
		"amount": amount,
		"element": element,
		"consume": consume_incoming_bonus,
		"trace_context": trace_context.duplicate(true),
		"damage_props": damage_props,
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


func _units_in_option(option: Dictionary) -> Array:
	var result: Array = []
	for unit_value in _units:
		var unit := Dictionary(unit_value)
		if _option_cell_index(option, unit) >= 0:
			result.append(unit)
	return result


func _friendly_units_in_option(attacker: Dictionary, option: Dictionary) -> Array:
	var result: Array = []
	for unit_value in _units_in_option(option):
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == "player" \
				and String(unit.get("id", "")) != String(attacker.get("id", "")):
			result.append(unit)
	return result


func _direction_delta(direction: String) -> Vector2i:
	match direction:
		"down":
			return Vector2i.DOWN
		"left":
			return Vector2i.LEFT
		"up":
			return Vector2i.UP
	return Vector2i.RIGHT


func _core_cell_index(option: Dictionary) -> int:
	return max(0, int(floor(float(max(0, Array(option.get("cells", [])).size() - 1)) / 2.0)))


func _option_cell_index(option: Dictionary, target: Dictionary) -> int:
	var cells := Array(option.get("cells", []))
	for index in range(cells.size()):
		var cell := Dictionary(cells[index])
		if int(cell.get("x", -1)) == int(target.get("x", -2)) \
				and int(cell.get("y", -1)) == int(target.get("y", -2)):
			return index
	return -1


func _mark_matches_unit(marked_cell: Dictionary, unit: Dictionary) -> bool:
	return (
		int(marked_cell.get("x", -1)) == int(unit.get("x", -2))
		and int(marked_cell.get("y", -1)) == int(unit.get("y", -2))
	)


func _lowest_low_hp_enemy() -> Dictionary:
	var result: Dictionary = {}
	for unit_value in _units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != "enemy" or int(unit.get("hp", 0)) > 5:
			continue
		if result.is_empty() or int(unit.get("hp", 0)) < int(result.get("hp", 0)):
			result = unit
	return result


func _adjacent_enemies(target: Dictionary) -> Array:
	var result: Array = []
	for unit_value in _units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != "enemy" \
				or String(unit.get("id", "")) == String(target.get("id", "")):
			continue
		var distance: int = (
			abs(int(unit.get("x", 0)) - int(target.get("x", 0)))
			+ abs(int(unit.get("y", 0)) - int(target.get("y", 0)))
		)
		if distance == 1:
			result.append(unit)
	return result


func _nearest_enemy(attacker: Dictionary, excluded: Array) -> Dictionary:
	var result: Dictionary = {}
	var best_distance := 9999
	for unit_value in _units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != "enemy" or excluded.has(unit):
			continue
		var distance: int = (
			abs(int(unit.get("x", 0)) - int(attacker.get("x", 0)))
			+ abs(int(unit.get("y", 0)) - int(attacker.get("y", 0)))
		)
		if distance < best_distance:
			best_distance = distance
			result = unit
	return result


func _set_board_trace(x: int, y: int, trace: Dictionary) -> bool:
	var key := "%d,%d" % [x, y]
	var rows := Array(_traces.get(key, []))
	rows.append(trace.duplicate(true))
	_traces[key] = rows
	return true


func _board_traces_at(x: int, y: int) -> Array:
	return Array(_traces.get("%d,%d" % [x, y], []))


func _cell_elements_at(x: int, y: int) -> Dictionary:
	var unit := _unit_at(x, y)
	return Dictionary(unit.get("elements", {}))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Quality full hooks smoke failed: %s" % message)
