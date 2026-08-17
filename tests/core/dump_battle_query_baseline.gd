extends SceneTree

const DocumentCodecScript := preload("res://persistence/save_codec.gd")
const StateScript := preload("res://core/state/game_state.gd")

const FIXTURE_PATH := "res://tests/fixtures/battle_query_baseline_v1.json"
const SEED := "battle-query-baseline-v1"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var state := StateScript.new()
	state.set_run_seed(SEED)
	var route_snapshot := state.snapshot()
	var start := state.run_command({
		"type": "START_BATTLE",
		"commandId": "battle_query_baseline_start",
		"baseStateVersion": int(route_snapshot.get("stateVersion", 0)),
	})
	_expect(bool(start.get("ok", false)) and bool(start.get("accepted", false)), "START_BATTLE succeeds", failures)
	var battle_snapshot := state.snapshot()
	var player := _first_living_unit(battle_snapshot, StateScript.PLAYER)
	var enemy := _first_living_unit(battle_snapshot, StateScript.ENEMY)
	_expect(not player.is_empty(), "battle exposes a living player unit", failures)
	_expect(not enemy.is_empty(), "battle exposes a living enemy unit", failures)
	var player_id := String(player.get("id", ""))
	var select := state.run_command({"type": "SELECT_UNIT", "unitId": player_id, "commandId": "battle_query_baseline_select"})
	var slot := state.run_command({"type": "SELECT_ACTION_SLOT", "unitId": player_id, "slotId": 0, "commandId": "battle_query_baseline_slot"})
	var direction := state.run_command({"type": "SET_ACTION_DIRECTION", "unitId": player_id, "slotId": 0, "direction": "up", "commandId": "battle_query_baseline_direction"})
	var selected_ap := state.run_command({"type": "SET_ACTION_AP", "unitId": player_id, "slotId": 0, "ap": 2, "commandId": "battle_query_baseline_ap"})
	for entry in [select, slot, direction, selected_ap]:
		_expect(bool(Dictionary(entry).get("ok", false)) and bool(Dictionary(entry).get("accepted", false)), "selection configuration command succeeds", failures)
	var configured_snapshot := state.snapshot()
	var preview_response := state.run_command({
		"type": "BUILD_PREVIEW",
		"unitId": player_id,
		"slotId": 0,
		"direction": "up",
		"ap": 2,
		"commandId": "battle_query_baseline_preview",
	})
	var player_detail_response := state.run_command({
		"type": "GET_CELL_DETAIL",
		"x": int(player.get("x", -1)),
		"y": int(player.get("y", -1)),
		"commandId": "battle_query_baseline_player_cell",
	})
	var enemy_detail_response := state.run_command({
		"type": "GET_CELL_DETAIL",
		"x": int(enemy.get("x", -1)),
		"y": int(enemy.get("y", -1)),
		"commandId": "battle_query_baseline_enemy_cell",
	})
	for entry in [preview_response, player_detail_response, enemy_detail_response]:
		_expect(bool(Dictionary(entry).get("ok", false)) and bool(Dictionary(entry).get("accepted", false)), "query command succeeds", failures)
	_expect(typeof(preview_response.get("result")) == TYPE_ARRAY, "BUILD_PREVIEW returns an Array", failures)
	var board := Dictionary(configured_snapshot.get("board", {}))
	var board_width := int(board.get("width", 0))
	var board_height := int(board.get("height", 0))
	_expect(board_width > 0 and board_height > 0, "board dimensions are positive", failures)
	_expect(Array(board.get("cells", [])).size() == board_width * board_height, "board cell count matches dimensions", failures)
	if not failures.is_empty():
		for failure in failures:
			push_error("BATTLE_QUERY_BASELINE_FAIL %s" % failure)
		quit(1)
		return
	var summary := {
		"schema": "ysbzs.battle-query-baseline.v1",
		"seed": SEED,
		"board": {"width": board_width, "height": board_height, "cellCount": Array(board.get("cells", [])).size()},
		"playerUnitId": player_id,
		"enemyUnitId": String(enemy.get("id", "")),
		"routeSnapshotSha256": _sha256(DocumentCodecScript.stable_json(route_snapshot)),
		"battleSnapshotSha256": _sha256(DocumentCodecScript.stable_json(battle_snapshot)),
		"configuredSnapshotSha256": _sha256(DocumentCodecScript.stable_json(configured_snapshot)),
		"buildPreviewSha256": _sha256(DocumentCodecScript.stable_json(preview_response.get("result", []))),
		"playerCellDetailSha256": _sha256(DocumentCodecScript.stable_json(player_detail_response.get("result", {}))),
		"enemyCellDetailSha256": _sha256(DocumentCodecScript.stable_json(enemy_detail_response.get("result", {}))),
	}
	if FileAccess.file_exists(FIXTURE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
		_expect(typeof(parsed) == TYPE_DICTIONARY, "fixture parses as a Dictionary", failures)
		if typeof(parsed) == TYPE_DICTIONARY:
			_expect(
				DocumentCodecScript.stable_json(Dictionary(parsed)) == DocumentCodecScript.stable_json(summary),
				"live baseline matches frozen fixture",
				failures
			)
	if not failures.is_empty():
		for failure in failures:
			push_error("BATTLE_QUERY_BASELINE_FAIL %s" % failure)
		quit(1)
		return
	print("BATTLE_QUERY_BASELINE_JSON %s" % JSON.stringify(summary))
	quit(0)


func _first_living_unit(snapshot: Dictionary, side: String) -> Dictionary:
	for item in Array(snapshot.get("units", [])):
		var unit := Dictionary(item)
		if String(unit.get("side", "")) == side and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _sha256(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
