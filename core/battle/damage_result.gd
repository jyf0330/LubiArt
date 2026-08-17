extends RefCounted

const DamagePropsScript := preload("res://core/battle/damage_props.gd")

## Stable transient result for one resolved packet. Legacy snake_case keys stay
## available while richer consumers can stop re-deriving outcomes from HP.

const SCHEMA := "ysbzs.damage-result"
const SCHEMA_VERSION := 1


static func empty(props: Variant = {}) -> Dictionary:
	return build({
		"props": props,
		"receiver": {},
	})


static func build(values: Dictionary) -> Dictionary:
	var hp_before: int = max(0, int(values.get("hp_before", 0)))
	var hp_after: int = max(0, int(values.get("hp_after", hp_before)))
	var shield_before: int = max(0, int(values.get("shield_before", 0)))
	var shield_after: int = max(0, int(values.get("shield_after", shield_before)))
	var shield_damage: int = max(0, int(values.get("shield_damage", shield_before - shield_after)))
	var hp_lost: int = max(0, hp_before - hp_after)
	var hp_damage_packet: int = max(0, int(values.get("hp_damage", values.get("unblocked_damage", hp_lost))))
	var unblocked_damage: int = max(0, int(values.get("unblocked_damage", hp_lost)))
	var overkill_damage: int = max(0, int(values.get("overkill_damage", hp_damage_packet - unblocked_damage)))
	var final_damage: int = max(0, int(values.get("final", shield_damage + hp_damage_packet)))
	var pending_death: bool = bool(values.get("pending_death", hp_before > 0 and hp_after <= 0))
	var was_target_killed: bool = bool(values.get("was_target_killed", false))
	var result := {
		"schema": SCHEMA,
		"schema_version": SCHEMA_VERSION,
		"raw": max(0, int(values.get("raw", 0))),
		"modified_damage": max(0, int(values.get("modified_damage", final_damage))),
		"blocked_damage": shield_damage,
		"unblocked_damage": unblocked_damage,
		"overkill_damage": overkill_damage,
		"total_damage": shield_damage + unblocked_damage,
		"actual_damage": shield_damage + hp_lost,
		"hp_lost": hp_lost,
		"was_block_broken": bool(values.get(
			"was_block_broken",
			shield_before > 0 and shield_damage > 0 and shield_after <= 0
		)),
		"was_fully_blocked": bool(values.get(
			"was_fully_blocked",
			DamagePropsScript.is_blockable(values.get("props", {})) and shield_before > 0 and hp_damage_packet <= 0
		)),
		"pending_death": pending_death,
		"was_target_killed": was_target_killed,
		"receiver": Dictionary(values.get("receiver", {})).duplicate(true),
		"props": DamagePropsScript.normalize(values.get("props", {})),
		"phases": Dictionary(values.get("phases", {})).duplicate(true),
		"element": String(values.get("element", "")),
		"guard_reduction": max(0, int(values.get("guard_reduction", 0))),
		"incoming_bonus": max(0, int(values.get("incoming_bonus", 0))),
		"leader_guard_applied": bool(values.get("leader_guard_applied", false)),
		"mechanic_logs": Array(values.get("mechanic_logs", [])).duplicate(),
		# Compatibility keys used by current gameplay, logs and tests.
		"shield_damage": shield_damage,
		"hp_damage": hp_damage_packet,
		"final": final_damage,
	}
	return result


static func settle_death(result: Dictionary, killed: bool) -> void:
	result["pending_death"] = false
	result["was_target_killed"] = killed
