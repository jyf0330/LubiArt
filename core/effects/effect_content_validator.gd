extends RefCounted

## Validates the assembled content graph, after cross-package references are
## available but before GameDataRepository caches or returns gameplay data.

const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")
const EffectInterpreterScript := preload("res://core/effects/effect_interpreter.gd")
const ConditionEvaluatorScript := preload("res://core/effects/condition_evaluator.gd")
const EffectTargetResolverScript := preload("res://core/effects/effect_target_resolver.gd")
const StatResolverScript := preload("res://core/stats/stat_resolver.gd")

var _effect_interpreter: RefCounted = EffectInterpreterScript.new()
var _condition_evaluator: RefCounted = ConditionEvaluatorScript.new()
var _target_resolver: RefCounted = EffectTargetResolverScript.new()
var _stat_resolver: RefCounted = StatResolverScript.new()


func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var stat_catalog := Dictionary(data.get("stat_catalog", {}))
	var status_catalog := Dictionary(data.get("status_catalog", {}))
	_validate_stat_catalog(stat_catalog, errors)
	_append_registry_errors(_effect_interpreter, "EFFECT", errors)
	_append_registry_errors(_condition_evaluator, "CONDITION", errors)
	_append_registry_errors(_target_resolver, "TARGET", errors)
	_append_registry_errors(_stat_resolver, "STAT_OPERATION", errors)
	if not errors.is_empty():
		return errors
	_walk(data, "$", stat_catalog, status_catalog, errors, "")
	return errors


func _append_registry_errors(registry_owner: RefCounted, label: String, errors: Array[String]) -> void:
	if bool(registry_owner.call(&"is_valid")):
		return
	for value in Array(registry_owner.call(&"validation_errors")):
		errors.append("INVALID_%s_REGISTRY:%s" % [label, String(value)])


func _validate_stat_catalog(catalog: Dictionary, errors: Array[String]) -> void:
	var ids: Array[String] = []
	for value in catalog.keys():
		ids.append(String(value))
	ids.sort()
	for stat_id in ids:
		if not StatIdsScript.ALL.has(stat_id):
			errors.append("UNKNOWN_STAT_DEFINITION:$.stat_catalog.%s" % stat_id)


func _walk(
	value: Variant,
	path: String,
	stat_catalog: Dictionary,
	status_catalog: Dictionary,
	errors: Array[String],
	owner_scope: String
) -> void:
	if value is Dictionary:
		var record := Dictionary(value)
		if record.has("effects"):
			_validate_effects(record.get("effects"), "%s.effects" % path, stat_catalog, status_catalog, errors, owner_scope)
		var keys: Array[String] = []
		for key_value in record.keys():
			keys.append(String(key_value))
		keys.sort()
		for key in keys:
			if key == "effects":
				continue
			var child_owner := owner_scope
			if path == "$":
				child_owner = key
			elif owner_scope == EffectVocabularyScript.OWNER_ECONOMY and key == "relics":
				child_owner = EffectVocabularyScript.OWNER_RELIC_CATALOG
			_walk(record.get(key), "%s.%s" % [path, key], stat_catalog, status_catalog, errors, child_owner)
	elif value is Array:
		var values := Array(value)
		for index in range(values.size()):
			_walk(values[index], "%s[%d]" % [path, index], stat_catalog, status_catalog, errors, owner_scope)


func _validate_effects(
	value: Variant,
	path: String,
	stat_catalog: Dictionary,
	status_catalog: Dictionary,
	errors: Array[String],
	owner_scope: String
) -> void:
	if not (value is Array):
		errors.append("INVALID_EFFECTS_ARRAY:%s" % path)
		return
	var effects := Array(value)
	for index in range(effects.size()):
		var effect_path := "%s[%d]" % [path, index]
		if not (effects[index] is Dictionary):
			errors.append("INVALID_EFFECT:%s" % effect_path)
			continue
		_validate_effect(Dictionary(effects[index]), effect_path, stat_catalog, status_catalog, errors, owner_scope)


