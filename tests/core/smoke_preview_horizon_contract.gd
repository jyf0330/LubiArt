extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const PreviewHorizonScript := preload("res://core/commands/preview_horizon.gd")
const TEST_LOG_PATH := "user://smoke_preview_horizon_operations.jsonl"

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_log()
	var state: RefCounted = StateScript.new()
	state.player_operation_log_path = TEST_LOG_PATH
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture enters battle without adding an outer operation row")
	var target_id := _configure_move_fixture(state)
	var response := Dictionary(state.run_command({
		"type": "MOVE_HERO",
		"unitId": "pal_002",
		"x": 4,
		"y": 5,
		"baseStateVersion": int(state.snapshot().get("stateVersion", 0)),
		"commandId": "smoke_preview_horizon",
	}))
	_expect(bool(response.get("accepted", false)), "MOVE_HERO fixture is accepted")

	var manual := Dictionary(response.get("manualFlowPreview", {}))
	_expect(String(manual.get("previewHorizon", "")) == PreviewHorizonScript.MANUAL_ROUND_FLOW, "manual preview declares the whole manual-round-flow horizon")
	var manual_damage := Dictionary(Dictionary(manual.get("damageByUnit", {})).get(target_id, {}))
	_expect(String(manual_damage.get("previewHorizon", "")) == PreviewHorizonScript.MANUAL_ROUND_FLOW, "per-unit manual damage keeps the manual-round-flow horizon")

	var snapshot := Dictionary(response.get("snapshot", {}))
	var target_cell := _board_cell(snapshot, 5, 5)
	var immediate := Dictionary(target_cell.get("action_preview_data", {}))
	_expect(String(immediate.get("previewHorizon", "")) == PreviewHorizonScript.IMMEDIATE_ACTION, "target cell declares the immediate-action horizon")
	_expect(int(immediate.get("predictedDamage", 0)) > 0, "immediate-action target keeps its predicted damage")

	var rows := _read_rows()
	_expect(rows.size() == 1, "one MOVE_HERO command appends one operation row")
	if rows.size() == 1:
		var row := Dictionary(rows[0])
		var summary := Dictionary(row.get("previewSummary", {}))
		_expect(String(summary.get("schema", "")) == PreviewHorizonScript.SUMMARY_SCHEMA, "operation row stores the stable compact-summary schema")
		var immediate_summary := Dictionary(summary.get("immediateAction", {}))
		_expect(String(immediate_summary.get("previewHorizon", "")) == PreviewHorizonScript.IMMEDIATE_ACTION, "operation summary separates immediate-action targets")
		_expect(int(immediate_summary.get("targetCount", 0)) > 0, "operation summary keeps compact immediate targets")
		var manual_summary := Dictionary(summary.get("manualRoundFlow", {}))
		_expect(String(manual_summary.get("previewHorizon", "")) == PreviewHorizonScript.MANUAL_ROUND_FLOW, "operation summary separates manual-round-flow damage")
		_expect(String(manual_summary.get("projectedStateHash", "")) != "", "operation summary keeps the projected hash")
		_expect(bool(manual_summary.get("rolledBack", false)), "operation summary states that the simulation rolled back")
		_expect(bool(Dictionary(manual_summary.get("simulation", {})).get("isolated", false)), "operation summary keeps simulation isolation evidence")
		var stored_damage := Dictionary(Dictionary(manual_summary.get("damageByUnit", {})).get(target_id, {}))
		_expect(int(stored_damage.get("totalDamage", 0)) == int(manual_damage.get("totalDamage", -1)), "stored compact damage equals the returned manual preview")
		_expect(not stored_damage.has("hits"), "compact damage omits full hit payloads")
		var encoded := JSON.stringify(row)
		_expect(not encoded.contains("\"viewModel\""), "operation row does not duplicate the simulated ViewModel")
		_expect(not encoded.contains("\"cellDiffs\""), "operation row does not duplicate simulated cell diffs")
		_expect(encoded.length() < 50000, "operation row remains compact")

	_remove_log()
	if _failed:
		quit(1)
		return
	print("SMOKE_PREVIEW_HORIZON_CONTRACT_OK")
	quit(0)


func _configure_move_fixture(state: RefCounted) -> String:
	var actor := Dictionary(state.unit_by_id("pal_002"))
	var target := _first_enemy(state)
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and String(unit.get("id", "")) != "pal_002":
			unit["hp"] = 0
		if String(unit.get("side", "")) == StateScript.ENEMY and String(unit.get("id", "")) != String(target.get("id", "")):
			unit["hp"] = 0
	actor["x"] = 1
	actor["y"] = 5
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["move_range"] = 3
	actor["moveRange"] = 3
	actor["has_attacked"] = false
	target["x"] = 5
	target["y"] = 5
	target["hp"] = 50
	target["max_hp"] = 50
	return String(target.get("id", ""))


func _first_enemy(state: RefCounted) -> Dictionary:
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			return unit
	return {}


func _board_cell(snapshot: Dictionary, x: int, y: int) -> Dictionary:
	for value in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		if not value is Dictionary:
			continue
		var cell := Dictionary(value)
		if int(cell.get("x", -1)) == x and int(cell.get("y", -1)) == y:
			return cell
	return {}


func _read_rows() -> Array:
	var rows: Array = []
	if not FileAccess.file_exists(TEST_LOG_PATH):
		return rows
	for line in FileAccess.get_file_as_string(TEST_LOG_PATH).split("\n", false):
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			rows.append(Dictionary(parsed))
	return rows


func _remove_log() -> void:
	var path := ProjectSettings.globalize_path(TEST_LOG_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_PREVIEW_HORIZON_CONTRACT_FAIL: %s" % message)
