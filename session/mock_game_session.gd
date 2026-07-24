extends "res://session/game_session.gd"
class_name MockGameSession

## JSON-backed implementation of the production-facing GameSession port.
## It deliberately owns only deterministic presentation data and mock rules.

signal snapshot_changed(snapshot: Dictionary, event: Dictionary)

const SNAPSHOT_PATH := "res://data/mock_battle_snapshot.json"

var _snapshot: Dictionary = {}
var _event_serial := 0


func _init(options: Dictionary = {}) -> void:
	reset(false)
	var dimensions: Variant = options.get("board_dimensions", Vector2i.ZERO)
	if dimensions is Vector2i:
		var size := dimensions as Vector2i
		if size.x > 0 and size.y > 0:
			var board := Dictionary(_snapshot.get("board", {}))
			board["width"] = size.x
			board["height"] = size.y
			_snapshot["board"] = board
			_rebuild_board_cells()
	_enter_battle_after_ui_ready()


func get_authority() -> RefCounted:
	return null


func current_snapshot() -> Dictionary:
	if _snapshot.is_empty():
		reset(false)
	return _snapshot.duplicate(true)


func submit_command(command: Dictionary) -> Dictionary:
	var requested_type := String(command.get("type", "")).strip_edges().to_upper()
	var command_type := _canonical_command_type(requested_type)
	var result := _execute_command(command_type, command)
	var accepted := String(result.get("type", "")) != "IGNORED"
	if accepted:
		_append_command_log(command_type, command)
	_snapshot["lastCommandResult"] = result.duplicate(true)
	_snapshot["last_command_result"] = result.duplicate(true)
	_rebuild_board_cells()
	var snapshot := current_snapshot()
	var response := {
		"accepted": accepted,
		"pending": false,
		"status": "accepted" if accepted else "rejected",
		"command": command_type,
		"result": result.duplicate(true),
		"snapshot": snapshot,
	}
	if accepted:
		command_completed.emit(command.duplicate(true), response.duplicate(true))
	else:
		command_rejected.emit(command.duplicate(true), response.duplicate(true))
	command_settled.emit(response.duplicate(true))
	snapshot_received.emit(snapshot, {
		"asynchronous": false,
		"source": "mock_json",
		"command": command_type,
	})
	snapshot_changed.emit(snapshot, result.duplicate(true))
	return response


func submit_command_and_wait(command: Dictionary) -> Dictionary:
	return submit_command(command)


