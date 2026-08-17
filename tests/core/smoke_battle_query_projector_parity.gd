extends SceneTree

const BattleQueryContextScript := preload("res://core/commands/battle_query_context.gd")
const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")
const StateScript := preload("res://core/state/game_state.gd")

var _failed := false


func _initialize() -> void:
	var state := StateScript.new()
	state.set_run_seed("battle-query-projector-parity")
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture starts battle")
	var player := _first_living_player(state.units)
	_expect(not player.is_empty(), "fixture exposes a living player")
	var player_id := String(player.get("id", ""))
	_expect(state.dispatch({"type": "SELECT_UNIT", "unitId": player_id}), "fixture selects player")
	_expect(state.dispatch({"type": "SET_ACTION_DIRECTION", "unitId": player_id, "slotId": 0, "direction": "up"}), "fixture sets direction")
	_expect(state.dispatch({"type": "SET_ACTION_AP", "unitId": player_id, "slotId": 0, "ap": 2}), "fixture sets AP")

	var context := Dictionary(state.call("_battle_query_context"))
	var context_before := context.duplicate(true)
	var unit_before := player.duplicate(true)
	_expect(BattleQueryContextScript.validate(context).is_empty(), "live query context validates")
	_expect(String(context.get("schema", "")) == BattleQueryContextScript.SCHEMA, "query context exposes v1 schema")
	_expect(not _contains_forbidden_value(context), "query context contains no Object or Callable")
	var projector: RefCounted = state.get("_core_composition").battle_query_projector
	var projected_slots: Array = Array(projector.call("action_slots", context, player))
	var facade_slots: Array = Array(state.call("_action_slots_for_unit", player))
	_expect(projected_slots == facade_slots, "projector and Facade action-slot adapter are exactly equal")
	_expect(context == context_before, "action-slot projection leaves context unchanged")
	_expect(player == unit_before, "action-slot projection leaves unit unchanged")
	for _iteration in range(3):
		_expect(projector.action_slots(context, player) == projected_slots, "action-slot projection is deterministic")

	var unit_rows: Array = Array(projector.call("project_unit_diff_rows", context))
	_expect(unit_rows == _expected_unit_rows(Array(context.get("units", []))), "projector unit rows match frozen projection schema")
	_expect(context == context_before, "unit-row projection leaves context unchanged")

	var request := {"unitId": player_id, "slotId": 0, "direction": "up", "ap": 2}
	var action_grid: Array = Array(projector.project_action_grid(context, request))
	_expect(action_grid == state.call("_battle_query_action_grid", request), "BUILD_PREVIEW adapter is exact projector output")
	var selected_cells: Array = Array(projector.selected_action_cells(context))
	var action_previews: Dictionary = Dictionary(projector.action_preview_by_unit(context))
	var block_ranges: Dictionary = Dictionary(projector.action_block_ranges_by_unit(context))
	var selected_preview_by_cell: Dictionary = Dictionary(projector.selected_action_preview_by_cell(context))
	var board: Dictionary = Dictionary(projector.project_board(context))
	var detail_request := {"x": int(player.get("x", -1)), "y": int(player.get("y", -1))}
	var cell_detail: Dictionary = Dictionary(projector.project_cell_detail(context, detail_request))
	var all_cell_details: Array = Array(projector.project_all_cell_details(context))
	var snapshot: Dictionary = state.snapshot()
	_expect(selected_cells == snapshot.get("selected_action_cells", []), "snapshot selected cells are exact projector output")
	_expect(action_previews == snapshot.get("action_preview_by_unit", {}), "snapshot per-unit previews are exact projector output")
	_expect(block_ranges == snapshot.get("action_block_ranges_by_unit", {}), "snapshot block ranges are exact projector output")
	_expect(board == snapshot.get("board", {}), "snapshot board is exact projector output")
	_expect(Array(board.get("cells", [])).size() == 56, "projected 8x7 board has 56 cells")
	_expect(cell_detail == state.battle_query_cell_detail(detail_request), "public GET_CELL_DETAIL capability is exact projector output")
	_expect(Dictionary(cell_detail.get("unit", {})).get("id", "") == player_id, "cell detail includes the selected unit")
	_expect(all_cell_details.size() == 56, "all-cell detail projection has width*height entries")
	_expect(all_cell_details.has(cell_detail), "all-cell projection contains the matching single-cell detail")
	_expect(projector.project_cell_detail(context, {"x": -1, "y": -1}).is_empty(), "invalid cell detail coordinates fail closed")
	_expect(not selected_preview_by_cell.is_empty(), "selected action grid is projected by the value service")
	_expect(context == context_before, "action and board projections leave context unchanged")

	var enemy := _first_living_enemy(Array(context.get("units", [])))
	var player_before := player.duplicate(true)
	var enemy_before := enemy.duplicate(true)
	var damage: Dictionary = Dictionary(projector.project_damage(
		context, player, enemy, 7, String(player.get("element", "")), {"sourceType": "projector_parity"}
	))
	var query_session: RefCounted = projector.begin(context)
	_expect(damage.has("final"), "value damage port returns the stable resolver schema")
	_expect(query_session != null, "valid context creates one ephemeral query session")
	_expect(query_session.project_damage(player, enemy, 7, String(player.get("element", "")), {"sourceType": "projector_parity"}) == damage, "bound session reuses the same damage projection")
	_expect(not _contains_forbidden_value(damage), "damage projection returns no Object or Callable")
	_expect(player == player_before and enemy == enemy_before, "damage projection leaves source and target unchanged")
	for _iteration in range(3):
		_expect(projector.project_action_grid(context, request) == action_grid, "action-grid projection is deterministic")
		_expect(projector.project_board(context) == board, "board projection is deterministic")
		_expect(projector.project_cell_detail(context, detail_request) == cell_detail, "cell-detail projection is deterministic")
		_expect(projector.project_all_cell_details(context) == all_cell_details, "all-cell detail projection is deterministic")
		_expect(projector.project_damage(context, player, enemy, 7, String(player.get("element", "")), {"sourceType": "projector_parity"}) == damage, "damage projection is deterministic")
	var detached_board := board.duplicate(true)
	Dictionary(Array(detached_board.get("cells", []))[0])["x"] = 999
	_expect(projector.project_board(context) == board, "returned board is detached from later calls")
	var settlement := Dictionary(projector.project_settlement(context, {"火": 3}, "火", {}))
	_expect(int(settlement.get("rawDamage", 0)) == 6, "settlement projection keeps triangular damage")
	_expect(context == context_before, "all C5b projections leave context unchanged")

	var raw_values := context.duplicate(true)
	raw_values.erase("schema")
	var built := BattleQueryContextScript.build(raw_values)
	var built_before := built.duplicate(true)
	Dictionary(raw_values.get("board", {}))["width"] = 99
	Array(raw_values.get("units", []))[0] = {"id": "mutated"}
	Dictionary(raw_values.get("gameData", {}))["sentinel"] = true
	_expect(built == built_before, "build deep-copies every query container")

	var missing := context.duplicate(true)
	missing.erase("units")
	_expect(BattleQueryContextScript.validate(missing).has("BATTLE_QUERY_CONTEXT_MISSING:units"), "missing required key reports stable error")
	var invalid_board := context.duplicate(true)
	invalid_board["board"] = {"width": 0, "height": 7}
	_expect(BattleQueryContextScript.validate(invalid_board).has("BATTLE_QUERY_BOARD_INVALID"), "invalid board reports stable error")
	var forbidden := context.duplicate(true)
	forbidden["gameData"] = {"authority": state}
	_expect(BattleQueryContextScript.validate(forbidden).has("BATTLE_QUERY_CONTEXT_FORBIDDEN_VALUE"), "authority-bearing context fails validation")
	_expect(projector.begin(forbidden) == null, "authority-bearing context cannot create a query session")
	var projector_source := FileAccess.get_file_as_string("res://core/commands/battle_query_projector.gd")
	var session_source := FileAccess.get_file_as_string("res://core/commands/battle_query_session.gd")
	var value_port_source := FileAccess.get_file_as_string("res://core/ports/value_damage_preview_port.gd")
	var query_port_source := FileAccess.get_file_as_string("res://core/ports/query_replay_command_port.gd")
	var facade_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	_expect(not projector_source.contains("game_state.gd") and not projector_source.contains("_authority"), "projector has no GameState back-reference")
	_expect(not session_source.contains("game_state.gd") and not session_source.contains("_authority"), "ephemeral query session has no authority back-reference")
	_expect(not value_port_source.contains("game_state.gd") and not value_port_source.contains("_authority"), "value damage port has no authority back-reference")
	_expect(query_port_source.contains('call("battle_query_cell_detail", action)'), "query Port uses the public cell-detail capability")
	_expect(not query_port_source.contains("_cell_detail_for_action"), "query Port no longer reflects through the old private detail helper")
	_expect(not FileAccess.file_exists("res://core/ports/damage_preview_port.gd"), "authority-backed damage preview port is removed")
	for removed_method in [
		"_board_cells", "_board_snapshot", "_selected_action_cells",
		"_action_preview_by_unit", "_action_block_ranges_by_unit",
		"_selected_action_preview_by_cell", "_build_preview_grid",
		"_threat_grid_by_cell", "_preview_settlement_for_cell",
		"_preview_resolved_damage", "_preview_manual_flow", "_unit_diff_rows",
		"_cell_detail_for_action", "_all_cell_details", "_cell_detail_unit",
	]:
		_expect(not facade_source.contains("func %s(" % removed_method), "Facade no longer defines %s" % removed_method)

	if _failed:
		quit(1)
		return
	print("SMOKE_BATTLE_QUERY_PROJECTOR_PARITY_OK slots=%d units=%d cells=%d previews=%d schema=%s" % [projected_slots.size(), unit_rows.size(), Array(board.get("cells", [])).size(), action_grid.size(), BattleQueryContextScript.SCHEMA])
	quit(0)


