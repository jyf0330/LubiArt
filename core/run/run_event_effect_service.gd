extends RefCounted

const OperationRegistryScript := preload("res://core/run/events/run_event_operation_registry.gd")

const PORT_CONTRACT_ID := &"ysbzs.run-event-port.v1"
const CONTEXT_KINDS := ["shop_event", "route_event", "rest", "post_battle"]
const REQUIRED_PORT_METHODS: Array[StringName] = [
	&"contract_id",
	&"begin_transaction",
	&"commit_transaction",
	&"rollback_transaction",
	&"current_coins",
	&"spend_coins",
	&"add_coins",
	&"heal_hero",
	&"queue_battle_prep",
	&"queue_outer_run",
	&"add_free_refreshes",
	&"set_next_discount",
	&"upgrade_first_eligible_pet",
	&"duplicate_first_pet",
	&"refill_shop_pool",
	&"select_reward_pool",
	&"append_shop_event_summary",
]
const REQUIRED_OPERATION_KEYS := ["id", "operation", "priority", "params"]
const ALLOWED_OPERATION_KEYS := ["id", "operation", "priority", "params", "contexts"]

var _registry: RefCounted


func _init(registry: RefCounted = null) -> void:
	_registry = registry if registry != null else OperationRegistryScript.new()


func execute(port: RefCounted, event: Dictionary, context: Dictionary, operations: Array) -> Dictionary:
	var event_id := String(event.get("id", ""))
	var context_kind_result := _validate_context(context)
	if not bool(context_kind_result.get("ok", false)):
		return _failure_envelope(String(context_kind_result.get("code", "invalid_context")), event_id, 0)
	if not _registry_is_valid():
		return _failure_envelope("invalid_operation_registry", event_id, 0)

	var normalization := _normalize_operations(operations)
	if not bool(normalization.get("ok", false)):
		return _failure_envelope("invalid_operations", event_id, 0)
	if not _port_is_valid(port):
		return _failure_envelope("invalid_port_contract", event_id, 0)

	var coins_from: int = int(port.current_coins())
	var normalized := Array(normalization.get("operations", []))
	var applicable: Array = []
	var context_kind := String(context.get("context_kind", ""))
	for operation_value in normalized:
		var operation := Dictionary(operation_value)
		var contexts := Array(operation.get("contexts", []))
		if contexts.is_empty() or contexts.has(context_kind):
			applicable.append(operation)
	applicable.sort_custom(_operation_precedes)

	var spend_operations: Array = []
	var typed_operations: Array = []
	for operation_value in applicable:
		var operation := Dictionary(operation_value)
		if String(operation.get("operation", "")) == "spend_coins":
			spend_operations.append(operation)
		else:
			typed_operations.append(operation)
	var execution_order := spend_operations
	execution_order.append_array(typed_operations)

	if not port.begin_transaction():
		return _failure_envelope("transaction_begin_failed", event_id, coins_from)

	var operation_results: Array = []
	var shop_effect: Dictionary = {}
	var battle_prep_effect: Dictionary = {}
	var outer_run_effect: Dictionary = {}
	var reward_pool_id := ""
	var logs: Array[String] = []
	var summary := _shop_summary(event, context)
	var execution_context := context.duplicate(true)
	execution_context["immediate_gold"] = 0
	for operation_value in execution_order:
		var operation := Dictionary(operation_value)
		var handler := operation.get("handler") as RefCounted
		var handler_result_value: Variant = handler.execute(
			port,
			event.duplicate(true),
			execution_context.duplicate(true),
			Dictionary(operation.get("params", {})).duplicate(true)
		)
		if not handler_result_value is Dictionary:
			port.rollback_transaction()
			return _failure_envelope("invalid_handler_result", event_id, port.current_coins(), operation_results)
		var handler_result := Dictionary(handler_result_value).duplicate(true)
		if not _is_structured_result(handler_result):
			port.rollback_transaction()
			return _failure_envelope("invalid_handler_result", event_id, port.current_coins(), operation_results)
		if not bool(handler_result.get("ok", false)):
			var failure_code := String(handler_result.get("code", "handler_failed"))
			if failure_code == "":
				failure_code = "handler_failed"
			port.rollback_transaction()
			return _failure_envelope(failure_code, event_id, port.current_coins(), operation_results)
		if handler_result.has("logs"):
			var handler_logs_value: Variant = handler_result.get("logs")
			if not handler_logs_value is Array:
				port.rollback_transaction()
				return _failure_envelope("invalid_handler_logs", event_id, port.current_coins(), operation_results)
			for log_value in Array(handler_logs_value):
				if typeof(log_value) != TYPE_STRING or String(log_value).strip_edges() == "":
					port.rollback_transaction()
					return _failure_envelope("invalid_handler_logs", event_id, port.current_coins(), operation_results)
				logs.append(String(log_value))
		var operation_result := handler_result.duplicate(true)
		operation_result["id"] = String(operation.get("id", ""))
		operation_result["operation"] = String(operation.get("operation", ""))
		operation_results.append(operation_result)
		if handler_result.get("battle_prep_effect", null) is Dictionary:
			battle_prep_effect = Dictionary(handler_result.get("battle_prep_effect", {})).duplicate(true)
		if handler_result.get("outer_run_effect", null) is Dictionary:
			outer_run_effect = Dictionary(handler_result.get("outer_run_effect", {})).duplicate(true)
		if typeof(handler_result.get("reward_pool_id", null)) == TYPE_STRING:
			reward_pool_id = String(handler_result.get("reward_pool_id", ""))
		if String(operation.get("operation", "")) == "add_coins":
			if typeof(handler_result.get("coins_from", null)) != TYPE_INT \
				or typeof(handler_result.get("coins_to", null)) != TYPE_INT \
				or int(handler_result.get("coins_to", 0)) < int(handler_result.get("coins_from", 0)):
				port.rollback_transaction()
				return _failure_envelope("invalid_handler_result", event_id, port.current_coins(), operation_results)
			execution_context["immediate_gold"] = int(execution_context.get("immediate_gold", 0)) \
				+ int(handler_result.get("coins_to", 0)) \
				- int(handler_result.get("coins_from", 0))
		_merge_summary(summary, handler_result)

	if _should_append_shop_summary(event, context_kind):
		var summary_result_value: Variant = port.append_shop_event_summary(summary)
		if not summary_result_value is Dictionary:
			port.rollback_transaction()
			return _failure_envelope("invalid_summary_result", event_id, port.current_coins(), operation_results)
		var summary_result := Dictionary(summary_result_value)
		if not _is_structured_result(summary_result):
			port.rollback_transaction()
			return _failure_envelope("invalid_summary_result", event_id, port.current_coins(), operation_results)
		if not bool(summary_result.get("ok", false)):
			var summary_code := String(summary_result.get("code", "summary_failed"))
			if summary_code == "":
				summary_code = "summary_failed"
			port.rollback_transaction()
			return _failure_envelope(summary_code, event_id, port.current_coins(), operation_results)
		shop_effect = Dictionary(summary_result.get("shop_effect", summary)).duplicate(true)

	if not port.commit_transaction():
		port.rollback_transaction()
		return _failure_envelope("commit_failed", event_id, port.current_coins(), operation_results)
	return _envelope(
		true,
		"ok",
		event_id,
		coins_from,
		port.current_coins(),
		operation_results,
		shop_effect,
		battle_prep_effect,
		outer_run_effect,
		reward_pool_id,
		logs
	)


