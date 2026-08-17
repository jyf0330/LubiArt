extends SceneTree

const QualityRegistryScript := preload("res://core/battle/quality/quality_effect_registry.gd")
const LegacyQualityCatalogScript := preload("res://core/battle/quality/legacy_quality_runtime_catalog.gd")
const TargetingServiceScript := preload("res://core/battle/targeting_service.gd")
const ElementFieldServiceScript := preload("res://core/battle/element_field_service.gd")
const PetResetPolicyScript := preload("res://core/battle/pet_reset_policy.gd")
const BattleOutcomePolicyScript := preload("res://core/battle/battle_outcome_policy.gd")
const BattleStartupServiceScript := preload("res://core/battle/battle_startup_service.gd")

var failed := false


func _initialize() -> void:
	var quality = _legacy_quality_registry()
	var g03_context := {
		"damage": 5,
		"core_cell": true,
	}
	_expect(quality.effect_for_id("G03").modify_hit_damage(g03_context) == 8, "G03 damage strategy adds core-cell bonus")
	var d17_context := {"damage": 5}
	_expect(quality.effect_for_id("D17").modify_hit_damage(d17_context) == 8, "D17 damage strategy keeps ceil 1.5 scaling")
	_expect(
		quality.effect_for_id("G02").modify_hit_damage({"damage": 5, "mode": "爆", "first_hit": true}) == 9,
		"G02 burst strategy preserves first-hit bonus"
	)
	_expect(
		quality.effect_for_id("G02").modify_hit_damage({"damage": 5, "mode": "爆", "first_hit": false}) == 5,
		"G02 burst strategy preserves no follow-up bonus"
	)

	var field := {}
	var element_service = ElementFieldServiceScript.new()
	var normalize := func(value: Dictionary) -> Dictionary: return value.duplicate(true)
	element_service.add_to_field(field, "1,2", "火", 2, normalize)
	element_service.add_to_field(field, "1,2", "火", 1, normalize)
	_expect(int(Dictionary(field.get("1,2", {})).get("火", 0)) == 3, "element field service stacks layers")
	element_service.clear_from_field(field, "1,2", "火", normalize)
	_expect(not element_service.has_active_element(Dictionary(field.get("1,2", {}))), "element field service clears active layer")

	var targeting = TargetingServiceScript.new()
	var option := {"cells": [{"x": 1, "y": 0}, {"x": 2, "y": 0}]}
	var targets := targeting.targets_in_option(
		{"side": "player"},
		option,
		[
			{"id": "high", "side": "enemy", "x": 1, "y": 0, "hp": 9},
			{"id": "low", "side": "enemy", "x": 2, "y": 0, "hp": 3},
		],
		{},
		"enemy"
	)
	quality.effect_for_id("D19").sort_targets(targets, option)
	_expect(String(Dictionary(targets[0]).get("id", "")) == "low", "D19 strategy applies low-HP order")

	var reset_policy = PetResetPolicyScript.new()
	var charges := {"player": 0, "enemy": 0}
	var next_round := {"player": 5, "enemy": 5}
	var grants := reset_policy.grant_for_round(["player", "enemy"], 5, 5, charges, next_round)
	_expect(grants.size() == 2 and int(charges["player"]) == 1 and int(next_round["player"]) == 10, "reset policy grants both sides on round five")
	_expect(reset_policy.is_eligible(2, 0, 1, 2), "reset policy accepts first reset threshold")
	var placement_seed := "pet_reset:seed:player:1:5:night:0"
	var first_placement := reset_policy.select_cells(
		Vector2i(8, 7),
		true,
		4,
		{"1,6": true},
		{"2,5": true},
		placement_seed
	)
	var repeated_placement := reset_policy.select_cells(
		Vector2i(8, 7),
		true,
		4,
		{"1,6": true},
		{"2,5": true},
		placement_seed
	)
	_expect(first_placement == repeated_placement, "reset placement is deterministic for the same seed")
	_expect(first_placement.size() >= 4, "reset placement expands the zone when the 3x3 region has a trap")
	_expect(not first_placement.has(Vector2i(0, 6)), "reset placement excludes the player leader cell")
	_expect(not first_placement.has(Vector2i(1, 6)), "reset placement excludes occupied cells")
	_expect(not first_placement.has(Vector2i(2, 5)), "reset placement excludes element traps")
	var enemy_placement := reset_policy.select_cells(Vector2i(8, 7), false, 1, {}, {}, "enemy-reset")
	_expect(not enemy_placement.has(Vector2i(7, 0)), "reset placement excludes the enemy leader cell")

	var outcome = BattleOutcomePolicyScript.new()
	var draw := outcome.terminal_reason(20, 20, 12, 12, true)
	_expect(bool(draw.get("draw", false)), "outcome policy resolves round-limit draw")
	_expect(String(outcome.base_result(true, false, "", 5).get("code", "")) == "WIN_FAST", "outcome policy preserves fast win")
	var failure_result := outcome.assemble_result({
		"win": false,
		"code": "LOSE",
		"grade": "D",
		"reason": "round_limit",
		"hero_hp_from": 20,
		"hero_hp_to": 17,
		"enemy_hero_hp": 19,
		"castle_line_from": 3,
		"castle_line_to": 2,
		"economy_multiplier_from": 1.0,
		"economy_multiplier_to": 0.9,
		"gold_base_delta": 1,
		"gold_delta": 1,
		"post_battle_events": [{"id": "failure_event"}],
	})
	_expect(int(Dictionary(failure_result.get("failure_audit", {})).get("hero_hp_penalty", 0)) == 3, "outcome policy owns the failure audit")
	_expect(int(Dictionary(Array(failure_result.get("post_battle_events", []))[0]).get("castleLineFrom", -1)) == 3, "outcome policy enriches failure event compatibility fields")
	var fallback_result := outcome.assemble_result({
		"win": true,
		"draw": false,
		"reward_pool_id": "fallback_pool",
		"event_reward_pool_id": "empty_pool",
	})
	_expect(bool(fallback_result.get("reward_fallback", false)) and bool(fallback_result.get("reward_eligible", false)), "outcome policy owns reward eligibility and fallback flags")

	var startup = BattleStartupServiceScript.new()
	var enemy_templates := startup.select_enemy_templates({
		"waves": [{
			"day": 2,
			"period": "中午",
			"enemies": [
				{"id": "enemy_a", "source_pet_id": "enemy_a"},
				{"id": "enemy_a_copy", "source_pet_id": "enemy_a"},
				{"id": "enemy_b", "source_pet_id": "enemy_b"},
			],
		}],
	}, 2, "中午", 4)
	_expect(enemy_templates.size() == 2, "startup service deduplicates enemy templates")
	var deployment := startup.prepare_player_deployment(
		[{"id": "pet_a", "hp": 5, "max_hp": 5}],
		[Vector2i(1, 2)],
		4,
		{
			"player_side": "player",
			"deploy_cell": func(_pet: Dictionary, fallback: Vector2i, _used: Dictionary) -> Vector2i: return fallback,
			"cell_key": func(x: int, y: int) -> String: return "%d,%d" % [x, y],
			"battle_start_mechanics": func(_pet: Dictionary) -> Array: return ["started"],
		}
	)
	_expect(
		deployment.size() == 1 \
			and Vector2i(int(Dictionary(Dictionary(deployment[0]).get("unit", {})).get("x", -1)), int(Dictionary(Dictionary(deployment[0]).get("unit", {})).get("y", -1))) == Vector2i(1, 2),
		"startup service prepares player deployment"
	)

	if failed:
		quit(1)
		return
	print("SMOKE_BATTLE_SERVICE_SPLIT_OK")
	quit(0)


func _legacy_quality_registry() -> QualityEffectRegistry:
	var registry: QualityEffectRegistry = QualityRegistryScript.new()
	var prepared := registry.prepare_configuration(
		LegacyQualityCatalogScript.upgrades(),
		0,
		QualityRegistryScript.PERSISTED_SNAPSHOT
	)
	_expect(bool(prepared.get("ok", false)), "legacy quality fixture prepares")
	registry.commit_configuration(Dictionary(prepared.get("candidate", {})))
	_expect(registry.is_configured(), "legacy quality fixture commits")
	return registry


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