func _first_living_player(units: Array) -> Dictionary:
	for item in units:
		var unit := Dictionary(item)
		if String(unit.get("side", "")) == StateScript.PLAYER and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _first_living_enemy(units: Array) -> Dictionary:
	for item in units:
		var unit := Dictionary(item)
		if String(unit.get("side", "")) == StateScript.ENEMY and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _expected_unit_rows(units: Array) -> Array:
	var out: Array = []
	for item in units:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var unit := Dictionary(item)
		out.append({
			"id": String(unit.get("id", "")),
			"name": String(unit.get("name", "")),
			"side": String(unit.get("side", "")),
			"hp": int(unit.get("hp", 0)),
			"shield": int(unit.get("shield", 0)),
			"x": int(unit.get("x", -1)),
			"y": int(unit.get("y", -1)),
			"alive": int(unit.get("hp", 0)) > 0,
			"elements": ElementRulesScript.normalize_layers(Dictionary(unit.get("elements", {}))),
		})
	return out


func _contains_forbidden_value(value: Variant) -> bool:
	if value is Callable or value is Object:
		return true
	if typeof(value) == TYPE_ARRAY:
		for item in Array(value):
			if _contains_forbidden_value(item):
				return true
	elif typeof(value) == TYPE_DICTIONARY:
		for item in Dictionary(value).values():
			if _contains_forbidden_value(item):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Battle query projector parity failed: %s" % message)
