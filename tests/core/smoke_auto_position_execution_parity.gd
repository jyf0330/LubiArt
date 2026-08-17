extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const AutoPositionTestContextScript := preload("res://tests/helpers/auto_position_test_context.gd")

var failed := false


func _initialize() -> void:
	_test_planned_direction_is_executed()
	_test_skill_damage_is_scored_with_equal_kill_count()
	_test_colliding_approach_keeps_a_legal_team_plan()
	if failed:
		quit(1)
		return
	print("SMOKE_AUTO_POSITION_EXECUTION_PARITY_OK")
	quit(0)


func _test_planned_direction_is_executed() -> void:
	var fixture := _direction_fixture(false)
	var state = fixture["state"]
	var actor_id := String(fixture["actor_id"])
	var left_id := String(fixture["left_id"])
	var right_id := String(fixture["right_id"])
	_expect(state.dispatch({"type": "AUTO_POSITION_HEROES"}), "direction fixture accepts auto position")
	_expect(String(state.action_dirs.get("%s:slot0" % actor_id, "")) == "right", "auto position plans the three-strike lethal right direction")
	state.ap = 1
	_expect(state.dispatch({"type": "RUN_PLAYER_ALL_OUT"}), "direction fixture accepts player all-out")
	_expect(int(state.unit_by_id(right_id).get("hp", 0)) == 0, "player all-out executes the planned lethal right direction")
	_expect(int(state.unit_by_id(left_id).get("hp", 0)) == 40, "player all-out does not replace the plan with a nonlethal left target")


func _test_skill_damage_is_scored_with_equal_kill_count() -> void:
	var fixture := _direction_fixture(true)
	var state = fixture["state"]
	var actor: Dictionary = state.unit_by_id(String(fixture["actor_id"]))
	var left: Dictionary = state.unit_by_id(String(fixture["left_id"]))
	actor["skill"] = ""
	var base_candidate := _candidate_for(
		AutoPositionTestContextScript.candidates(state, actor, _stationary_candidate_options()),
		actor,
		"left",
		String(left.get("id", ""))
	)
	var base_plan := Dictionary(state.call("_build_auto_position_plan"))
	actor["skill"] = "spaceExplosionBonus"
	var skill_candidate := _candidate_for(
		AutoPositionTestContextScript.candidates(state, actor, _stationary_candidate_options()),
		actor,
		"left",
		String(left.get("id", ""))
	)
	var skill_plan := Dictionary(state.call("_build_auto_position_plan"))
	var base_damage := int(Dictionary(base_candidate.get("damageByTarget", {})).get(String(left.get("id", "")), 0))
	var skill_damage := int(Dictionary(skill_candidate.get("damageByTarget", {})).get(String(left.get("id", "")), 0))
	_expect(skill_damage > base_damage, "auto-position damage metrics include the real action skill bonus")
	_expect(String(Dictionary(Array(base_plan.get("directions", []))[0]).get("dir", "")) == "right", "equal-kill base plan chooses the higher-damage right target")
	_expect(String(Dictionary(Array(skill_plan.get("directions", []))[0]).get("dir", "")) == "right", "equal-kill skill plan still chooses the higher-damage right target")
	_expect(int(skill_plan.get("effectiveDamage", 0)) > int(base_plan.get("effectiveDamage", 0)), "skill damage raises the selected equal-kill plan score")


func _test_colliding_approach_keeps_a_legal_team_plan() -> void:
	var fixture := _approach_fixture()
	var state = fixture["state"]
	var first: Dictionary = state.unit_by_id("approach_a")
	var second: Dictionary = state.unit_by_id("approach_b")
	var first_candidates := AutoPositionTestContextScript.candidates(state, first)
	var second_candidates := AutoPositionTestContextScript.candidates(state, second)
	_expect(first_candidates.size() > 2 and second_candidates.size() > 2, "distant pets retain multiple approach alternatives plus skip")
	var plan := Dictionary(state.call("_build_auto_position_plan"))
	var moves := Array(plan.get("moves", []))
	_expect(moves.size() == 2, "both distant pets keep legal approach moves")
	var target_keys := {}
	for move_value in moves:
		var to := Dictionary(Dictionary(move_value).get("to", {}))
		var key := "%d,%d" % [int(to.get("x", -1)), int(to.get("y", -1))]
		_expect(not target_keys.has(key), "distant-team approach alternatives keep final cells distinct")
		target_keys[key] = true


