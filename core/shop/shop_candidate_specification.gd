extends RefCounted

## Stateless Specification for deciding whether a catalog item can appear in a store.
## Store rows remain Type Objects supplied by the exported planning data.


func matches(item: Dictionary, store: Dictionary, context: Dictionary) -> bool:
	var day := int(context.get("day", 1))
	if int(item.get("unlock_day", 1)) > day:
		return false
	var source_stall_id := String(context.get("source_stall_id", ""))
	if source_stall_id != "" and not Array(item.get("source_stall_ids", [])).has(source_stall_id):
		return false
	var pool_id := String(store.get("pool_id", store.get("id", "")))
	var require_pool_membership := bool(store.get("require_pool_membership", true))
	if require_pool_membership and not Array(item.get("shop_pools", [])).has(pool_id):
		return false
	var weight_fn: Callable = context.get("weight_fn", Callable())
	if weight_fn.is_valid() and int(weight_fn.call(item)) <= 0:
		return false
	var blocked_fn: Callable = context.get("blocked_fn", Callable())
	if blocked_fn.is_valid() and bool(blocked_fn.call(item)):
		return false
	var rules := Dictionary(store.get("specification", store.get("candidate_specification", {})))
	return _matches_rules(item, rules)


func filter(items: Array, store: Dictionary, context: Dictionary) -> Array:
	var candidates: Array = []
	for value in items:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var item := Dictionary(value)
		if matches(item, store, context):
			candidates.append(item)
	return candidates


func _matches_rules(item: Dictionary, rules: Dictionary) -> bool:
	if rules.is_empty():
		return true
	if not _matches_allowed_value(String(item.get("item_type", "")), Array(rules.get("item_types", []))):
		return false
	if not _matches_allowed_value(String(item.get("quality", "")), Array(rules.get("qualities", []))):
		return false
	if not _matches_allowed_value(String(item.get("role", "")), Array(rules.get("roles", []))):
		return false
	if not _matches_allowed_value(String(item.get("source_type", "")), Array(rules.get("source_types", []))):
		return false
	if not _matches_allowed_value(String(item.get("source_tier", "")), Array(rules.get("source_tiers", []))):
		return false
	if not _matches_allowed_value(String(item.get("source_size", "")), Array(rules.get("source_sizes", []))):
		return false
	if not _matches_any(_item_elements(item), Array(rules.get("elements_any", []))):
		return false
	var tags := _string_values(Array(item.get("tags", [])))
	if not _matches_any(tags, Array(rules.get("tags_any", []))):
		return false
	if not _matches_all(tags, Array(rules.get("tags_all", []))):
		return false
	var traits := _item_traits(item, tags)
	if not _matches_any(traits, Array(rules.get("traits_any", []))):
		return false
	if not _matches_all(traits, Array(rules.get("traits_all", []))):
		return false
	if not _matches_any(_item_enchantments(item), Array(rules.get("enchantments_any", []))):
		return false
	var source_tags := _string_values(Array(item.get("source_tags", [])))
	if not _matches_any(source_tags, Array(rules.get("source_tags_any", []))):
		return false
	if not _matches_all(source_tags, Array(rules.get("source_tags_all", []))):
		return false
	if not _matches_number(int(item.get("slot_count", 0)), rules, "slot_count"):
		return false
	if not _matches_number(int(item.get("hit_cells", 0)), rules, "hit_cells"):
		return false
	if not _matches_number(int(item.get("hit_cells", 0)), rules, "attack_target_count"):
		return false
	if not _matches_number(int(item.get("slot_count", 0)), rules, "action_count"):
		return false
	if rules.has("enchanted") and bool(rules.get("enchanted", false)) != _is_enchanted(item):
		return false
	return true


func _matches_allowed_value(value: String, allowed: Array) -> bool:
	if allowed.is_empty():
		return true
	return _string_values(allowed).has(value)


func _matches_any(values: Array[String], required: Array) -> bool:
	if required.is_empty():
		return true
	for value in _string_values(required):
		if values.has(value):
			return true
	return false


func _matches_all(values: Array[String], required: Array) -> bool:
	for value in _string_values(required):
		if not values.has(value):
			return false
	return true


func _matches_number(value: int, rules: Dictionary, field: String) -> bool:
	var minimum_key := "min_%s" % field
	var maximum_key := "max_%s" % field
	if rules.has(minimum_key) and value < int(rules.get(minimum_key, value)):
		return false
	if rules.has(maximum_key) and value > int(rules.get(maximum_key, value)):
		return false
	return true


func _item_elements(item: Dictionary) -> Array[String]:
	var values := _string_values(Array(item.get("element_types", [])))
	var primary := String(item.get("element", ""))
	if primary != "" and not values.has(primary):
		values.append(primary)
	return values


func _is_enchanted(item: Dictionary) -> bool:
	return not _item_enchantments(item).is_empty()


func _item_traits(item: Dictionary, tags: Array[String]) -> Array[String]:
	var values := tags.duplicate()
	for key in ["traits", "features"]:
		for value in _string_values(Array(item.get(key, []))):
			if not values.has(value):
				values.append(value)
	return values


func _item_enchantments(item: Dictionary) -> Array[String]:
	var values := _string_values(Array(item.get("enchantments", [])))
	for key in ["enchantment", "main_enchantment", "primary_enchant", "affix"]:
		var value := String(item.get(key, "")).strip_edges()
		if value != "" and not values.has(value):
			values.append(value)
	return values


func _string_values(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var text := String(value)
		if text != "":
			result.append(text)
	return result
