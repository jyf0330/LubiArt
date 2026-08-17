extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const MAX_ROUTE_COMMAND_MS := 900
const MAX_SNAPSHOT_US := 600_000

var _failed := false


func _initialize() -> void:
	var state = StateScript.new()
	_assert_combined_battle_projection_parity(state)
	var run_plan := Dictionary(state.get("run_plan"))
	_expect(String(run_plan.get("plan_hash", "")) == String(state.call("_run_plan_hash", run_plan)), "stored run-plan hash equals a full recomputation")

	var shop_option_id := _route_option_id(state, "shop")
	_expect(shop_option_id != "", "fixture exposes a shop route")
	var started := Time.get_ticks_msec()
	var response := Dictionary(state.run_command({"type": "CHOOSE_ROUTE", "optionId": shop_option_id}))
	var duration_ms := Time.get_ticks_msec() - started
	_expect(bool(response.get("accepted", false)), "shop route command is accepted")
	_expect(String(Dictionary(response.get("snapshot", {})).get("phase", "")) == "shop", "returned Snapshot enters shop")
	_expect(String(response.get("stateHash", "")) == String(state.call("_state_hash")), "reused command hash equals a fresh authoritative hash")
	_expect(duration_ms <= MAX_ROUTE_COMMAND_MS, "shop route command remains within %dms budget (actual %dms)" % [MAX_ROUTE_COMMAND_MS, duration_ms])
	var snapshot_us := int(Dictionary(response.get("timing", {})).get("snapshotDurationUs", -1))
	_expect(snapshot_us >= 0 and snapshot_us <= MAX_SNAPSHOT_US, "command Snapshot remains within %dus budget (actual %dus)" % [MAX_SNAPSHOT_US, snapshot_us])

	var before_rejection_hash := String(state.call("_state_hash"))
	var before_rejection_version := int(state.get("state_version"))
	var rejected := Dictionary(state.run_command({"type": "NOT_A_REAL_COMMAND"}))
	_expect(not bool(rejected.get("accepted", true)), "unknown command remains rejected")
	_expect(String(state.call("_state_hash")) == before_rejection_hash, "rejection preserves authoritative hash")
	_expect(int(state.get("state_version")) == before_rejection_version, "rejection preserves authoritative version")

	var document := Dictionary(state.save_document())
	var restored = StateScript.new()
	_expect(restored.load_document(document), "optimized state still restores from its save document")
	_expect(String(restored.call("_state_hash")) == String(state.call("_state_hash")), "save/load preserves the optimized authoritative hash")

	if _failed:
		quit(1)
		return
	print("SMOKE_COMMAND_LATENCY_BUDGET_OK route_ms=%d snapshot_us=%d" % [duration_ms, snapshot_us])
	quit()


func _assert_combined_battle_projection_parity(state) -> void:
	var composition: RefCounted = state.get("_core_composition")
	var projector: RefCounted = composition.get("battle_query_projector")
	var context := Dictionary(state.call("_battle_query_context"))
	var unit := Dictionary(state.call("selected_unit"))
	var combined := Dictionary(projector.call("snapshot_projection", context, unit))
	_expect(Array(combined.get("actionSlots", [])) == Array(projector.call("action_slots", context, unit)), "combined action slots equal the public projection")
	_expect(Array(combined.get("selectedActionCells", [])) == Array(projector.call("selected_action_cells", context)), "combined selected cells equal the public projection")
	_expect(Dictionary(combined.get("actionPreviewByUnit", {})) == Dictionary(projector.call("action_preview_by_unit", context)), "combined action previews equal the public projection")
	_expect(Dictionary(combined.get("actionBlockRangesByUnit", {})) == Dictionary(projector.call("action_block_ranges_by_unit", context)), "combined block ranges equal the public projection")
	_expect(Dictionary(combined.get("board", {})) == Dictionary(projector.call("project_board", context)), "combined board equals the public projection")


func _route_option_id(state, kind: String) -> String:
	for value in Array(state.get("route_options")):
		var option := Dictionary(value)
		if String(option.get("kind", "")) == kind:
			return String(option.get("id", option.get("optionId", "")))
	return ""


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_COMMAND_LATENCY_BUDGET_FAIL: %s" % message)
