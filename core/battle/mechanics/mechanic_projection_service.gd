extends RefCounted

const ElementBurstPolicyScript := preload("res://core/battle/elements/element_burst_policy.gd")
const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")

const ELEMENT_HOOK := &"project_element_settlement"
const TRAP_HOOK := &"project_trap_entry"
const THREAT_HOOK := &"project_threat_redirect"
const DEATH_HOOK := &"project_death_preview"
const ELEMENT_CONTRIBUTION_KEYS := ["exclusive_key", "damage_add", "source", "target_pattern"]
const TRAP_RESULT_KEYS := ["allow"]
const THREAT_RESULT_KEYS := ["range", "mechanic_id", "mechanic_name"]
const DEATH_RESULT_KEYS := ["radius", "metric", "damage"]
const THREAT_FACT_KEYS := ["enemy"]
const DEATH_FACT_KEYS := ["projected_dead"]
const TARGET_PATTERNS := ["", "single", "cross"]

var _handler_registry: RefCounted


func configure(registry: RefCounted) -> RefCounted:
	_handler_registry = registry
	return self


func element_settlement_plan(
	units: Array,
	mechanisms: Array,
	elements: Dictionary,
	element: String
) -> Dictionary:
	if not _registry_valid():
		return {"ok": false}
	var mechanism_index := _mechanism_index(mechanisms)
	if not bool(mechanism_index.get("ok", false)) or not _units_are_dictionaries(units):
		return {"ok": false}
	var layers: int = max(0, int(elements.get(element, 0)))
	var base_damage: int = ElementBurstPolicyScript.damage(layers)
	var facts := {
		"element": element,
		"layers": layers,
		"active_element_type_count": _active_element_type_count(elements),
		"base_damage": base_damage,
	}
	var contributions: Array = []
	var exclusive_keys := {}
	var damage_add := 0
	var first_add_source: Dictionary = {}
	var first_pattern_source: Dictionary = {}
	var target_pattern := ""
	for unit_value in units:
		var unit := Dictionary(unit_value)
		if int(unit.get("hp", 0)) <= 0:
			continue
		for mechanism_id_value in _unit_mechanic_ids(unit):
			var mechanism_id := String(mechanism_id_value)
			var resolved := _resolve_projection_handler(
				mechanism_id,
				Dictionary(mechanism_index.get("by_id", {})),
				ELEMENT_HOOK
			)
			if not bool(resolved.get("ok", false)):
				return {"ok": false}
			if not bool(resolved.get("supported", false)):
				continue
			var projected := _call_pure_hook(
				resolved.get("handler") as RefCounted,
				ELEMENT_HOOK,
				unit,
				Dictionary(resolved.get("mechanism", {})),
				facts
			)
			if not bool(projected.get("ok", false)):
				return {"ok": false}
			var contribution := Dictionary(projected.get("value", {}))
			if contribution.is_empty():
				continue
			if not _valid_element_contribution(contribution):
				return {"ok": false}
			var exclusive_key := String(contribution.get("exclusive_key", ""))
			if exclusive_key != "" and exclusive_keys.has(exclusive_key):
				continue
			if exclusive_key != "":
				exclusive_keys[exclusive_key] = true
			var accepted := contribution.duplicate(true)
			contributions.append(accepted)
			var accepted_damage_add := int(accepted.get("damage_add", 0))
			damage_add += accepted_damage_add
			var accepted_source := Dictionary(accepted.get("source", {}))
			var accepted_pattern := String(accepted.get("target_pattern", ""))
			if accepted_pattern != "" and target_pattern == "":
				target_pattern = accepted_pattern
				first_pattern_source = accepted_source.duplicate(true)
			if first_add_source.is_empty() and not accepted_source.is_empty():
				first_add_source = accepted_source.duplicate(true)
	var source := first_pattern_source if target_pattern != "" else first_add_source
	return {
		"ok": true,
		"base_damage": base_damage,
		"damage": base_damage + damage_add,
		"source": source.duplicate(true),
		"target_pattern": target_pattern,
		"contributions": contributions,
	}


func trap_entry_allowed(unit: Dictionary, mechanisms: Array, default_enemy: bool) -> bool:
	if not _registry_valid() or unit.is_empty():
		return false
	var mechanism_index := _mechanism_index(mechanisms)
	if not bool(mechanism_index.get("ok", false)):
		return false
	var facts := {"default_enemy": default_enemy}
	var allowed := default_enemy
	for mechanism_id_value in _unit_mechanic_ids(unit):
		var resolved := _resolve_projection_handler(
			String(mechanism_id_value),
			Dictionary(mechanism_index.get("by_id", {})),
			TRAP_HOOK
		)
		if not bool(resolved.get("ok", false)):
			return false
		if not bool(resolved.get("supported", false)):
			continue
		var projected := _call_pure_hook(
			resolved.get("handler") as RefCounted,
			TRAP_HOOK,
			unit,
			Dictionary(resolved.get("mechanism", {})),
			facts
		)
		if not bool(projected.get("ok", false)):
			return false
		var result := Dictionary(projected.get("value", {}))
		if result.is_empty():
			continue
		if not _has_exact_keys(result, TRAP_RESULT_KEYS) or typeof(result.get("allow")) != TYPE_BOOL:
			return false
		allowed = allowed or bool(result.get("allow", false))
	return allowed


