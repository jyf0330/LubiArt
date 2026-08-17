extends RefCounted

## Versioned write-through boundary for the death safe point. The service owns
## ordering; the port exposes only the existing authoritative hook capabilities.

const CONTRACT_ID := &"ysbzs.damage-death-port.v1"
var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func should_die(target: Dictionary) -> bool:
	return not target.is_empty() and int(target.get("hp", 0)) <= 0


func on_death(target: Dictionary, source: Dictionary) -> Array:
	return Array(_authority.call("_apply_mechanic_on_death", target, source))


func after_ally_death(target: Dictionary) -> Array:
	return Array(_authority.call("_apply_mechanic_after_ally_death", target))


func attacker_after_kill(source: Dictionary, target: Dictionary) -> Array:
	return Array(_authority.call("_apply_attacker_mechanic_after_kill", source, target))


func publish_defeated(source: Dictionary, target: Dictionary) -> void:
	_authority.call("_publish_relic_event", "UNIT_DEFEATED", {
		"source_unit_id": String(source.get("id", "")),
		"source_side": String(source.get("side", "")),
		"target_unit_id": String(target.get("id", "")),
		"target_side": String(target.get("side", "")),
	})
