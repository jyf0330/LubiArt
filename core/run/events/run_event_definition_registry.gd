extends RefCounted
class_name RunEventDefinitionRegistry

const LegacyCatalogScript := preload("res://core/run/events/legacy_run_event_catalog.gd")
const OperationRegistryScript := preload("res://core/run/events/run_event_operation_registry.gd")

const RUNTIME_SCHEMA_VERSION := 1
const CURRENT_ASSEMBLY := &"current_assembly"
const PERSISTED_SNAPSHOT := &"persisted_snapshot"
const CONTEXT_KINDS := ["shop_event", "route_event", "rest", "post_battle"]
const POST_BATTLE_OPERATION_IDS := ["select_reward_pool"]
const OPERATION_KEYS := ["id", "operation", "priority", "params", "contexts"]
const TRIGGER_KEYS := ["id", "hook", "priority", "conditions", "condition_label"]

var _operation_registry: RefCounted
var _event_operations: Dictionary = {}
var _rest_operations: Dictionary = {}
var _post_battle_triggers: Array = []
var _configured := false
var _validation_errors: Array[String] = []
var _pending_candidates: Dictionary = {}


func _init(operation_directory: String = OperationRegistryScript.HANDLER_DIRECTORY) -> void:
	_operation_registry = OperationRegistryScript.new(operation_directory)
	if not _operation_registry.is_valid():
		_validation_errors.append_array(_operation_registry.validation_errors())


func prepare_configuration(content: Dictionary, source_kind: StringName) -> Dictionary:
	_pending_candidates.clear()
	var errors: Array[String] = []
	if _operation_registry == null or not _operation_registry.is_valid():
		errors.append("Run event operation registry is invalid.")
		if _operation_registry != null:
			errors.append_array(_operation_registry.validation_errors())
		return _failure(errors)
	if not [CURRENT_ASSEMBLY, PERSISTED_SNAPSHOT].has(source_kind):
		errors.append("Run event source kind '%s' is unsupported." % String(source_kind))
		return _failure(errors)
	var economy_value: Variant = content.get("economy", null)
	if not economy_value is Dictionary:
		return _failure(["Run event content must contain economy data."])
	var economy := Dictionary(economy_value)
	var version_value: Variant = economy.get("runtime_schema_version", 0)
	if economy.has("runtime_schema_version") and not _is_integral_number(version_value):
		return _failure(["Run event runtime schema version must be an integer."])
	var runtime_schema_version := int(version_value)
	var legacy_snapshot := source_kind == PERSISTED_SNAPSHOT and runtime_schema_version < RUNTIME_SCHEMA_VERSION
	if source_kind == CURRENT_ASSEMBLY and runtime_schema_version < RUNTIME_SCHEMA_VERSION:
		return _failure(["Run event runtime schema version %d is below required version %d for current assembly." % [
			runtime_schema_version,
			RUNTIME_SCHEMA_VERSION,
		]])
	var events_value: Variant = economy.get("events", null)
	if not events_value is Array or Array(events_value).is_empty():
		return _failure(["Run event configuration must contain at least one event."])
	var route_value: Variant = content.get("route", null)
	if not route_value is Dictionary:
		return _failure(["Run event content must contain route data."])
	var node_pool_value: Variant = Dictionary(route_value).get("node_pool", null)
	if not node_pool_value is Array:
		return _failure(["Run event route node_pool must be an Array."])

	var effective_events := Array(events_value).duplicate(true)
	var effective_nodes := Array(node_pool_value).duplicate(true)
	if legacy_snapshot:
		effective_events = _legacy_events(effective_events, errors)
		effective_nodes = _legacy_rest_nodes(effective_nodes, errors)

	var event_blueprints: Dictionary = {}
	var rest_blueprints: Dictionary = {}
	var trigger_blueprints: Array = []
	_normalize_events(effective_events, event_blueprints, trigger_blueprints, errors)
	_normalize_rest_nodes(effective_nodes, rest_blueprints, errors)
	if not errors.is_empty():
		return _failure(errors)
	trigger_blueprints.sort_custom(_trigger_precedes)
	var token := RefCounted.new()
	_pending_candidates[token.get_instance_id()] = {
		"token": token,
		"event_operations": event_blueprints.duplicate(true),
		"rest_operations": rest_blueprints.duplicate(true),
		"post_battle_triggers": trigger_blueprints.duplicate(true),
	}
	return {"ok": true, "candidate": {"token": token}, "errors": []}


