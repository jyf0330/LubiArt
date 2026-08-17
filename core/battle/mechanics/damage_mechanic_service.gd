extends RefCounted

const MechanicHandlerRegistryScript := preload("res://core/battle/mechanics/mechanic_handler_registry.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")

## Owns deterministic battle-start and direct damage mechanic ordering. Business
## behavior is discovered from repository-owned handlers; authority access stays
## behind the versioned DamageMechanicPort contract.

const PORT_CONTRACT_ID := &"ysbzs.damage-mechanic-port.v2"
const REQUIRED_PORT_METHODS: Array[StringName] = [
	&"contract_id",
	&"mechanic_ids",
	&"mechanism",
	&"mechanic_param_int",
	&"mechanic_param_float",
	&"mechanic_param_string",
	&"battle_round",
	&"all_units",
	&"deal_damage",
	&"resolve_damage_deaths",
	&"resolved_stat_value",
	&"first_adjacent_empty_cell",
	&"summon_unit_on_cell",
	&"direction_delta",
	&"inside",
	&"unit_at",
]

var _handler_registry: RefCounted


func _init(handler_directory: String = MechanicHandlerRegistryScript.HANDLER_DIRECTORY) -> void:
	_handler_registry = MechanicHandlerRegistryScript.new(handler_directory)


func configure_handler_registry(registry: RefCounted) -> RefCounted:
	_handler_registry = registry
	return self


func apply_battle_start(port: RefCounted, unit: Dictionary) -> Array:
	var logs: Array = []
	if not _accepts(port) or not _handlers_valid():
		return logs
	for mechanism_id_value in port.mechanic_ids(unit):
		var mechanism_id := String(mechanism_id_value)
		var mechanism := Dictionary(port.mechanism(mechanism_id))
		var handler: RefCounted = _handler_for(mechanism_id, mechanism)
		if not _supports(handler, &"on_battle_start"):
			continue
		_append_lines(logs, Array(handler.call(&"on_battle_start", port, unit, mechanism)))
	return logs


func apply_before_damage(
	port: RefCounted,
	target: Dictionary,
	source: Dictionary,
	amount: int,
	element: String = "",
	damage_props: Dictionary = {}
) -> Dictionary:
	var damage: int = max(0, amount)
	var logs: Array = []
	if not _accepts(port) or not _handlers_valid():
		return {"damage": damage, "logs": logs}
	for mechanism_id_value in port.mechanic_ids(target):
		if damage <= 0:
			continue
		var mechanism_id := String(mechanism_id_value)
		var mechanism := Dictionary(port.mechanism(mechanism_id))
		var handler: RefCounted = _handler_for(mechanism_id, mechanism)
		if not _supports(handler, &"before_damage"):
			continue
		var result := Dictionary(handler.call(
			&"before_damage", port, target, source, damage, element, damage_props, mechanism
		))
		damage = max(0, int(result.get("damage", damage)))
		_append_lines(logs, Array(result.get("logs", [])))
	return {"damage": damage, "logs": logs}


func apply_after_damage(
	port: RefCounted,
	target: Dictionary,
	source: Dictionary,
	amount: int,
	damage_props: Dictionary = {}
) -> Array:
	var logs: Array = []
	if not _accepts(port) or not _handlers_valid() or target.is_empty() or amount <= 0 or int(target.get("hp", 0)) <= 0:
		return logs
	for mechanism_id_value in port.mechanic_ids(target):
		var mechanism_id := String(mechanism_id_value)
		var mechanism := Dictionary(port.mechanism(mechanism_id))
		var handler: RefCounted = _handler_for(mechanism_id, mechanism)
		if not _supports(handler, &"after_damage"):
			continue
		_append_lines(logs, Array(handler.call(
			&"after_damage", port, target, source, amount, damage_props, mechanism
		)))
	return logs