func _validate_effect(
	effect: Dictionary,
	path: String,
	stat_catalog: Dictionary,
	status_catalog: Dictionary,
	errors: Array[String],
	owner_scope: String
) -> void:
	var normalized_effect := EffectVocabularyScript.normalize_for_owner(effect, owner_scope)
	var effect_type := EffectVocabularyScript.effect_type(normalized_effect)
	if effect_type == "":
		errors.append("EFFECT_TYPE_REQUIRED:%s" % path)
	elif not _effect_interpreter.supported_types().has(effect_type):
		errors.append("UNKNOWN_EFFECT_TYPE:%s:%s" % [path, effect_type])

	_validate_effect_hook(normalized_effect, effect_type, path, owner_scope, errors)

	if normalized_effect.has(EffectVocabularyScript.FIELD_TARGET):
		var target_id := EffectVocabularyScript.text(normalized_effect, EffectVocabularyScript.FIELD_TARGET)
		if not _target_resolver.supported_types().has(target_id):
			errors.append("UNKNOWN_EFFECT_TARGET:%s:%s" % [path, target_id])

	if effect_type == EffectVocabularyScript.TYPE_MODIFY_STAT \
			or normalized_effect.has(EffectVocabularyScript.FIELD_STAT) \
			or normalized_effect.has(EffectVocabularyScript.FIELD_STAT_ID):
		_validate_effect_stat(normalized_effect, path, stat_catalog, errors)

	if effect_type == EffectVocabularyScript.TYPE_MODIFY_STAT \
			or normalized_effect.has(EffectVocabularyScript.FIELD_OPERATION):
		_validate_effect_operation(normalized_effect, path, errors, owner_scope)

	if normalized_effect.has(EffectVocabularyScript.FIELD_STATUS_ID):
		var status_id := EffectVocabularyScript.status_id(normalized_effect)
		if status_id == "":
			errors.append("EFFECT_STATUS_REQUIRED:%s" % path)
		elif not status_catalog.has(status_id):
			errors.append("UNKNOWN_EFFECT_STATUS:%s:%s" % [path, status_id])
	elif effect_type == EffectVocabularyScript.TYPE_APPLY_STATUS \
			or effect_type == EffectVocabularyScript.TYPE_REMOVE_STATUS:
		errors.append("EFFECT_STATUS_REQUIRED:%s" % path)

	if normalized_effect.has(EffectVocabularyScript.FIELD_CONDITION):
		var condition_value: Variant = normalized_effect.get(EffectVocabularyScript.FIELD_CONDITION)
		if not (condition_value is Dictionary):
			errors.append("INVALID_EFFECT_CONDITION:%s.condition" % path)
		else:
			_validate_condition(Dictionary(condition_value), "%s.condition" % path, stat_catalog, errors)


func _validate_effect_hook(
	effect: Dictionary,
	effect_type: String,
	path: String,
	owner_scope: String,
	errors: Array[String]
) -> void:
	var has_hook := effect.has(EffectVocabularyScript.FIELD_HOOK)
	if effect_type == EffectVocabularyScript.TYPE_MODIFY_STAT:
		if not has_hook:
			return
		var modifier_hook := EffectVocabularyScript.text(effect, EffectVocabularyScript.FIELD_HOOK)
		if not EffectHookIdsScript.MODIFIER_HOOKS.has(modifier_hook):
			errors.append("UNKNOWN_EFFECT_HOOK:%s:%s" % [path, modifier_hook])
		return
	if EffectVocabularyScript.HOOK_COLLECTION_OWNERS.has(owner_scope):
		if not has_hook:
			errors.append("EFFECT_HOOK_REQUIRED:%s" % path)
			return
		var trigger_hook := EffectVocabularyScript.text(effect, EffectVocabularyScript.FIELD_HOOK)
		if not EffectHookIdsScript.TRIGGER_HOOKS.has(trigger_hook):
			errors.append("UNKNOWN_EFFECT_HOOK:%s:%s" % [path, trigger_hook])
		return
	if has_hook:
		var ignored_hook := EffectVocabularyScript.text(effect, EffectVocabularyScript.FIELD_HOOK)
		errors.append("INVALID_EFFECT_HOOK_OWNER:%s:%s:%s" % [path, owner_scope, ignored_hook])