func commit_configuration(candidate: Dictionary) -> void:
	var token_value: Variant = candidate.get("token", null)
	if not token_value is RefCounted:
		return
	var token := token_value as RefCounted
	var pending_value: Variant = _pending_candidates.get(token.get_instance_id(), null)
	if not pending_value is Dictionary or Dictionary(pending_value).get("token", null) != token:
		return
	_pending_candidates.erase(token.get_instance_id())
	var pending := Dictionary(pending_value)
	_event_operations = Dictionary(pending["event_operations"]).duplicate(true)
	_rest_operations = Dictionary(pending["rest_operations"]).duplicate(true)
	_post_battle_triggers = Array(pending["post_battle_triggers"]).duplicate(true)
	_configured = true


func _is_configuration_candidate_pending(candidate: Dictionary) -> bool:
	var token_value: Variant = candidate.get("token", null)
	if not token_value is RefCounted:
		return false
	var token := token_value as RefCounted
	var pending_value: Variant = _pending_candidates.get(token.get_instance_id(), null)
	return pending_value is Dictionary and Dictionary(pending_value).get("token", null) == token


func is_configured() -> bool:
	return _configured


func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func operations_for_event(event_id: String) -> Array:
	if not _configured or not _event_operations.has(event_id):
		return []
	return Array(_event_operations[event_id]).duplicate(true)


func operations_for_rest_node(node_id: String) -> Array:
	if not _configured or not _rest_operations.has(node_id):
		return []
	return Array(_rest_operations[node_id]).duplicate(true)


func matching_post_battle_events(result_code: String) -> Array:
	var result: Array = []
	if not _configured:
		return result
	for trigger_value in _post_battle_triggers:
		var trigger := Dictionary(trigger_value)
		if not Array(trigger.get("result_codes", [])).has(result_code):
			continue
		result.append({
			"event_id": String(trigger.get("event_id", "")),
			"trigger_id": String(trigger.get("trigger_id", "")),
			"priority": int(trigger.get("priority", 0)),
			"source_index": int(trigger.get("source_index", 0)),
			"trigger_index": int(trigger.get("trigger_index", 0)),
			"condition_label": String(trigger.get("condition_label", "")),
			"operations": Array(trigger.get("operations", [])).duplicate(true),
		})
	return result


func _normalize_events(
	events: Array,
	event_blueprints: Dictionary,
	trigger_blueprints: Array,
	errors: Array[String]
) -> void:
	var seen_events := {}
	for source_index in range(events.size()):
		var event_value: Variant = events[source_index]
		if not event_value is Dictionary:
			errors.append("Run event at index %d must be a Dictionary." % source_index)
			continue
		var event := Dictionary(event_value)
		var event_id := _identifier(event.get("id", null))
		if event_id == "":
			errors.append("Run event at index %d has an invalid id." % source_index)
			continue
		if seen_events.has(event_id):
			errors.append("Duplicate run event id '%s'." % event_id)
			continue
		seen_events[event_id] = true
		var operations := _normalize_operations(
			event_id,
			event.get("event_operations", null),
			source_index,
			errors
		)
		if not operations.is_empty():
			event_blueprints[event_id] = operations.duplicate(true)
		var triggers := _normalize_triggers(
			event_id,
			event.get("event_triggers", []),
			source_index,
			operations,
			errors
		)
		trigger_blueprints.append_array(triggers)


func _normalize_rest_nodes(nodes: Array, rest_blueprints: Dictionary, errors: Array[String]) -> void:
	var seen_nodes := {}
	for source_index in range(nodes.size()):
		var node_value: Variant = nodes[source_index]
		if not node_value is Dictionary:
			continue
		var node := Dictionary(node_value)
		if String(node.get("nodeType", "")) != "rest":
			continue
		var node_id := _identifier(node.get("nodeId", null))
		if node_id == "":
			errors.append("Rest node at index %d has an invalid nodeId." % source_index)
			continue
		if seen_nodes.has(node_id):
			errors.append("Duplicate rest node id '%s'." % node_id)
			continue
		seen_nodes[node_id] = true
		var operations := _normalize_operations(
			node_id,
			node.get("event_operations", null),
			source_index,
			errors
		)
		if not operations.is_empty():
			rest_blueprints[node_id] = operations.duplicate(true)


