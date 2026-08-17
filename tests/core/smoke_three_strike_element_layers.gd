extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: RefCounted = _r1c5_fixture()
	var projector: RefCounted = state.get("_core_composition").battle_query_projector
	var preview_by_cell := Dictionary(projector.selected_action_preview_by_cell(state.call("_battle_query_context")))
	var preview_cell := Dictionary(preview_by_cell.get("4,0", {}))
	_expect(
		int(preview_cell.get("layers", 0)) == 3,
		"R1C5 preview reports three total layers"
	)
	state.battle_trace = []
	_expect(state.use_selected_action_slot(1), "R1C5 action succeeds")
	_expect(int(state._cell_elements_at(4, 0).get("水", 0)) == 3, "R1C5 keeps three water layers after the three-strike action")
	var element_events: Array = []
	for event_value in state.battle_trace:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) == "ELEMENT_APPLIED":
			element_events.append(event)
	_expect(element_events.size() == 1, "R1C5 action emits one aggregate element event")
	if element_events.size() == 1:
		var payload := Dictionary(Dictionary(element_events[0]).get("payload", {}))
		_expect(int(payload.get("layers", 0)) == 3, "R1C5 trace carries the three applied layers")
	_expect(_log_contains(state, "水3层"), "player log reports the three applied layers")
	if failed:
		quit(1)
		return
	print("SMOKE_THREE_STRIKE_ELEMENT_LAYERS_OK")
	quit(0)


func _r1c5_fixture() -> RefCounted:
	var state: RefCounted = StateScript.new()
	state.dispatch({"type": "START_BATTLE"})
	var actor: Dictionary = {}
	var enemy: Dictionary = {}
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.PLAYER and actor.is_empty():
			actor = unit
		elif String(unit.get("side", "")) == StateScript.ENEMY and enemy.is_empty():
			enemy = unit
	state.units = [actor, enemy]
	actor["id"] = "r1c5_actor"
	actor["name"] = "企丸丸"
	actor["x"] = 3
	actor["y"] = 0
	actor["shape"] = "形状01"
	actor["shape_id"] = "01"
	actor["shape_name"] = "形状01"
	actor["slot_count"] = 1
	actor["slot_elements"] = ["水"]
	actor["base_layers"] = 1
	actor["action_slots_used"] = {}
	enemy["x"] = 7
	enemy["y"] = 6
	state.ap = 1
	state.selected_unit_id = "r1c5_actor"
	state.selected_action_slot_index = 0
	state.action_dirs[state._action_slot_key(actor, 0)] = "right"
	return state


func _log_contains(state: RefCounted, needle: String) -> bool:
	for line_value in Array(state.snapshot().get("log_lines", [])):
		if String(line_value).contains(needle):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_THREE_STRIKE_ELEMENT_LAYERS_FAIL: %s" % message)
