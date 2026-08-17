extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	_test_normal_preserves_direction_through_all_out()
	_test_easy_optimizes_direction_through_all_out()
	_test_difficulty_snapshot_and_save_load()
	if failed:
		quit(1)
		return
	print("SMOKE_AUTO_POSITION_DIFFICULTY_DIRECTION_OK")
	quit(0)


func _test_normal_preserves_direction_through_all_out() -> void:
	var fixture := _direction_fixture(StateScript.DIFFICULTY_NORMAL)
	var state = fixture["state"]
	var actor_id := String(fixture["actor_id"])
	var left_id := String(fixture["left_id"])
	var right_id := String(fixture["right_id"])
	_expect(String(state.difficulty) == StateScript.DIFFICULTY_NORMAL, "normal fixture uses normal difficulty")
	_expect(_all_slot_directions_equal(state, actor_id, "left"), "normal fixture starts with player left directions")
	_expect(state.dispatch({"type": "AUTO_POSITION_HEROES"}), "normal difficulty accepts auto position")
	var plan := Dictionary(Dictionary(state.last_command_result).get("plan", {}))
	_expect(String(plan.get("directionPolicy", "")) == "preserve", "normal plan reports preserve direction policy")
	_expect(_planned_directions_equal(plan, actor_id, "left"), "normal plan keeps every planned action on its player direction")
	_expect(_all_slot_directions_equal(state, actor_id, "left"), "normal auto position does not write new directions")
	state.ap = 1
	_expect(state.dispatch({"type": "RUN_PLAYER_ALL_OUT"}), "normal difficulty accepts player all-out")
	_expect(_all_slot_directions_equal(state, actor_id, "left"), "normal all-out executes and retains the original directions")
	var actor_after: Dictionary = state.unit_by_id(actor_id)
	var right_after: Dictionary = state.unit_by_id(right_id)
	_expect(int(actor_after.get("x", -1)) > int(right_after.get("x", -1)), "normal auto position moves to the target's right before retaining the left attack direction")
	_expect(int(right_after.get("hp", 0)) == 0, "normal all-out executes the planned left attack from the optimized position")
	_expect(int(state.unit_by_id(left_id).get("hp", 0)) == 40, "normal all-out leaves the target outside the preserved left direction untouched")


func _test_easy_optimizes_direction_through_all_out() -> void:
	var fixture := _direction_fixture(StateScript.DIFFICULTY_EASY)
	var state = fixture["state"]
	var actor_id := String(fixture["actor_id"])
	var left_id := String(fixture["left_id"])
	var right_id := String(fixture["right_id"])
	_expect(String(state.difficulty) == StateScript.DIFFICULTY_EASY, "easy fixture uses easy difficulty")
	_expect(_all_slot_directions_equal(state, actor_id, "left"), "easy fixture starts with player left directions")
	_expect(state.dispatch({"type": "AUTO_POSITION_HEROES"}), "easy difficulty accepts auto position")
	var plan := Dictionary(Dictionary(state.last_command_result).get("plan", {}))
	_expect(String(plan.get("directionPolicy", "")) == "optimize", "easy plan reports optimize direction policy")
	_expect(_planned_directions_equal(plan, actor_id, "right"), "easy plan chooses the lethal right direction")
	_expect(_planned_direction_is_written(state, plan, actor_id, "right"), "easy auto position writes the optimized direction")
	state.ap = 1
	_expect(state.dispatch({"type": "RUN_PLAYER_ALL_OUT"}), "easy difficulty accepts player all-out")
	_expect(_planned_direction_is_written(state, plan, actor_id, "right"), "easy all-out executes the optimized direction")
	_expect(int(state.unit_by_id(actor_id).get("x", -1)) < int(state.unit_by_id(right_id).get("x", -1)), "easy all-out attacks the target to the actor's right")
	_expect(int(state.unit_by_id(right_id).get("hp", 0)) == 0, "easy all-out kills the lethal right target")
	_expect(int(state.unit_by_id(left_id).get("hp", 0)) == 40, "easy all-out leaves the nonlethal left target untouched")


func _test_difficulty_snapshot_and_save_load() -> void:
	var default_state := StateScript.new()
	_expect(String(default_state.snapshot().get("difficulty", "")) == StateScript.DIFFICULTY_NORMAL, "unspecified difficulty defaults to normal in snapshot")
	_expect(default_state.dispatch({"type": "SET_DIFFICULTY", "difficulty": "simple"}), "public command switches to simple difficulty")
	_expect(String(default_state.snapshot().get("difficulty", "")) == StateScript.DIFFICULTY_EASY, "public difficulty command normalizes the simple alias")
	_expect(default_state.dispatch({"type": "setDifficulty", "difficulty": "normal"}), "camelCase alias switches back to normal difficulty")
	_expect(String(default_state.snapshot().get("difficulty", "")) == StateScript.DIFFICULTY_NORMAL, "public difficulty alias projects normal difficulty")
	_expect(default_state.dispatch({"type": "NEW_RUN", "difficulty": "simple", "seed": "difficulty-save-load"}), "new run accepts the simple difficulty alias")
	_expect(String(default_state.snapshot().get("difficulty", "")) == StateScript.DIFFICULTY_EASY, "snapshot projects normalized easy difficulty")
	default_state.action_dirs["save_actor:slot0"] = "up"
	var document := default_state.save_document("difficulty-round-trip")
	_expect(String(Dictionary(document.get("state", {})).get("difficulty", "")) == StateScript.DIFFICULTY_EASY, "save document stores difficulty")
	var restored := StateScript.new()
	_expect(restored.load_document(document), "difficulty save document loads")
	_expect(String(restored.snapshot().get("difficulty", "")) == StateScript.DIFFICULTY_EASY, "difficulty survives save-load")
	_expect(String(restored.action_dirs.get("save_actor:slot0", "")) == "up", "player direction survives save-load")
	_expect(restored.dispatch({"type": "NEW_RUN", "seed": "difficulty-default"}), "new run without difficulty is accepted")
	_expect(String(restored.snapshot().get("difficulty", "")) == StateScript.DIFFICULTY_NORMAL, "new run without difficulty resets to normal")