func _normalize_operations(
	owner_id: String,
	operations_value: Variant,
	source_index: int,
	errors: Array[String]
) -> Array:
	var normalized: Array = []
	if not operations_value is Array or Array(operations_value).is_empty():
		errors.append("Run event definition '%s' must declare at least one event operation." % owner_id)
		return normalized
	var seen_operations := {}
	for operation_index in range(Array(operations_value).size()):
		var operation_value: Variant = Array(operations_value)[operation_index]
		if not operation_value is Dictionary:
			errors.append("Run event definition '%s' operation %d must be a Dictionary." % [owner_id, operation_index])
			continue
		var operation := Dictionary(operation_value)
		for required_key in ["id", "operation", "priority", "params"]:
			if not operation.has(required_key):
				errors.append("Run event definition '%s' operation %d is missing '%s'." % [owner_id, operation_index, required_key])
		for key_value in operation.keys():
			if typeof(key_value) != TYPE_STRING or not OPERATION_KEYS.has(String(key_value)):
				errors.append("Run event definition '%s' operation %d has unknown key '%s'." % [owner_id, operation_index, str(key_value)])
		var operation_id := _identifier(operation.get("id", null))
		if operation_id == "":
			errors.append("Run event definition '%s' operation %d has an invalid id." % [owner_id, operation_index])
		elif seen_operations.has(operation_id):
			errors.append("Duplicate run event operation id '%s'." % operation_id)
		else:
			seen_operations[operation_id] = true
		var handler_id := _identifier(operation.get("operation", null))
		var handler := _operation_registry.handler_for(handler_id) as RefCounted
		if handler_id == "" or handler == null:
			errors.append("Run event operation '%s' references unknown operation '%s'." % [operation_id, handler_id])
		var params_value: Variant = operation.get("params", null)
		var params_valid := params_value is Dictionary
		var params: Dictionary = {}
		if not params_valid or not _is_json_compatible(params_value):
			errors.append("Run event operation '%s' params must be a JSON-compatible Dictionary." % operation_id)
			params_valid = false
		elif _contains_script_path(params_value):
			errors.append("Run event operation '%s' params must not contain a script path." % operation_id)
			params_valid = false
		elif _contains_reserved_key(params_value):
			errors.append("Run event operation '%s' params must not contain reserved '__*' keys." % operation_id)
			params_valid = false
		else:
			params = Dictionary(_normalize_json_numbers(params_value))
		if params_valid and handler != null:
			for error_value in _operation_registry.validate_params(handler_id, params.duplicate(true)):
				errors.append("Run event operation '%s' params: %s" % [operation_id, String(error_value)])
				params_valid = false
		var priority_valid := _is_integral_number(operation.get("priority", null))
		if not priority_valid:
			errors.append("Run event operation '%s' priority must be an integer." % operation_id)
		var contexts: Array[String] = []
		var contexts_valid := true
		if operation.has("contexts"):
			var contexts_value: Variant = operation.get("contexts")
			if not contexts_value is Array or Array(contexts_value).is_empty():
				errors.append("Run event operation '%s' contexts must be a non-empty Array." % operation_id)
				contexts_valid = false
			else:
				for context_value in Array(contexts_value):
					if typeof(context_value) != TYPE_STRING:
						errors.append("Run event operation '%s' context must be a String." % operation_id)
						contexts_valid = false
						continue
					var context_kind := String(context_value)
					if context_kind != context_kind.strip_edges() or not CONTEXT_KINDS.has(context_kind):
						errors.append("Run event operation '%s' declares unknown context '%s'." % [operation_id, context_kind])
						contexts_valid = false
					elif contexts.has(context_kind):
						errors.append("Run event operation '%s' repeats context '%s'." % [operation_id, context_kind])
						contexts_valid = false
					else:
						contexts.append(context_kind)
		if operation_id == "" or handler == null or not params_valid or not priority_valid or not contexts_valid:
			continue
		normalized.append({
			"id": operation_id,
			"operation": handler_id,
			"priority": int(operation.get("priority", 0)),
			"params": params.duplicate(true),
			"contexts": contexts.duplicate(),
			"source_index": source_index,
			"operation_index": operation_index,
		})
	normalized.sort_custom(_operation_precedes)
	var blueprints: Array = []
	for operation_value in normalized:
		var operation := Dictionary(operation_value)
		var blueprint := {
			"id": String(operation.get("id", "")),
			"operation": String(operation.get("operation", "")),
			"priority": int(operation.get("priority", 0)),
			"params": Dictionary(operation.get("params", {})).duplicate(true),
		}
		var operation_contexts := Array(operation.get("contexts", []))
		if not operation_contexts.is_empty():
			blueprint["contexts"] = operation_contexts.duplicate()
		blueprints.append(blueprint)
	return blueprints


