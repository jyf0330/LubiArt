extends RefCounted

## Narrow read-only bridge from the planner to authoritative battle rules.
## It exposes candidate generation and evaluation, but no state mutation API.

var _context: Dictionary
var _evaluator: RefCounted


func _init(context: Dictionary, evaluator: RefCounted) -> void:
	_context = context.duplicate(true)
	_evaluator = evaluator


func sorted_units(side: String) -> Array:
	return Array(_evaluator.call("sorted_units", _context, side))


func effective_move_range(unit: Dictionary) -> int:
	return int(_evaluator.call("effective_move_range", _context, unit))


func candidates_for_unit(unit: Dictionary, limit: int, movement_budget: int, allow_direction_changes: bool, position_independent: bool) -> Array:
	return Array(_evaluator.call(
		"candidates_for_unit",
		_context,
		unit,
		{
			"limit": limit,
			"movementBudget": movement_budget,
			"allowDirectionChanges": allow_direction_changes,
			"positionIndependent": position_independent,
		}
	))


func choices_conflict(choices: Array, candidate: Dictionary) -> bool:
	return bool(_evaluator.call("choices_conflict", choices, candidate))


func optimization_context() -> Dictionary:
	return Dictionary(_evaluator.call("optimization_context", _context))


func decorate_finalists(beams: Array, side: String) -> Array:
	return Array(_evaluator.call("decorate_finalists", _context, beams, side))
