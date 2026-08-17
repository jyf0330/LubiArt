extends RefCounted

const MechanicHandlerRegistryScript := preload("res://core/battle/mechanics/mechanic_handler_registry.gd")

## Owns deterministic ordering after element application. Business behavior is
## discovered from repository-owned handlers and authority access remains behind
## ElementMechanicPort.

const PORT_CONTRACT_ID := &"ysbzs.element-mechanic-port.v1"
const REQUIRED_PORT_METHODS: Array[StringName] = [
	&"contract_id", &"mechanic_ids", &"mechanism", &"mechanic_param_int",
	&"mechanic_param_string", &"mechanic_param_element", &"heal_unit",
	&"summon_unit", &"summon_wall", &"inside", &"apply_element_to_cell",
	&"set_board_trace", &"cell_elements_at", &"clear_element_from_cell",
]

var _handler_registry: RefCounted


func _init(handler_directory: String = MechanicHandlerRegistryScript.HANDLER_DIRECTORY) -> void:
	_handler_registry = MechanicHandlerRegistryScript.new(handler_directory)


func configure_handler_registry(registry: RefCounted) -> RefCounted:
	_handler_registry = registry
	return self


func apply_after_element(
	port: RefCounted,
	caster: Dictionary,
	target: Dictionary,
	element: String,
	layers: int,
	cell: Dictionary = {}
) -> Array:
	var logs: Array = []
	if not _accepts(port) or not _handlers_valid() or caster.is_empty() or element == "" or layers <= 0:
		return logs
	for mechanism_id_value in port.mechanic_ids(caster):
		var mechanism_id := String(mechanism_id_value)
		var mechanism := Dictionary(port.mechanism(mechanism_id))
		var handler: RefCounted = _handler_registry.handler_for(mechanism_id, mechanism)
		if handler == null or not _handler_registry.supports(handler, &"after_element"):
			continue
		for line in Array(handler.call(&"after_element", port, caster, target, element, layers, cell, mechanism)):
			logs.append(String(line))
	return logs


func _handlers_valid() -> bool:
	return _handler_registry != null and _handler_registry.is_valid()


func _accepts(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.call(&"contract_id")) == PORT_CONTRACT_ID