func threat_candidates(units: Array, mechanisms: Array, facts: Dictionary) -> Array:
	if (
		not _registry_valid()
		or not _units_are_dictionaries(units)
		or not _has_exact_keys(facts, THREAT_FACT_KEYS)
		or typeof(facts.get("enemy")) != TYPE_DICTIONARY
	):
		return []
	var mechanism_index := _mechanism_index(mechanisms)
	if not bool(mechanism_index.get("ok", false)):
		return []
	var candidates: Array = []
	for unit_value in units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != "player" or int(unit.get("hp", 0)) <= 0:
			continue
		for mechanism_id_value in _unit_mechanic_ids(unit):
			var resolved := _resolve_projection_handler(
				String(mechanism_id_value),
				Dictionary(mechanism_index.get("by_id", {})),
				THREAT_HOOK
			)
			if not bool(resolved.get("ok", false)):
				return []
			if not bool(resolved.get("supported", false)):
				continue
			var projected := _call_pure_hook(
				resolved.get("handler") as RefCounted,
				THREAT_HOOK,
				unit,
				Dictionary(resolved.get("mechanism", {})),
				facts
			)
			if not bool(projected.get("ok", false)):
				return []
			var result := Dictionary(projected.get("value", {}))
			if result.is_empty():
				continue
			if not _valid_threat_result(result):
				return []
			candidates.append({
				"target": unit.duplicate(true),
				"range": int(result.get("range", 0)),
				"mechanic_id": String(result.get("mechanic_id", "")),
				"mechanic_name": String(result.get("mechanic_name", "")),
			})
	return candidates


func death_preview_effects(unit: Dictionary, mechanisms: Array, facts: Dictionary) -> Array:
	if (
		not _registry_valid()
		or unit.is_empty()
		or not _has_exact_keys(facts, DEATH_FACT_KEYS)
		or typeof(facts.get("projected_dead")) != TYPE_BOOL
		or not bool(facts.get("projected_dead", false))
	):
		return []
	var mechanism_index := _mechanism_index(mechanisms)
	if not bool(mechanism_index.get("ok", false)):
		return []
	var effects: Array = []
	for mechanism_id_value in _unit_mechanic_ids(unit):
		var resolved := _resolve_projection_handler(
			String(mechanism_id_value),
			Dictionary(mechanism_index.get("by_id", {})),
			DEATH_HOOK
		)
		if not bool(resolved.get("ok", false)):
			return []
		if not bool(resolved.get("supported", false)):
			continue
		var projected := _call_pure_hook(
			resolved.get("handler") as RefCounted,
			DEATH_HOOK,
			unit,
			Dictionary(resolved.get("mechanism", {})),
			facts
		)
		if not bool(projected.get("ok", false)):
			return []
		var result := Dictionary(projected.get("value", {}))
		if result.is_empty():
			continue
		if not _valid_death_result(result):
			return []
		effects.append(result.duplicate(true))
	return effects


func _resolve_projection_handler(
	mechanism_id: String,
	mechanisms_by_id: Dictionary,
	hook: StringName
) -> Dictionary:
	var mechanism := Dictionary(mechanisms_by_id.get(mechanism_id, {}))
	if mechanism.is_empty():
		return {"ok": false}
	var handler := _handler_registry.call(&"handler_for", mechanism_id, mechanism) as RefCounted
	if handler == null:
		return {"ok": false}
	return {
		"ok": true,
		"supported": bool(_handler_registry.call(&"supports", handler, hook)),
		"handler": handler,
		"mechanism": mechanism,
	}


func _call_pure_hook(
	handler: RefCounted,
	hook: StringName,
	unit: Dictionary,
	mechanism: Dictionary,
	facts: Dictionary
) -> Dictionary:
	if handler == null or not handler.has_method(hook):
		return {"ok": false}
	var unit_input := unit.duplicate(true)
	var mechanism_input := mechanism.duplicate(true)
	var facts_input := facts.duplicate(true)
	var unit_before := unit_input.duplicate(true)
	var mechanism_before := mechanism_input.duplicate(true)
	var facts_before := facts_input.duplicate(true)
	var value = handler.call(hook, unit_input, mechanism_input, facts_input)
	if (
		not _deep_equal(unit_input, unit_before)
		or not _deep_equal(mechanism_input, mechanism_before)
		or not _deep_equal(facts_input, facts_before)
		or typeof(value) != TYPE_DICTIONARY
	):
		return {"ok": false}
	var result := Dictionary(value)
	if not _json_compatible(result):
		return {"ok": false}
	return {"ok": true, "value": result.duplicate(true)}


