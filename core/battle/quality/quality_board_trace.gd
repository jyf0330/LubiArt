extends RefCounted
class_name QualityBoardTrace

const QualityOperationRegistryScript := preload("res://core/battle/quality/quality_operation_registry.gd")

static var _default_operation_registry: RefCounted


static func element_apply_bonus(traces: Array, operation_registry: RefCounted = null) -> int:
	var registry := _resolve_registry(operation_registry)
	if not _registry_is_valid(registry):
		return 0
	var current := 0
	for group_value in _trace_groups(traces):
		var group := Dictionary(group_value)
		var handler: RefCounted = registry.call(
			&"handler_for",
			String(group.get("handler_id", ""))
		) as RefCounted
		if handler == null or not bool(registry.call(
			&"supports",
			handler,
			&"trace_element_application_count"
		)):
			continue
		current = int(handler.call(
			&"trace_element_application_count",
			Array(group.get("traces", [])).duplicate(true),
			current,
			Dictionary(group.get("params", {})).duplicate(true)
		))
	return current


static func apply_round_start(
	context: QualityEffectContext,
	unit: Dictionary,
	traces: Array,
	operation_registry: RefCounted = null
) -> Array:
	var logs: Array = []
	var registry := _resolve_registry(operation_registry)
	if not _registry_is_valid(registry):
		return logs
	for group_value in _trace_groups(traces):
		var group := Dictionary(group_value)
		var handler: RefCounted = registry.call(
			&"handler_for",
			String(group.get("handler_id", ""))
		) as RefCounted
		if handler == null or not bool(registry.call(
			&"supports",
			handler,
			&"trace_round_start"
		)):
			continue
		var result = handler.call(
			&"trace_round_start",
			context,
			unit,
			Array(group.get("traces", [])).duplicate(true),
			Dictionary(group.get("params", {})).duplicate(true)
		)
		if typeof(result) != TYPE_ARRAY:
			continue
		for log_value in Array(result):
			logs.append(String(log_value))
	return logs


static func apply_after_attack(
	context: QualityEffectContext,
	attacker: Dictionary,
	option: Dictionary,
	trace_definition: Dictionary,
	operation_registry: RefCounted = null
) -> Array:
	var logs: Array = []
	if trace_definition.is_empty():
		return logs
	var registry := _resolve_registry(operation_registry)
	if not _registry_is_valid(registry):
		return logs
	var handler_id := _handler_id(trace_definition)
	var handler: RefCounted = registry.call(&"handler_for", handler_id) as RefCounted
	if handler == null or not bool(registry.call(&"supports", handler, &"after_attack")):
		return logs
	var params := _trace_params(trace_definition)
	if trace_definition.has("kind") and not trace_definition.has("handler_id"):
		params["__legacy_state_schema"] = true
	params["duration"] = max(1, int(trace_definition.get("duration", params.get("duration", 1))))
	params["persistent"] = bool(trace_definition.get("persistent", params.get("persistent", false)))
	var trace_id := String(trace_definition.get("id", ""))
	var trace_name := String(trace_definition.get("name", ""))
	if trace_id != "":
		params["__trace_id"] = trace_id
	if trace_name != "":
		params["__trace_name"] = trace_name
	var result = handler.call(
		&"after_attack",
		context,
		attacker,
		option.duplicate(true),
		[],
		params
	)
	return Array(result).duplicate(true) if typeof(result) == TYPE_ARRAY else logs


static func apply_to_unit(
	context: QualityEffectContext,
	unit: Dictionary,
	trace: Dictionary,
	operation_registry: RefCounted = null
) -> String:
	if unit.is_empty() or trace.is_empty() or int(unit.get("hp", 0)) <= 0:
		return ""
	var registry := _resolve_registry(operation_registry)
	if not _registry_is_valid(registry):
		return ""
	var handler: RefCounted = registry.call(&"handler_for", _handler_id(trace)) as RefCounted
	if handler == null or not bool(registry.call(&"supports", handler, &"trace_enter")):
		return ""
	return String(handler.call(
		&"trace_enter",
		context,
		unit,
		trace.duplicate(true),
		_trace_params(trace)
	))


static func _trace_groups(traces: Array) -> Array:
	var groups: Array = []
	var group_indexes: Dictionary = {}
	for trace_value in traces:
		if typeof(trace_value) != TYPE_DICTIONARY:
			continue
		var trace := Dictionary(trace_value)
		var handler_id := _handler_id(trace)
		if handler_id == "":
			continue
		var params := _trace_params(trace)
		var group_key := "%s\n%s" % [handler_id, JSON.stringify(params, "", true, true)]
		if not group_indexes.has(group_key):
			group_indexes[group_key] = groups.size()
			groups.append({
				"handler_id": handler_id,
				"traces": [],
				"params": params,
			})
		var group_index := int(group_indexes[group_key])
		var group := Dictionary(groups[group_index])
		var group_traces := Array(group.get("traces", []))
		group_traces.append(trace.duplicate(true))
		group["traces"] = group_traces
		groups[group_index] = group
	return groups


static func _handler_id(trace: Dictionary) -> String:
	return String(trace.get("handler_id", trace.get("kind", ""))).strip_edges()


static func _trace_params(trace: Dictionary) -> Dictionary:
	var value = trace.get("params", {})
	return Dictionary(value).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


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
