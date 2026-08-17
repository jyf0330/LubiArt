extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const PolicyScript := preload("res://core/battle/auto_position/auto_position_policy.gd")

const PLANNER_PATH := "res://core/battle/auto_position/auto_position_planner.gd"
const POLICY_PATH := "res://core/battle/auto_position/auto_position_policy.gd"
const READ_PORT_PATH := "res://core/battle/auto_position/auto_position_read_port.gd"
const EVALUATOR_PATH := "res://core/battle/auto_position/auto_position_evaluator.gd"
const TURN_OPTIMIZER_PATH := "res://core/battle/auto_position/auto_position_turn_optimizer.gd"
const BATTLE_RULES_PATH := "res://core/state/game_state.gd"

var failed := false


func _initialize() -> void:
	var planner_source := FileAccess.get_file_as_string(PLANNER_PATH)
	var policy_source := FileAccess.get_file_as_string(POLICY_PATH)
	var read_port_source := FileAccess.get_file_as_string(READ_PORT_PATH)
	var evaluator_source := FileAccess.get_file_as_string(EVALUATOR_PATH)
	var turn_optimizer_source := FileAccess.get_file_as_string(TURN_OPTIMIZER_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE_RULES_PATH)
	_expect(planner_source.begins_with("extends RefCounted"), "planner is a composed RefCounted service")
	_expect(policy_source.begins_with("extends RefCounted"), "policy is a composed RefCounted strategy")
	_expect(read_port_source.begins_with("extends RefCounted"), "read port is independent from the state inheritance chain")
	_expect(evaluator_source.begins_with("extends RefCounted"), "evaluator is a composed RefCounted value service")
	_expect(turn_optimizer_source.begins_with("extends RefCounted"), "turn optimizer is a composed RefCounted service")
	for source in [planner_source, policy_source, read_port_source, evaluator_source, turn_optimizer_source]:
		_expect(not source.contains("extends \"res://core/state/"), "auto-position service does not inherit a state layer")
		_expect(not source.contains("extends \"res://persistence/compatibility/"), "auto-position service does not inherit the persistence compatibility layer")
		_expect(not source.contains("class_name YsbzsState"), "auto-position service does not redefine the public facade")
	for forbidden in ["_apply_auto_position_moves_atomically", "move_selected(", "auto_position_action_plan =", "action_dirs["]:
		_expect(not planner_source.contains(forbidden), "planner does not mutate authoritative battle state: %s" % forbidden)
		_expect(not turn_optimizer_source.contains(forbidden), "turn optimizer does not mutate authoritative battle state: %s" % forbidden)
	_expect(planner_source.contains("_turn_optimizer.optimize"), "planner separates placement search from AP action optimization")
	_expect(planner_source.contains("beams = read_port.decorate_finalists(beams, side)"), "planner receives a detached retaliation-decorated finalist list")
	_expect(not read_port_source.contains("_core.call") and not read_port_source.contains("_core.get"), "read port has no reflective whole-state access")
	_expect(read_port_source.contains("func _init(context: Dictionary, evaluator: RefCounted)"), "read port accepts only value context plus evaluator")
	_expect(read_port_source.contains("_context = context.duplicate(true)"), "read port owns a detached value-context copy")
	for method_name in ["sorted_units", "effective_move_range", "candidates_for_unit", "choices_conflict", "optimization_context", "decorate_finalists"]:
		_expect(evaluator_source.contains("func %s(" % method_name), "evaluator publishes %s" % method_name)
	_expect(battle_source.contains("AutoPositionReadPortScript.new(context, _core_composition.auto_position_evaluator)"), "facade delegates planning through value context and the composed evaluator")
	_expect(not battle_source.contains("_auto_position_policy_service"), "facade no longer owns auto-position ordering policy")
	for moved_method in [
		"_auto_position_cells_for_unit", "_has_living_non_boss_enemy", "_auto_position_damage_allocation",
		"_auto_position_damage_metrics", "_auto_position_current_approach_distance", "_auto_position_approach_distance",
		"_auto_position_directions_for_slot", "_auto_position_candidates_for_unit", "_auto_position_choices_conflict",
		"_auto_position_choice_positions", "_auto_position_retaliation_summary", "_auto_position_projected_player_states",
		"_auto_position_on_death_incoming", "_auto_position_retaliation_metrics", "_auto_position_attach_retaliation_to_final_beams",
		"_auto_position_candidate_is_better", "_auto_position_target_signature", "_auto_position_enemy_response_is_better",
		"_auto_position_evaluation_is_better", "_auto_position_prune_beams",
	]:
		_expect(not battle_source.contains("func %s(" % moved_method), "facade no longer defines %s" % moved_method)

	var policy := PolicyScript.new()
	var normal_mode := policy.mode("player", "player", "normal", "easy", false)
	var easy_mode := policy.mode("player", "player", "easy", "easy", false)
	_expect(not bool(normal_mode.get("allowDirectionChanges", true)), "normal policy preserves player direction")
	_expect(bool(easy_mode.get("allowDirectionChanges", false)), "easy policy optimizes player direction")

	var state := StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "composition fixture starts battle")
	var plan := Dictionary(state.call("_build_auto_position_plan"))
	_expect(String(plan.get("objective", "")) == "max_kills_then_effective_damage", "composed planner returns the stable objective")
	_expect(String(plan.get("decisionModel", "")) == "placement_ap_lookahead_v2", "planner reports the AP lookahead decision model")
	_expect(int(plan.get("resultCount", 0)) == 1, "composed planner returns one canonical plan")
	var sandbox := Dictionary(plan.get("sandbox", {}))
	_expect(sandbox.has("evaluatedPlans"), "composed planner preserves deterministic search diagnostics")
	_expect(int(sandbox.get("actionSubsetsEvaluated", 0)) >= 1, "planner reports exact AP action subsets")
	_expect(int(sandbox.get("retaliationFinalistsEvaluated", 0)) >= int(sandbox.get("survivalFinalistLimit", 1)), "retaliation evaluates a risk shortlist before final survival pruning")
	if failed:
		quit(1)
		return
	print("SMOKE_AUTO_POSITION_PLANNER_COMPOSITION_OK moves=%d actions=%d" % [
		Array(plan.get("moves", [])).size(),
		Array(plan.get("actions", [])).size()
	])
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
