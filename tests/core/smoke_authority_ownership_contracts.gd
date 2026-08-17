extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const ContentSourceConfigScript := preload("res://core/content/content_source_config.gd")
const AutoPositionConfigScript := preload("res://core/battle/auto_position/auto_position_config.gd")
const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")
const LegacySkillCatalogScript := preload("res://core/battle/skills/legacy_skill_catalog.gd")
const QualityRulesScript := preload("res://core/party/quality_rules.gd")
const PersistenceConfigScript := preload("res://persistence/persistence_config.gd")
const ReplayContractScript := preload("res://persistence/replay_contract.gd")
const SaveContractScript := preload("res://persistence/save_contract.gd")

var failed := false


func _initialize() -> void:
	_test_battle_mechanic_ownership()
	_expect(StateScript.DATA_PATH == ContentSourceConfigScript.CONTENT_PACK_PATH, "state content path remains a compatibility alias")
	_expect(StateScript.BAZAAR_DAY1_CATALOG_PATH == ContentSourceConfigScript.BAZAAR_DAY1_CATALOG_PATH, "supplement path belongs to content source config")
	_expect(StateScript.SAVE_PATH == PersistenceConfigScript.SAVE_PATH and StateScript.REPLAY_PATH == PersistenceConfigScript.REPLAY_PATH, "state storage paths remain compatible aliases")
	_expect(StateScript.SAVE_SCHEMA == SaveContractScript.SCHEMA and StateScript.SAVE_SCHEMA_VERSION == SaveContractScript.SCHEMA_VERSION, "save contract owns schema identity")
	_expect(StateScript.REPLAY_SCHEMA == ReplayContractScript.SCHEMA and StateScript.COMMAND_REPLAY_VERSION == ReplayContractScript.COMMAND_VERSION, "replay contract owns schema and command version")
	_expect(StateScript.QUALITY_ORDER == QualityRulesScript.ORDER and StateScript.QUALITY_EVOLUTION_POINT_TOTALS == QualityRulesScript.EVOLUTION_POINT_TOTALS, "quality rules own vocabulary and evolution totals")
	_expect(QualityRulesScript.normalize("gold") == "黄金" and QualityRulesScript.next("黄金") == "钻石", "quality behavior is unchanged")
	_expect(StateScript.ACTIVE_ELEMENTS == ElementRulesScript.ACTIVE_ELEMENTS and ElementRulesScript.canonical("earth") == "地", "element rules own vocabulary and aliases")
	_expect(ElementRulesScript.empty_layers().keys().size() == ElementRulesScript.ACTIVE_ELEMENTS.size(), "element empty projection covers every canonical element")
	_expect(StateScript.SKILL_LABELS == LegacySkillCatalogScript.LABELS and String(LegacySkillCatalogScript.snapshot_entries().get("buffAllSummons", {}).get("name", "")) == "召唤强化", "legacy skill metadata is projected by its catalog owner")
	var auto_defaults := AutoPositionConfigScript.defaults()
	_expect(int(auto_defaults.get("candidateLimit", 0)) == 32 and int(auto_defaults.get("beamWidth", 0)) == 128, "auto-position deterministic thresholds keep their values")
	_expect(StateScript.AUTO_POSITION_CANDIDATE_LIMIT == AutoPositionConfigScript.CANDIDATE_LIMIT, "state auto-position constant remains a compatibility alias")
	var slot_config := PersistenceConfigScript.save_slot_config()
	_expect(int(slot_config.get("slotCount", 0)) == 3 and Array(slot_config.get("legacyPaths", [])).size() == 2, "persistence config assembles repository slot inputs")
	if failed:
		quit(1)
		return
	print("SMOKE_AUTHORITY_OWNERSHIP_CONTRACTS_OK")
	quit(0)


func _test_battle_mechanic_ownership() -> void:
	var battle_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	var resolver_source := FileAccess.get_file_as_string("res://core/battle/damage_resolver.gd")
	_expect(not FileAccess.file_exists("res://core/party/catalog_roster_core.gd"), "party compatibility layer stays deleted")
	for method_name in [
		"_apply_mechanic_battle_start",
		"_apply_mechanic_round_start",
		"_apply_mechanic_round_end",
		"_apply_mechanic_before_damage",
		"_apply_mechanic_after_damage",
		"_apply_mechanic_on_shield_break",
		"_apply_mechanic_after_hit",
		"_apply_attacker_mechanic_after_hit",
		"_apply_mechanic_on_death",
		"_apply_mechanic_after_ally_death",
		"_apply_attacker_mechanic_after_kill",
		"_apply_mechanic_after_action",
		"_apply_mechanic_after_element_apply",
		"_apply_mechanic_battle_end",
	]:
		_expect(battle_source.contains("func %s" % method_name), "single authority exposes the %s adapter" % method_name)
	_expect(resolver_source.contains("ysbzs.damage-resolution-port.v2"), "damage pipeline depends on one versioned capability port")
	_expect(not resolver_source.contains("callbacks: Dictionary") and not resolver_source.contains("Callable(self"), "damage pipeline no longer receives an unversioned callback bag")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