func reset(emit_change: bool = true) -> void:
	var file := FileAccess.open(SNAPSHOT_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open mock snapshot: %s" % SNAPSHOT_PATH)
		_snapshot = {}
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_snapshot = Dictionary(parsed).duplicate(true) if parsed is Dictionary else {}
	_snapshot["battleTrace"] = Array(_snapshot.get("battleTrace", []))
	_snapshot["battle_trace"] = Array(_snapshot["battleTrace"]).duplicate(true)
	_snapshot["command_log"] = Array(_snapshot.get("command_log", []))
	_rebuild_board_cells()
	if emit_change:
		var event := {"type": "RESET_MOCK", "ok": true, "message": "假数据已载入"}
		var snapshot := current_snapshot()
		snapshot_received.emit(snapshot, {"asynchronous": true, "source": "mock_json"})
		snapshot_changed.emit(snapshot, event)


func _enter_battle_after_ui_ready() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	_snapshot["phase"] = "battle"
	var snapshot := current_snapshot()
	snapshot_received.emit(snapshot, {
		"asynchronous": true,
		"source": "mock_json",
		"command": "MOCK_ENTER_BATTLE",
	})
	snapshot_changed.emit(snapshot, {
		"type": "MOCK_ENTER_BATTLE",
		"ok": true,
		"message": "固定数据已进入战斗",
	})


func _canonical_command_type(command_type: String) -> String:
	match command_type:
		"AUTO_POSITION":
			return "AUTO_POSITION_HEROES"
		"RUN_PLAYER_ALL_OUT", "END_PLAYER_TURN", "RUN_MONSTER_TURN", "RUN_BATTLE":
			return "RUN_COMBAT_ROUND"
	return command_type


func _execute_command(command_type: String, command: Dictionary) -> Dictionary:
	match command_type:
		"AUTO_POSITION_HEROES":
			return _auto_position()
		"RUN_COMBAT_ROUND":
			return _run_combat_round()
		"SELECT_UNIT":
			return _select_unit(String(command.get("unit_id", command.get("unitId", ""))))
		"GET_CELL_DETAIL":
			return _cell_detail(
				int(command.get("x", Dictionary(command.get("cell", {})).get("x", -1))),
				int(command.get("y", Dictionary(command.get("cell", {})).get("y", -1)))
			)
		"MOVE_HERO":
			return _move_hero(command)
		"SET_DIFFICULTY":
			return _set_difficulty(String(command.get("difficulty", "normal")))
		"SELECT_CELL", "SELECT_ACTION_SLOT", "SET_ACTION_DIRECTION", "SET_ACTION_AP", "USE_ACTION_SLOT":
			return {"type": command_type, "ok": true, "message": "Mock 已接收展示命令"}
		"RESET_MOCK":
			reset(false)
			return {"type": "RESET_MOCK", "ok": true, "message": "已恢复假数据初始状态"}
		_:
			return {"type": "IGNORED", "ok": false, "message": "未识别的假命令：%s" % command_type}


func _auto_position() -> Dictionary:
	var positions := [
		Vector2i(0, 2),
		Vector2i(0, 5),
		Vector2i(2, 3),
		Vector2i(2, 4),
	]
	var moves: Array = []
	var player_index := 0
	var units := Array(_snapshot.get("units", []))
	for index in range(units.size()):
		var unit := Dictionary(units[index])
		if String(unit.get("side", "")) != "player":
			continue
		var from := Vector2i(int(unit.get("x", -1)), int(unit.get("y", -1)))
		var position: Vector2i = positions[min(player_index, positions.size() - 1)]
		unit["x"] = position.x
		unit["y"] = position.y
		units[index] = unit
		if from != position:
			moves.append({
				"unitId": String(unit.get("id", "")),
				"from": {"x": from.x, "y": from.y},
				"to": {"x": position.x, "y": position.y},
			})
		player_index += 1
	_snapshot["units"] = units
	return {
		"type": "AUTO_POSITION_HEROES",
		"ok": true,
		"moves": moves,
		"message": "我方宠物已按假规则重新布置",
	}


func _run_combat_round() -> Dictionary:
	var units := Array(_snapshot.get("units", []))
	var attacker_index := _first_living_unit_index(units, "player")
	var target_index := _first_living_unit_index(units, "enemy")
	if attacker_index < 0 or target_index < 0:
		return {"type": "NO_TARGET", "ok": false, "message": "没有可行动的假单位"}

	var attacker := Dictionary(units[attacker_index])
	var target_before := Dictionary(units[target_index]).duplicate(true)
	var target := target_before.duplicate(true)
	var damage: int = maxi(1, int(attacker.get("atk", 1)))
	var old_shield: int = maxi(0, int(target.get("shield", 0)))
	var absorbed: int = mini(old_shield, damage)
	var hp_damage: int = damage - absorbed
	target["shield"] = old_shield - absorbed
	target["hp"] = maxi(0, int(target.get("hp", 0)) - hp_damage)
	target["alive"] = int(target.get("hp", 0)) > 0
	units[target_index] = target

	var counter_event: Dictionary = {}
	var counter_index := _first_living_unit_index(units, "enemy")
	var player_target_index := _first_living_unit_index(units, "player")
	if counter_index >= 0 and player_target_index >= 0:
		var counter := Dictionary(units[counter_index])
		var player_before := Dictionary(units[player_target_index]).duplicate(true)
		var player_target := player_before.duplicate(true)
		var counter_damage: int = maxi(1, int(counter.get("atk", 1)) - 1)
		var player_shield: int = maxi(0, int(player_target.get("shield", 0)))
		var counter_absorbed: int = mini(player_shield, counter_damage)
		player_target["shield"] = player_shield - counter_absorbed
		player_target["hp"] = maxi(
			0,
			int(player_target.get("hp", 0)) - (counter_damage - counter_absorbed)
		)
		player_target["alive"] = int(player_target.get("hp", 0)) > 0
		units[player_target_index] = player_target
		counter_event = _damage_trace(counter, player_before, player_target, counter_damage)

	_snapshot["units"] = units
	_snapshot["battle_round"] = mini(
		int(_snapshot.get("battle_round", 1)) + 1,
		int(_snapshot.get("maxRounds", 12))
	)
	_snapshot["battleRound"] = int(_snapshot["battle_round"])
	_damage_enemy_leader(1)
	var trace := Array(_snapshot.get("battleTrace", []))
	trace.append(_damage_trace(attacker, target_before, target, damage))
	if not counter_event.is_empty():
		trace.append(counter_event)
	_snapshot["battleTrace"] = trace
	_snapshot["battle_trace"] = trace.duplicate(true)
	return {
		"type": "COMBAT_ROUND",
		"ok": true,
		"message": "%s 对 %s 造成 %d 点伤害（护盾吸收 %d）" % [
			attacker.get("name", "我方宠物"),
			target.get("name", "敌方宠物"),
			damage,
			absorbed,
		],
		"attacker_id": String(attacker.get("id", "")),
		"target_id": String(target.get("id", "")),
	}


func _damage_trace(actor: Dictionary, before: Dictionary, after: Dictionary, raw_damage: int) -> Dictionary:
	_event_serial += 1
	var shield_damage := maxi(0, int(before.get("shield", 0)) - int(after.get("shield", 0)))
	var hp_damage := maxi(0, int(before.get("hp", 0)) - int(after.get("hp", 0)))
	return {
		"eventId": "mock_damage_%d" % _event_serial,
		"kind": "combat",
		"type": "DAMAGE_APPLIED",
		"round": int(_snapshot.get("battle_round", 1)),
		"actor": _unit_ref(actor),
		"target": _unit_ref(before),
		"payload": {
			"rawDamage": raw_damage,
			"finalDamage": raw_damage,
			"shieldDamage": shield_damage,
			"hpDamage": hp_damage,
			"hpFrom": int(before.get("hp", 0)),
			"hpTo": int(after.get("hp", 0)),
			"shieldFrom": int(before.get("shield", 0)),
			"shieldTo": int(after.get("shield", 0)),
			"element": String(actor.get("element_id", "fire")),
			"sourceType": "action",
		},
	}


func _unit_ref(unit: Dictionary) -> Dictionary:
	return {
		"id": String(unit.get("id", unit.get("unitId", ""))),
		"name": String(unit.get("name", "")),
		"side": String(unit.get("side", "")),
		"x": int(unit.get("x", -1)),
		"y": int(unit.get("y", -1)),
	}


func _cell_detail(x: int, y: int) -> Dictionary:
	var board := Dictionary(_snapshot.get("board", {}))
	for value in Array(board.get("cells", [])):
		var cell := Dictionary(value)
		if int(cell.get("x", -1)) != x or int(cell.get("y", -1)) != y:
			continue
		return {
			"type": "GET_CELL_DETAIL",
			"ok": true,
			"x": x,
			"y": y,
			"c": x,
			"r": y,
			"elements": Dictionary(cell.get("elements", {})).duplicate(true),
			"unit": _unit_by_id(String(cell.get("unitId", ""))),
		}
	return {"type": "GET_CELL_DETAIL", "ok": false, "x": x, "y": y, "unit": {}}


func _move_hero(command: Dictionary) -> Dictionary:
	var unit_id := String(command.get("unitId", command.get("unit_id", "")))
	var target := Dictionary(command.get("to", command.get("cell", {})))
	var x := int(command.get("x", target.get("x", target.get("c", -1))))
	var y := int(command.get("y", target.get("y", target.get("r", -1))))
	var board := Dictionary(_snapshot.get("board", {}))
	var width := maxi(1, int(board.get("width", 8)))
	var height := maxi(1, int(board.get("height", 8)))
	if x < 0 or x >= width or y < 0 or y >= height or _unit_id_at(x, y) != "":
		return {"type": "MOVE_HERO", "ok": false, "unitId": unit_id, "x": x, "y": y}
	var units := Array(_snapshot.get("units", []))
	for index in range(units.size()):
		var unit := Dictionary(units[index])
		if String(unit.get("id", "")) != unit_id or String(unit.get("side", "")) != "player":
			continue
		var from := {"x": int(unit.get("x", -1)), "y": int(unit.get("y", -1))}
		unit["x"] = x
		unit["y"] = y
		units[index] = unit
		_snapshot["units"] = units
		return {
			"type": "MOVE_HERO",
			"ok": true,
			"unitId": unit_id,
			"from": from,
			"to": {"x": x, "y": y},
		}
	return {"type": "MOVE_HERO", "ok": false, "unitId": unit_id, "x": x, "y": y}


func _set_difficulty(value: String) -> Dictionary:
	var difficulty := "easy" if value == "easy" else "normal"
	_snapshot["difficulty"] = difficulty
	return {"type": "SET_DIFFICULTY", "ok": true, "difficulty": difficulty}


func _select_unit(unit_id: String) -> Dictionary:
	_snapshot["selected_unit_id"] = unit_id
	var unit := _unit_by_id(unit_id)
	return {
		"type": "SELECT_UNIT",
		"ok": not unit.is_empty(),
		"message": "查看 %s 的预制体详情" % unit.get("name", unit_id),
		"unit_id": unit_id,
		"unit": unit,
	}


func _damage_enemy_leader(amount: int) -> void:
	var leaders := Array(_snapshot.get("leaders", []))
	for index in range(leaders.size()):
		var leader := Dictionary(leaders[index])
		if String(leader.get("side", "")) == "enemy":
			leader["hp"] = maxi(0, int(leader.get("hp", 0)) - amount)
			leaders[index] = leader
			break
	_snapshot["leaders"] = leaders


func _first_living_unit_index(units: Array, side: String) -> int:
	for index in range(units.size()):
		var unit := Dictionary(units[index])
		if String(unit.get("side", "")) == side and bool(unit.get("alive", true)):
			return index
	return -1


func _unit_by_id(unit_id: String) -> Dictionary:
	for value in Array(_snapshot.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", unit.get("unitId", ""))) == unit_id:
			return unit.duplicate(true)
	return {}


func _unit_id_at(x: int, y: int) -> String:
	for value in Array(_snapshot.get("units", [])):
		var unit := Dictionary(value)
		if not bool(unit.get("alive", true)):
			continue
		if int(unit.get("x", -1)) == x and int(unit.get("y", -1)) == y:
			return String(unit.get("id", ""))
	return ""


func _append_command_log(command_type: String, command: Dictionary) -> void:
	var command_log := Array(_snapshot.get("command_log", []))
	command_log.append({
		"type": command_type,
		"command": command.duplicate(true),
		"sequence": command_log.size() + 1,
	})
	_snapshot["command_log"] = command_log


func _rebuild_board_cells() -> void:
	if _snapshot.is_empty():
		return
	var board := Dictionary(_snapshot.get("board", {}))
	var width := maxi(1, int(board.get("width", 8)))
	var height := maxi(1, int(board.get("height", 8)))
	var units_by_cell := {}
	for value in Array(_snapshot.get("units", [])):
		var unit := Dictionary(value)
		if not bool(unit.get("alive", true)):
			continue
		units_by_cell["%d:%d" % [int(unit.get("x", -1)), int(unit.get("y", -1))]] = unit
	var elements := ["fire", "water", "ground", "wind"]
	var cells: Array = []
	for y in range(height):
		for x in range(width):
			var element_id: String = elements[(x + y * 2) % elements.size()]
			var layers := 3 if (x + y) % 5 == 0 else 1
			var cell := {
				"index": y * width + x,
				"x": x,
				"y": y,
				"c": x,
				"r": y,
				"element": element_id,
				"layers": layers,
				"elements": {element_id: layers},
				"unitId": "",
			}
			var key := "%d:%d" % [x, y]
			if units_by_cell.has(key):
				var unit := Dictionary(units_by_cell[key])
				cell.merge(unit, true)
				cell["unitId"] = String(unit.get("id", ""))
				cell["unitName"] = String(unit.get("name", ""))
				cell["unitSide"] = String(unit.get("side", ""))
				cell["elements"] = {element_id: layers}
			cells.append(cell)
	board["width"] = width
	board["height"] = height
	board["columns"] = width
	board["rows"] = height
	board["cells"] = cells
	_snapshot["board"] = board
