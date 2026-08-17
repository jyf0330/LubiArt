extends RefCounted
class_name QualityEffectRegistry

const LegacyCatalogScript := preload("res://core/battle/quality/legacy_quality_runtime_catalog.gd")
const OperationRegistryScript := preload("res://core/battle/quality/quality_operation_registry.gd")
const StrategyScript := preload("res://core/battle/quality/quality_effect_strategy.gd")

const RUNTIME_SCHEMA_VERSION := 1
const LEGACY_TRACE_SCHEMA_PARAM := "__legacy_state_schema"
const CURRENT_ASSEMBLY := &"current_assembly"
const PERSISTED_SNAPSHOT := &"persisted_snapshot"

var _operation_registry: RefCounted
var _effects: Dictionary = {}
var _empty_effect: QualityEffectStrategy
var _configured := false
var _validation_errors: Array[String] = []
var _pending_candidates: Dictionary = {}
var _preparing_legacy_snapshot := false


func _init(operation_directory: String = OperationRegistryScript.HANDLER_DIRECTORY) -> void:
	_operation_registry = OperationRegistryScript.new(operation_directory)
	_empty_effect = StrategyScript.new().configure("", {}, [], _operation_registry)
	if not _operation_registry.is_valid():
		_validation_errors.append_array(_operation_registry.validation_errors())


func prepare_configuration(
	upgrades: Array,
	runtime_schema_version: int,
	source_kind: StringName
) -> Dictionary:
	_pending_candidates.clear()
	var errors: Array[String] = []
	if _operation_registry == null or not _operation_registry.is_valid():
		errors.append("Quality operation registry is invalid.")
		if _operation_registry != null:
			errors.append_array(_operation_registry.validation_errors())
		return {"ok": false, "candidate": {}, "errors": errors}
	if not [CURRENT_ASSEMBLY, PERSISTED_SNAPSHOT].has(source_kind):
		errors.append("Quality runtime source kind '%s' is unsupported." % String(source_kind))
	var effective_upgrades := upgrades.duplicate(true)
	var use_legacy_snapshot := false
	if runtime_schema_version < RUNTIME_SCHEMA_VERSION:
		if source_kind == CURRENT_ASSEMBLY:
			errors.append("Quality runtime schema version %d is below required version %d for current assembly." % [
				runtime_schema_version,
				RUNTIME_SCHEMA_VERSION,
			])
		elif source_kind == PERSISTED_SNAPSHOT:
			use_legacy_snapshot = true
			effective_upgrades = _legacy_snapshot_upgrades(upgrades, errors)
	if effective_upgrades.is_empty():
		errors.append("Quality runtime configuration must contain at least one upgrade.")
	var seen_effects := {}
	var normalized_upgrades: Array = []
	_preparing_legacy_snapshot = use_legacy_snapshot
	for source_index in range(effective_upgrades.size()):
		var upgrade_value: Variant = effective_upgrades[source_index]
		if not upgrade_value is Dictionary:
			errors.append("Quality upgrade at index %d must be a Dictionary." % source_index)
			continue
		var upgrade := Dictionary(upgrade_value)
		var effect_id_value: Variant = upgrade.get("id", null)
		var effect_id := String(effect_id_value).strip_edges() if typeof(effect_id_value) == TYPE_STRING else ""
		if typeof(effect_id_value) != TYPE_STRING:
			errors.append("Quality upgrade at index %d id must be a String." % source_index)
			continue
		if effect_id == "":
			errors.append("Quality upgrade at index %d has an empty id." % source_index)
			continue
		if effect_id != String(effect_id_value):
			errors.append("Quality upgrade at index %d id must not contain surrounding whitespace." % source_index)
			continue
		if seen_effects.has(effect_id):
			errors.append("Duplicate quality upgrade id '%s'." % effect_id)
			continue
		seen_effects[effect_id] = true
		var operation_values: Variant = upgrade.get("runtime_operations", null)
		if not operation_values is Array or Array(operation_values).is_empty():
			errors.append("Quality upgrade '%s' must declare at least one runtime operation." % effect_id)
			continue
		var seen_operations := {}
		var normalized_operations: Array = []
		for operation_index in range(Array(operation_values).size()):
			var operation_value: Variant = Array(operation_values)[operation_index]
			var normalized := _normalize_operation(
				effect_id,
				operation_value,
				source_index,
				operation_index,
				seen_operations,
				errors
			)
			if not normalized.is_empty():
				normalized_operations.append(normalized)
		normalized_upgrades.append({
			"id": effect_id,
			"operations": normalized_operations,
		})
	_preparing_legacy_snapshot = false
	if not errors.is_empty():
		return {"ok": false, "candidate": {}, "errors": errors}
	var candidate_blueprints := {}
	for normalized_value in normalized_upgrades:
		var normalized_upgrade := Dictionary(normalized_value)
		var effect_id := String(normalized_upgrade.get("id", ""))
		var operations := Array(normalized_upgrade.get("operations", []))
		operations.sort_custom(Callable(self, "_operation_precedes"))
		var metadata_result := _metadata_for_operations(effect_id, operations)
		for error_value in Array(metadata_result.get("errors", [])):
			errors.append(String(error_value))
		if not errors.is_empty():
			continue
		candidate_blueprints[effect_id] = {
			"metadata": Dictionary(metadata_result.get("metadata", {})).duplicate(true),
			"operations": operations.duplicate(true),
		}
	if not errors.is_empty():
		return {"ok": false, "candidate": {}, "errors": errors}
	var token := RefCounted.new()
	_pending_candidates[token.get_instance_id()] = {
		"token": token,
		"blueprints": candidate_blueprints,
	}
	return {
		"ok": true,
		"candidate": {"token": token},
		"errors": [],
	}


