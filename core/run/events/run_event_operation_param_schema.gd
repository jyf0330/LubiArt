extends RefCounted

## Shared, deterministic parameter validation for repository-owned run-event
## operations. Context selection is validated by RunEventEffectService, not by
## individual handlers.


static func validate_empty(params: Dictionary) -> Array[String]:
	return _validate(params, {})


static func validate_nonnegative_amount(params: Dictionary) -> Array[String]:
	return _validate(params, {
		"amount": {"type": TYPE_INT, "minimum": 0},
	})


static func validate_positive_amount(params: Dictionary) -> Array[String]:
	return _validate(params, {
		"amount": {"type": TYPE_INT, "minimum": 1},
	})


static func validate_reward_multiplier(params: Dictionary) -> Array[String]:
	return _validate(params, {
		"percent": {"type": TYPE_INT, "minimum": 0, "maximum": 99},
	})


static func validate_discount(params: Dictionary) -> Array[String]:
	return _validate(params, {
		"percent": {"type": TYPE_INT, "minimum": 1, "maximum": 100},
	})


static func validate_refill_shop_pool(params: Dictionary) -> Array[String]:
	return _validate(params, {
		"pool_id": {"type": TYPE_STRING, "nonempty": true},
		"minimum_slots": {"type": TYPE_INT, "minimum": 3, "maximum": 10},
	})


static func validate_reward_pool(params: Dictionary) -> Array[String]:
	return _validate(params, {
		"pool_id": {"type": TYPE_STRING, "nonempty": true},
	})


static func _validate(params: Dictionary, required: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var string_keys: Array[String] = []
	var invalid_keys: Array[String] = []
	for key_value in params.keys():
		if typeof(key_value) != TYPE_STRING:
			invalid_keys.append(str(key_value))
			continue
		string_keys.append(String(key_value))
	invalid_keys.sort()
	for invalid_key in invalid_keys:
		errors.append("parameter key '%s' must be a String." % invalid_key)
	string_keys.sort()
	for key in string_keys:
		if key.begins_with("__"):
			errors.append("reserved parameter '%s' is not allowed." % key)
		elif not required.has(key):
			errors.append("unknown parameter '%s'." % key)
	var required_keys: Array[String] = []
	for key_value in required.keys():
		required_keys.append(String(key_value))
	required_keys.sort()
	for key in required_keys:
		if not params.has(key):
			errors.append("missing required parameter '%s'." % key)
			continue
		_validate_value(key, params[key], Dictionary(required[key]), errors)
	return errors


static func _validate_value(
	key: String,
	value: Variant,
	rule: Dictionary,
	errors: Array[String]
) -> void:
	var expected_type := int(rule.get("type", TYPE_NIL))
	if typeof(value) != expected_type:
		errors.append("parameter '%s' must be %s." % [key, _type_label(expected_type)])
		return
	if expected_type == TYPE_STRING:
		if bool(rule.get("nonempty", false)) and String(value).strip_edges() == "":
			errors.append("parameter '%s' must be a non-empty String." % key)
		return
	if expected_type != TYPE_INT:
		return
	var integer_value := int(value)
	if rule.has("minimum") and integer_value < int(rule["minimum"]):
		errors.append("parameter '%s' must be at least %d." % [key, int(rule["minimum"])])
	if rule.has("maximum") and integer_value > int(rule["maximum"]):
		errors.append("parameter '%s' must be at most %d." % [key, int(rule["maximum"])])


static func _type_label(type_code: int) -> String:
	match type_code:
		TYPE_INT:
			return "an integer"
		TYPE_STRING:
			return "a String"
		_:
			return type_string(type_code)
