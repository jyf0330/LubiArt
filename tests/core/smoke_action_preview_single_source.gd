extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const BATTLE_CONTROLLER_PATH := "res://core_ui/scripts/battle/scenes/battle_scene.gd"

var _failed := false


func _initialize() -> void:
	var state = StateScript.new()
	state.set_run_seed("action-preview-single-source")
	_expect(state.dispatch({"type": "START_BATTLE"}), "battle starts")
	var snapshot: Dictionary = state.snapshot()
	var previews := Dictionary(snapshot.get("action_preview_by_unit", {}))
	var block_ranges_by_unit := Dictionary(snapshot.get("action_block_ranges_by_unit", {}))
	var living_player_ids: Array[String] = []
	for unit_value in Array(snapshot.get("units", [])):
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) != "player" or int(unit.get("hp", 0)) <= 0:
			continue
		var unit_id := String(unit.get("id", ""))
		living_player_ids.append(unit_id)
		_expect(previews.has(unit_id), "snapshot projects action preview for %s" % unit_id)
		_expect(block_ranges_by_unit.has(unit_id), "snapshot projects three action-block ranges for %s" % unit_id)
		if not previews.has(unit_id):
			continue
		var preview := Dictionary(previews[unit_id])
		_expect(String(preview.get("unitId", "")) == unit_id, "preview keeps unit identity")
		_expect(Dictionary(preview.get("origin", {})).has("x"), "preview exposes authoritative origin")
		_expect(preview.has("slotIndex"), "preview exposes the core-selected slot")
		_expect(preview.has("cells"), "preview exposes core-computed cells")
		var block_ranges := Array(block_ranges_by_unit.get(unit_id, []))
		_expect(block_ranges.size() == 3, "range projection exposes exactly three action blocks")
		for block_value in block_ranges:
			_expect(Dictionary(block_value).has("cells"), "each action-block range exposes core-computed cells")
	for cell_value in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		var action_preview := Dictionary(Dictionary(cell_value).get("action_preview_data", {}))
		if action_preview.is_empty():
			continue
		_expect(String(action_preview.get("previewHorizon", "")) == "immediate_action", "board target preview declares its immediate-action horizon")
	_expect(not living_player_ids.is_empty(), "battle fixture has living player units")

	var view_model := Dictionary(state.run_command({
		"type": "GET_CELL_DETAIL",
		"r": 0,
		"c": 0,
		"commandId": "action-preview-query"
	}).get("viewModel", {}))
	_expect(Dictionary(view_model.get("actionPreviewByUnit", {})).size() == previews.size(), "public ViewModel forwards per-unit previews")
	_expect(Dictionary(view_model.get("actionBlockRangesByUnit", {})).size() == block_ranges_by_unit.size(), "public ViewModel forwards three-block ranges")

	var ui_source := FileAccess.get_file_as_string(BATTLE_CONTROLLER_PATH)
	_expect(not ui_source.contains("_computed_drag_action_cells"), "battle UI no longer computes attack shapes")
	_expect(not ui_source.contains("_apply_drag_quality_shape_mutation"), "battle UI no longer mutates quality shapes")
	for quality_id in ["D01", "D02", "D03", "D04", "D06", "D09", "D10", "D20"]:
		_expect(not ui_source.contains("\"%s\"" % quality_id), "battle UI contains no concrete quality rule %s" % quality_id)

	if _failed:
		quit(1)
		return
	print("SMOKE_ACTION_PREVIEW_SINGLE_SOURCE_OK units=%d" % previews.size())
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_ACTION_PREVIEW_SINGLE_SOURCE_FAIL: %s" % message)