func apply_after_hit(
	port: RefCounted,
	target: Dictionary,
	source: Dictionary,
	amount: int,
	damage_props: Dictionary = {}
) -> Array:
	var logs: Array = []
	if not _accepts(port) or not _handlers_valid() or not DamagePropsScript.is_move(damage_props) or target.is_empty() or source.is_empty() or amount <= 0 or int(source.get("hp", 0)) <= 0:
		return logs
	for mechanism_id_value in port.mechanic_ids(target):
		var mechanism_id := String(mechanism_id_value)
		var mechanism := Dictionary(port.mechanism(mechanism_id))
		var handler: RefCounted = _handler_for(mechanism_id, mechanism)
		if not _supports(handler, &"after_hit"):
			continue
		_append_lines(logs, Array(handler.call(
			&"after_hit", port, target, source, amount, damage_props, mechanism
		)))
	return logs


func apply_cross_damage(
	port: RefCounted,
	unit: Dictionary,
	source: Dictionary,
	damage: int,
	element: String,
	label: String,
	trace_context: Dictionary = {}
) -> Dictionary:
	var logs: Array = []
	var hit_count := 0
	if not _accepts(port) or not _handlers_valid() or unit.is_empty() or damage <= 0:
		return {"hit_count": hit_count, "logs": logs}
	var center_x := int(unit.get("x", -1))
	var center_y := int(unit.get("y", -1))
	var unit_side := String(unit.get("side", ""))
	var pending_deaths: Array = []
	for target_value in port.all_units():
		var target := Dictionary(target_value)
		if String(target.get("id", "")) == String(unit.get("id", "")) or int(target.get("hp", 0)) <= 0 or String(target.get("side", "")) == unit_side:
			continue
		var distance: int = abs(int(target.get("x", -1)) - center_x) + abs(int(target.get("y", -1)) - center_y)
		if distance != 1:
			continue
		var hp_before := int(target.get("hp", 0))
		var resolved_trace_context := trace_context.duplicate(true)
		if not source.is_empty() and String(source.get("id", "")) != String(unit.get("id", "")):
			resolved_trace_context["causedById"] = String(source.get("id", ""))
			resolved_trace_context["causedByName"] = String(source.get("name", source.get("id", "")))
		resolved_trace_context["deferDeathResolution"] = true
		var result := Dictionary(port.deal_damage(
			unit,
			target,
			damage,
			element,
			resolved_trace_context,
			DamagePropsScript.non_move_unpowered()
		))
		if bool(result.get("pending_death", false)):
			pending_deaths.append({"source": unit, "target": target, "result": result})
		hit_count += 1
		logs.append("%s 波及%s：HP %d→%d。" % [label, String(target.get("name", "目标")), hp_before, int(target.get("hp", 0))])
		_append_lines(logs, Array(result.get("mechanic_logs", [])))
	_append_lines(logs, Array(port.resolve_damage_deaths(pending_deaths)))
	return {"hit_count": hit_count, "logs": logs}


func apply_attacker_after_hit(
	port: RefCounted,
	attacker: Dictionary,
	target: Dictionary,
	amount: int,
	element: String,
	direction: String = ""
) -> Array:
	var logs: Array = []
	if not _accepts(port) or not _handlers_valid() or attacker.is_empty() or target.is_empty() or amount <= 0 or int(attacker.get("hp", 0)) <= 0:
		return logs
	for mechanism_id_value in port.mechanic_ids(attacker):
		var mechanism_id := String(mechanism_id_value)
		var mechanism := Dictionary(port.mechanism(mechanism_id))
		var handler: RefCounted = _handler_for(mechanism_id, mechanism)
		if not _supports(handler, &"attacker_after_hit"):
			continue
		_append_lines(logs, Array(handler.call(
			&"attacker_after_hit", port, attacker, target, amount, element, direction, mechanism
		)))
	return logs


func _handler_for(mechanism_id: String, mechanism: Dictionary) -> RefCounted:
	return _handler_registry.handler_for(mechanism_id, mechanism) if _handlers_valid() else null


func _supports(handler: RefCounted, hook: StringName) -> bool:
	return handler != null and _handler_registry.supports(handler, hook)


func _handlers_valid() -> bool:
	return _handler_registry != null and _handler_registry.is_valid()


func _accepts(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.call(&"contract_id")) == PORT_CONTRACT_ID


func _append_lines(target: Array, lines: Array) -> void:
	for line in lines:
		target.append(String(line))
