extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	var state := StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "fixture starts battle through the public command")
	var unit := _first_player_unit(state)
	_expect(not unit.is_empty(), "fixture exposes one living player unit")
	if unit.is_empty():
		quit(1)
		return
	var unit_id := String(unit.get("id", ""))
	unit["quality_upgrade"] = {"id": "G01", "name": "攻守转换"}
	unit["quality_runtime"] = {"flags": {"keep": true}}
	_expect(state.dispatch({"type": "SELECT_UNIT", "unitId": unit_id}), "public command selects the quality unit")
	_expect(state.dispatch({"type": "SET_QUALITY_MODE", "unitId": unit_id, "mode": "guard"}), "public command accepts a mode alias")
	var mode_runtime := Dictionary(unit.get("quality_runtime", {}))
	_expect(String(mode_runtime.get("mode", "")) == "守", "public mode command stores the normalized mode")
	_expect(bool(mode_runtime.get("mode_explicit", false)), "public mode command records explicit intent")
	_expect(bool(Dictionary(mode_runtime.get("flags", {})).get("keep", false)), "public mode command preserves strategy flags")
	var before_invalid: Dictionary = unit.duplicate(true)
	_expect(not state.dispatch({"type": "SET_QUALITY_MODE", "unitId": unit_id, "mode": "invalid-mode"}), "public command rejects an unknown mode")
	_expect(unit == before_invalid, "rejected public mode command is non-mutating")

	unit["quality_upgrade"] = {"id": "G22", "name": "标记护盾"}
	var slot := state._selected_action_slot(unit)
	var option := state._attack_option_for_direction(unit, String(slot.get("direction", "right")))
	var cells := Array(option.get("cells", []))
	_expect(not slot.is_empty() and not cells.is_empty(), "fixture exposes one usable action option")
	if slot.is_empty() or cells.is_empty():
		quit(1)
		return
	var cell := Dictionary(cells[0])
	var x := int(cell.get("x", -1))
	var y := int(cell.get("y", -1))
	_expect(state.dispatch({"type": "SET_QUALITY_MARK", "unitId": unit_id, "x": x, "y": y}), "public command writes a legal quality mark")
	var marked := Dictionary(Dictionary(unit.get("quality_runtime", {})).get("marked_cell", {}))
	_expect(marked == {
		"x": x,
		"y": y,
		"c": x,
		"r": y,
		"key": "%d,%d" % [x, y],
		"slot_index": int(slot.get("index", 0)),
		"round": int(state.get("battle_round")),
	}, "public mark command preserves the compatibility schema")
	var before_invalid_mark: Dictionary = unit.duplicate(true)
	_expect(not state.dispatch({"type": "SET_QUALITY_MARK", "unitId": unit_id, "x": -1, "y": -1}), "public command rejects an out-of-board mark")
	_expect(unit == before_invalid_mark, "rejected public mark command is non-mutating")
	var snapshot := state.snapshot()
	var mark_action := _next_action(snapshot, "SET_QUALITY_MARK")
	_expect(Dictionary(mark_action.get("defaultPayload", {})).get("cell", {}) == marked, "snapshot projects the authoritative mark through the existing command contract")
	state._reset_action_slots("player")
	var cleared_runtime := Dictionary(unit.get("quality_runtime", {}))
	_expect(not cleared_runtime.has("marked_cell"), "action-slot reset clears the quality mark")
	_expect(String(cleared_runtime.get("mode", "")) == "守", "action-slot reset preserves the stored mode")
	_expect(bool(Dictionary(cleared_runtime.get("flags", {})).get("keep", false)), "action-slot reset preserves strategy flags")

	if failed:
		quit(1)
		return
	print("SMOKE_QUALITY_RUNTIME_COMMAND_CONTRACT_OK unit=%s mark=%s" % [unit_id, String(marked.get("key", ""))])
	quit(0)


func _first_player_unit(state: RefCounted) -> Dictionary:
	for value in Array(state.get("units")):
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == "player" and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _next_action(snapshot: Dictionary, action_type: String) -> Dictionary:
	for value in Array(Dictionary(snapshot.get("viewModel", {})).get("nextActions", [])):
		var action := Dictionary(value)
		if String(action.get("type", "")) == action_type:
			return action
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
