extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	var direct_easy := _fixture()
	direct_easy.set_difficulty(StateScript.DIFFICULTY_EASY)
	_expect(direct_easy.dispatch({"type": "AUTO_POSITION_HEROES"}), "direct easy auto-position succeeds")
	var direct_plan := Dictionary(Dictionary(direct_easy.last_command_result).get("plan", {}))
	var direct_layout := _player_layout(direct_easy)
	var moved_easy := _fixture()
	_scatter_players(moved_easy)
	moved_easy.set_difficulty(StateScript.DIFFICULTY_EASY)
	_expect(moved_easy.dispatch({"type": "AUTO_POSITION_HEROES"}), "easy auto-position succeeds after arbitrary player movement")
	var moved_easy_plan := Dictionary(Dictionary(moved_easy.last_command_result).get("plan", {}))
	_expect(_player_layout(moved_easy) == direct_layout, "easy final layout is independent of arbitrary player movement")
	_expect(String(moved_easy_plan.get("resultSignature", "")) == String(direct_plan.get("resultSignature", "")), "easy signature is independent of arbitrary player movement")

	var direct_normal := _fixture()
	_expect(direct_normal.dispatch({"type": "AUTO_POSITION_HEROES"}), "direct normal auto-position succeeds")
	var direct_normal_plan := Dictionary(Dictionary(direct_normal.last_command_result).get("plan", {}))
	var moved_normal := _fixture()
	_scatter_players(moved_normal)
	_expect(moved_normal.dispatch({"type": "AUTO_POSITION_HEROES"}), "normal auto-position succeeds after arbitrary player movement")
	var moved_normal_plan := Dictionary(Dictionary(moved_normal.last_command_result).get("plan", {}))
	_expect(_player_layout(moved_normal) == _player_layout(direct_normal), "normal final layout is independent of arbitrary player movement")
	_expect(String(moved_normal_plan.get("resultSignature", "")) == String(direct_normal_plan.get("resultSignature", "")), "normal signature is independent of arbitrary player movement")

	var normal_then_easy := _fixture()
	_expect(normal_then_easy.dispatch({"type": "AUTO_POSITION_HEROES"}), "normal auto-position succeeds before switching")
	normal_then_easy.set_difficulty(StateScript.DIFFICULTY_EASY)
	_expect(normal_then_easy.dispatch({"type": "AUTO_POSITION_HEROES"}), "easy auto-position succeeds after normal")
	var ordered_plan := Dictionary(Dictionary(normal_then_easy.last_command_result).get("plan", {}))
	var ordered_layout := _player_layout(normal_then_easy)

	_expect(direct_layout == ordered_layout, "easy final positions and directions are independent of prior normal auto-position")
	_expect(String(direct_plan.get("resultSignature", "")) == String(ordered_plan.get("resultSignature", "")), "easy plan signature is independent of difficulty switch order")
	_expect(String(ordered_plan.get("difficulty", "")) == StateScript.DIFFICULTY_EASY, "ordered path still reports easy difficulty")
	_expect(String(ordered_plan.get("directionPolicy", "")) == "optimize", "ordered path still optimizes directions")

	print("SMOKE_AUTO_POSITION_DIFFICULTY_ORDER_INDEPENDENCE_%s" % ["FAIL" if failed else "OK"])
	quit(1 if failed else 0)


func _fixture() -> RefCounted:
	var state := StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture starts battle")
	var player_template := _first_side(state, StateScript.PLAYER)
	_expect(not player_template.is_empty(), "fixture has a player template")
	var enemies: Array = []
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			enemies.append(unit.duplicate(true))
	state.units.clear()
	var starts := [Vector2i(1, 4), Vector2i(2, 5), Vector2i(0, 5)]
	for index in range(starts.size()):
		var player := player_template.duplicate(true)
		player["id"] = "order_player_%d" % index
		player["name"] = "顺序测试宠物%d" % (index + 1)
		player["x"] = starts[index].x
		player["y"] = starts[index].y
		player["hp"] = 20 + index * 5
		player["max_hp"] = int(player["hp"])
		player["atk"] = 8 + index
		player["shape_id"] = "01"
		player["shape_name"] = "形状01"
		player["slot_count"] = 1
		player["move_range"] = 6
		player["moveRange"] = 6
		player["has_attacked"] = false
		player["action_slots_used"] = {}
		state.units.append(player)
		state.action_dirs["%s:slot0" % String(player["id"])] = "right"
	for enemy in enemies:
		state.units.append(enemy)
	state.ap = 3
	state.auto_position_action_plan = []
	state.auto_position_applied_result = {}
	return state


func _player_layout(state: RefCounted) -> String:
	var rows: Array = []
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != StateScript.PLAYER or int(unit.get("hp", 0)) <= 0:
			continue
		var unit_id := String(unit.get("id", ""))
		rows.append("%s@%d,%d:%s" % [
			unit_id,
			int(unit.get("x", -1)),
			int(unit.get("y", -1)),
			String(state.action_dirs.get("%s:slot0" % unit_id, "right"))
		])
	rows.sort()
	return "|".join(rows)


func _scatter_players(state: RefCounted) -> void:
	var destinations := [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]
	var index := 0
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != StateScript.PLAYER or int(unit.get("hp", 0)) <= 0:
			continue
		unit["x"] = destinations[index].x
		unit["y"] = destinations[index].y
		index += 1
	state.auto_position_action_plan = []
	state.auto_position_applied_result = {}


func _first_side(state: RefCounted, side: String) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == side:
			return unit.duplicate(true)
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_AUTO_POSITION_DIFFICULTY_ORDER_INDEPENDENCE_FAIL: %s" % message)