func _validate_effect_stat(effect: Dictionary, path: String, stat_catalog: Dictionary, errors: Array[String]) -> void:
	var stat_id := EffectVocabularyScript.stat_id(effect)
	if stat_id == "":
		errors.append("EFFECT_STAT_REQUIRED:%s" % path)
		return
	if not StatIdsScript.ALL.has(stat_id):
		errors.append("UNKNOWN_EFFECT_STAT_ID:%s:%s" % [path, stat_id])
		return
	if not stat_catalog.has(stat_id):
		errors.append("MISSING_EFFECT_STAT_DEFINITION:%s:%s" % [path, stat_id])


func _validate_effect_operation(effect: Dictionary, path: String, errors: Array[String], owner_scope: String) -> void:
	var operation_id := EffectVocabularyScript.operation_id(effect)
	if effect.has(EffectVocabularyScript.FIELD_OPERATION):
		operation_id = EffectVocabularyScript.text(effect, EffectVocabularyScript.FIELD_OPERATION)
		if operation_id == "":
			errors.append("EFFECT_OPERATION_REQUIRED:%s" % path)
			return
	var supported: Array[String] = _stat_resolver.supported_operations()
	if supported.has(operation_id):
		return
	if StatOperationIdsScript.CONTENT_ADAPTERS.has(operation_id):
		if operation_id == StatOperationIdsScript.FLAT_ADD_PER_STACK \
				and owner_scope == EffectVocabularyScript.OWNER_STATUS_CATALOG:
			return
		errors.append("INVALID_EFFECT_OPERATION_SCOPE:%s:%s" % [path, operation_id])
		return
	errors.append("UNKNOWN_EFFECT_OPERATION:%s:%s" % [path, operation_id])


func _validate_condition(
	condition: Dictionary,
	path: String,
	stat_catalog: Dictionary,
	errors: Array[String]
) -> void:
	if condition.is_empty():
		return
	var condition_type := EffectVocabularyScript.condition_type(condition)
	if condition.has(EffectVocabularyScript.FIELD_TYPE) \
			and EffectVocabularyScript.text(condition, EffectVocabularyScript.FIELD_TYPE) == "":
		errors.append("CONDITION_TYPE_REQUIRED:%s" % path)
		return
	if not _condition_evaluator.supported_types().has(condition_type):
		errors.append("UNKNOWN_CONDITION_TYPE:%s:%s" % [path, condition_type])
		return
	for schema_error in _condition_evaluator.content_schema_errors(condition):
		errors.append("%s:%s" % [schema_error, path])
	if condition.has(EffectVocabularyScript.FIELD_STAT) or condition.has(EffectVocabularyScript.FIELD_STAT_ID):
		_validate_condition_stat(condition, path, stat_catalog, errors)
	match condition_type:
		EffectVocabularyScript.CONDITION_ALL, EffectVocabularyScript.CONDITION_ANY:
			var children: Variant = condition.get(EffectVocabularyScript.FIELD_CONDITIONS, [])
			if not (children is Array):
				errors.append("INVALID_CONDITION_CHILDREN:%s" % path)
				return
			for index in range(Array(children).size()):
				var child: Variant = Array(children)[index]
				var child_path := "%s.conditions[%d]" % [path, index]
				if child is Dictionary:
					_validate_condition(Dictionary(child), child_path, stat_catalog, errors)
				else:
					errors.append("INVALID_CONDITION:%s" % child_path)
		EffectVocabularyScript.CONDITION_NOT:
			var child: Variant = condition.get(EffectVocabularyScript.FIELD_CONDITION, {})
			if child is Dictionary:
				_validate_condition(Dictionary(child), "%s.condition" % path, stat_catalog, errors)
			else:
				errors.append("INVALID_CONDITION:%s.condition" % path)


func _validate_condition_stat(
	condition: Dictionary,
	path: String,
	stat_catalog: Dictionary,
	errors: Array[String]
) -> void:
	var stat_id := EffectVocabularyScript.stat_id(condition)
	if stat_id == "":
		errors.append("CONDITION_STAT_REQUIRED:%s" % path)
		return
	if not StatIdsScript.ALL.has(stat_id):
		errors.append("UNKNOWN_CONDITION_STAT_ID:%s:%s" % [path, stat_id])
		return
	if not stat_catalog.has(stat_id):
		errors.append("MISSING_CONDITION_STAT_DEFINITION:%s:%s" % [path, stat_id])