func commit_configuration(candidate: Dictionary) -> void:
	var token_value: Variant = candidate.get("token", null)
	if not token_value is RefCounted:
		return
	var token := token_value as RefCounted
	var token_id := token.get_instance_id()
	var pending_value: Variant = _pending_candidates.get(token_id, null)
	if not pending_value is Dictionary or Dictionary(pending_value).get("token", null) != token:
		return
	_pending_candidates.erase(token_id)
	var blueprint_values: Variant = Dictionary(pending_value).get("blueprints", null)
	if not blueprint_values is Dictionary or Dictionary(blueprint_values).is_empty():
		return
	var rebuilt_effects := {}
	for effect_id_value in Dictionary(blueprint_values).keys():
		if typeof(effect_id_value) != TYPE_STRING or String(effect_id_value) == "":
			return
		var effect_id := String(effect_id_value)
		var blueprint_value: Variant = Dictionary(blueprint_values)[effect_id_value]
		if not blueprint_value is Dictionary:
			return
		var blueprint := Dictionary(blueprint_value)
		var metadata_value: Variant = blueprint.get("metadata", null)
		var operations_value: Variant = blueprint.get("operations", null)
		if not metadata_value is Dictionary or not operations_value is Array or Array(operations_value).is_empty():
			return
		rebuilt_effects[effect_id] = StrategyScript.new().configure(
			effect_id,
			Dictionary(metadata_value).duplicate(true),
			Array(operations_value).duplicate(true),
			_operation_registry
		)
	_effects = rebuilt_effects
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


func effect_for_id(effect_id: String) -> QualityEffectStrategy:
	if not _configured:
		return _empty_effect
	return _effects.get(effect_id, _empty_effect) as QualityEffectStrategy


func effect_for_unit(unit: Dictionary) -> QualityEffectStrategy:
	return effect_for_id(String(Dictionary(unit.get("quality_upgrade", {})).get("id", "")))


func registered_effect_ids() -> Array[String]:
	var result: Array[String] = []
	if not _configured:
		return result
	for effect_id in _effects.keys():
		result.append(String(effect_id))
	result.sort()
	return result


func operation_registry() -> RefCounted:
	return _operation_registry