func _registry_is_valid() -> bool:
	return _registry != null \
		and _registry.has_method(&"is_valid") \
		and _registry.has_method(&"handler_for") \
		and _registry.has_method(&"validate_params") \
		and bool(_registry.is_valid())


func _port_is_valid(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.contract_id()) == PORT_CONTRACT_ID


func _validate_context(context: Dictionary) -> Dictionary:
	if not context.has("context_kind") or typeof(context.get("context_kind")) != TYPE_STRING:
		return {"ok": false, "code": "invalid_context"}
	var context_kind := String(context.get("context_kind", ""))
	if not CONTEXT_KINDS.has(context_kind):
		return {"ok": false, "code": "invalid_context"}
	return {"ok": true, "code": "ok"}


func _normalize_operations(operations: Array) -> Dictionary:
	var errors: Array[String] = []
	var normalized: Array = []
	var seen_ids := {}
	if operations.is_empty():
		errors.append("operations must not be empty")
	for operation_index in range(operations.size()):
		var operation_value: Variant = operations[operation_index]
		if not operation_value is Dictionary:
			errors.append("operation %d must be a Dictionary" % operation_index)
			continue
		var operation := Dictionary(operation_value)
		for required_key in REQUIRED_OPERATION_KEYS:
			if not operation.has(required_key):
				errors.append("operation %d is missing %s" % [operation_index, required_key])
		for key_value in operation.keys():
			if not key_value is String or not ALLOWED_OPERATION_KEYS.has(String(key_value)):
				errors.append("operation %d has unknown key %s" % [operation_index, str(key_value)])

		var descriptor_id := ""
		if typeof(operation.get("id", null)) != TYPE_STRING:
			errors.append("operation %d id must be a String" % operation_index)
		else:
			descriptor_id = String(operation.get("id", "")).strip_edges()
			if descriptor_id == "":
				errors.append("operation %d id must not be empty" % operation_index)
			elif seen_ids.has(descriptor_id):
				errors.append("duplicate operation id %s" % descriptor_id)
			else:
				seen_ids[descriptor_id] = true

		var handler_id := ""
		var handler: RefCounted = null
		if typeof(operation.get("operation", null)) != TYPE_STRING:
			errors.append("operation %s handler id must be a String" % descriptor_id)
		else:
			handler_id = String(operation.get("operation", "")).strip_edges()
			if handler_id == "":
				errors.append("operation %s handler id must not be empty" % descriptor_id)
			else:
				handler = _registry.handler_for(handler_id) as RefCounted
				if handler == null or not handler.has_method(&"execute"):
					errors.append("operation %s references unknown handler %s" % [descriptor_id, handler_id])

		if typeof(operation.get("priority", null)) != TYPE_INT:
			errors.append("operation %s priority must be an integer" % descriptor_id)
		var params_value: Variant = operation.get("params", null)
		var params_are_valid := params_value is Dictionary
		if not params_are_valid:
			errors.append("operation %s params must be a Dictionary" % descriptor_id)
		elif not _is_json_compatible(params_value):
			errors.append("operation %s params must be JSON-compatible" % descriptor_id)
			params_are_valid = false
		elif handler != null:
			var param_errors_value: Variant = _registry.validate_params(handler_id, Dictionary(params_value).duplicate(true))
			if not param_errors_value is Array:
				errors.append("operation %s parameter validator returned a non-Array" % descriptor_id)
				params_are_valid = false
			else:
				for error_value in Array(param_errors_value):
					if typeof(error_value) != TYPE_STRING or String(error_value).strip_edges() == "":
						errors.append("operation %s parameter validator returned an invalid error" % descriptor_id)
					else:
						errors.append("operation %s params: %s" % [descriptor_id, String(error_value)])
					params_are_valid = false

		var contexts: Array = []
		var contexts_are_valid := true
		if operation.has("contexts"):
			var contexts_value: Variant = operation.get("contexts")
			if not contexts_value is Array or Array(contexts_value).is_empty():
				errors.append("operation %s contexts must be a non-empty Array" % descriptor_id)
				contexts_are_valid = false
			else:
				for context_value in Array(contexts_value):
					if typeof(context_value) != TYPE_STRING:
						errors.append("operation %s context must be a String" % descriptor_id)
						contexts_are_valid = false
						continue
					var context_kind := String(context_value)
					if not CONTEXT_KINDS.has(context_kind):
						errors.append("operation %s declares unknown context %s" % [descriptor_id, context_kind])
						contexts_are_valid = false
					elif contexts.has(context_kind):
						errors.append("operation %s repeats context %s" % [descriptor_id, context_kind])
						contexts_are_valid = false
					else:
						contexts.append(context_kind)

		if descriptor_id == "" or handler == null or not params_are_valid or not contexts_are_valid:
			continue
		normalized.append({
			"id": descriptor_id,
			"operation": handler_id,
			"priority": int(operation.get("priority", 0)),
			"params": Dictionary(params_value).duplicate(true),
			"contexts": contexts.duplicate(),
			"source_index": 0,
			"operation_index": operation_index,
			"handler": handler,
		})
	return {
		"ok": errors.is_empty() and normalized.size() == operations.size(),
		"errors": errors,
		"operations": normalized,
	}


