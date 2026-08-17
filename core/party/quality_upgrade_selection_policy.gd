extends RefCounted
class_name QualityUpgradeSelectionPolicy

## Pure selection policy for quality-upgrade Type Objects.
##
## The catalog order remains authoritative. An empty seed preserves the legacy
## "first eligible row" behavior; an explicit seed uses the same FNV-1a rule as
## the browser core so assignment is deterministic across engines.


static func eligible_upgrades(upgrades: Array, quality_key: String, shape_size: int) -> Array:
	var wanted_size: int = clamp(shape_size, 1, 3)
	var result: Array = []
	for item in upgrades:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("quality", "")) != quality_key:
			continue
		if String(row.get("runtime_status", "")) != "implemented":
			continue
		var allowed := Array(row.get("allowed_shape_sizes", []))
		if allowed.is_empty() or _contains_size(allowed, wanted_size):
			result.append(row)
	return result


static func select_upgrade(
	upgrades: Array,
	quality_key: String,
	shape_size: int,
	selection_seed: String = ""
) -> Dictionary:
	if quality_key == "bronze":
		return {}
	var candidates := eligible_upgrades(upgrades, quality_key, shape_size)
	if candidates.is_empty():
		return {}
	if selection_seed == "":
		return Dictionary(candidates[0]).duplicate(true)
	var key := "%s:%d:%s" % [quality_key, clamp(shape_size, 1, 3), selection_seed]
	var index: int = int(_fnv1a_32(key) % candidates.size())
	return Dictionary(candidates[index]).duplicate(true)


static func _contains_size(values: Array, wanted_size: int) -> bool:
	for value in values:
		if int(value) == wanted_size:
			return true
	return false


static func _fnv1a_32(text: String) -> int:
	var value: int = 2166136261
	for index in range(text.length()):
		var codepoint := text.unicode_at(index)
		if codepoint <= 0xffff:
			value = _fnv_step(value, codepoint)
			continue
		var scalar := codepoint - 0x10000
		value = _fnv_step(value, 0xd800 + (scalar >> 10))
		value = _fnv_step(value, 0xdc00 + (scalar & 0x3ff))
	return value


static func _fnv_step(value: int, code_unit: int) -> int:
	return ((value ^ code_unit) * 16777619) & 0xffffffff