func _normalize_operation(
	effect_id: String,
	operation_value: Variant,
	source_index: int,
	operation_index: int,
	seen_operations: Dictionary,
	errors: Array[String]
) -> Dictionary:
	if not operation_value is Dictionary:
		errors.append("Quality upgrade '%s' operation %d must be a Dictionary." % [effect_id, operation_index])
		return {}
	var operation := Dictionary(operation_value)
	for required_key in ["id", "hook", "operation", "priority", "params"]:
		if not operation.has(required_key):
			errors.append("Quality upgrade '%s' operation %d is missing '%s'." % [
				effect_id,
				operation_index,
				required_key,
			])
	var operation_id_value: Variant = operation.get("id", null)
	var operation_id := String(operation_id_value).strip_edges() if typeof(operation_id_value) == TYPE_STRING else ""
	if typeof(operation_id_value) != TYPE_STRING:
		errors.append("Quality upgrade '%s' operation %d id must be a String." % [effect_id, operation_index])
	elif operation_id == "":
		errors.append("Quality upgrade '%s' operation %d has an empty id." % [effect_id, operation_index])
	elif operation_id != String(operation_id_value):
		errors.append("Quality upgrade '%s' operation %d id must not contain surrounding whitespace." % [effect_id, operation_index])
		operation_id = ""
	elif seen_operations.has(operation_id):
		errors.append("Duplicate quality runtime operation id '%s'." % operation_id)
	else:
		seen_operations[operation_id] = true
	var hook_value: Variant = operation.get("hook", null)
	var hook := StringName(String(hook_value)) if typeof(hook_value) == TYPE_STRING else &""
	if typeof(hook_value) != TYPE_STRING:
		errors.append("Quality runtime operation '%s' hook must be a String." % operation_id)
	elif String(hook_value) != String(hook_value).strip_edges():
		errors.append("Quality runtime operation '%s' hook must not contain surrounding whitespace." % operation_id)
	elif not OperationRegistryScript.ALLOWED_HOOKS.has(hook):
		errors.append("Quality runtime operation '%s' declares unknown hook '%s'." % [operation_id, String(hook)])
	var handler_id_value: Variant = operation.get("operation", null)
	var handler_id := String(handler_id_value).strip_edges() if typeof(handler_id_value) == TYPE_STRING else ""
	if typeof(handler_id_value) != TYPE_STRING:
		errors.append("Quality runtime operation '%s' operation must be a String." % operation_id)
	elif handler_id != String(handler_id_value):
		errors.append("Quality runtime operation '%s' operation must not contain surrounding whitespace." % operation_id)
		handler_id = ""
	var handler: RefCounted = _operation_registry.handler_for(handler_id)
	if handler == null:
		errors.append("Quality runtime operation '%s' references unknown operation '%s'." % [operation_id, handler_id])
	elif not _operation_registry.supports(handler, hook):
		errors.append("Quality runtime operation '%s' handler '%s' does not support hook '%s'." % [
			operation_id,
			handler_id,
			String(hook),
		])
	var params_value: Variant = operation.get("params", null)
	var params_are_valid := params_value is Dictionary
	var normalized_params: Dictionary = {}
	if not params_value is Dictionary:
		errors.append("Quality runtime operation '%s' params must be a Dictionary." % operation_id)
	elif not _is_json_compatible(params_value):
		errors.append("Quality runtime operation '%s' params must be JSON-compatible values with string keys." % operation_id)
		params_are_valid = false
	else:
		normalized_params = Dictionary(_normalize_json_numbers(params_value))
	if params_are_valid and handler != null:
		if not handler.has_method(&"_validate_params"):
			errors.append("Quality runtime operation '%s' handler '%s' is missing _validate_params." % [
				operation_id,
				handler_id,
			])
			params_are_valid = false
		else:
			var params_for_validation := normalized_params.duplicate(true)
			if _preparing_legacy_snapshot \
				and bool(params_for_validation.get(LEGACY_TRACE_SCHEMA_PARAM, false)):
				params_for_validation.erase(LEGACY_TRACE_SCHEMA_PARAM)
			var param_validation_value: Variant = handler.call(
				&"_validate_params",
				params_for_validation
			)
			if not param_validation_value is Array:
				errors.append("Quality runtime operation '%s' handler '%s' returned an invalid parameter validation result." % [
					operation_id,
					handler_id,
				])
				params_are_valid = false
			else:
				for param_error_value in Array(param_validation_value):
					if typeof(param_error_value) != TYPE_STRING or String(param_error_value).strip_edges() == "":
						errors.append("Quality runtime operation '%s' handler '%s' returned an invalid parameter validation error." % [
							operation_id,
							handler_id,
						])
						params_are_valid = false
						continue
					errors.append("Quality runtime operation '%s' params: %s" % [
						operation_id,
						String(param_error_value),
					])
					params_are_valid = false
	if not _is_integral_number(operation.get("priority", null)):
		errors.append("Quality runtime operation '%s' priority must be an integer." % operation_id)
	if handler == null \
			or not _operation_registry.supports(handler, hook) \
			or not params_are_valid \
			or operation_id == "":
		return {}
	return {
		"id": operation_id,
		"hook": hook,
		"operation": handler_id,
		"priority": int(operation.get("priority", 0)),
		"params": normalized_params.duplicate(true),
		"source_index": source_index,
		"operation_index": operation_index,
	}


