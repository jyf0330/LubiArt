extends "res://core/battle/world/battle_system.gd"

const STAGE := 300


func system_name() -> StringName:
	return &"damage"


func stage() -> int:
	return STAGE


func reads() -> Array[StringName]:
	return [&"damage_queue", &"identity", &"vitals"]


func writes() -> Array[StringName]:
	return [&"damage_queue", &"vitals", &"events"]


func run(world: RefCounted, _context: Dictionary = {}) -> Dictionary:
	var packets: Array = world.call("take_pending_damage_packets")
	var processed := 0
	var total_shield_damage := 0
	var total_hp_damage := 0
	for packet_value in packets:
		var packet := Dictionary(packet_value)
		var target_entity := int(packet.get("targetEntity", -1))
		var resolved_amount := int(packet.get("resolvedAmount", 0))
		var vitals := Dictionary(world.call("vitals", target_entity))
		if vitals.is_empty() or resolved_amount <= 0:
			continue
		var hp_before := int(vitals.get("hp", 0))
		var shield_before := int(vitals.get("shield", 0))
		var round_damage_before := int(vitals.get("roundDamageTaken", 0))
		var shield_damage: int = min(shield_before, resolved_amount)
		var hp_damage: int = min(hp_before, max(0, resolved_amount - shield_damage))
		var shield_after := shield_before - shield_damage
		var hp_after := hp_before - hp_damage
		var final_damage := shield_damage + hp_damage
		if final_damage <= 0:
			continue
		var source_entity := int(packet.get("sourceEntity", -1))
		world.call(
			"write_vitals",
			target_entity,
			hp_after,
			shield_after,
			round_damage_before + hp_damage
		)
		total_shield_damage += shield_damage
		total_hp_damage += hp_damage
		processed += 1
		world.call("emit_event", {
			"type": "DAMAGE_APPLIED",
			"actor": {
				"entityId": source_entity,
				"id": String(world.call("source_id", source_entity))
			},
			"target": {
				"entityId": target_entity,
				"id": String(world.call("source_id", target_entity))
			},
			"payload": {
				"resolvedAmount": resolved_amount,
				"final": final_damage,
				"shieldDamage": shield_damage,
				"hpDamage": hp_damage,
				"shieldBefore": shield_before,
				"shieldAfter": shield_after,
				"hpBefore": hp_before,
				"hpAfter": hp_after,
				"element": String(packet.get("element", "")),
				"context": Dictionary(packet.get("context", {})).duplicate(true)
			}
		})
		if hp_before > 0 and hp_after <= 0:
			world.call(
				"queue_defeat_candidate",
				source_entity,
				target_entity,
				Dictionary(packet.get("context", {}))
			)
	return {
		"ok": true,
		"packets": packets.size(),
		"processed": processed,
		"shieldDamage": total_shield_damage,
		"hpDamage": total_hp_damage
	}
