extends RefCounted

## Versioned bridge for the unified damage pipeline. All dynamic compatibility
## calls stay here; DamageResolver never receives a full authority or a bag of
## per-call Callables.

const CONTRACT_ID := &"ysbzs.damage-resolution-port.v2"
var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func leader_guard_active(target: Dictionary) -> bool:
	return bool(_authority.call("_leader_guard_active", target))


func leader_guarded_damage_packet(target: Dictionary, amount: int) -> int:
	return int(_authority.call("_leader_guarded_damage_packet", target, amount))


func before_damage(target: Dictionary, source: Dictionary, amount: int, element: String, damage_props: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("_apply_mechanic_before_damage", target, source, amount, element, damage_props))


func stat_value(unit: Dictionary, stat_id: String, context: Dictionary, fallback: int) -> int:
	if unit.is_empty():
		return fallback
	return int(_authority.call("_resolved_stat_value", unit, stat_id, context))


func apply_stat_semantics(event_id: String, context: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("_apply_stat_semantics", event_id, context))


func is_boss(unit: Dictionary) -> bool:
	return bool(_authority.call("_is_boss_enemy", unit))


func heal_source(source: Dictionary, amount: int) -> int:
	return int(_authority.call("_heal_unit", source, amount))


func sync_leader_hp(target: Dictionary) -> void:
	_authority.call("_sync_leader_hp_from_target", target)


func record_trace(
	source: Dictionary,
	target: Dictionary,
	raw_damage: int,
	shield_damage: int,
	hp_damage: int,
	hp_before: int,
	hp_after: int,
	shield_before: int,
	shield_after: int,
	element: String,
	trace_context: Dictionary
) -> void:
	_authority.call(
		"_record_damage_trace",
		source,
		target,
		raw_damage,
		shield_damage,
		hp_damage,
		hp_before,
		hp_after,
		shield_before,
		shield_after,
		element,
		trace_context
	)


func on_shield_break(target: Dictionary, source: Dictionary) -> Array:
	return Array(_authority.call("_apply_mechanic_on_shield_break", target, source))


func after_damage(target: Dictionary, source: Dictionary, amount: int, damage_props: Dictionary) -> Array:
	return Array(_authority.call("_apply_mechanic_after_damage", target, source, amount, damage_props))


func after_hit(target: Dictionary, source: Dictionary, amount: int, damage_props: Dictionary) -> Array:
	return Array(_authority.call("_apply_mechanic_after_hit", target, source, amount, damage_props))