func _legacy_snapshot_upgrades(upgrades: Array, errors: Array[String]) -> Array:
	var legacy_by_id := {}
	for legacy_value in _legacy_catalog_upgrades():
		var legacy_upgrade := Dictionary(legacy_value)
		legacy_by_id[String(legacy_upgrade.get("id", ""))] = legacy_upgrade
	var result: Array = []
	for index in range(upgrades.size()):
		var upgrade_value: Variant = upgrades[index]
		if not upgrade_value is Dictionary:
			result.append(upgrade_value)
			continue
		var effect_id_value: Variant = Dictionary(upgrade_value).get("id", null)
		var effect_id := String(effect_id_value).strip_edges() if typeof(effect_id_value) == TYPE_STRING else ""
		if typeof(effect_id_value) != TYPE_STRING or effect_id == "" or effect_id != String(effect_id_value) or not legacy_by_id.has(effect_id):
			errors.append("Persisted legacy quality upgrade '%s' is not in the frozen catalog." % effect_id)
			continue
		result.append(Dictionary(legacy_by_id[effect_id]).duplicate(true))
	return result


func _legacy_catalog_upgrades() -> Array:
	var upgrades := LegacyCatalogScript.upgrades().duplicate(true)
	for upgrade_index in range(upgrades.size()):
		var upgrade := Dictionary(upgrades[upgrade_index])
		var operations := Array(upgrade.get("runtime_operations", [])).duplicate(true)
		for operation_index in range(operations.size()):
			var operation := Dictionary(operations[operation_index])
			if StringName(operation.get("hook", &"")) != &"after_attack":
				continue
			var handler := _operation_registry.handler_for(String(operation.get("operation", ""))) as RefCounted
			if not _is_trace_handler(handler):
				continue
			var params := Dictionary(operation.get("params", {})).duplicate(true)
			params[LEGACY_TRACE_SCHEMA_PARAM] = true
			operation["params"] = params
			operations[operation_index] = operation
		upgrade["runtime_operations"] = operations
		upgrades[upgrade_index] = upgrade
	return upgrades


func _is_trace_handler(handler: RefCounted) -> bool:
	if handler == null:
		return false
	for hook in [&"trace_enter", &"trace_round_start", &"trace_element_application_count"]:
		if _operation_registry.supports(handler, hook):
			return true
	return false


func _metadata_for_operations(effect_id: String, operations: Array) -> Dictionary:
	var metadata := {}
	var errors: Array[String] = []
	for operation_value in operations:
		var operation := Dictionary(operation_value)
		var handler: RefCounted = _operation_registry.handler_for(String(operation.get("operation", "")))
		if not _operation_registry.supports(handler, &"profile"):
			continue
		var profile_value: Variant = handler.call(&"profile", Dictionary(operation.get("params", {})).duplicate(true))
		if not profile_value is Dictionary or not _is_json_compatible(profile_value):
			errors.append("Quality runtime operation '%s' for '%s' returned an invalid profile." % [
				String(operation.get("id", "")),
				effect_id,
			])
			continue
		_merge_profile(metadata, Dictionary(profile_value))
	return {"metadata": metadata, "errors": errors}


func _merge_profile(metadata: Dictionary, profile: Dictionary) -> void:
	for key_value in profile.keys():
		var key := String(key_value)
		var value: Variant = profile[key_value]
		if value is Array and metadata.get(key, null) is Array:
			var merged := Array(metadata.get(key, [])).duplicate(true)
			merged.append_array(Array(value).duplicate(true))
			metadata[key] = merged
		else:
			metadata[key] = value.duplicate(true) if value is Array or value is Dictionary else value


func _operation_precedes(left_value: Variant, right_value: Variant) -> bool:
	var left := Dictionary(left_value)
	var right := Dictionary(right_value)
	for key in ["priority", "source_index", "operation_index"]:
		var left_number := int(left.get(key, 0))
		var right_number := int(right.get(key, 0))
		if left_number != right_number:
			return left_number < right_number
	return String(left.get("id", "")) < String(right.get("id", ""))


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


func _is_integral_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value))


func _normalize_json_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value)):
		return int(value)
	if value is Array:
		var normalized_array: Array = []
		for item in Array(value):
			normalized_array.append(_normalize_json_numbers(item))
		return normalized_array
	if value is Dictionary:
		var normalized_dictionary := {}
		for key_value in Dictionary(value).keys():
			normalized_dictionary[key_value] = _normalize_json_numbers(Dictionary(value)[key_value])
		return normalized_dictionary
	return value