func _normalize_triggers(
	event_id: String,
	triggers_value: Variant,
	source_index: int,
	operations: Array,
	errors: Array[String]
) -> Array:
	var normalized: Array = []
	if not triggers_value is Array:
		errors.append("Run event '%s' event_triggers must be an Array." % event_id)
		return normalized
	var seen_triggers := {}
	for trigger_index in range(Array(triggers_value).size()):
		var trigger_value: Variant = Array(triggers_value)[trigger_index]
		if not trigger_value is Dictionary:
			errors.append("Run event '%s' trigger %d must be a Dictionary." % [event_id, trigger_index])
			continue
		var trigger := Dictionary(trigger_value)
		for required_key in TRIGGER_KEYS:
			if not trigger.has(required_key):
				errors.append("Run event '%s' trigger %d is missing '%s'." % [event_id, trigger_index, required_key])
		for key_value in trigger.keys():
			if typeof(key_value) != TYPE_STRING or not TRIGGER_KEYS.has(String(key_value)):
				errors.append("Run event '%s' trigger %d has unknown key '%s'." % [event_id, trigger_index, str(key_value)])
		var trigger_id := _identifier(trigger.get("id", null))
		if trigger_id == "":
			errors.append("Run event '%s' trigger %d has an invalid id." % [event_id, trigger_index])
		elif seen_triggers.has(trigger_id):
			errors.append("Duplicate run event trigger id '%s'." % trigger_id)
		else:
			seen_triggers[trigger_id] = true
		var hook := _identifier(trigger.get("hook", null))
		if hook != "post_battle":
			errors.append("Run event trigger '%s' declares unknown hook '%s'." % [trigger_id, hook])
		var priority_valid := _is_integral_number(trigger.get("priority", null))
		if not priority_valid:
			errors.append("Run event trigger '%s' priority must be an integer." % trigger_id)
		var conditions_value: Variant = trigger.get("conditions", null)
		var result_codes: Array[String] = []
		var conditions_valid := conditions_value is Dictionary
		if not conditions_valid \
				or Dictionary(conditions_value).size() != 1 \
				or not Dictionary(conditions_value).has("result_codes"):
			errors.append("Run event trigger '%s' conditions must contain only result_codes." % trigger_id)
			conditions_valid = false
		elif not _is_json_compatible(conditions_value) or _contains_script_path(conditions_value):
			errors.append("Run event trigger '%s' conditions must be JSON-compatible without script paths." % trigger_id)
			conditions_valid = false
		else:
			var result_codes_value: Variant = Dictionary(conditions_value).get("result_codes", null)
			if not result_codes_value is Array or Array(result_codes_value).is_empty():
				errors.append("Run event trigger '%s' result_codes must be a non-empty Array." % trigger_id)
				conditions_valid = false
			else:
				for code_value in Array(result_codes_value):
					var code := _identifier(code_value)
					if code == "" or result_codes.has(code):
						errors.append("Run event trigger '%s' has an invalid or duplicate result code." % trigger_id)
						conditions_valid = false
					else:
						result_codes.append(code)
		var condition_label := _identifier(trigger.get("condition_label", null))
		if condition_label == "":
			errors.append("Run event trigger '%s' condition_label must be a non-empty String." % trigger_id)
		var operations_valid := true
		for operation_value in operations:
			var operation_id := String(Dictionary(operation_value).get("operation", ""))
			if not POST_BATTLE_OPERATION_IDS.has(operation_id):
				errors.append("Run event trigger '%s' references mutating or unsupported post-battle operation '%s'." % [
					trigger_id,
					operation_id,
				])
				operations_valid = false
		if trigger_id == "" \
				or hook != "post_battle" \
				or not priority_valid \
				or not conditions_valid \
				or condition_label == "" \
				or not operations_valid:
			continue
		normalized.append({
			"event_id": event_id,
			"trigger_id": trigger_id,
			"priority": int(trigger.get("priority", 0)),
			"source_index": source_index,
			"trigger_index": trigger_index,
			"condition_label": condition_label,
			"result_codes": result_codes.duplicate(),
			"operations": operations.duplicate(true),
		})
	return normalized


