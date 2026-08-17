extends SceneTree

const PolicyScript := preload("res://core/party/quality_upgrade_selection_policy.gd")
const ProgressionPolicyScript := preload("res://core/party/quality_progression_policy.gd")
const GameStateScript := preload("res://core/state/game_state.gd")

var _failed := false


func _initialize() -> void:
	var core := GameStateScript.new()
	var upgrades := Array(Dictionary(core.game_data.get("quality", {})).get("upgrades", []))
	_expect(upgrades.size() == 68, "quality Type Object catalog exposes all 68 upgrades")

	var silver_one := PolicyScript.eligible_upgrades(upgrades, "silver", 1)
	var gold_one := PolicyScript.eligible_upgrades(upgrades, "gold", 1)
	var gold_three := PolicyScript.eligible_upgrades(upgrades, "gold", 3)
	var diamond_one := PolicyScript.eligible_upgrades(upgrades, "diamond", 1)
	var diamond_three := PolicyScript.eligible_upgrades(upgrades, "diamond", 3)
	_expect(_has_id(silver_one, "S04"), "one-cell silver pool keeps universal effects")
	_expect(not _has_id(silver_one, "S05"), "one-cell silver pool excludes multi-cell effects")
	_expect(_has_id(gold_one, "G17"), "one-cell gold pool includes precise mark")
	_expect(not _has_id(gold_three, "G17"), "three-cell gold pool excludes one-cell precise mark")
	_expect(_has_id(diamond_one, "D16"), "one-cell diamond pool includes repeated strike")
	_expect(not _has_id(diamond_three, "D16"), "three-cell diamond pool excludes one-cell repeated strike")

	_expect(
		String(PolicyScript.select_upgrade(upgrades, "silver", 1).get("id", "")) == "S01",
		"empty seed preserves legacy first-row assignment"
	)
	_expect(
		String(PolicyScript.select_upgrade(upgrades, "silver", 1, "pal_002").get("id", "")) == "S08",
		"silver seeded selection matches browser FNV-1a result"
	)
	_expect(
		String(PolicyScript.select_upgrade(upgrades, "gold", 2, "pal_002").get("id", "")) == "G08",
		"gold seeded selection matches browser FNV-1a result"
	)
	_expect(
		String(PolicyScript.select_upgrade(upgrades, "diamond", 3, "pal_002").get("id", "")) == "D25",
		"diamond seeded selection matches browser FNV-1a result"
	)
	_expect(
		String(PolicyScript.select_upgrade(upgrades, "silver", 1, "捣蛋猫").get("id", "")) == "S03",
		"Chinese seed matches browser UTF-16 FNV-1a result"
	)
	_expect(
		String(PolicyScript.select_upgrade(upgrades, "diamond", 3, "宠物😀").get("id", "")) == "D01",
		"surrogate-pair seed matches browser UTF-16 FNV-1a result"
	)
	var stable_a := PolicyScript.select_upgrade(upgrades, "gold", 2, "pal_001:hero")
	var stable_b := PolicyScript.select_upgrade(upgrades, "gold", 2, "pal_001:hero")
	_expect(String(stable_a.get("id", "")) == String(stable_b.get("id", "")), "same seed is stable")
	_expect(_distinct_seeded_ids(upgrades, "silver", 1, 64) >= 6, "silver seeds distribute through most eligible effects")
	_expect(_distinct_seeded_ids(upgrades, "gold", 2, 128) >= 12, "gold seeds distribute through eligible effects")
	_expect(_distinct_seeded_ids(upgrades, "diamond", 3, 128) >= 15, "diamond seeds distribute through eligible effects")

	var progression_policy := ProgressionPolicyScript.new()
	var progression_context := {"gameData": core.game_data.duplicate(true)}
	var seeded_unit := {
		"id": "pal_002",
		"pet_id": "pal_002",
		"name": "捣蛋猫",
		"quality": "白银",
		"quality_upgrade_seed": "pal_002",
		"hit_cells": 1,
		"max_hp": 24,
		"hp": 24,
		"atk": 4,
		"def": 0,
		"shield": 1,
		"elements": {"无": 1},
	}
	var seeded_unit_before := seeded_unit.duplicate(true)
	var progression_context_before := progression_context.duplicate(true)
	var progression_result := progression_policy.progress(seeded_unit, progression_context, true)
	var progressed_unit := Dictionary(progression_result.get("unit", {}))
	_expect(String(progression_result.get("schema", "")) == "ysbzs.quality-progression-result.v1", "progression returns the versioned result schema")
	_expect(bool(progression_result.get("ok", false)), "valid progression succeeds")
	_expect(seeded_unit == seeded_unit_before, "successful progression leaves the input unit unchanged")
	_expect(progression_context == progression_context_before, "successful progression leaves the input context unchanged")
	_expect(not Array(progression_result.get("changes", [])).is_empty(), "successful progression reports changed top-level fields")
	_expect(String(Dictionary(progressed_unit.get("quality_upgrade", {})).get("id", "")) == "S08", "quality progression honors explicit seed")
	_expect(String(Dictionary(progressed_unit.get("quality_progression", {})).get("upgrade_selection", "")) == "seeded", "progression records seeded selection mode")

	var expected_repeat := progressed_unit.duplicate(true)
	for _iteration in range(100):
		var repeated := progression_policy.progress(seeded_unit, progression_context, true)
		_expect(bool(repeated.get("ok", false)) and Dictionary(repeated.get("unit", {})) == expected_repeat, "same seed is stable across 100 progression evaluations")

	var alternate_upgrade_unit := seeded_unit.duplicate(true)
	alternate_upgrade_unit["quality_upgrade_seed"] = "pal_002:alternate"
	var alternate_upgrade_result := progression_policy.progress(alternate_upgrade_unit, progression_context, true)
	var alternate_progressed := Dictionary(alternate_upgrade_result.get("unit", {}))
	_expect(bool(alternate_upgrade_result.get("ok", false)), "alternate upgrade seed progression succeeds")
	_expect(
		_without_upgrade_selection(alternate_progressed) == _without_upgrade_selection(progressed_unit),
		"changing only the upgrade seed changes only allowed upgrade-selection outputs"
	)

	var evolution_unit := seeded_unit.duplicate(true)
	evolution_unit["quality"] = "钻石"
	evolution_unit["quality_growth_mode"] = "evolution_points"
	evolution_unit["quality_growth_seed"] = "growth-route-a"
	var evolution_a := Dictionary(progression_policy.progress(evolution_unit, progression_context, true).get("unit", {}))
	evolution_unit["quality_growth_seed"] = "growth-route-b"
	var evolution_b := Dictionary(progression_policy.progress(evolution_unit, progression_context, true).get("unit", {}))
	_expect(Array(Dictionary(evolution_a.get("quality_progression", {})).get("evolution_points", [])) != Array(Dictionary(evolution_b.get("quality_progression", {})).get("evolution_points", [])), "different growth seeds can change evolution selection")
	_expect(_without_evolution_outputs(evolution_a) == _without_evolution_outputs(evolution_b), "different growth seeds change only evolution and derived-stat outputs")

	var invalid_context := {"gameData": [], "sentinel": {"unchanged": true}}
	var invalid_context_before := invalid_context.duplicate(true)
	var failed_result := progression_policy.progress(seeded_unit, invalid_context, true)
	_expect(not bool(failed_result.get("ok", true)), "invalid context fails closed")
	_expect(Array(failed_result.get("errors", [])).has("QUALITY_PROGRESSION_CONTEXT_INVALID:gameData"), "invalid context reports a stable error code")
	_expect(Dictionary(failed_result.get("unit", {})) == seeded_unit_before, "failed progression returns an unchanged unit copy")
	_expect(seeded_unit == seeded_unit_before, "failed progression leaves the input unit unchanged")
	_expect(invalid_context == invalid_context_before, "failed progression leaves the input context unchanged")

	if _failed:
		quit(1)
		return
	print("SMOKE_QUALITY_UPGRADE_SELECTION_POLICY_OK catalog=68 legacy=S01 seeded=S08/G08/D25")
	quit(0)


