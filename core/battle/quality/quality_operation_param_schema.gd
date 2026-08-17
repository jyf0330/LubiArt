extends RefCounted

const CONDITION_FACT_TYPES := {
	"damage": TYPE_INT,
	"mode": TYPE_STRING,
	"mode_is_guard": TYPE_BOOL,
	"mode_is_stable": TYPE_BOOL,
	"mode_is_same": TYPE_BOOL,
	"hit_index": TYPE_INT,
	"first_hit": TYPE_BOOL,
	"last_hit": TYPE_BOOL,
	"target_count": TYPE_INT,
	"cell_index": TYPE_INT,
	"core_cell": TYPE_BOOL,
	"farthest_cell": TYPE_BOOL,
	"first_cell": TYPE_BOOL,
	"farthest_positive": TYPE_BOOL,
	"distance": TYPE_INT,
	"target_hp": TYPE_INT,
	"off_axis": TYPE_BOOL,
	"has_mark": TYPE_BOOL,
	"marked_match": TYPE_BOOL,
	"core_or_single": TYPE_BOOL,
	"core_or_first": TYPE_BOOL,
	"g28_active": TYPE_BOOL,
	"first_target_exists": TYPE_BOOL,
}


static func validate(
	params: Dictionary,
	required: Dictionary = {},
	optional: Dictionary = {},
	require_any: bool = false
) -> Array[String]:
	var errors: Array[String] = []
	var allowed := required.duplicate()
	for key_value in optional.keys():
		allowed[String(key_value)] = optional[key_value]
	var provided_keys: Array[String] = []
	for key_value in params.keys():
		provided_keys.append(String(key_value))
	provided_keys.sort()
	for key in provided_keys:
		if not allowed.has(key):
			errors.append("unknown parameter '%s'." % key)
	var required_keys: Array[String] = []
	for key_value in required.keys():
		required_keys.append(String(key_value))
	required_keys.sort()
	for key in required_keys:
		if not params.has(key):
			errors.append("missing required parameter '%s'." % key)
	var allowed_keys: Array[String] = []
	for key_value in allowed.keys():
		allowed_keys.append(String(key_value))
	allowed_keys.sort()
	for key in allowed_keys:
		if not params.has(key):
			continue
		_validate_value(key, params[key], String(allowed[key]), errors)
	if require_any and params.is_empty():
		errors.append("at least one parameter is required.")
	return errors


static func validate_mode_profile(params: Dictionary) -> Array[String]:
	var errors := validate(
		params,
		{"options": "nonempty_string_array"},
		{"aliases": "string_array_map"}
	)
	if not errors.is_empty():
		return errors
	var options := Array(params.get("options", []))
	var aliases := Dictionary(params.get("aliases", {}))
	for alias_key_value in aliases.keys():
		var alias_key := String(alias_key_value)
		if not options.has(alias_key):
			errors.append("alias key '%s' must name one declared option." % alias_key)
	return errors


static func validate_trace(params: Dictionary, behavior_schema: Dictionary = {}) -> Array[String]:
	var optional := {
		"duration": "positive_int",
		"persistent": "bool",
	}
	for key_value in behavior_schema.keys():
		optional[String(key_value)] = behavior_schema[key_value]
	return validate(params, {}, optional)


static func _validate_value(
	key: String,
	value: Variant,
	descriptor: String,
	errors: Array[String]
) -> void:
	match descriptor:
		"bool":
			if typeof(value) != TYPE_BOOL:
				errors.append("parameter '%s' must be a boolean." % key)
		"int":
			if typeof(value) != TYPE_INT:
				errors.append("parameter '%s' must be an integer." % key)
		"positive_int":
			if typeof(value) != TYPE_INT or int(value) <= 0:
				errors.append("parameter '%s' must be a positive integer." % key)
		"nonnegative_int":
			if typeof(value) != TYPE_INT or int(value) < 0:
				errors.append("parameter '%s' must be a non-negative integer." % key)
		"nonzero_int":
			if typeof(value) != TYPE_INT or int(value) == 0:
				errors.append("parameter '%s' must be a non-zero integer." % key)
		"nonempty_string":
			if typeof(value) != TYPE_STRING or String(value).strip_edges() == "":
				errors.append("parameter '%s' must be a non-empty string." % key)
		"dictionary":
			if typeof(value) != TYPE_DICTIONARY:
				errors.append("parameter '%s' must be a Dictionary." % key)
		"condition_map":
			_validate_condition_map(key, value, errors)
		"nonempty_string_array":
			_validate_string_array(key, value, true, errors)
		"string_array_map":
			_validate_string_array_map(key, value, errors)
		_:
			errors.append("parameter '%s' has unknown schema descriptor '%s'." % [key, descriptor])


static func _validate_condition_map(key: String, value: Variant, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("parameter '%s' must be a condition Dictionary." % key)
		return
	var condition_keys: Array[String] = []
	for condition_key_value in Dictionary(value).keys():
		if typeof(condition_key_value) != TYPE_STRING:
			errors.append("parameter '%s' condition keys must be strings." % key)
			continue
		condition_keys.append(String(condition_key_value))
	condition_keys.sort()
	for condition_key in condition_keys:
		var fact_key := condition_key
		var is_range_condition := false
		if condition_key.ends_with("_min"):
			fact_key = condition_key.trim_suffix("_min")
			is_range_condition = true
		elif condition_key.ends_with("_max"):
			fact_key = condition_key.trim_suffix("_max")
			is_range_condition = true
		if not CONDITION_FACT_TYPES.has(fact_key):
			errors.append("parameter '%s' condition '%s' references unknown fact '%s'." % [
				key,
				condition_key,
				fact_key,
			])
			continue
		var fact_type := int(CONDITION_FACT_TYPES[fact_key])
		if is_range_condition and fact_type != TYPE_INT:
			errors.append("parameter '%s' condition '%s' may use _min/_max only with an integer fact." % [
				key,
				condition_key,
			])
			continue
		var condition_value: Variant = Dictionary(value)[condition_key]
		if typeof(condition_value) != fact_type:
			errors.append("parameter '%s' condition '%s' must match fact '%s' type %s." % [
				key,
				condition_key,
				fact_key,
				type_string(fact_type),
			])


static func _validate_string_array(
	key: String,
	value: Variant,
	require_nonempty: bool,
	errors: Array[String]
) -> void:
	if typeof(value) != TYPE_ARRAY:
		errors.append("parameter '%s' must be an Array of non-empty strings." % key)
		return
	var seen := {}
	if require_nonempty and Array(value).is_empty():
		errors.append("parameter '%s' must not be empty." % key)
	for item_value in Array(value):
		if typeof(item_value) != TYPE_STRING or String(item_value).strip_edges() == "":
			errors.append("parameter '%s' must contain only non-empty strings." % key)
			continue
		var item := String(item_value)
		if seen.has(item):
			errors.append("parameter '%s' contains duplicate value '%s'." % [key, item])
		else:
			seen[item] = true


static func _validate_string_array_map(key: String, value: Variant, errors: Array[String]) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("parameter '%s' must map strings to string Arrays." % key)
		return
	var map_keys: Array[String] = []
	for map_key_value in Dictionary(value).keys():
		map_keys.append(String(map_key_value))
	map_keys.sort()
	for map_key in map_keys:
		if map_key.strip_edges() == "":
			errors.append("parameter '%s' contains an empty map key." % key)
		_validate_string_array("%s.%s" % [key, map_key], Dictionary(value)[map_key], false, errors)
