extends RefCounted

const SkillActionRulesScript := preload("res://core/battle/skills/skill_action_rules.gd")

## Pure projection from the authoritative shared skill bar to immutable-by-
## convention execution steps. Steps freeze identities and intent only; ports
## re-resolve live units and catalog definitions before mutation.

const SCHEMA := "ysbzs.skill-action-plan-step.v1"


func build(entries: Array, skill_catalog: Dictionary, action_directions: Dictionary = {}) -> Array:
	var steps: Array = []
	for entry_value in entries:
		var entry := Dictionary(entry_value)
		var entry_id := String(entry.get("entryId", entry.get("entry_id", ""))).strip_edges()
		var unit_id := String(entry.get("unitId", entry.get("unit_id", ""))).strip_edges()
		var skill_id := String(entry.get("skillId", entry.get("skill_id", ""))).strip_edges()
		var definition := Dictionary(skill_catalog.get(skill_id, {}))
		if entry_id == "" or unit_id == "" or skill_id == "" or definition.is_empty():
			continue
		var slot_index := SkillActionRulesScript.action_slot_index(definition)
		steps.append({
			"schema": SCHEMA,
			"entryId": entry_id,
			"unitId": unit_id,
			"skillId": skill_id,
			"skillSlot": String(entry.get("skillSlot", entry.get("skill_slot", ""))),
			"orderIndex": int(entry.get("orderIndex", entry.get("order_index", steps.size()))),
			"actionSlotIndex": slot_index,
			"direction": String(action_directions.get("%s:slot%d" % [unit_id, slot_index], "right")),
		})
	return steps