func _legacy_events(events: Array, errors: Array[String]) -> Array:
	var legacy_by_id := {}
	for value in LegacyCatalogScript.events():
		var definition := Dictionary(value)
		legacy_by_id[String(definition.get("id", ""))] = definition
	var result: Array = []
	for index in range(events.size()):
		var event_value: Variant = events[index]
		if not event_value is Dictionary:
			result.append(event_value)
			continue
		var event := Dictionary(event_value).duplicate(true)
		var event_id := _identifier(event.get("id", null))
		if event_id == "" or not legacy_by_id.has(event_id):
			errors.append("Persisted legacy run event '%s' is not in the frozen catalog." % event_id)
			continue
		var definition := Dictionary(legacy_by_id[event_id])
		event["event_operations"] = Array(definition.get("event_operations", [])).duplicate(true)
		event["event_triggers"] = Array(definition.get("event_triggers", [])).duplicate(true)
		result.append(event)
	return result


func _legacy_rest_nodes(nodes: Array, errors: Array[String]) -> Array:
	var legacy_by_id := {}
	for value in LegacyCatalogScript.rest_nodes():
		var definition := Dictionary(value)
		legacy_by_id[String(definition.get("nodeId", ""))] = definition
	var result := nodes.duplicate(true)
	for index in range(result.size()):
		var node_value: Variant = result[index]
		if not node_value is Dictionary:
			continue
		var node := Dictionary(node_value).duplicate(true)
		if String(node.get("nodeType", "")) != "rest":
			continue
		var node_id := _identifier(node.get("nodeId", null))
		if node_id == "" or not legacy_by_id.has(node_id):
			errors.append("Persisted legacy rest node '%s' is not in the frozen catalog." % node_id)
			continue
		node["event_operations"] = Array(Dictionary(legacy_by_id[node_id]).get("event_operations", [])).duplicate(true)
		result[index] = node
	return result


func _operation_precedes(left_value: Variant, right_value: Variant) -> bool:
	var left := Dictionary(left_value)
	var right := Dictionary(right_value)
	for key in ["priority", "source_index", "operation_index"]:
		var left_number := int(left.get(key, 0))
		var right_number := int(right.get(key, 0))
		if left_number != right_number:
			return left_number < right_number
	return String(left.get("id", "")) < String(right.get("id", ""))


func _trigger_precedes(left_value: Variant, right_value: Variant) -> bool:
	var left := Dictionary(left_value)
	var right := Dictionary(right_value)
	for key in ["priority", "source_index", "trigger_index"]:
		var left_number := int(left.get(key, 0))
		var right_number := int(right.get(key, 0))
		if left_number != right_number:
			return left_number < right_number
	var left_id := String(left.get("trigger_id", ""))
	var right_id := String(right.get("trigger_id", ""))
	if left_id != right_id:
		return left_id < right_id
	return String(left.get("event_id", "")) < String(right.get("event_id", ""))


func _failure(errors: Array) -> Dictionary:
	var strings: Array[String] = []
	for error_value in errors:
		strings.append(String(error_value))
	return {"ok": false, "candidate": {}, "errors": strings}


func _identifier(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var result := String(value)
	return result if result != "" and result == result.strip_edges() else ""


func _contains_reserved_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_value in Dictionary(value).keys():
			if typeof(key_value) != TYPE_STRING or String(key_value).begins_with("__"):
				return true
			if _contains_reserved_key(Dictionary(value)[key_value]):
				return true
	elif value is Array:
		for item in Array(value):
			if _contains_reserved_key(item):
				return true
	return false


func _contains_script_path(value: Variant) -> bool:
	if typeof(value) == TYPE_STRING:
		var normalized := String(value).strip_edges().to_lower()
		return normalized.begins_with("res://") \
			or normalized.begins_with("user://") \
			or normalized.begins_with("uid://") \
			or normalized.ends_with(".gd") \
			or normalized.ends_with(".gdc")
	if value is Array:
		for item in Array(value):
			if _contains_script_path(item):
				return true
	elif value is Dictionary:
		for item in Dictionary(value).values():
			if _contains_script_path(item):
				return true
	return false


func _is_json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			for item in Array(value):
				if not _is_json_compatible(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key_value in Dictionary(value).keys():
				if typeof(key_value) != TYPE_STRING or not _is_json_compatible(Dictionary(value)[key_value]):
					return false
			return true
	return false


func _normalize_json_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and _is_integral_number(value):
		return int(value)
	if value is Array:
		var result: Array = []
		for item in Array(value):
			result.append(_normalize_json_numbers(item))
		return result
	if value is Dictionary:
		var result := {}
		for key_value in Dictionary(value).keys():
			result[String(key_value)] = _normalize_json_numbers(Dictionary(value)[key_value])
		return result
	return value


func _is_integral_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value))