func _has_id(rows: Array, wanted_id: String) -> bool:
	for row_value in rows:
		if String(Dictionary(row_value).get("id", "")) == wanted_id:
			return true
	return false


func _distinct_seeded_ids(
	upgrades: Array,
	quality_key: String,
	shape_size: int,
	seed_count: int
) -> int:
	var ids := {}
	for index in range(seed_count):
		var selected := PolicyScript.select_upgrade(
			upgrades,
			quality_key,
			shape_size,
			"seed_%03d" % index
		)
		ids[String(selected.get("id", ""))] = true
	return ids.size()


func _without_upgrade_selection(unit: Dictionary) -> Dictionary:
	var result := unit.duplicate(true)
	result.erase("quality_upgrade_seed")
	result.erase("quality_upgrade")
	var progression := Dictionary(result.get("quality_progression", {})).duplicate(true)
	progression.erase("upgrade_id")
	progression.erase("upgrade_name")
	result["quality_progression"] = progression
	return result


func _without_evolution_outputs(unit: Dictionary) -> Dictionary:
	var result := unit.duplicate(true)
	for field in ["quality_growth_seed", "quality_growth", "quality_progression", "max_hp", "hp", "atk", "def", "elements"]:
		result.erase(field)
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Quality upgrade selection policy smoke failed: %s" % message)