func _direction_fixture(difficulty: String) -> Dictionary:
	var state := StateScript.new()
	state.set_difficulty(difficulty)
	_expect(state.dispatch({"type": "START_BATTLE"}), "difficulty fixture starts battle")
	var actor := state.unit_by_id("pal_002").duplicate(true)
	var enemy_templates := _enemy_templates(state, 2)
	_expect(not actor.is_empty() and enemy_templates.size() == 2, "difficulty fixture has actor and enemy templates")
	state.units.clear()
	actor["id"] = "difficulty_actor"
	actor["name"] = "难度方向测试宠物"
	actor["side"] = StateScript.PLAYER
	actor["x"] = 3
	actor["y"] = 5
	actor["hp"] = 30
	actor["max_hp"] = 30
	actor["atk"] = 10
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["move_range"] = 0
	actor["moveRange"] = 0
	actor["slot_count"] = 1
	actor["base_layers"] = 1
	actor["slot_elements"] = ["风"]
	actor["has_attacked"] = false
	actor["action_slots_used"] = {}
	# The formal player phase executes the shared skill bar. Keep this fixture on
	# that production path instead of the retired normal-action fallback.
	actor["skill"] = "skill_vanguard"
	state.units.append(actor)
	var left := Dictionary(enemy_templates[0]).duplicate(true)
	_prepare_enemy(left, "difficulty_left", "左侧目标", 2, 5, 40)
	state.units.append(left)
	var right := Dictionary(enemy_templates[1]).duplicate(true)
	_prepare_enemy(right, "difficulty_right", "右侧目标", 4, 5, 10)
	state.units.append(right)
	state.battle_roster_templates[StateScript.PLAYER] = [actor.duplicate(true)]
	state.battle_roster_templates[StateScript.ENEMY] = [left.duplicate(true), right.duplicate(true)]
	state._initialize_skill_control_orders()
	for slot_index in range(int(actor.get("slot_count", 1))):
		state.action_dirs["%s:slot%d" % [String(actor["id"]), slot_index]] = "left"
	state.ap = 1
	return {
		"state": state,
		"actor_id": String(actor["id"]),
		"left_id": String(left["id"]),
		"right_id": String(right["id"])
	}


func _prepare_enemy(enemy: Dictionary, id: String, display_name: String, x: int, y: int, hp: int) -> void:
	enemy["id"] = id
	enemy["name"] = display_name
	enemy["side"] = StateScript.ENEMY
	enemy["x"] = x
	enemy["y"] = y
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["shield"] = 0
	enemy["def"] = 0
	enemy["atk"] = 0
	enemy["attack"] = 0
	enemy["ap"] = 1
	enemy["move_range"] = 0
	enemy["moveRange"] = 0
	enemy["role"] = "minion"
	enemy["type"] = "pet"
	enemy.erase("is_boss")
	enemy.erase("isBoss")
	enemy.erase("boss")


func _planned_directions_equal(plan: Dictionary, actor_id: String, expected_direction: String) -> bool:
	var matched := false
	for direction_value in Array(plan.get("directions", [])):
		var direction := Dictionary(direction_value)
		if String(direction.get("unitId", "")) != actor_id:
			continue
		matched = true
		if String(direction.get("dir", "")) != expected_direction:
			return false
	return matched


func _planned_direction_is_written(state: RefCounted, plan: Dictionary, actor_id: String, expected_direction: String) -> bool:
	for direction_value in Array(plan.get("directions", [])):
		var direction := Dictionary(direction_value)
		if String(direction.get("unitId", "")) != actor_id:
			continue
		var key := "%s:slot%d" % [actor_id, int(direction.get("slotIndex", -1))]
		if String(state.action_dirs.get(key, "")) != expected_direction:
			return false
	return true


func _all_slot_directions_equal(state: RefCounted, actor_id: String, expected_direction: String) -> bool:
	var actor: Dictionary = state.unit_by_id(actor_id)
	for slot_index in range(int(actor.get("slot_count", 1))):
		if String(state.action_dirs.get("%s:slot%d" % [actor_id, slot_index], "")) != expected_direction:
			return false
	return true


func _enemy_templates(state: RefCounted, count: int) -> Array:
	var out: Array = []
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			out.append(unit.duplicate(true))
			if out.size() >= count:
				break
	return out


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