func _operation_precedes(left_value: Variant, right_value: Variant) -> bool:
	var left := Dictionary(left_value)
	var right := Dictionary(right_value)
	for key in ["priority", "source_index", "operation_index"]:
		var left_number := int(left.get(key, 0))
		var right_number := int(right.get(key, 0))
		if left_number != right_number:
			return left_number < right_number
	return String(left.get("id", "")) < String(right.get("id", ""))


func _shop_summary(event: Dictionary, context: Dictionary) -> Dictionary:
	return {
		"event_id": String(event.get("id", "")),
		"name": String(event.get("name", "")),
		"source": String(context.get("context_kind", "")),
		"node_id": String(context.get("node_id", "")),
		"free_rolls": 0,
		"next_discount": 0,
		"targeted_pool_id": String(event.get("shop_pool_id", "")),
		"construction": {},
	}


func _merge_summary(summary: Dictionary, handler_result: Dictionary) -> void:
	if handler_result.has("free_rolls_from") and handler_result.has("free_rolls_to"):
		summary["free_rolls"] = int(summary.get("free_rolls", 0)) \
			+ int(handler_result.get("free_rolls_to", 0)) \
			- int(handler_result.get("free_rolls_from", 0))
	if handler_result.has("next_discount_to"):
		summary["next_discount"] = int(handler_result.get("next_discount_to", 0))
	if handler_result.get("construction", null) is Dictionary:
		summary["construction"] = Dictionary(handler_result.get("construction", {})).duplicate(true)


