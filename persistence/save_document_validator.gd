extends RefCounted

const BattleBoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")

## Pure save-schema validation. Persistence orchestration owns logging and
## repositories; this service owns document and state-payload shape checks.


func validate_document(
	doc: Dictionary,
	schema_version: int,
	checksum: Callable,
	log_error: Callable,
	default_dimensions: Vector2i
) -> bool:
	if int(doc.get("schemaVersion", 0)) != schema_version:
		log_error.call("读档失败：存档版本不支持。")
		return false
	if typeof(doc.get("state", null)) != TYPE_DICTIONARY:
		log_error.call("读档失败：缺少状态。")
		return false
	var expected_checksum := String(doc.get("checksum", ""))
	if expected_checksum != "" and expected_checksum != String(checksum.call(doc)):
		log_error.call("读档失败：校验不匹配。")
		return false
	return validate_state_payload(
		Dictionary(doc.get("state", {})),
		log_error,
		default_dimensions
	)


func validate_state_payload(
	saved: Dictionary,
	log_error: Callable,
	default_dimensions: Vector2i
) -> bool:
	var phase_value := String(saved.get("phase", ""))
	if not ["route", "shop", "reward", "battle", "battle_end", "day_end", "game_over"].has(phase_value):
		log_error.call("读档失败：阶段不合法。")
		return false
	if int(saved.get("stateVersion", saved.get("state_version", -1))) < 0:
		log_error.call("读档失败：状态版本不合法。")
		return false
	if int(saved.get("day", 0)) < 1:
		log_error.call("读档失败：天数不合法。")
		return false
	if int(saved.get("coins", saved.get("gold", 0))) < 0:
		log_error.call("读档失败：金币不合法。")
		return false
	if int(saved.get("hero_hp", 0)) < 0 or int(saved.get("hero_max_hp", saved.get("heroMaxHp", 1))) < 1:
		log_error.call("读档失败：英雄生命不合法。")
		return false
	for array_key in [
		"route_options",
		"roster",
		"shop_offers",
		"reward_options",
		"units",
		"defeated_units",
		"auto_position_action_plan",
		"log_lines",
		"battle_trace",
		"battle_round_start_checkpoints",
		"battleRoundStartCheckpoints",
		"command_log",
		"replay_debug_timeline"
	]:
		if saved.has(array_key) and typeof(saved.get(array_key)) != TYPE_ARRAY:
			log_error.call("读档失败：%s 不是数组。" % array_key)
			return false
	var round_start_checkpoints_value: Variant = saved.get(
		"battle_round_start_checkpoints",
		saved.get("battleRoundStartCheckpoints", [])
	)
	if not _validate_battle_round_start_checkpoints(Array(round_start_checkpoints_value)):
		log_error.call("读档失败：回合开始回撤点不合法。")
		return false
	var dimensions := saved_board_dimensions(saved, default_dimensions)
	if not BattleBoardDimensionsScript.is_valid(dimensions.x, dimensions.y):
		log_error.call("读档失败：棋盘尺寸不合法。")
		return false
	if not validate_units(Array(saved.get("units", [])), dimensions, log_error):
		return false
	if phase_value == "battle" and Array(saved.get("units", [])).is_empty():
		log_error.call("读档失败：战斗存档缺少单位。")
		return false
	if saved.has("skill_control_orders") or saved.has("skillControlOrders"):
		var orders_value: Variant = saved.get("skill_control_orders", saved.get("skillControlOrders"))
		if typeof(orders_value) != TYPE_DICTIONARY or not _validate_skill_control_orders(Dictionary(orders_value)):
			log_error.call("读档失败：技能控制条顺序不合法。")
			return false
	return true


func _validate_battle_round_start_checkpoints(checkpoints: Array) -> bool:
	if checkpoints.size() > 12:
		return false
	var previous_round := 0
	for checkpoint_value in checkpoints:
		if typeof(checkpoint_value) != TYPE_DICTIONARY:
			return false
		var checkpoint := Dictionary(checkpoint_value)
		var round_number := int(checkpoint.get("round", 0))
		if round_number <= previous_round or round_number > 12:
			return false
		if typeof(checkpoint.get("state", null)) != TYPE_DICTIONARY:
			return false
		var state := Dictionary(checkpoint.get("state", {}))
		if state.has("battle_round_start_checkpoints") or state.has("battleRoundStartCheckpoints"):
			return false
		if int(state.get("battle_round", state.get("round", 0))) != round_number:
			return false
		previous_round = round_number
	return true


func saved_board_dimensions(saved: Dictionary, default_dimensions: Vector2i) -> Vector2i:
	var has_explicit_dimensions := (
		saved.has("board_width")
		or saved.has("boardWidth")
		or saved.has("board_height")
		or saved.has("boardHeight")
	)
	if not has_explicit_dimensions:
		return BattleBoardDimensionsScript.legacy_defaults()
	return Vector2i(
		int(saved.get("board_width", saved.get("boardWidth", default_dimensions.x))),
		int(saved.get("board_height", saved.get("boardHeight", default_dimensions.y)))
	)


func validate_units(saved_units: Array, dimensions: Vector2i, log_error: Callable) -> bool:
	var occupied := {}
	for item in saved_units:
		if typeof(item) != TYPE_DICTIONARY:
			log_error.call("读档失败：单位数据不合法。")
			return false
		var unit := Dictionary(item)
		var unit_id := String(unit.get("id", ""))
		if unit_id == "":
			log_error.call("读档失败：单位缺少 id。")
			return false
		var hp := int(unit.get("hp", 0))
		var max_hp := int(unit.get("max_hp", unit.get("maxHp", max(1, hp))))
		if hp < 0 or max_hp < 1:
			log_error.call("读档失败：单位生命不合法。")
			return false
		if not unit.has("x") or not unit.has("y") or hp <= 0:
			continue
		var x := int(unit.get("x", -1))
		var y := int(unit.get("y", -1))
		if not BattleBoardDimensionsScript.contains(dimensions, x, y):
			log_error.call("读档失败：单位坐标越界。")
			return false
		var key := "%d:%d" % [x, y]
		if occupied.has(key):
			log_error.call("读档失败：多个存活单位占用同一格。")
			return false
		occupied[key] = unit_id
	return true


func _validate_skill_control_orders(orders: Dictionary) -> bool:
	for side in ["player", "enemy"]:
		if not orders.has(side) or typeof(orders.get(side)) != TYPE_ARRAY:
			return false
		var seen := {}
		var entry_ids := Array(orders.get(side, []))
		if entry_ids.size() > 8:
			return false
		for entry_id_value in entry_ids:
			if typeof(entry_id_value) != TYPE_STRING:
				return false
			var entry_id := String(entry_id_value).strip_edges()
			if entry_id == "" or seen.has(entry_id):
				return false
			seen[entry_id] = true
	return true
