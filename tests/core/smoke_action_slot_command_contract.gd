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
	_expect(state.dispatch({"type": "SELECT_UNIT", "unitId": unit_id}), "public command selects the action unit")
	_expect(state.dispatch({"type": "SET_ACTION_DIRECTION", "unitId": unit_id, "slotId": 0, "direction": "down"}), "public direction command succeeds")
	_expect(state.dispatch({"type": "SET_ACTION_AP", "unitId": unit_id, "slotId": 0, "ap": 2}), "public AP command succeeds")
	var slot_key := state._action_slot_key(unit, 0)
	_expect(String(Dictionary(state.get("action_dirs")).get(slot_key, "")) == "down", "public command writes the stable direction choice key")
	_expect(int(Dictionary(state.get("action_ap_choices")).get(slot_key, 0)) == 2, "public command writes the stable AP choice key")

	var dirs_before_invalid: Dictionary = Dictionary(state.get("action_dirs")).duplicate(true)
	_expect(not state.dispatch({"type": "SET_ACTION_DIRECTION", "unitId": unit_id, "slotId": 99, "direction": "left"}), "public command rejects a missing slot")
	_expect(Dictionary(state.get("action_dirs")) == dirs_before_invalid, "rejected direction command is non-mutating")
	var ap_before_invalid: Dictionary = Dictionary(state.get("action_ap_choices")).duplicate(true)
	_expect(not state.dispatch({"type": "SET_ACTION_AP", "unitId": unit_id, "slotId": 0, "ap": int(state.get("ap")) + 1}), "public command rejects AP above the budget")
	_expect(Dictionary(state.get("action_ap_choices")) == ap_before_invalid, "rejected AP command is non-mutating")

	var snapshot := state.snapshot()
	var slot := _slot_by_index(Array(snapshot.get("selected_action_slots", [])), 0)
	_expect(String(slot.get("direction", "")) == "down", "Snapshot projects the stored action direction")
	_expect(int(slot.get("selected_ap", 0)) == 2, "Snapshot projects the stored AP choice")
	state._set_action_slot_used(unit, 0, 2)
	_expect(bool(Dictionary(unit.get("action_slots_used", {})).get("0", false)), "compatibility entry delegates used-slot bookkeeping")
	_expect(int(unit.get("action_ap_spent", 0)) == 2, "compatibility entry delegates AP bookkeeping")
	state._reset_action_slots("player")
	_expect(Dictionary(unit.get("action_slots_used", {})).is_empty(), "battle reset clears used-slot state through the service")
	_expect(int(unit.get("action_ap_spent", -1)) == 0, "battle reset clears spent AP through the service")
	_expect(not Dictionary(state.get("action_ap_choices")).has(slot_key), "battle reset clears this unit's AP choices")
	_expect(String(Dictionary(state.get("action_dirs")).get(slot_key, "")) == "down", "battle reset preserves direction compatibility semantics")
	var battle_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	var projection_source := battle_source
	_expect(battle_source.contains("if value > ap:"), "battle coordinator retains AP-budget validation")
	_expect(battle_source.contains("_core_composition.action_slot_service.set_ap_choice("), "validated AP choice writes use the composed service")
	_expect(battle_source.contains("_core_composition.action_slot_service.mark_used("), "battle used-slot writes use the composed service")
	_expect(projection_source.contains("_core_composition.action_slot_service.slot_key("), "command projection keeps the stable helper as a composed delegate")
	_expect(projection_source.contains("_core_composition.action_slot_service.selected_ap("), "Snapshot AP projection uses the composed service")

	if failed:
		quit(1)
		return
	print("SMOKE_ACTION_SLOT_COMMAND_CONTRACT_OK unit=%s slot=%s" % [unit_id, slot_key])
	quit(0)


func _first_player_unit(state: RefCounted) -> Dictionary:
	for value in Array(state.get("units")):
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == "player" and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _slot_by_index(slots: Array, index: int) -> Dictionary:
	for value in slots:
		var slot := Dictionary(value)
		if int(slot.get("index", -1)) == index:
			return slot
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
