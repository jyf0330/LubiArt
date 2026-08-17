extends RefCounted

## Deterministic seeded selection shared by route, shop, and reward planning.

const ALGORITHM_VERSION := "ysbzs_seeded_selector_fnv1a_mulberry32_v1"


static func u32(value: int) -> int:
	return value & 0xffffffff


static func hash_seed(seed: String) -> int:
	var hash := 2166136261
	for index in range(seed.length()):
		hash = u32(hash ^ seed.unicode_at(index))
		hash = u32(hash * 16777619)
	return hash


static func rng(seed: String) -> Dictionary:
	var hashed := hash_seed(seed)
	if hashed == 0:
		hashed = 1
	return {"a": hashed}


static func next(random: Dictionary) -> float:
	var a := u32(int(random.get("a", 1)) + 0x6D2B79F5)
	random["a"] = a
	var t := u32((a ^ (a >> 15)) * (1 | a))
	t = u32((t + u32((t ^ (t >> 7)) * (61 | t))) ^ t)
	return float(u32(t ^ (t >> 14))) / 4294967296.0


static func weighted_pick(items: Array, weight_fn: Callable, random: Dictionary) -> Dictionary:
	var list: Array = []
	var total := 0
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		var weight: int = max(0, int(weight_fn.call(row)))
		if weight <= 0:
			continue
		list.append(row)
		total += weight
	if list.is_empty() or total <= 0:
		return {}
	var roll := next(random) * float(total)
	for item in list:
		var weight: int = max(0, int(weight_fn.call(Dictionary(item))))
		roll -= float(weight)
		if roll <= 0.0:
			return Dictionary(item)
	return Dictionary(list[list.size() - 1])


static func id_value(row: Dictionary, id_keys: Array) -> String:
	for key in id_keys:
		var value := String(row.get(String(key), ""))
		if value != "":
			return value
	return ""


static func weighted_unique(items: Array, count: int, id_keys: Array, seed: String, weight_fn: Callable) -> Array:
	var pool: Array = []
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			pool.append(Dictionary(item).duplicate(true))
	pool.sort_custom(func(a, b):
		return id_value(Dictionary(a), id_keys) < id_value(Dictionary(b), id_keys)
	)
	var random := rng(seed)
	var options: Array = []
	while not pool.is_empty() and options.size() < count:
		var picked := weighted_pick(pool, weight_fn, random)
		if picked.is_empty():
			break
		options.append(picked)
		var picked_id := id_value(picked, id_keys)
		for index in range(pool.size()):
			if id_value(Dictionary(pool[index]), id_keys) == picked_id:
				pool.remove_at(index)
				break
	return options
