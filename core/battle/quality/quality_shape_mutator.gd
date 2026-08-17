extends RefCounted
class_name QualityShapeMutator

const QualityOperationRegistryScript := preload("res://core/battle/quality/quality_operation_registry.gd")

const SHAPE_HANDLER_PREFIX := "shape_"

static var _default_operation_registry: RefCounted


static func apply(
	mutation: String,
	source_id: String,
	unit: Dictionary,
	direction: String,
	cells: Array,
	width: int,
	height: int,
	operation_registry: RefCounted = null,
	params: Dictionary = {}
) -> Array:
	var unchanged := cells.duplicate(true)
	var normalized_mutation := mutation.strip_edges()
	if normalized_mutation == "" or unchanged.is_empty():
		return unchanged
	var registry := _resolve_registry(operation_registry)
	if not _registry_is_valid(registry):
		return unchanged
	var handler_id := normalized_mutation
	if not handler_id.begins_with(SHAPE_HANDLER_PREFIX):
		handler_id = "%s%s" % [SHAPE_HANDLER_PREFIX, handler_id]
	var handler: RefCounted = registry.call(&"handler_for", handler_id) as RefCounted
	if handler == null or not bool(registry.call(&"supports", handler, &"mutate_shape")):
		return unchanged
	var result = handler.call(
		&"mutate_shape",
		unit.duplicate(true),
		direction,
		unchanged,
		width,
		height,
		source_id,
		params.duplicate(true)
	)
	if typeof(result) != TYPE_ARRAY:
		return cells.duplicate(true)
	return Array(result).duplicate(true)


static func _resolve_registry(operation_registry: RefCounted) -> RefCounted:
	if operation_registry != null:
		return operation_registry
	if _default_operation_registry == null:
		_default_operation_registry = QualityOperationRegistryScript.new()
	return _default_operation_registry


static func _registry_is_valid(registry: RefCounted) -> bool:
	return (
		registry != null
		and registry.has_method(&"handler_for")
		and registry.has_method(&"supports")
		and registry.has_method(&"is_valid")
		and bool(registry.call(&"is_valid"))
	)
