extends RefCounted

## Ephemeral value-query scope. BattleQueryProjector validates the context once
## before constructing this object; the session never owns gameplay authority
## and is discarded with its caller's read/planning operation.

var _projector: RefCounted
var _context: Dictionary


func _init(projector: RefCounted, context: Dictionary) -> void:
	_projector = projector
	_context = context


func project_damage(
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String = "",
	trace_context: Dictionary = {},
	damage_props: Variant = {}
) -> Dictionary:
	if _projector == null:
		return {}
	return Dictionary(_projector.call(
		"_project_damage",
		_context,
		source,
		target,
		amount,
		element,
		trace_context,
		damage_props
	)).duplicate(true)


func project_damage_final(
	source: Dictionary,
	target: Dictionary,
	amount: int,
	element: String = "",
	trace_context: Dictionary = {},
	damage_props: Variant = {}
) -> int:
	return int(project_damage(
		source, target, amount, element, trace_context, damage_props
	).get("final", 0))


func project_settlement(
	after_elements: Dictionary,
	element: String,
	source: Dictionary = {}
) -> Dictionary:
	if _projector == null:
		return {}
	return Dictionary(_projector.call(
		"_project_settlement", _context, after_elements, element, source
	)).duplicate(true)
