extends RefCounted
class_name QualityEffectStrategy

const BoardTraceScript := preload("res://core/battle/quality/quality_board_trace.gd")
const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")
const ShapeMutatorScript := preload("res://core/battle/quality/quality_shape_mutator.gd")

var effect_id := ""
var mode_options: Array[String] = []
var mode_aliases: Dictionary = {}
var supports_mark := false
var actor_order := 0
var changes_shape_name := false
var damage_rules: Array = []
var preview_damage := false
var element_apply_bonus := 0
var doubles_matching_element := false
var before_attack_rules: Array = []
var after_attack_rules: Array = []
var after_hit_rules: Array = []
var immediate_element_burst := false
var shape_mutation := ""
var target_order := "shape"
var narrow_to_target_mode := ""
var board_trace: Dictionary = {}

var _operations: Array = []
var _operation_registry: RefCounted


func configure(
	id: String,
	metadata: Dictionary = {},
	operations: Array = [],
	operation_registry: RefCounted = null
) -> QualityEffectStrategy:
	effect_id = id
	mode_options.clear()
	for option in Array(metadata.get("mode_options", [])):
		mode_options.append(String(option))
	mode_aliases = Dictionary(metadata.get("mode_aliases", {})).duplicate(true)
	supports_mark = bool(metadata.get("supports_mark", false))
	actor_order = int(metadata.get("actor_order", 0))
	changes_shape_name = bool(metadata.get("changes_shape_name", false))
	damage_rules = Array(metadata.get("damage_rules", [])).duplicate(true)
	preview_damage = bool(metadata.get("preview_damage", false))
	element_apply_bonus = int(metadata.get("element_apply_bonus", 0))
	doubles_matching_element = bool(metadata.get("doubles_matching_element", false))
	before_attack_rules = Array(metadata.get("before_attack_rules", [])).duplicate(true)
	after_attack_rules = Array(metadata.get("after_attack_rules", [])).duplicate(true)
	after_hit_rules = Array(metadata.get("after_hit_rules", [])).duplicate(true)
	immediate_element_burst = bool(metadata.get("immediate_element_burst", false))
	shape_mutation = String(metadata.get("shape_mutation", ""))
	target_order = String(metadata.get("target_order", "shape"))
	narrow_to_target_mode = String(metadata.get("narrow_to_target_mode", ""))
	board_trace = Dictionary(metadata.get("board_trace", {})).duplicate(true)
	if not board_trace.is_empty():
		board_trace["id"] = effect_id
	_operations = operations.duplicate(true)
	_operation_registry = operation_registry
	return self


func normalize_mode(raw_mode: String) -> String:
	var text := raw_mode.strip_edges()
	for option in mode_options:
		if text == option:
			return option
		for alias in Array(mode_aliases.get(option, [])):
			if text == String(alias):
				return option
	return ""


func default_mode() -> String:
	return mode_options[0] if not mode_options.is_empty() else ""


func on_round_start(context: QualityEffectContext, unit: Dictionary) -> Array:
	var logs: Array = []
	for operation_value in _operations_for(&"round_start"):
		var operation := Dictionary(operation_value)
		var handler := _handler_for(operation, &"round_start")
		if handler == null:
			continue
		_append_logs(logs, handler.call(
			&"round_start",
			context,
			unit,
			_params(operation)
		))
	return logs


func element_application_count(context: QualityEffectContext, cell: Dictionary) -> int:
	var current := 1
	for operation_value in _operations_for(&"element_application_count"):
		var operation := Dictionary(operation_value)
		var handler := _handler_for(operation, &"element_application_count")
		if handler == null:
			continue
		current = int(handler.call(
			&"element_application_count",
			context,
			cell,
			current,
			_params(operation)
		))
	current += BoardTraceScript.element_apply_bonus(
		context.board_traces_at(int(cell.get("x", -1)), int(cell.get("y", -1))),
		_operation_registry
	)
	return max(1, current)


func element_layers(attacker: Dictionary, slot_element: String, base_layers: int) -> int:
	var current: int = max(1, base_layers)
	for operation_value in _operations_for(&"element_layers"):
		var operation := Dictionary(operation_value)
		var handler := _handler_for(operation, &"element_layers")
		if handler == null:
			continue
		current = int(handler.call(
			&"element_layers",
			attacker,
			slot_element,
			current,
			_params(operation)
		))
	return max(1, current)


func on_before_attack(
	context: QualityEffectContext,
	attacker: Dictionary,
	option: Dictionary
) -> Array:
	var runtime := Dictionary(attacker.get("quality_runtime", {}))
	runtime["lastChainDamage"] = 0
	attacker["quality_runtime"] = runtime
	var logs: Array = []
	for operation_value in _operations_for(&"before_attack"):
		var operation := Dictionary(operation_value)
		var handler := _handler_for(operation, &"before_attack")
		if handler == null:
			continue
		_append_logs(logs, handler.call(
			&"before_attack",
			context,
			attacker,
			option,
			_params(operation)
		))
	return logs


