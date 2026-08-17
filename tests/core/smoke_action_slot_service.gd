extends SceneTree

const ServiceScript := preload("res://core/battle/action_slot_service.gd")

var failed := false


func _initialize() -> void:
	var service := ServiceScript.new()
	var unit := {
		"id": "pal_action",
		"action_slots_used": {},
		"action_ap_spent": 0,
		"quality_runtime": {"keep": true},
	}
	var directions := {"0": "left", "other:slot0": "up"}
	var choices := {"other:slot0": 3}
	_expect(service.slot_key(unit, 2) == "pal_action:slot2", "slot key is stable and unit-scoped")
	_expect(service.stored_direction(unit, 0, directions) == "left", "legacy numeric direction key remains readable")
	_expect(service.set_direction(unit, 0, "down", directions), "valid direction write succeeds")
	_expect(service.stored_direction(unit, 0, directions) == "down", "unit-scoped direction overrides the legacy key")
	_expect(String(directions.get("other:slot0", "")) == "up", "direction write preserves another unit")

	_expect(service.selected_ap(unit, 0, choices, 3) == 1, "missing AP choice defaults to one")
	_expect(service.set_ap_choice(unit, 0, 2, choices), "validated AP choice is stored")
	_expect(service.selected_ap(unit, 0, choices, 3) == 2, "stored AP choice is projected")
	var choices_before_invalid: Dictionary = choices.duplicate(true)
	_expect(not service.set_ap_choice(unit, 0, 0, choices), "non-positive prevalidated AP value fails closed")
	_expect(choices == choices_before_invalid, "rejected AP write is non-mutating")
	_expect(not service.set_ap_choice({}, 0, 1, choices), "empty unit AP write fails closed")

	_expect(service.mark_used(unit, 0, 2), "mark-used accepts an explicit authoritative unit")
	_expect(bool(Dictionary(unit.get("action_slots_used", {})).get("0", false)), "used schema records the slot index")
	_expect(int(unit.get("action_ap_spent", 0)) == 2, "used schema accumulates spent AP")
	var slots := [{"index": 0, "used": true}, {"index": 1, "used": false}]
	_expect(service.has_used(unit), "service detects a used action slot")
	_expect(service.has_available(slots), "service detects an available projected slot")
	_expect(service.next_available_index(slots) == 1, "service returns the first available projected slot")

	_expect(service.clear_unit(unit, choices, 3), "clear accepts the authoritative unit")
	_expect(Dictionary(unit.get("action_slots_used", {})).is_empty(), "clear removes used-slot state")
	_expect(int(unit.get("action_ap_spent", -1)) == 0, "clear resets spent AP")
	_expect(not choices.has("pal_action:slot0") and int(choices.get("other:slot0", 0)) == 3, "clear removes only this unit's AP choices")
	_expect(bool(Dictionary(unit.get("quality_runtime", {})).get("keep", false)), "clear preserves unrelated unit runtime")
	_expect(String(directions.get("pal_action:slot0", "")) == "down", "clear preserves direction choices like the compatibility path")

	var equivalent_a := {"id": "same", "action_slots_used": {}, "action_ap_spent": 0}
	var equivalent_b: Dictionary = equivalent_a.duplicate(true)
	var choices_a := {}
	var choices_b := {}
	var second := ServiceScript.new()
	service.set_ap_choice(equivalent_a, 1, 2, choices_a)
	second.set_ap_choice(equivalent_b, 1, 2, choices_b)
	service.mark_used(equivalent_a, 1, 2)
	second.mark_used(equivalent_b, 1, 2)
	_expect(equivalent_a == equivalent_b and choices_a == choices_b, "separate instances produce deterministic equivalent writes")

	if failed:
		quit(1)
		return
	print("SMOKE_ACTION_SLOT_SERVICE_OK key=%s ap=%d" % [
		service.slot_key(unit, 0),
		2,
	])
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
