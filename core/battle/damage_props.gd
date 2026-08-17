extends RefCounted

## Orthogonal properties for one damage packet. These flags compose; they are
## deliberately not an enum of mutually exclusive physical/magic/true types.

const MOVE := "move"
const UNPOWERED := "unpowered"
const UNBLOCKABLE := "unblockable"
const SKIP_HURT_ANIM := "skip_hurt_anim"

const ALL: Array[String] = [MOVE, UNPOWERED, UNBLOCKABLE, SKIP_HURT_ANIM]

const _ALIASES := {
	"move": MOVE,
	"unpowered": UNPOWERED,
	"unblockable": UNBLOCKABLE,
	"skip_hurt_anim": SKIP_HURT_ANIM,
	"skipHurtAnim": SKIP_HURT_ANIM,
	"Move": MOVE,
	"Unpowered": UNPOWERED,
	"Unblockable": UNBLOCKABLE,
	"SkipHurtAnim": SKIP_HURT_ANIM,
}

const _MOVE_SOURCE_TYPES := {
	"action": true,
	"action_area": true,
	"action_projection": true,
	"attack_power_smoke": true,
	"auto_position_action": true,
	"counter_attack": true,
	"enemy_pet_action": true,
	"enemy_targeting": true,
	"quality_chase": true,
	"quality_repeat": true,
	"retaliation_preview": true,
	"skill": true,
	"skill_combo": true,
	"threat_projection": true,
}

const _HP_LOSS_SOURCE_TYPES := {
	"hp_loss": true,
	"poison": true,
	"self_cost": true,
}


static func normalize(value: Variant = {}) -> Dictionary:
	var result := {
		MOVE: false,
		UNPOWERED: false,
		UNBLOCKABLE: false,
		SKIP_HURT_ANIM: false,
	}
	if value is Dictionary:
		for raw_key in Dictionary(value).keys():
			var key := String(raw_key)
			var canonical := String(_ALIASES.get(key, ""))
			if canonical != "":
				result[canonical] = bool(Dictionary(value).get(raw_key, false))
	elif value is Array or value is PackedStringArray:
		for raw_flag in value:
			var canonical := String(_ALIASES.get(String(raw_flag), ""))
			if canonical != "":
				result[canonical] = true
	elif value != null:
		var canonical := String(_ALIASES.get(String(value), ""))
		if canonical != "":
			result[canonical] = true
	return result


static func has(value: Variant, flag: String) -> bool:
	return bool(normalize(value).get(flag, false))


static func move_damage() -> Dictionary:
	return normalize({MOVE: true})


static func move_unpowered() -> Dictionary:
	return normalize({MOVE: true, UNPOWERED: true})


static func move_hp_loss() -> Dictionary:
	return normalize({MOVE: true, UNPOWERED: true, UNBLOCKABLE: true})


static func non_move_unpowered() -> Dictionary:
	return normalize({UNPOWERED: true})


static func non_move_hp_loss() -> Dictionary:
	return normalize({UNPOWERED: true, UNBLOCKABLE: true})


static func for_source_type(source_type: String) -> Dictionary:
	var normalized_source := source_type.strip_edges().to_lower()
	if _MOVE_SOURCE_TYPES.has(normalized_source):
		return move_damage()
	if _HP_LOSS_SOURCE_TYPES.has(normalized_source):
		return non_move_hp_loss()
	return non_move_unpowered()


static func resolve(declared: Variant, source_type: String) -> Dictionary:
	return normalize(declared) if is_declared(declared) else for_source_type(source_type)


static func is_declared(value: Variant) -> bool:
	if value is Dictionary:
		for raw_key in Dictionary(value).keys():
			if _ALIASES.has(String(raw_key)):
				return true
		return false
	if value is Array or value is PackedStringArray:
		for raw_flag in value:
			if _ALIASES.has(String(raw_flag)):
				return true
		return false
	return value != null and _ALIASES.has(String(value))


static func is_move(value: Variant) -> bool:
	return has(value, MOVE)


static func is_powered(value: Variant) -> bool:
	return not has(value, UNPOWERED)


static func is_blockable(value: Variant) -> bool:
	return not has(value, UNBLOCKABLE)
