extends SceneTree

const ServiceScript := preload("res://core/battle/skills/skill_action_plan_service.gd")

var failed := false


func _initialize() -> void:
	var entries := [
		{"entryId": "pet_a:a", "unitId": "pet_a", "skillId": "skill_a", "skillSlot": "a", "orderIndex": 0},
		{"entryId": "pet_a:b", "unitId": "pet_a", "skillId": "skill_b", "skillSlot": "b", "orderIndex": 1},
		{"entryId": "missing:a", "unitId": "missing", "skillId": "missing_skill", "orderIndex": 2},
	]
	var catalog := {
		"skill_a": {"action_slot_index": 1},
		"skill_b": {"shape_slot": 2},
	}
	var steps := ServiceScript.new().build(entries, catalog, {
		"pet_a:slot1": "left",
		"pet_a:slot2": "up",
	})
	_expect(steps.size() == 2, "invalid catalog identities are excluded from the plan")
	_expect(String(Dictionary(steps[0]).get("schema", "")) == ServiceScript.SCHEMA, "plan steps publish a versioned schema")
	_expect(String(Dictionary(steps[0]).get("entryId", "")) == "pet_a:a" and int(Dictionary(steps[0]).get("actionSlotIndex", -1)) == 1, "canonical action slot is frozen with stable identity")
	_expect(String(Dictionary(steps[0]).get("direction", "")) == "left", "plan freezes the selected direction")
	_expect(int(Dictionary(steps[1]).get("actionSlotIndex", -1)) == 2 and String(Dictionary(steps[1]).get("direction", "")) == "up", "legacy slot content is normalized before planning")
	_expect(not Dictionary(steps[0]).has("definition") and not Dictionary(steps[0]).has("unit"), "plan never freezes mutable unit or catalog dictionaries")
	if failed:
		quit(1)
		return
	print("SMOKE_SKILL_ACTION_PLAN_SERVICE_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_SKILL_ACTION_PLAN_SERVICE_FAIL: %s" % message)
