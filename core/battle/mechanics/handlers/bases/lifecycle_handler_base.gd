extends RefCounted

const LIFECYCLE_PORT_CONTRACT_ID := &"ysbzs.unit-lifecycle-mechanic-port.v1"


func _accepts_lifecycle_port(port: RefCounted) -> bool:
	return (
		port != null
		and port.has_method(&"contract_id")
		and StringName(port.call(&"contract_id")) == LIFECYCLE_PORT_CONTRACT_ID
	)


func _summon_death_units(
	port: RefCounted,
	unit: Dictionary,
	mechanism: Dictionary,
	count: int,
	display_name: String,
	default_hp: int,
	default_atk: int
) -> int:
	var summoned_count := 0
	for _index in range(max(0, count)):
		var cell := Dictionary(port.first_empty_near(unit, true))
		if cell.is_empty():
			break
		var summoned := Dictionary(port.summon_unit(
			unit, mechanism, cell, "mon_swarm_plain_01", display_name, default_hp, default_atk
		))
		if summoned.is_empty():
			break
		summoned_count += 1
	return summoned_count


func _reward_copy(reward_state: Dictionary) -> Dictionary:
	return {
		"gold": int(reward_state.get("gold", 0)),
		"logs": Array(reward_state.get("logs", [])).duplicate(true),
		"applied": Array(reward_state.get("applied", [])).duplicate(true),
		"extra_rewards": Array(reward_state.get("extra_rewards", [])).duplicate(true),
		"discount_from": int(reward_state.get("discount_from", 0)),
		"discount_to": int(reward_state.get("discount_to", 0)),
		"discount_requested": bool(reward_state.get("discount_requested", false)),
	}
