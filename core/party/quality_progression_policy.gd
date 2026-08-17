extends RefCounted

## Pure quality-growth calculation. Inputs are copied before evaluation and the
## caller decides whether the returned next unit becomes authoritative state.

const QualityRulesScript := preload("res://core/party/quality_rules.gd")
const QualityUpgradeSelectionPolicyScript := preload("res://core/party/quality_upgrade_selection_policy.gd")
const QualitySeededSelectorScript := preload("res://core/run/seeded_selector.gd")
const SkillShapeRulesScript := preload("res://core/battle/skills/skill_shape_rules.gd")
const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")

const RESULT_SCHEMA := "ysbzs.quality-progression-result.v1"


func progress(unit: Dictionary, context: Dictionary, fill_hp_to_max: bool) -> Dictionary:
	var before := unit.duplicate(true)
	var errors: Array[String] = []
	if not context.has("gameData"):
		errors.append("QUALITY_PROGRESSION_CONTEXT_MISSING:gameData")
	elif typeof(context.get("gameData")) != TYPE_DICTIONARY:
		errors.append("QUALITY_PROGRESSION_CONTEXT_INVALID:gameData")
	if not errors.is_empty():
		return _result(false, before, [], errors)

	var game_data := Dictionary(context.get("gameData", {})).duplicate(true)
	var next_unit := before.duplicate(true)
	var quality := QualityRulesScript.normalize(String(next_unit.get("quality", "青铜")))
	next_unit["quality"] = quality
	if not next_unit.has("base_max_hp"):
		next_unit["base_max_hp"] = max(1, int(next_unit.get("max_hp", next_unit.get("hp", 1))))
	if not next_unit.has("base_atk"):
		next_unit["base_atk"] = max(0, int(next_unit.get("atk", 0)))
	if not next_unit.has("base_def"):
		next_unit["base_def"] = max(0, int(next_unit.get("def", 0)))
	if not next_unit.has("base_shield"):
		next_unit["base_shield"] = max(0, int(next_unit.get("shield", 0)))
	if not next_unit.has("base_elements"):
		next_unit["base_elements"] = Dictionary(next_unit.get("elements", {})).duplicate(true)

	var shape_size := _shape_size_for_unit(next_unit, game_data)
	var growth_mode := "evolution_points" if String(next_unit.get("quality_growth_mode", "")) == "evolution_points" else "quality_table"
	var growth := _quality_growth_for(quality, shape_size, game_data)
	var evolution_points: Array = []
	var evolution_summary := {"hp_bonus": 0, "attack_bonus": 0, "defense_bonus": 0, "element_layers": {}}
	var hp_bonus: int = int(growth.get("hp_bonus", 0))
	var atk_bonus: int = int(growth.get("atk_bonus", 0))
	var def_bonus := 0
	if growth_mode == "evolution_points":
		var seed := String(next_unit.get("quality_growth_seed", next_unit.get("pet_id", next_unit.get("id", next_unit.get("name", "")))))
		evolution_points = _build_quality_evolution_points(quality, seed, next_unit)
		evolution_summary = QualityRulesScript.summarize_evolution_points(evolution_points)
		hp_bonus = int(evolution_summary.get("hp_bonus", 0))
		atk_bonus = int(evolution_summary.get("attack_bonus", 0))
		def_bonus = int(evolution_summary.get("defense_bonus", 0))
		growth = {
			"quality": QualityRulesScript.key(quality),
			"label": quality,
			"shape_size": shape_size,
			"growth_mode": growth_mode,
			"hp_bonus": hp_bonus,
			"atk_bonus": atk_bonus,
			"def_bonus": def_bonus,
			"element_layers": Dictionary(evolution_summary.get("element_layers", {})).duplicate(true),
		}

	next_unit["max_hp"] = max(1, int(next_unit.get("base_max_hp", 1)) + hp_bonus)
	next_unit["atk"] = max(0, int(next_unit.get("base_atk", 0)) + atk_bonus + int(next_unit.get("skill_bonus_atk", 0)))
	next_unit["def"] = max(0, int(next_unit.get("base_def", 0)) + def_bonus)
	next_unit["shield"] = max(0, int(next_unit.get("base_shield", 0)))
	if growth_mode == "evolution_points":
		var current_elements := Dictionary(next_unit.get("base_elements", {})).duplicate(true)
		for element in Dictionary(evolution_summary.get("element_layers", {})).keys():
			current_elements[element] = int(current_elements.get(element, 0)) + int(Dictionary(evolution_summary.get("element_layers", {})).get(element, 0))
		next_unit["elements"] = current_elements

	next_unit["quality_growth"] = growth.duplicate(true)
	var upgrade_seed := String(next_unit.get("quality_upgrade_seed", ""))
	var upgrade := QualityUpgradeSelectionPolicyScript.select_upgrade(
		Array(Dictionary(game_data.get("quality", {})).get("upgrades", [])),
		QualityRulesScript.key(quality),
		shape_size,
		upgrade_seed
	)
	next_unit["quality_upgrade"] = upgrade.duplicate(true)
	next_unit["quality_progression"] = {
		"growth_mode": growth_mode,
		"quality": QualityRulesScript.key(quality),
		"label": quality,
		"shape_size": shape_size,
		"hp_bonus": hp_bonus,
		"atk_bonus": atk_bonus,
		"def_bonus": def_bonus,
		"evolution_points": evolution_points.duplicate(true),
		"evolution_summary": evolution_summary.duplicate(true),
		"upgrade_selection": "seeded" if upgrade_seed != "" else "legacy_first",
		"upgrade_id": String(upgrade.get("id", "")),
		"upgrade_name": String(upgrade.get("name", "")),
	}
	if fill_hp_to_max or not next_unit.has("hp"):
		next_unit["hp"] = int(next_unit["max_hp"])
	else:
		next_unit["hp"] = min(int(next_unit.get("hp", next_unit["max_hp"])), int(next_unit["max_hp"]))

	return _result(true, next_unit, _changes(before, next_unit), [])


