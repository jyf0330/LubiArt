extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const PLAN_TIME_BUDGET_MS := 3500.0

var failed := false


func _initialize() -> void:
	var state := StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "search-precision fixture can start battle")
	var player_template := state.unit_by_id("pal_002").duplicate(true)
	var enemy_template := _first_enemy(state).duplicate(true)
	_expect(not player_template.is_empty() and not enemy_template.is_empty(), "search-precision fixture has player and enemy templates")
	if failed:
		quit(1)
		return
	state.units.clear()
	var player_positions := [Vector2i(0, 5), Vector2i(2, 5), Vector2i(4, 5), Vector2i(6, 5)]
	for index in range(player_positions.size()):
		var player := player_template.duplicate(true)
		player["id"] = "precision_player_%d" % index
		player["name"] = "精度测试宠物%d" % index
		player["side"] = StateScript.PLAYER
		player["x"] = player_positions[index].x
		player["y"] = player_positions[index].y
		player["hp"] = 30
		player["max_hp"] = 30
		player["atk"] = 10
		player["shape_id"] = "01"
		player["shape_name"] = "形状01"
		player["move_range"] = 14
		player["moveRange"] = 14
		player["slot_count"] = 3
		player["has_attacked"] = false
		player["action_slots_used"] = {}
		state.units.append(player)
	var enemy_positions := [Vector2i(1, 1), Vector2i(3, 1), Vector2i(5, 1), Vector2i(7, 1), Vector2i(2, 3), Vector2i(6, 3)]
	for index in range(enemy_positions.size()):
		var enemy := enemy_template.duplicate(true)
		enemy["id"] = "precision_enemy_%d" % index
		enemy["name"] = "精度测试敌人%d" % index
		enemy["side"] = StateScript.ENEMY
		enemy["x"] = enemy_positions[index].x
		enemy["y"] = enemy_positions[index].y
		enemy["hp"] = 50
		enemy["max_hp"] = 50
		enemy["shield"] = 0
		enemy["def"] = 0
		enemy["role"] = "minion"
		enemy["type"] = "pet"
		enemy.erase("is_boss")
		enemy.erase("isBoss")
		enemy.erase("boss")
		state.units.append(enemy)
	var started_usec := Time.get_ticks_usec()
	var plan := Dictionary(state.call("_build_auto_position_plan"))
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var sandbox := Dictionary(plan.get("sandbox", {}))
	var candidate_counts := Array(sandbox.get("candidateCounts", []))
	print("AUTO_POSITION_PERF_BREAKDOWN %s" % JSON.stringify(sandbox))
	_expect(int(sandbox.get("candidateLimit", 0)) == 32, "auto-position keeps 32 candidates per pet")
	_expect(int(sandbox.get("targetSignatureLimit", 0)) == 6, "auto-position keeps six alternatives for the same target signature")
	_expect(int(sandbox.get("beamWidth", 0)) == 128, "auto-position evaluates a 128-wide team beam")
	_expect(candidate_counts.size() == 4, "search-precision fixture evaluates all four player pets")
	_expect(_max_int(candidate_counts) > 17, "search-precision fixture retains more candidates than the previous 16-plus-skip cap")
	_expect(int(sandbox.get("evaluatedPlans", 0)) > 40, "search-precision fixture evaluates beyond the previous beam width")
	_expect(elapsed_ms < PLAN_TIME_BUDGET_MS, "search-precision plan completes within %.0fms, got %.2fms" % [PLAN_TIME_BUDGET_MS, elapsed_ms])
	if failed:
		quit(1)
		return
	print("SMOKE_AUTO_POSITION_SEARCH_PRECISION_OK elapsed_ms=%.2f candidates=%s plans=%d" % [elapsed_ms, candidate_counts, int(sandbox.get("evaluatedPlans", 0))])
	quit(0)


func _first_enemy(state: RefCounted) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			return unit
	return {}


func _max_int(values: Array) -> int:
	var result := 0
	for value in values:
		result = max(result, int(value))
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