func _mechanism_index(mechanisms: Array) -> Dictionary:
	var by_id := {}
	for mechanism_value in mechanisms:
		if typeof(mechanism_value) != TYPE_DICTIONARY:
			return {"ok": false}
		var mechanism := Dictionary(mechanism_value)
		var mechanism_id_value = mechanism.get("id")
		if typeof(mechanism_id_value) != TYPE_STRING:
			return {"ok": false}
		var mechanism_id := String(mechanism_id_value).strip_edges()
		if mechanism_id == "" or by_id.has(mechanism_id):
			return {"ok": false}
		by_id[mechanism_id] = mechanism
	return {"ok": true, "by_id": by_id}


func _unit_mechanic_ids(unit: Dictionary) -> Array:
	var ids := _split_id_list(unit.get("mechanics", []))
	for mechanism_id_value in _split_id_list(unit.get("mechanism_id", "")):
		var mechanism_id := String(mechanism_id_value)
		if mechanism_id != "none" and not ids.has(mechanism_id):
			ids.append(mechanism_id)
	ids.erase("none")
	return ids


func _split_id_list(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item in Array(value):
			var mechanism_id := String(item).strip_edges()
			if mechanism_id != "" and not result.has(mechanism_id):
				result.append(mechanism_id)
		return result
	var text := String(value).strip_edges()
	if text == "":
		return result
	for token in text.replace("，", ",").replace("、", ",").replace("；", ",").replace(";", ",").split(",", false):
		var mechanism_id := String(token).strip_edges()
		if mechanism_id != "" and not result.has(mechanism_id):
			result.append(mechanism_id)
	return result


func _active_element_type_count(elements: Dictionary) -> int:
	var count := 0
	for element in ElementRulesScript.SETTLEMENT_ELEMENTS:
		if int(elements.get(element, 0)) > 0:
			count += 1
	return count


func _valid_element_contribution(value: Dictionary) -> bool:
	if not _has_exact_keys(value, ELEMENT_CONTRIBUTION_KEYS):
		return false
	if (
		typeof(value.get("exclusive_key")) != TYPE_STRING
		or typeof(value.get("damage_add")) != TYPE_INT
		or typeof(value.get("source")) != TYPE_DICTIONARY
		or typeof(value.get("target_pattern")) != TYPE_STRING
	):
		return false
	return TARGET_PATTERNS.has(String(value.get("target_pattern", "")))


func _valid_threat_result(value: Dictionary) -> bool:
	return (
		_has_exact_keys(value, THREAT_RESULT_KEYS)
		and typeof(value.get("range")) == TYPE_INT
		and typeof(value.get("mechanic_id")) == TYPE_STRING
		and typeof(value.get("mechanic_name")) == TYPE_STRING
	)


func _valid_death_result(value: Dictionary) -> bool:
	return (
		_has_exact_keys(value, DEATH_RESULT_KEYS)
		and typeof(value.get("radius")) == TYPE_INT
		and typeof(value.get("metric")) == TYPE_STRING
		and typeof(value.get("damage")) == TYPE_INT
		and String(value.get("metric", "")) == "manhattan"
	)


func _has_exact_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not value.has(String(key)):
			return false
	return true


func _units_are_dictionaries(units: Array) -> bool:
	for unit in units:
		if typeof(unit) != TYPE_DICTIONARY:
			return false
	return true


func _registry_valid() -> bool:
	return (
		_handler_registry != null
		and _handler_registry.has_method(&"is_valid")
		and _handler_registry.has_method(&"handler_for")
		and _handler_registry.has_method(&"supports")
		and bool(_handler_registry.call(&"is_valid"))
	)


func _json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			for item in Array(value):
				if not _json_compatible(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key in Dictionary(value).keys():
				if typeof(key) != TYPE_STRING or not _json_compatible(Dictionary(value)[key]):
					return false
			return true
	return false


func _deep_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	match typeof(left):
		TYPE_ARRAY:
			var left_array := Array(left)
			var right_array := Array(right)
			if left_array.size() != right_array.size():
				return false
			for index in left_array.size():
				if not _deep_equal(left_array[index], right_array[index]):
					return false
			return true
		TYPE_DICTIONARY:
			var left_dictionary := Dictionary(left)
			var right_dictionary := Dictionary(right)
			if left_dictionary.size() != right_dictionary.size():
				return false
			for key in left_dictionary.keys():
				if not right_dictionary.has(key) or not _deep_equal(left_dictionary[key], right_dictionary[key]):
					return false
			return true
	return left == right