func _shape_size_for_unit(unit: Dictionary, game_data: Dictionary) -> int:
	var size: int = max(1, int(unit.get("hit_cells", 1)))
	if size <= 1:
		size = max(size, int(SkillShapeRulesScript.shape_definition(unit, game_data).get("cell_count", size)))
	return clamp(size, 1, 3)


func _quality_growth_for(quality: String, shape_size: int, game_data: Dictionary) -> Dictionary:
	var quality_key := QualityRulesScript.key(quality)
	var wanted_size: int = clamp(shape_size, 1, 3)
	for item in Array(Dictionary(game_data.get("quality", {})).get("growth", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("quality", "")) == quality_key and int(row.get("shape_size", 1)) == wanted_size:
			return row.duplicate(true)
	return {"quality": quality_key, "label": QualityRulesScript.normalize(quality), "shape_size": wanted_size, "hp_bonus": 0, "atk_bonus": 0}


func _pick_from_list(list: Array, random: Dictionary) -> Variant:
	if list.is_empty():
		return null
	var index: int = min(list.size() - 1, int(floor(QualitySeededSelectorScript.next(random) * list.size())))
	return list[index]


func _choose_quality_evolution_category(previous_categories: Array, random: Dictionary) -> String:
	var existing := QualityRulesScript.known_categories(previous_categories, QualityRulesScript.EVOLUTION_POINT_CATEGORIES)
	var all: Array = []
	for row in QualityRulesScript.EVOLUTION_POINT_CATEGORIES:
		all.append(String(Dictionary(row).get("id", "")))
	var missing: Array = []
	for category in all:
		if not existing.has(String(category)):
			missing.append(category)
	if existing.is_empty():
		return String(_pick_from_list(all, random))
	if missing.is_empty():
		return String(_pick_from_list(existing, random))
	var hit_existing := QualitySeededSelectorScript.next(random) < QualityRulesScript.existing_category_hit_probability(existing.size(), QualityRulesScript.EVOLUTION_POINT_CATEGORIES)
	return String(_pick_from_list(existing if hit_existing else missing, random))


func _element_slots_for_evolution(unit: Dictionary) -> Array:
	var elements := Dictionary(unit.get("elements", {}))
	var positive: Array = []
	for key in elements.keys():
		if int(elements.get(key, 0)) > 0:
			positive.append(String(key))
	positive.sort()
	if not positive.is_empty():
		return positive
	var element := String(unit.get("element", ""))
	if element != "":
		return [element]
	return ElementRulesScript.active_elements()


func _build_quality_evolution_points(quality: String, seed: String, unit: Dictionary) -> Array:
	var quality_key := QualityRulesScript.key(quality)
	var count: int = int(QualityRulesScript.EVOLUTION_POINT_TOTALS.get(quality_key, 0))
	var random := QualitySeededSelectorScript.rng("quality:evolution:%s:%s" % [quality_key, seed])
	var previous_categories: Array = []
	var points: Array = []
	for index in range(count):
		var category := _choose_quality_evolution_category(previous_categories, random)
		var meta := {}
		for row in QualityRulesScript.EVOLUTION_POINT_CATEGORIES:
			if String(Dictionary(row).get("id", "")) == category:
				meta = Dictionary(row)
				break
		var point := {
			"index": index + 1,
			"category": category,
			"label": String(meta.get("label", category)),
			"description": String(meta.get("description", "")),
			"amount": 1,
		}
		if category == "hp":
			point["amount"] = 5 + int(floor(QualitySeededSelectorScript.next(random) * 6.0))
		elif category == "element":
			point["element"] = String(_pick_from_list(_element_slots_for_evolution(unit), random))
		points.append(point)
		previous_categories.append(category)
	return points


func _changes(before: Dictionary, after: Dictionary) -> Array:
	var fields: Array[String] = []
	for raw_field in before.keys():
		var field := String(raw_field)
		if not fields.has(field):
			fields.append(field)
	for raw_field in after.keys():
		var field := String(raw_field)
		if not fields.has(field):
			fields.append(field)
	fields.sort()
	var changes: Array = []
	for field in fields:
		if before.has(field) == after.has(field) and before.get(field) == after.get(field):
			continue
		changes.append({
			"field": field,
			"before": before.get(field),
			"after": after.get(field),
		})
	return changes


func _result(ok: bool, unit: Dictionary, changes: Array, errors: Array) -> Dictionary:
	return {
		"schema": RESULT_SCHEMA,
		"ok": ok,
		"unit": unit.duplicate(true),
		"changes": changes.duplicate(true),
		"errors": errors.duplicate(true),
	}
