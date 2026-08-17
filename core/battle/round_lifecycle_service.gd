extends RefCounted

## Owns the complete round-start / round-end hook order. Mechanic behavior is
## discovered from repository-owned handlers and receives only the v1 port.

const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const MechanicHandlerRegistryScript := preload("res://core/battle/mechanics/mechanic_handler_registry.gd")

const PORT_CONTRACT_ID := &"ysbzs.round-lifecycle-port.v1"
const REQUIRED_PORT_METHODS: Array[StringName] = [
	&"contract_id",
	&"units_for_side",
	&"tick_skill_cooldowns",
	&"execute_attribute_hook",
	&"mechanic_ids",
	&"mechanism",
	&"mechanic_param_int",
	&"mechanic_param_string",
	&"battle_round",
	&"first_adjacent_empty_cell",
	&"first_empty_cell",
	&"summon_unit_on_cell",
	&"apply_cross_damage",
	&"advance_status_round",
	&"log_lines",
]

var _handler_registry: RefCounted


func _init(handler_directory: String = MechanicHandlerRegistryScript.HANDLER_DIRECTORY) -> void:
	_handler_registry = MechanicHandlerRegistryScript.new(handler_directory)


func configure_handler_registry(registry: RefCounted) -> RefCounted:
	_handler_registry = registry
	return self


func run_start(port: RefCounted, side: String) -> bool:
	if not _ready(port):
		return false
	for unit_value in port.units_for_side(side, false):
		port.tick_skill_cooldowns(Dictionary(unit_value))
	for unit_value in port.units_for_side(side, true):
		port.execute_attribute_hook(Dictionary(unit_value), EffectHookIdsScript.ROUND_START)
	for unit_value in port.units_for_side(side, true):
		port.log_lines(_round_mechanic_logs(port, Dictionary(unit_value), side, &"round_start"))
	return true


func run_end(port: RefCounted, side: String) -> bool:
	if not _ready(port):
		return false
	for unit_value in port.units_for_side(side, true):
		port.log_lines(_round_mechanic_logs(port, Dictionary(unit_value), side, &"round_end"))
	for unit_value in port.units_for_side(side, true):
		port.execute_attribute_hook(Dictionary(unit_value), EffectHookIdsScript.ROUND_END)
	for unit_value in port.units_for_side(side, false):
		port.advance_status_round(Dictionary(unit_value))
	return true


func is_valid() -> bool:
	return _handler_registry != null and bool(_handler_registry.is_valid())


func validation_errors() -> Array[String]:
	return _handler_registry.validation_errors() if _handler_registry != null else ["Mechanic handler registry is unavailable."]


func _round_mechanic_logs(port: RefCounted, unit: Dictionary, side: String, hook: StringName) -> Array:
	var logs: Array = []
	for mechanism_id_value in port.mechanic_ids(unit):
		var mechanism_id := String(mechanism_id_value)
		var mechanism := Dictionary(port.mechanism(mechanism_id))
		var handler: RefCounted = _handler_registry.handler_for(mechanism_id, mechanism)
		if handler == null or not _handler_registry.supports(handler, hook):
			continue
		var result: Variant = handler.call(hook, port, unit, side, mechanism)
		if typeof(result) != TYPE_ARRAY:
			continue
		_merge_log_entries(logs, Array(result))
	return logs


func _merge_log_entries(logs: Array, entries: Array) -> void:
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			logs.append(String(entry))
			continue
		var typed_entry := Dictionary(entry)
		var line := String(typed_entry.get("line", ""))
		if String(typed_entry.get("placement", "append")) == "front":
			logs.push_front(line)
		else:
			logs.append(line)


func _ready(port: RefCounted) -> bool:
	return _accepts(port) and is_valid()


func _accepts(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.call(&"contract_id")) == PORT_CONTRACT_ID