func _should_append_shop_summary(event: Dictionary, context_kind: String) -> bool:
	return String(event.get("layer", "")) == "shop_phase" \
		and ["shop_event", "route_event"].has(context_kind)


func _is_json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
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


func _is_structured_result(result: Dictionary) -> bool:
	return typeof(result.get("ok", null)) == TYPE_BOOL \
		and typeof(result.get("code", null)) == TYPE_STRING \
		and String(result.get("code", "")).strip_edges() != ""


func _failure_envelope(code: String, event_id: String, coins_to: int, operation_results: Array = []) -> Dictionary:
	return _envelope(false, code, event_id, coins_to, coins_to, operation_results, {}, {}, {}, "", [])


func _envelope(
	ok: bool,
	code: String,
	event_id: String,
	coins_from: int,
	coins_to: int,
	operation_results: Array,
	shop_effect: Dictionary,
	battle_prep_effect: Dictionary,
	outer_run_effect: Dictionary,
	reward_pool_id: String,
	logs: Array[String]
) -> Dictionary:
	return {
		"ok": ok,
		"code": code,
		"event_id": event_id,
		"coins_from": coins_from,
		"coins_to": coins_to,
		"operation_results": operation_results.duplicate(true),
		"shop_effect": shop_effect.duplicate(true),
		"battle_prep_effect": battle_prep_effect.duplicate(true),
		"outer_run_effect": outer_run_effect.duplicate(true),
		"reward_pool_id": reward_pool_id,
		"logs": logs.duplicate(),
	}
