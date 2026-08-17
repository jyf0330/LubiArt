extends SceneTree

const SeededSelectorScript := preload("res://core/run/seeded_selector.gd")
const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")
const UnitVitalsScript := preload("res://core/battle/unit_vitals.gd")
const BattleTraceFactoryScript := preload("res://core/battle/battle_trace_factory.gd")
const ReplayBuilderScript := preload("res://persistence/replay_builder.gd")
const RouteRulesScript := preload("res://core/route/route_rules.gd")
const EconomyRulesScript := preload("res://core/economy/economy_rules.gd")
const QualityRulesScript := preload("res://core/party/quality_rules.gd")
const RosterSlotRulesScript := preload("res://core/party/roster_slot_rules.gd")

var _failed := false


func _initialize() -> void:
	var random_a := SeededSelectorScript.rng("stable")
	var random_b := SeededSelectorScript.rng("stable")
	_expect(SeededSelectorScript.next(random_a) == SeededSelectorScript.next(random_b), "seeded selector is deterministic")
	var cells: Array = [{"x": 2, "y": 2}]
	_expect(ShapeGeometryScript.append_unique_cell(cells, 3, 2, 8, 7), "shape geometry appends an in-bounds cell")
	_expect(not ShapeGeometryScript.append_unique_cell(cells, 8, 2, 8, 7), "shape geometry rejects an out-of-bounds cell")
	_expect(ShapeGeometryScript.normalize_direction("上") == "up", "shape geometry normalizes localized direction")
	var unit := {"hp": 4, "max_hp": 10}
	_expect(UnitVitalsScript.heal(unit, 3) == 3 and int(unit.get("hp", 0)) == 7, "unit vitals applies bounded healing")
	var damage_trace := BattleTraceFactoryScript.damage_event(
		1,
		2,
		"battle",
		{"id": "p1", "name": "甲", "side": "player"},
		{"id": "e1", "name": "乙", "side": "enemy"},
		5,
		2,
		3,
		10,
		7,
		2,
		0,
		"fire",
		{"sourceType": "action"}
	)
	_expect(String(damage_trace.get("protocol", "")).contains("|hp=3|shield=2|element=fire"), "battle trace factory preserves damage protocol")
	_expect(QualityRulesScript.next("白银", ["青铜", "白银", "黄金", "钻石"]) == "黄金", "quality rules advance known quality")
	var roster: Array = [{"active": true, "slot": 1}, {"active": false, "bag_slot": 1}]
	_expect(RosterSlotRulesScript.next_active_slot(roster, 2) == 2, "roster slot rules allocate active slots")
	_expect(RosterSlotRulesScript.next_bag_slot(roster, 3) == 2, "roster slot rules allocate bag slots")
	var command_log := [{
		"command": {"type": "START_BATTLE"},
		"beforeVersion": 0,
		"beforeHash": "a",
		"afterVersion": 1,
		"afterHash": "b",
		"round": 1,
		"afterPhase": "battle"
	}]
	var stream := ReplayBuilderScript.command_stream(command_log)
	_expect(stream.size() == 1 and int(Dictionary(stream[0]).get("index", 0)) == 1, "replay builder projects command stream")
	_expect(ReplayBuilderScript.battle_trace(command_log).size() == 1, "replay builder projects fallback battle trace")
	_expect(RouteRulesScript.day_expression_allows("D2-D4", 3), "route rules evaluate day ranges")
	_expect(not RouteRulesScript.day_expression_allows("D2-D4", 5), "route rules reject days outside ranges")
	_expect(EconomyRulesScript.reward_pool_for_battle("WIN_FAST", 1) == "reward_fast_clear", "economy rules choose fast-clear reward")
	_expect(EconomyRulesScript.tier_reward_pool_for_day(2) == "reward_pT1", "economy rules keep early rewards in tier one")
	_expect(EconomyRulesScript.tier_reward_pool_for_day(3) == "reward_pT2", "economy rules advance day-three rewards to tier two")
	_expect(EconomyRulesScript.reward_multiplier_from_event({"cost": "奖励 - 10%"}) == 90, "economy rules parse reward risk from event cost")
	_expect(EconomyRulesScript.reward_multiplier_from_event({"option_text": "奖励-125%"}) == 0, "economy rules clamp an over-100-percent reduction")
	_expect(EconomyRulesScript.reward_multiplier_from_event({"cost": "金币 - 2"}) == 100, "economy rules default unrelated events to full rewards")
	_expect(EconomyRulesScript.apply_reward_gold_multiplier(6, 90) == 5, "economy rules floor fractional reward gold deterministically")
	_expect(EconomyRulesScript.apply_reward_gold_multiplier(-2, 90) == 0, "economy rules never return negative reward gold")
	if _failed:
		quit(1)
		return
	print("SMOKE_EXTRACTED_CORE_SERVICES_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Smoke failed: %s" % message)