func modify_hit_damage(hit_context: Dictionary) -> int:
	var current: int = max(0, int(hit_context.get("damage", 0)))
	if bool(hit_context.get("preview", false)) and not preview_damage:
		return current
	for operation_value in _operations_for(&"modify_hit_damage"):
		var operation := Dictionary(operation_value)
		var handler := _handler_for(operation, &"modify_hit_damage")
		if handler == null:
			continue
		current = int(handler.call(
			&"modify_hit_damage",
			hit_context,
			current,
			_params(operation)
		))
	return max(0, current)


func on_before_hit(
	context: QualityEffectContext,
	attacker: Dictionary,
	target: Dictionary,
	slot_element: String
) -> Array:
	var logs: Array = []
	for operation_value in _operations_for(&"before_hit"):
		var operation := Dictionary(operation_value)
		var handler := _handler_for(operation, &"before_hit")
		if handler == null:
			continue
		_append_logs(logs, handler.call(
			&"before_hit",
			context,
			attacker,
			target,
			slot_element,
			_params(operation)
		))
	return logs


func on_after_hit(
	context: QualityEffectContext,
	attacker: Dictionary,
	target: Dictionary
) -> Array:
	var logs: Array = []
	for operation_value in _operations_for(&"after_hit"):
		var operation := Dictionary(operation_value)
		var handler := _handler_for(operation, &"after_hit")
		if handler == null:
			continue
		_append_logs(logs, handler.call(
			&"after_hit",
			context,
			attacker,
			target,
			_params(operation)
		))
	return logs


func on_after_attack(
	context: QualityEffectContext,
	attacker: Dictionary,
	option: Dictionary,
	targets: Array
) -> Array:
	var logs: Array = []
	for operation_value in _operations_for(&"after_attack"):
		var operation := Dictionary(operation_value)
		var handler := _handler_for(operation, &"after_attack")
		if handler == null:
			continue
		_append_logs(logs, handler.call(
			&"after_attack",
			context,
			attacker,
			option,
			targets,
			_params(operation)
		))
	return logs


func mutate_shape(
	unit: Dictionary,
	direction: String,
	cells: Array,
	width: int,
	height: int
) -> Array:
	var current := cells.duplicate(true)
	for operation_value in _operations_for(&"mutate_shape"):
		var operation := Dictionary(operation_value)
		current = ShapeMutatorScript.apply(
			String(operation.get("operation", "")),
			effect_id,
			unit,
			direction,
			current,
			width,
			height,
			_operation_registry,
			_params(operation)
		)
	return current


func attack_option_for_target(
	attacker: Dictionary,
	target: Dictionary,
	option: Dictionary
) -> Dictionary:
	var current := option
	for operation_value in _operations_for(&"attack_option_for_target"):
		var operation := Dictionary(operation_value)
		var handler := _handler_for(operation, &"attack_option_for_target")
		if handler == null:
			continue
		var result: Variant = handler.call(
			&"attack_option_for_target",
			attacker,
			target,
			current,
			_params(operation)
		)
		if result is Dictionary:
			current = Dictionary(result)
	return current


func sort_targets(targets: Array, option: Dictionary) -> void:
	var current := targets.duplicate()
	var typed_sort := false
	for operation_value in _operations_for(&"sort_targets"):
		var operation := Dictionary(operation_value)
		var handler := _handler_for(operation, &"sort_targets")
		if handler == null:
			continue
		var result: Variant = handler.call(&"sort_targets", current, option, _params(operation))
		if result is Array:
			current = Array(result)
			typed_sort = true
	if not typed_sort:
		current.sort_custom(func(a, b):
			var left := Dictionary(a)
			var right := Dictionary(b)
			var left_index := ShapeGeometryScript.option_cell_index(option, left)
			var right_index := ShapeGeometryScript.option_cell_index(option, right)
			if left_index != right_index:
				return left_index < right_index
			return String(left.get("id", "")) < String(right.get("id", ""))
		)
	targets.clear()
	targets.append_array(current)


func runtime_operations() -> Array:
	return _operations.duplicate(true)


func _operations_for(hook: StringName) -> Array:
	var result: Array = []
	for operation_value in _operations:
		var operation := Dictionary(operation_value)
		if StringName(operation.get("hook", "")) == hook:
			result.append(operation)
	return result


func _handler_for(operation: Dictionary, hook: StringName) -> RefCounted:
	if _operation_registry == null \
			or not _operation_registry.has_method(&"handler_for") \
			or not _operation_registry.has_method(&"supports") \
			or not bool(_operation_registry.call(&"is_valid")):
		return null
	var handler := _operation_registry.call(
		&"handler_for",
		String(operation.get("operation", ""))
	) as RefCounted
	if handler == null or not bool(_operation_registry.call(&"supports", handler, hook)):
		return null
	return handler


func _params(operation: Dictionary) -> Dictionary:
	return Dictionary(operation.get("params", {})).duplicate(true)


func _append_logs(logs: Array, value: Variant) -> void:
	if not value is Array:
		return
	for line_value in Array(value):
		logs.append(String(line_value))
