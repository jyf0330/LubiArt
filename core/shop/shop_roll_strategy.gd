extends RefCounted

## Stateless Strategy selected by a store Type Object.

const SeededSelectorScript := preload("res://core/run/seeded_selector.gd")


func select(candidates: Array, count: int, store: Dictionary, context: Dictionary) -> Array:
	if count <= 0 or candidates.is_empty():
		return []
	var strategy_id := String(store.get("roll_strategy", "weighted_unique"))
	if strategy_id == "catalog_order":
		return _catalog_order(candidates, count, context)
	if strategy_id == "uniform_unique":
		var uniform_context := context.duplicate()
		uniform_context["weight_fn"] = func(_row: Dictionary): return 1
		return _weighted_unique(candidates, count, uniform_context)
	return _weighted_unique(candidates, count, context)


func _weighted_unique(candidates: Array, count: int, context: Dictionary) -> Array:
	var pool: Array = []
	for value in candidates:
		if typeof(value) == TYPE_DICTIONARY:
			pool.append(Dictionary(value))
	var selected: Array = []
	var random := Dictionary(context.get("random", {}))
	var weight_fn: Callable = context.get("weight_fn", Callable())
	var key_fn: Callable = context.get("key_fn", Callable())
	while not pool.is_empty() and selected.size() < count:
		var picked := SeededSelectorScript.weighted_pick(pool, weight_fn, random)
		if picked.is_empty():
			break
		selected.append(picked)
		_remove_matching_key(pool, _key_for(picked, key_fn), key_fn)
	return selected


func _catalog_order(candidates: Array, count: int, context: Dictionary) -> Array:
	var key_fn: Callable = context.get("key_fn", Callable())
	var ordered: Array = []
	for value in candidates:
		if typeof(value) == TYPE_DICTIONARY:
			ordered.append(Dictionary(value))
	ordered.sort_custom(func(a, b):
		return _key_for(Dictionary(a), key_fn) < _key_for(Dictionary(b), key_fn)
	)
	var selected: Array = []
	var seen := {}
	for item in ordered:
		var key := _key_for(Dictionary(item), key_fn)
		if key != "" and seen.has(key):
			continue
		selected.append(item)
		if key != "":
			seen[key] = true
		if selected.size() >= count:
			break
	return selected


func _remove_matching_key(pool: Array, picked_key: String, key_fn: Callable) -> void:
	if picked_key == "":
		if not pool.is_empty():
			pool.remove_at(0)
		return
	for index in range(pool.size() - 1, -1, -1):
		if _key_for(Dictionary(pool[index]), key_fn) == picked_key:
			pool.remove_at(index)


func _key_for(item: Dictionary, key_fn: Callable) -> String:
	if key_fn.is_valid():
		return String(key_fn.call(item))
	return String(item.get("pet_id", item.get("id", "")))
