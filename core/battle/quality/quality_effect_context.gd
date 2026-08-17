extends RefCounted
class_name QualityEffectContext

var _handlers: Dictionary = {}


func configure(handlers: Variant) -> QualityEffectContext:
	if handlers is Callable:
		_handlers = {"heal_unit": handlers}
	else:
		_handlers = Dictionary(handlers).duplicate()
	return self


func configure_for_core(core: Object) -> QualityEffectContext:
	return configure({
		"heal_unit": Callable(core, "_heal_unit"),
		"deal_damage": Callable(core, "_deal_damage"),
		"resolve_damage_deaths": Callable(core, "_resolve_damage_deaths"),
		"add_incoming_damage_bonus": Callable(core, "_add_incoming_damage_bonus"),
		"unit_at": Callable(core, "unit_at"),
		"units_in_option": Callable(core, "_units_in_option"),
		"friendly_units_in_option": Callable(core, "_friendly_units_in_option"),
		"direction_delta": Callable(core, "_direction_delta"),
		"core_cell_index": Callable(core, "_core_cell_index"),
		"option_cell_index": Callable(core, "_option_cell_index_for_target"),
		"mark_matches_unit": Callable(core, "_quality_mark_matches_unit"),
		"lowest_low_hp_enemy": Callable(core, "_lowest_low_hp_enemy"),
		"adjacent_enemies": Callable(core, "_adjacent_enemies"),
		"nearest_enemy": Callable(core, "_nearest_enemy"),
		"set_board_trace": Callable(core, "_set_board_trace"),
		"board_traces_at": Callable(core, "_board_traces_at"),
		"cell_elements_at": Callable(core, "_cell_elements_at"),
		"resolved_stat": Callable(core, "_resolved_stat_value"),
	})


func heal_unit(unit: Dictionary, amount: int) -> int:
	return int(call_handler(&"heal_unit", [unit, amount], 0))


func deal_damage(
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String = "",
	consume_incoming_bonus: bool = true,
	trace_context: Dictionary = {},
	damage_props: Variant = {}
) -> Dictionary:
	var effective_trace_context := trace_context.duplicate(true)
	if String(effective_trace_context.get("sourceType", "")).strip_edges() == "":
		effective_trace_context["sourceType"] = "quality_effect"
	return Dictionary(call_handler(
		&"deal_damage",
		[source, target, amount, element, consume_incoming_bonus, effective_trace_context, damage_props],
		{}
	))


func resolve_damage_deaths(candidates: Array) -> Array:
	return Array(call_handler(&"resolve_damage_deaths", [candidates], []))


func add_incoming_damage_bonus(unit: Dictionary, amount: int) -> int:
	return int(call_handler(&"add_incoming_damage_bonus", [unit, amount], 0))


func unit_at(x: int, y: int) -> Dictionary:
	return Dictionary(call_handler(&"unit_at", [x, y], {}))


func units_in_option(option: Dictionary) -> Array:
	return Array(call_handler(&"units_in_option", [option], []))


func friendly_units_in_option(attacker: Dictionary, option: Dictionary) -> Array:
	return Array(call_handler(&"friendly_units_in_option", [attacker, option], []))


func direction_delta(direction: String) -> Vector2i:
	return call_handler(&"direction_delta", [direction], Vector2i.RIGHT) as Vector2i


func core_cell_index(option: Dictionary) -> int:
	return int(call_handler(&"core_cell_index", [option], 0))


func option_cell_index(option: Dictionary, target: Dictionary) -> int:
	return int(call_handler(&"option_cell_index", [option, target], -1))


func mark_matches_unit(marked_cell: Dictionary, unit: Dictionary) -> bool:
	return bool(call_handler(&"mark_matches_unit", [marked_cell, unit], false))


func lowest_low_hp_enemy() -> Dictionary:
	return Dictionary(call_handler(&"lowest_low_hp_enemy", [], {}))


func adjacent_enemies(target: Dictionary) -> Array:
	return Array(call_handler(&"adjacent_enemies", [target], []))


func nearest_enemy(attacker: Dictionary, excluded: Array = []) -> Dictionary:
	return Dictionary(call_handler(&"nearest_enemy", [attacker, excluded], {}))


func set_board_trace(x: int, y: int, trace: Dictionary) -> bool:
	return bool(call_handler(&"set_board_trace", [x, y, trace], false))


func board_traces_at(x: int, y: int) -> Array:
	return Array(call_handler(&"board_traces_at", [x, y], []))


func cell_elements_at(x: int, y: int) -> Dictionary:
	return Dictionary(call_handler(&"cell_elements_at", [x, y], {}))


func resolved_stat(unit: Dictionary, stat_id: String, context: Dictionary = {}) -> int:
	return int(call_handler(&"resolved_stat", [unit, stat_id, context], int(unit.get(stat_id, 0))))


func call_handler(key: StringName, args: Array, fallback: Variant = null) -> Variant:
	var handler: Variant = _handlers.get(key)
	if handler is Callable and (handler as Callable).is_valid():
		return (handler as Callable).callv(args)
	return fallback
