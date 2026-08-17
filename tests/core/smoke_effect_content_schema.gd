extends SceneTree

const GameDataRepositoryScript := preload("res://persistence/game_data_repository.gd")
const EffectVocabularyScript := preload("res://core/effects/effect_vocabulary.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const StatIdsScript := preload("res://core/stats/stat_ids.gd")
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")
const StatResolverScript := preload("res://core/stats/stat_resolver.gd")
const TraitServiceScript := preload("res://core/battle/traits/trait_service.gd")
const CoreCompositionScript := preload("res://core/composition/core_composition.gd")
const SkillEffectPortScript := preload("res://core/ports/skill_effect_port.gd")

const OWNER_SKILL_CATALOG := EffectVocabularyScript.OWNER_SKILL_CATALOG

class EffectAuthority:
	extends RefCounted
	var _core_composition: RefCounted = null
	var _fixture_content: Dictionary = {}
	var game_data: Dictionary:
		get:
			return _fixture_content

	func _init(content: Dictionary = {}) -> void:
		_fixture_content = content.duplicate(true)

var failed := false
var _fixture_root := "user://puzzle_effect_schema_%d" % OS.get_process_id()


func _initialize() -> void:
	_remove_tree(_fixture_root)
	_verify_current_content()
	_verify_vocabulary_contract()
	_verify_repository_rejections()
	_verify_scoped_hook_behavior()
	_verify_runtime_modifier_hook_behavior()
	_verify_legacy_trait_behavior()
	_verify_literal_convergence()
	_remove_tree(_fixture_root)
	if failed:
		quit(1)
		return
	print("SMOKE_EFFECT_CONTENT_SCHEMA_OK")
	quit(0)


func _verify_current_content() -> void:
	var repository := GameDataRepositoryScript.new()
	var data := Dictionary(repository.read_content_pack("res://data/content"))
	_expect(not data.is_empty(), "current modular content passes assembled semantic validation")
	_expect(repository.content_errors().is_empty(), "current modular content reports no semantic errors")
	var actual_stats: Array[String] = []
	for value in Dictionary(data.get("stat_catalog", {})).keys():
		actual_stats.append(String(value))
	actual_stats.sort()
	var expected_stats: Array[String] = []
	for value in StatIdsScript.ALL:
		expected_stats.append(String(value))
	expected_stats.sort()
	_expect(actual_stats == expected_stats, "stat ID constants exactly cover the planner stat catalog")
	_expect(StatResolverScript.new().supported_operations() == StatOperationIdsScript.RUNTIME, "operation constants exactly cover runtime operation plugins")


func _verify_vocabulary_contract() -> void:
	var spec := {
		EffectVocabularyScript.FIELD_TYPE: "  modify_stat ",
		EffectVocabularyScript.FIELD_STAT_ID: StatIdsScript.ATK,
	}
	_expect(EffectVocabularyScript.effect_type(spec) == EffectVocabularyScript.TYPE_MODIFY_STAT, "effect type parsing is centralized and trims IDs")
	_expect(EffectVocabularyScript.stat_id(spec) == StatIdsScript.ATK, "legacy stat_id input shares the centralized stat parser")
	_expect(EffectVocabularyScript.operation_id(spec) == StatOperationIdsScript.FLAT_ADD, "missing operation has one stable fallback")
	_expect(EffectHookIdsScript.TRIGGER_HOOKS.size() == 8, "trigger hook vocabulary keeps the executable lifecycle surface explicit")
	_expect(EffectHookIdsScript.STAT_QUERY_HOOKS.size() == 28, "stat query hook vocabulary keeps every live query publisher explicit")
	var unique_hooks: Array = []
	for hook_id in EffectHookIdsScript.MODIFIER_HOOKS:
		if not unique_hooks.has(hook_id):
			unique_hooks.append(hook_id)
	_expect(unique_hooks.size() == EffectHookIdsScript.MODIFIER_HOOKS.size(), "modifier hook vocabulary contains no duplicate IDs")


func _verify_repository_rejections() -> void:
	_expect(_case_passes("valid", {"type": "physical_damage", "target": "targets", "condition": {"type": "always"}}), "valid registered effect loads at the repository boundary")
	_expect(_case_has("unknown_type", {"type": "typo_effect"}, "UNKNOWN_EFFECT_TYPE"), "unknown effect type fails during content load")
	_expect(_case_has("unknown_stat", {"type": "modify_stat", "stat": "typo_stat"}, "UNKNOWN_EFFECT_STAT_ID"), "unknown stat ID fails during content load")
	_expect(_case_has("missing_stat_definition", {"type": "modify_stat", "stat": StatIdsScript.MAX_HP}, "MISSING_EFFECT_STAT_DEFINITION"), "known stat without a loaded Type Object fails during content load")
	_expect(_case_has("unknown_operation", {"type": "modify_stat", "stat": StatIdsScript.ATK, "operation": "typo_operation"}, "UNKNOWN_EFFECT_OPERATION"), "unknown stat operation fails during content load")
	_expect(_case_has("empty_operation", {"type": "modify_stat", "stat": StatIdsScript.ATK, "operation": "  "}, "EFFECT_OPERATION_REQUIRED"), "explicit empty operation cannot masquerade as the default")
	_expect(_case_has("adapter_scope", {"type": "modify_stat", "stat": StatIdsScript.ATK, "operation": StatOperationIdsScript.FLAT_ADD_PER_STACK}, "INVALID_EFFECT_OPERATION_SCOPE"), "status-only adapter operation is rejected outside status definitions")
	_expect(_case_has("adapter_path_collision", {"type": "modify_stat", "stat": StatIdsScript.ATK, "operation": StatOperationIdsScript.FLAT_ADD_PER_STACK}, "INVALID_EFFECT_OPERATION_SCOPE", {}, OWNER_SKILL_CATALOG, "status_catalog"), "a nested skill ID named status_catalog cannot spoof the top-level status owner")
	_expect(_case_passes("adapter_status_owner", {"type": "modify_stat", "stat": StatIdsScript.ATK, "operation": StatOperationIdsScript.FLAT_ADD_PER_STACK}, {}, EffectVocabularyScript.OWNER_STATUS_CATALOG, "status_stack"), "status-only adapter remains valid for a real top-level status definition")
	_expect(_case_has("unknown_hook", {"type": "physical_damage", "hook": "typo_hook"}, "UNKNOWN_EFFECT_HOOK", {}, EffectVocabularyScript.OWNER_TRAIT_CATALOG, "trait_unknown_hook"), "unknown effect hook fails during content load")
	_expect(_case_has("trigger_rejects_stat_hook", {"type": "physical_damage", "hook": EffectHookIdsScript.MOVEMENT}, "UNKNOWN_EFFECT_HOOK", {}, EffectVocabularyScript.OWNER_TRAIT_CATALOG, "trait_trigger"), "executable effects cannot subscribe to stat-query-only hooks")
	_expect(_case_has("trait_trigger_requires_hook", {"type": "heal", "amount": 1}, "EFFECT_HOOK_REQUIRED", {}, EffectVocabularyScript.OWNER_TRAIT_CATALOG, "trait_missing_hook"), "trait trigger effects cannot load without an explicit executable hook")
	_expect(_case_has("status_trigger_requires_hook", {"type": "heal", "amount": 1}, "EFFECT_HOOK_REQUIRED", {}, EffectVocabularyScript.OWNER_STATUS_CATALOG, "status_missing_hook"), "status trigger effects cannot load without an explicit executable hook")
	_expect(_case_passes("trait_trigger_hook", {"type": "heal", "hook": EffectHookIdsScript.ROUND_START, "amount": 1}, {}, EffectVocabularyScript.OWNER_TRAIT_CATALOG, "trait_with_hook"), "trait trigger effects load when bound to a real trigger hook")
	_expect(_case_has("skill_ignored_hook", {"type": "physical_damage", "hook": EffectHookIdsScript.SKILL}, "INVALID_EFFECT_HOOK_OWNER"), "direct skill effects cannot declare a hook the interpreter would ignore")
	_expect(_case_has("combo_ignored_hook", {"type": "physical_damage", "hook": EffectHookIdsScript.COMBO}, "INVALID_EFFECT_HOOK_OWNER", {}, EffectVocabularyScript.OWNER_SKILL_COMBO_CATALOG, "combo_ignored_hook"), "direct combo effects cannot declare a hook the interpreter would ignore")
	_expect(_case_has("relic_ignored_hook", {"type": "heal", "hook": EffectHookIdsScript.ROUND_START, "amount": 1}, "INVALID_EFFECT_HOOK_OWNER", {}, EffectVocabularyScript.OWNER_RELIC_CATALOG, "relic_ignored_hook"), "direct relic effects cannot declare a hook the interpreter would ignore")
	_expect(_case_has("unknown_target", {"type": "physical_damage", "target": "typo_target"}, "UNKNOWN_EFFECT_TARGET"), "unknown target resolver fails during content load")
	_expect(_case_has("unknown_condition", {"type": "physical_damage", "condition": {"type": "typo_condition"}}, "UNKNOWN_CONDITION_TYPE"), "unknown condition handler fails during content load")
	_expect(_case_has("empty_condition", {"type": "physical_damage", "condition": {"type": "  "}}, "CONDITION_TYPE_REQUIRED"), "explicit empty condition type cannot masquerade as always")
	_expect(_case_has("missing_condition_stat", {"type": "physical_damage", "condition": {"type": "stat_compare", "value": 1}}, "CONDITION_STAT_REQUIRED"), "condition plugin schema rejects stat_compare without a stat ID")
	_expect(_case_has("unknown_condition_stat", {"type": "physical_damage", "condition": {"type": "stat_compare", "stat": "typo_stat", "value": 1}}, "UNKNOWN_CONDITION_STAT_ID"), "condition stat IDs share the same whitelist")
	_expect(_case_has("unknown_status", {"type": "apply_status", "status_id": "status_missing"}, "UNKNOWN_EFFECT_STATUS"), "unknown status reference fails during content load")
	_expect(_case_has("generic_unknown_status", {"type": "physical_damage", "status_id": "status_missing"}, "UNKNOWN_EFFECT_STATUS"), "every explicit status_id is a checked cross-reference, regardless of effect type")
	_expect(_case_has_unknown_stat_definition(), "unknown stat Type Object IDs fail during content load")
	_verify_failed_cache_preserves_errors()
	var validator_source := FileAccess.get_file_as_string("res://core/effects/effect_content_validator.gd")
	_expect(not validator_source.contains('"stat_compare"'), "condition-specific requirements remain owned by condition plugins")


func _verify_scoped_hook_behavior() -> void:
	var effect := {
		"type": EffectVocabularyScript.TYPE_MODIFY_STAT,
		"stat": StatIdsScript.ATK,
		"operation": StatOperationIdsScript.FLAT_ADD,
		"hook": EffectHookIdsScript.MOVEMENT,
		"value": 5,
	}
	var result := _read_case("movement_modifier", effect, {}, EffectVocabularyScript.OWNER_TRAIT_CATALOG, "trait_movement")
	var data := Dictionary(result.get("data", {}))
	_expect(not data.is_empty() and Array(result.get("errors", [])).is_empty(), "a modifier using a live stat-query hook passes the repository boundary")
	if data.is_empty():
		return
	var service := TraitServiceScript.new()
	var catalog := Dictionary(data.get("trait_catalog", {}))
	var unit := {"traits": ["trait_movement"]}
	var matched := Dictionary(service.modifiers(unit, catalog, EffectHookIdsScript.MOVEMENT))
	var unmatched := Dictionary(service.modifiers(unit, catalog, EffectHookIdsScript.SNAPSHOT))
	_expect(Array(matched.get("modifiers", [])).size() == 1, "movement modifier executes at its matching StatQuery hook")
	_expect(Array(unmatched.get("modifiers", [])).is_empty(), "movement modifier does not leak into another StatQuery hook")


func _verify_runtime_modifier_hook_behavior() -> void:
	var effect := {
		"type": EffectVocabularyScript.TYPE_MODIFY_STAT,
		"stat": StatIdsScript.ATK,
		"operation": StatOperationIdsScript.FLAT_ADD,
		"hook": EffectHookIdsScript.MOVEMENT,
		"value": 5,
	}
	var result := _read_case("direct_movement_modifier", effect)
	var data := Dictionary(result.get("data", {}))
	_expect(not data.is_empty() and Array(result.get("errors", [])).is_empty(), "a direct skill modifier with a StatQuery scope passes repository validation")
	if data.is_empty():
		return
	var authority := EffectAuthority.new(data)
	authority._core_composition = CoreCompositionScript.new()
	var unit := {"id": "unit_runtime_modifier", "side": "player", "hp": 10, StatIdsScript.ATK: 10}
	var context := {
		"unit": unit,
		"definition": {"id": "skill_runtime_modifier"},
		"source_kind": EffectHookIdsScript.SKILL,
		"targets": [],
		"all_units": [unit],
	}
	var applied := Dictionary(SkillEffectPortScript.new(authority).apply_stat_modifier(context, effect))
	_expect(bool(applied.get("applied", false)) and Array(unit.get("runtime_modifiers", [])).size() == 1, "SkillEffectPort materializes the scoped effect as one runtime modifier")
	var query_service: RefCounted = authority._core_composition.stat_query_service
	var movement_value := int(query_service.value(unit, data, StatIdsScript.ATK, EffectHookIdsScript.MOVEMENT))
	var snapshot_value := int(query_service.value(unit, data, StatIdsScript.ATK, EffectHookIdsScript.SNAPSHOT))
	_expect(movement_value == 15, "runtime modifier applies at its matching StatQuery hook")
	_expect(snapshot_value == 10, "runtime modifier does not leak into a different StatQuery hook")


func _verify_legacy_trait_behavior() -> void:
	var cases := [
		{
			"name": "physical_power",
			"legacy_type": EffectVocabularyScript.LEGACY_TYPE_PHYSICAL_POWER_BONUS,
			"stat": StatIdsScript.PHYSICAL_POWER_PERMILLE,
			"value": 100,
		},
		{
			"name": "element_layer",
			"legacy_type": EffectVocabularyScript.LEGACY_TYPE_ELEMENT_LAYER_BONUS,
			"stat": StatIdsScript.ELEMENT_LAYER_BONUS,
			"value": 2,
		},
	]
	for case_value in cases:
		var case := Dictionary(case_value)
		var trait_id := "trait_legacy_%s" % String(case["name"])
		var stat_id := String(case["stat"])
		var legacy_effect := {
			"type": String(case["legacy_type"]),
			"hook": EffectHookIdsScript.SKILL,
			"value": int(case["value"]),
		}
		var stats := {}
		stats[stat_id] = {"id": stat_id, "default_value": 0}
		var result := _read_case("legacy_trait_%s" % String(case["name"]), legacy_effect, stats, EffectVocabularyScript.OWNER_TRAIT_CATALOG, trait_id)
		var data := Dictionary(result.get("data", {}))
		_expect(not data.is_empty() and Array(result.get("errors", [])).is_empty(), "%s legacy trait effect is normalized before repository validation" % case["name"])
		if data.is_empty():
			continue
		var resolved := Dictionary(TraitServiceScript.new().modifiers({"traits": [trait_id]}, Dictionary(data.get("trait_catalog", {})), EffectHookIdsScript.SKILL))
		var modifiers := Array(resolved.get("modifiers", []))
		_expect(modifiers.size() == 1, "%s legacy trait effect still produces one runtime modifier" % case["name"])
		if modifiers.is_empty():
			continue
		var modifier := Dictionary(modifiers[0])
		_expect(EffectVocabularyScript.effect_type(modifier) == EffectVocabularyScript.TYPE_MODIFY_STAT, "%s legacy trait type normalizes to modify_stat" % case["name"])
		_expect(EffectVocabularyScript.stat_id(modifier) == stat_id, "%s legacy trait type normalizes to its canonical stat ID" % case["name"])
		_expect(EffectVocabularyScript.operation_id(modifier) == StatOperationIdsScript.FLAT_ADD and int(modifier.get("value", 0)) == int(case["value"]), "%s legacy trait normalization preserves operation and value" % case["name"])


func _verify_literal_convergence() -> void:
	var parser_paths := [
		"res://core/effects/effect_interpreter.gd",
		"res://core/effects/condition_evaluator.gd",
		"res://core/effects/effect_target_resolver.gd",
		"res://core/effects/status_service.gd",
		"res://core/battle/traits/trait_service.gd",
		"res://core/stats/stat_resolver.gd",
	]
	for path in parser_paths:
		var source := FileAccess.get_file_as_string(path)
		for field in ["type", "stat", "stat_id", "operation", "hook", "target", "condition", "status_id"]:
			_expect(not source.contains('get("%s"' % field), "%s reads %s through EffectVocabulary" % [path, field])
	var stat_literal_roots := [
		"res://core/stats/consumers",
		"res://core/effects/handlers",
		"res://core/effects/conditions",
	]
	for root in stat_literal_roots:
		for path in _gd_files(root):
			var source := FileAccess.get_file_as_string(path)
			for stat_id in StatIdsScript.ALL:
				_expect(not source.contains('"%s"' % stat_id), "%s imports stat ID %s instead of a literal" % [path, stat_id])
	var hook_publisher_paths := [
		"res://core/state/game_state.gd",
		"res://core/ports/player_turn_port.gd",
		"res://core/ports/enemy_turn_port.gd",
		"res://core/ports/skill_effect_port.gd",
		"res://core/battle/skills/skill_execution_service.gd",
		"res://core/effects/effect_interpreter.gd",
		"res://core/battle/damage_resolver.gd",
		"res://core/battle/quality/quality_effect_strategy.gd",
		"res://core/battle/round_lifecycle_service.gd",
	]
	for path in hook_publisher_paths:
		var source := FileAccess.get_file_as_string(path)
		for hook_id in EffectHookIdsScript.ALL:
			_expect(not source.contains('"hook": "%s"' % hook_id), "%s publishes hook %s through the common constant" % [path, hook_id])
			_expect(not source.contains('context.get("hook", "%s")' % hook_id), "%s defaults hook %s through the common constant" % [path, hook_id])
			_expect(not source.contains('context.get("source_kind", "%s")' % hook_id), "%s defaults source kind %s through the common constant" % [path, hook_id])
			_expect(not source.contains('source_kind: String = "%s"' % hook_id), "%s declares source kind %s through the common constant" % [path, hook_id])
	for path in _gd_files("res://core/stats/consumers"):
		var source := FileAccess.get_file_as_string(path)
		if source.contains('"hook"'):
			_expect(source.contains("effect_hook_ids.gd"), "%s imports the common hook vocabulary" % path)
		for hook_id in EffectHookIdsScript.ALL:
			_expect(not source.contains('"hook": "%s"' % hook_id), "%s publishes hook %s through the common constant" % [path, hook_id])


func _case_passes(
	case_name: String,
	effect: Dictionary,
	stats: Dictionary = {},
	owner_scope: String = OWNER_SKILL_CATALOG,
	entity_id: String = "skill_fixture"
) -> bool:
	var result := _read_case(case_name, effect, stats, owner_scope, entity_id)
	return not Dictionary(result.get("data", {})).is_empty() and Array(result.get("errors", [])).is_empty()


func _case_has(
	case_name: String,
	effect: Dictionary,
	code: String,
	stats: Dictionary = {},
	owner_scope: String = OWNER_SKILL_CATALOG,
	entity_id: String = "skill_fixture"
) -> bool:
	var result := _read_case(case_name, effect, stats, owner_scope, entity_id)
	return Dictionary(result.get("data", {})).is_empty() and _has_code(Array(result.get("errors", [])), code)


func _case_has_unknown_stat_definition() -> bool:
	var result := _read_case("unknown_stat_definition", {"type": "physical_damage"}, {"future_stat": {"id": "future_stat"}})
	return Dictionary(result.get("data", {})).is_empty() and _has_code(Array(result.get("errors", [])), "UNKNOWN_STAT_DEFINITION")


func _verify_failed_cache_preserves_errors() -> void:
	var case_path := _write_case("cached_invalid", {"type": "typo_effect"})
	var repository := GameDataRepositoryScript.new()
	var first := Dictionary(repository.read_content_pack(case_path))
	var first_errors: Array = repository.content_errors()
	var second := Dictionary(repository.read_content_pack(case_path))
	var second_errors: Array = repository.content_errors()
	_expect(first.is_empty() and second.is_empty(), "invalid semantic content is never cached as successful data")
	_expect(first_errors == second_errors and _has_code(second_errors, "UNKNOWN_EFFECT_TYPE"), "cached rejection preserves deterministic semantic errors")


func _read_case(
	case_name: String,
	effect: Dictionary,
	stats: Dictionary = {},
	owner_scope: String = OWNER_SKILL_CATALOG,
	entity_id: String = "skill_fixture"
) -> Dictionary:
	var case_path := _write_case(case_name, effect, stats, owner_scope, entity_id)
	var repository := GameDataRepositoryScript.new()
	var data := Dictionary(repository.read_content_pack(case_path))
	return {"data": data, "errors": repository.content_errors()}


func _write_case(
	case_name: String,
	effect: Dictionary,
	stats: Dictionary = {},
	owner_scope: String = OWNER_SKILL_CATALOG,
	entity_id: String = "skill_fixture"
) -> String:
	var case_path := _fixture_root.path_join(case_name)
	var absolute := ProjectSettings.globalize_path(case_path)
	DirAccess.make_dir_recursive_absolute(absolute)
	var stat_catalog := stats.duplicate(true)
	if stat_catalog.is_empty():
		stat_catalog[StatIdsScript.ATK] = {"id": StatIdsScript.ATK, "default_value": 0}
	var status_catalog := {"status_ok": {"id": "status_ok", "effects": []}}
	var skill_catalog := {}
	var skill_combo_catalog := {}
	var trait_catalog := {}
	var economy := {"relics": []}
	var definition := {"id": entity_id, "effects": [effect]}
	match owner_scope:
		EffectVocabularyScript.OWNER_STATUS_CATALOG:
			status_catalog[entity_id] = definition
		EffectVocabularyScript.OWNER_TRAIT_CATALOG:
			trait_catalog[entity_id] = definition
		EffectVocabularyScript.OWNER_SKILL_COMBO_CATALOG:
			skill_combo_catalog[entity_id] = definition
		EffectVocabularyScript.OWNER_RELIC_CATALOG:
			economy["relics"] = [definition]
		_:
			skill_catalog[entity_id] = definition
	var package := {
		"schema": "ysbzs.content-package.v1",
		"package_id": "fixture.%s" % case_name,
		"priority": 0,
		"order": 0,
		"operations": [
			{"op": "set", "path": ["stat_catalog"], "value": stat_catalog},
			{"op": "set", "path": ["status_catalog"], "value": status_catalog},
			{"op": "set", "path": ["skill_catalog"], "value": skill_catalog},
			{"op": "set", "path": ["skill_combo_catalog"], "value": skill_combo_catalog},
			{"op": "set", "path": ["trait_catalog"], "value": trait_catalog},
			{"op": "set", "path": ["economy"], "value": economy},
		],
	}
	var file := FileAccess.open(case_path.path_join("content.json"), FileAccess.WRITE)
	if file == null:
		failed = true
		push_error("Smoke failed: cannot write fixture %s" % case_path)
		return case_path
	file.store_string(JSON.stringify(package))
	file.close()
	return case_path


func _gd_files(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if not name.begins_with("."):
			var child := root.path_join(name)
			if directory.current_is_dir():
				result.append_array(_gd_files(child))
			elif name.ends_with(".gd"):
				result.append(child)
		name = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result


func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name != "." and name != "..":
			var child := absolute.path_join(name)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)


func _has_code(errors: Array, code: String) -> bool:
	for value in errors:
		if String(value).begins_with("%s:" % code):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
