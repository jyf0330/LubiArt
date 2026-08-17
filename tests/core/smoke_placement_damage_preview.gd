extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	var state := StateScript.new()
	if not state.dispatch({"type": "START_BATTLE"}):
		_fail("fixture can start battle")
		return
	var actor := state.unit_by_id("pal_002")
	var target := _first_enemy(state)
	if actor.is_empty() or target.is_empty():
		_fail("fixture has a player actor and enemy target")
		return
	for unit in state.units:
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
	var target_id := String(target.get("id", ""))
	var response: Dictionary = state.run_command({
		"type": "MOVE_HERO",
		"unitId": "pal_002",
		"to": {"r": 5, "c": 4},
		"baseStateVersion": int(state.snapshot().get("stateVersion", 0)),
		"commandId": "smoke_placement_damage_preview"
	})
	var preview := Dictionary(response.get("manualFlowPreview", {}))
	_expect(String(preview.get("previewHorizon", "")) == "manual_round_flow", "preview declares the whole manual-round-flow horizon")
	var target_diff := _unit_diff(preview, target_id)
	var summary := Dictionary(target_diff.get("damageSummary", {}))
	_expect(String(summary.get("previewHorizon", "")) == "manual_round_flow", "damage summary keeps the manual-round-flow horizon")
	_expect(int(summary.get("totalDamage", 0)) > 0, "preview aggregates totalDamage")
	_expect(int(summary.get("hpDamage", 0)) > 0, "preview aggregates hpDamage")
	_expect(int(summary.get("hpFrom", -1)) == 50 and int(summary.get("hpTo", -1)) < 50, "preview exposes hp range")
	var target_cell := _board_cell(state, 5, 5)
	var threat := Dictionary(target_cell.get("threat", {}))
	_expect(String(threat.get("source", "")) == "manual_flow_preview", "current board projects manual-flow threat")
	_expect(int(threat.get("totalDamage", 0)) == int(summary.get("totalDamage", -1)), "board threat reuses damage summary")
	_expect(int(state.unit_by_id(target_id).get("hp", 0)) == 50, "preview keeps authoritative target hp unchanged")
	var auto_response: Dictionary = state.run_command({
		"type": "AUTO_POSITION_HEROES",
		"baseStateVersion": int(state.snapshot().get("stateVersion", 0)),
		"commandId": "smoke_auto_position_damage_preview"
	})
	_expect(bool(auto_response.get("ok", false)), "auto-position fixture command is accepted")
	var auto_snapshot := state.snapshot()
	var auto_damage_by_unit := Dictionary(auto_snapshot.get("placementDamageByUnit", {}))
	var auto_target_cell := _board_cell(state, int(target.get("x", -1)), int(target.get("y", -1)))
	var auto_board_threat := Dictionary(auto_target_cell.get("threat", {}))
	_expect(state.dispatch({"type": "GET_CELL_DETAIL", "r": int(target.get("y", -1)), "c": int(target.get("x", -1))}), "auto-position fixture can request target cell detail")
	var auto_detail := Dictionary(state.snapshot().get("lastCommandResult", {}))
	var auto_detail_threat := Dictionary(auto_detail.get("threat", {}))
	if auto_damage_by_unit.has(target_id):
		var auto_summary := Dictionary(auto_damage_by_unit.get(target_id, {}))
		_expect(String(auto_board_threat.get("source", "")) == "manual_flow_preview", "auto-position board threat comes from the real placement preview")
		_expect(int(auto_board_threat.get("totalDamage", -1)) == int(auto_summary.get("totalDamage", -2)), "auto-position board threat matches placement damage summary")
		_expect(String(auto_detail_threat.get("source", "")) == "manual_flow_preview", "cell detail reuses the same auto-position placement preview")
		_expect(int(auto_detail_threat.get("totalDamage", -1)) == int(auto_board_threat.get("totalDamage", -2)), "cell detail and board show the same incoming damage after auto-position")
	else:
		_expect(auto_board_threat.is_empty(), "zero-damage auto-position clears the stale board threat")
		_expect(auto_detail_threat.is_empty(), "zero-damage auto-position clears the stale cell-detail threat")
	if failed:
		quit(1)
		return
	print("SMOKE_PLACEMENT_DAMAGE_PREVIEW_OK")
	quit(0)


func _first_enemy(state: RefCounted) -> Dictionary:
	for unit in state.units:
		if String(unit.get("side", "")) == StateScript.ENEMY:
			return unit
	return {}


func _unit_diff(preview: Dictionary, unit_id: String) -> Dictionary:
	for item in Array(preview.get("unitDiffs", [])):
		if typeof(item) == TYPE_DICTIONARY and String(Dictionary(item).get("id", "")) == unit_id:
			return Dictionary(item)
	return {}


func _board_cell(state: RefCounted, x: int, y: int) -> Dictionary:
	for item in Array(Dictionary(state.snapshot().get("board", {})).get("cells", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var cell := Dictionary(item)
		if int(cell.get("x", -1)) == x and int(cell.get("y", -1)) == y:
			return cell
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("Smoke failed: %s" % message)