func _direction_fixture(with_skill: bool) -> Dictionary:
	var state := StateScript.new()
	state.set_difficulty(StateScript.DIFFICULTY_EASY)
	_expect(state.dispatch({"type": "START_BATTLE"}), "direction fixture starts battle")
	var actor := state.unit_by_id("pal_002").duplicate(true)
	var enemy_templates := _enemy_templates(state, 2)
	_expect(not actor.is_empty() and enemy_templates.size() == 2, "direction fixture has actor and enemy templates")
	state.units.clear()
	actor["id"] = "parity_actor"
	actor["name"] = "计划执行测试宠物"
	actor["side"] = StateScript.PLAYER
	actor["x"] = 3
	actor["y"] = 5
	actor["hp"] = 30
	actor["max_hp"] = 30
	actor["atk"] = 4 if with_skill else 10
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["move_range"] = 0
	actor["moveRange"] = 0
	actor["slot_count"] = 3
	actor["base_layers"] = 1
	actor["slot_elements"] = ["风", "风", "风"]
	actor["has_attacked"] = false
	actor["action_slots_used"] = {}
	actor["skill"] = "spaceExplosionBonus" if with_skill else ""
	state.units.append(actor)
	var left := Dictionary(enemy_templates[0]).duplicate(true)
	left["id"] = "parity_left"
	left["name"] = "左侧目标"
	left["side"] = StateScript.ENEMY
	left["x"] = 2
	left["y"] = 5
	left["hp"] = 200 if with_skill else 40
	left["max_hp"] = int(left["hp"])
	left["shield"] = 0
	left["def"] = 1 if with_skill else 0
	left["atk"] = 0
	left["attack"] = 0
	left["ap"] = 1
	left["move_range"] = 0
	left["moveRange"] = 0
	left["role"] = "minion"
	left["type"] = "pet"
	_remove_boss_flags(left)
	state.units.append(left)
	var right := Dictionary(enemy_templates[1]).duplicate(true)
	right["id"] = "parity_right"
	right["name"] = "右侧目标"
	right["side"] = StateScript.ENEMY
	right["x"] = 4
	right["y"] = 5
	right["hp"] = 200 if with_skill else 10
	right["max_hp"] = int(right["hp"])
	right["shield"] = 0
	right["def"] = 0
	right["atk"] = 0
	right["attack"] = 0
	right["ap"] = 1
	right["move_range"] = 0
	right["moveRange"] = 0
	right["role"] = "minion"
	right["type"] = "pet"
	_remove_boss_flags(right)
	state.units.append(right)
	state.battle_roster_templates[StateScript.PLAYER] = [actor.duplicate(true)]
	state.call("_normalize_skill_control_orders")
	state.ap = 1
	return {
		"state": state,
		"actor_id": String(actor["id"]),
		"left_id": String(left["id"]),
		"right_id": String(right["id"])
	}


func _approach_fixture() -> Dictionary:
	var state := StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var actor_template := state.unit_by_id("pal_002").duplicate(true)
	var enemy_rows := _enemy_templates(state, 1)
	var first := actor_template.duplicate(true)
	var second := actor_template.duplicate(true)
	var enemy := Dictionary(enemy_rows[0]).duplicate(true)
	_prepare_approach_actor(first, "approach_a", 0, 7, 2)
	_prepare_approach_actor(second, "approach_b", 1, 7, 2)
	_prepare_approach_enemy(enemy, 7, 0)
	state.units = [first, second, enemy]
	return {"state": state}


func _prepare_approach_actor(actor: Dictionary, id: String, x: int, y: int, move_range: int) -> void:
	actor["id"] = id
	actor["name"] = id
	actor["side"] = StateScript.PLAYER
	actor["x"] = x
	actor["y"] = y
	actor["hp"] = 30
	actor["max_hp"] = 30
	actor["atk"] = 4
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["move_range"] = move_range
	actor["moveRange"] = move_range
	actor["has_attacked"] = false
	actor["action_slots_used"] = {}


func _prepare_approach_enemy(enemy: Dictionary, x: int, y: int) -> void:
	enemy["id"] = "approach_enemy"
	enemy["name"] = "远处敌人"
	enemy["side"] = StateScript.ENEMY
	enemy["x"] = x
	enemy["y"] = y
	enemy["hp"] = 100
	enemy["max_hp"] = 100
	enemy["shield"] = 0
	enemy["def"] = 0
	enemy["role"] = "minion"
	enemy["type"] = "pet"
	_remove_boss_flags(enemy)


func _enemy_templates(state: RefCounted, count: int) -> Array:
	var out: Array = []
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			out.append(unit.duplicate(true))
			if out.size() >= count:
				break
	return out


func _remove_boss_flags(unit: Dictionary) -> void:
	unit.erase("is_boss")
	unit.erase("isBoss")
	unit.erase("boss")


func _stationary_candidate_options() -> Dictionary:
	return {
		"limit": 64,
		"movementBudget": 0,
		"allowDirectionChanges": true,
		"positionIndependent": false,
	}


func _candidate_for(candidates: Array, actor: Dictionary, direction: String, target_id: String) -> Dictionary:
	for candidate_value in candidates:
		var candidate := Dictionary(candidate_value)
		var to := Dictionary(candidate.get("to", {}))
		if String(candidate.get("dir", "")) == direction \
				and int(to.get("x", -1)) == int(actor.get("x", -2)) \
				and int(to.get("y", -1)) == int(actor.get("y", -2)) \
				and Array(candidate.get("targets", [])).has(target_id):
			return candidate
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
