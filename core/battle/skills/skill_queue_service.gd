extends RefCounted

## Pure, deterministic party skill-control rules. The authority stores only the
## ordered stable entry ids; UI labels and skill definitions remain projections.

const SKILLS_PER_UNIT := 2
const MAX_UNITS_PER_BAR := 4
const MAX_CONTROL_ENTRIES := SKILLS_PER_UNIT * MAX_UNITS_PER_BAR
const BASIC_ATTACK_SKILL_ID := "basic_attack"
const SKILL_SLOTS := ["a", "b"]


func catalog_skill_ids(catalog: Dictionary) -> Array[String]:
	var rows: Array = []
	for skill_id_value in catalog.keys():
		var skill_id := String(skill_id_value).strip_edges()
		if skill_id == "":
			continue
		var definition := Dictionary(catalog.get(skill_id_value, {}))
		rows.append({"id": skill_id, "order": int(definition.get("order_index", 1_000_000))})
	rows.sort_custom(func(left, right):
		var left_row := Dictionary(left)
		var right_row := Dictionary(right)
		if int(left_row.get("order", 0)) == int(right_row.get("order", 0)):
			return String(left_row.get("id", "")) < String(right_row.get("id", ""))
		return int(left_row.get("order", 0)) < int(right_row.get("order", 0))
	)
	var ids: Array[String] = []
	for row_value in rows:
		ids.append(String(Dictionary(row_value).get("id", "")))
		if ids.size() >= SKILLS_PER_UNIT:
			break
	return ids


func unit_skill_ids(unit: Dictionary, fallback_skill_ids: Array = []) -> Array[String]:
	var result := _normalized_skill_ids(Array(unit.get("skills", [])))
	if result.is_empty():
		var normalized_fallback := _normalized_skill_ids(fallback_skill_ids)
		if not normalized_fallback.is_empty():
			result = normalized_fallback
		else:
			result.append(BASIC_ATTACK_SKILL_ID)
			var legacy_skill := String(unit.get("skill", "")).strip_edges()
			if legacy_skill != "" and legacy_skill != "none" and not result.has(legacy_skill):
				result.append(legacy_skill)
	for fallback_value in fallback_skill_ids:
		var fallback_id := String(fallback_value).strip_edges()
		if fallback_id != "" and not result.has(fallback_id):
			result.append(fallback_id)
		if result.size() >= SKILLS_PER_UNIT:
			break
	return result.slice(0, SKILLS_PER_UNIT)


func control_entries(
		units: Array,
		stored_entry_ids: Array = [],
		label_resolver: Callable = Callable(),
		fallback_skill_ids: Array = []
	) -> Array:
	var available_by_id := {}
	var default_order: Array[String] = []
	var seen_unit_ids := {}
	for unit_value in units.slice(0, MAX_UNITS_PER_BAR):
		var unit := Dictionary(unit_value)
		var unit_id := String(unit.get("id", "")).strip_edges()
		if unit_id == "" or seen_unit_ids.has(unit_id):
			continue
		seen_unit_ids[unit_id] = true
		var unit_name := String(unit.get("name", unit_id))
		var skill_ids := unit_skill_ids(unit, fallback_skill_ids)
		for slot_index in range(skill_ids.size()):
			var skill_slot := String(SKILL_SLOTS[slot_index])
			var skill_id := String(skill_ids[slot_index])
			var entry_id := "%s:%s" % [unit_id, skill_slot]
			var label := skill_id
			if label_resolver.is_valid():
				label = String(label_resolver.call(skill_id))
			available_by_id[entry_id] = {
				"entryId": entry_id,
				"entry_id": entry_id,
				"unitId": unit_id,
				"unit_id": unit_id,
				"unitName": unit_name,
				"unit_name": unit_name,
				"skillSlot": skill_slot,
				"skill_slot": skill_slot,
				"skillId": skill_id,
				"skill_id": skill_id,
				"label": label,
			}
			default_order.append(entry_id)

	var ordered_ids: Array[String] = []
	for entry_id in _normalized_entry_ids(stored_entry_ids):
		if available_by_id.has(entry_id):
			ordered_ids.append(entry_id)
	for entry_id in default_order:
		if not ordered_ids.has(entry_id):
			ordered_ids.append(entry_id)

	var entries: Array = []
	for index in range(ordered_ids.size()):
		var entry := Dictionary(available_by_id[ordered_ids[index]]).duplicate(true)
		entry["orderIndex"] = index
		entry["order_index"] = index
		entries.append(entry)
	return entries


func entry_ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for entry_value in entries:
		var entry_id := String(Dictionary(entry_value).get("entryId", Dictionary(entry_value).get("entry_id", ""))).strip_edges()
		if entry_id != "":
			result.append(entry_id)
	return result


func skill_ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for entry_value in entries:
		var skill_id := String(Dictionary(entry_value).get("skillId", Dictionary(entry_value).get("skill_id", ""))).strip_edges()
		if skill_id != "":
			result.append(skill_id)
	return result


func is_exact_reorder(current_entries: Array, requested_values: Array) -> bool:
	var current := entry_ids(current_entries)
	var requested := _normalized_entry_ids(requested_values)
	if requested.size() != requested_values.size() or requested.size() != current.size():
		return false
	for entry_id in current:
		if requested.count(entry_id) != 1:
			return false
	return true


func _normalized_skill_ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var skill_id := String(value).strip_edges()
		if skill_id == "" or result.has(skill_id):
			continue
		result.append(skill_id)
		if result.size() >= SKILLS_PER_UNIT:
			break
	return result


func _normalized_entry_ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var entry_id := String(value).strip_edges()
		if entry_id == "" or result.has(entry_id):
			continue
		result.append(entry_id)
		if result.size() >= MAX_CONTROL_ENTRIES:
			break
	return result
