extends "res://core/battle/world/battle_system.gd"

const BattleWorldScript := preload("res://core/battle/world/battle_world.gd")
const STAGE := 400


func system_name() -> StringName:
	return &"death"


func stage() -> int:
	return STAGE


func reads() -> Array[StringName]:
	return [&"alive", &"defeat_queue", &"identity", &"vitals"]


func writes() -> Array[StringName]:
	return [&"alive", &"defeat_queue", &"events"]


func run(world: RefCounted, _context: Dictionary = {}) -> Dictionary:
	var defeated := 0
	var candidates: Array = world.call("take_defeat_candidates")
	for candidate_value in candidates:
		var candidate := Dictionary(candidate_value)
		var entity_id := int(candidate.get("targetEntity", BattleWorldScript.INVALID_ENTITY))
		if not bool(world.call("is_alive", entity_id)):
			continue
		var vitals := Dictionary(world.call("vitals", entity_id))
		if vitals.is_empty() or int(vitals.get("hp", 0)) > 0:
			continue
		world.call("set_alive", entity_id, false)
		var source_entity := int(candidate.get("sourceEntity", BattleWorldScript.INVALID_ENTITY))
		world.call("emit_event", {
			"type": "UNIT_DEFEATED",
			"actor": {
				"entityId": source_entity,
				"id": String(world.call("source_id", source_entity))
			},
			"target": {
				"entityId": entity_id,
				"id": String(world.call("source_id", entity_id))
			},
			"payload": {
				"hp": 0,
				"context": Dictionary(candidate.get("context", {})).duplicate(true)
			}
		})
		defeated += 1
	return {
		"ok": true,
		"candidates": candidates.size(),
		"defeated": defeated
	}
