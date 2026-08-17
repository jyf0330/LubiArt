extends RefCounted

## Stable IDs for the planner-owned stat Type Objects. Data remains the source
## of labels, bounds and defaults; gameplay code imports these IDs instead of
## scattering string literals.

const ACTION_COST_DELTA := "action_cost_delta"
const ACTION_POINTS := "action_points"
const ARMOR_PIERCE_FLAT := "armor_pierce_flat"
const ARMOR_PIERCE_PERMILLE := "armor_pierce_permille"
const ATK := "atk"
const ATTACK_COUNT := "attack_count"
const BLOCK_RATE_PERMILLE := "block_rate_permille"
const BLOCK_VALUE := "block_value"
const BOSS_DAMAGE_PERMILLE := "boss_damage_permille"
const COMBO_POWER_PERMILLE := "combo_power_permille"
const CONTROL_RESIST_PERMILLE := "control_resist_permille"
const COOLDOWN_RATE_PERMILLE := "cooldown_rate_permille"
const CRIT_DAMAGE_PERMILLE := "crit_damage_permille"
const CRIT_RATE_PERMILLE := "crit_rate_permille"
const DAMAGE_TAKEN_PERMILLE := "damage_taken_permille"
const DARK_RESIST_PERMILLE := "dark_resist_permille"
const DEF := "def"
const DODGE_RATE_PERMILLE := "dodge_rate_permille"
const DRAGON_RESIST_PERMILLE := "dragon_resist_permille"
const ELECTRIC_RESIST_PERMILLE := "electric_resist_permille"
const ELEMENT_LAYER_BONUS := "element_layer_bonus"
const ELEMENT_POWER_PERMILLE := "element_power_permille"
const ELEMENT_TAKEN_PERMILLE := "element_taken_permille"
const FIRE_RESIST_PERMILLE := "fire_resist_permille"
const GRASS_RESIST_PERMILLE := "grass_resist_permille"
const GROUND_RESIST_PERMILLE := "ground_resist_permille"
const HEALING_POWER_PERMILLE := "healing_power_permille"
const HEALING_TAKEN_PERMILLE := "healing_taken_permille"
const ICE_RESIST_PERMILLE := "ice_resist_permille"
const INITIATIVE := "initiative"
const LIFESTEAL_PERMILLE := "lifesteal_permille"
const MAX_HP := "max_hp"
const MOVE_RANGE := "move_range"
const MOVEMENT_COST_DELTA := "movement_cost_delta"
const NEUTRAL_RESIST_PERMILLE := "neutral_resist_permille"
const PHYSICAL_POWER_PERMILLE := "physical_power_permille"
const PHYSICAL_TAKEN_PERMILLE := "physical_taken_permille"
const SHIELD_GAIN_PERMILLE := "shield_gain_permille"
const SKILL_POWER_PERMILLE := "skill_power_permille"
const SPEED := "speed"
const STARTING_SHIELD := "starting_shield"
const STATUS_DURATION_PERMILLE := "status_duration_permille"
const STATUS_HIT_PERMILLE := "status_hit_permille"
const STATUS_RESIST_PERMILLE := "status_resist_permille"
const SUMMON_POWER_PERMILLE := "summon_power_permille"
const THREAT := "threat"
const WATER_RESIST_PERMILLE := "water_resist_permille"

const ALL := [
	ACTION_COST_DELTA,
	ACTION_POINTS,
	ARMOR_PIERCE_FLAT,
	ARMOR_PIERCE_PERMILLE,
	ATK,
	ATTACK_COUNT,
	BLOCK_RATE_PERMILLE,
	BLOCK_VALUE,
	BOSS_DAMAGE_PERMILLE,
	COMBO_POWER_PERMILLE,
	CONTROL_RESIST_PERMILLE,
	COOLDOWN_RATE_PERMILLE,
	CRIT_DAMAGE_PERMILLE,
	CRIT_RATE_PERMILLE,
	DAMAGE_TAKEN_PERMILLE,
	DARK_RESIST_PERMILLE,
	DEF,
	DODGE_RATE_PERMILLE,
	DRAGON_RESIST_PERMILLE,
	ELECTRIC_RESIST_PERMILLE,
	ELEMENT_LAYER_BONUS,
	ELEMENT_POWER_PERMILLE,
	ELEMENT_TAKEN_PERMILLE,
	FIRE_RESIST_PERMILLE,
	GRASS_RESIST_PERMILLE,
	GROUND_RESIST_PERMILLE,
	HEALING_POWER_PERMILLE,
	HEALING_TAKEN_PERMILLE,
	ICE_RESIST_PERMILLE,
	INITIATIVE,
	LIFESTEAL_PERMILLE,
	MAX_HP,
	MOVE_RANGE,
	MOVEMENT_COST_DELTA,
	NEUTRAL_RESIST_PERMILLE,
	PHYSICAL_POWER_PERMILLE,
	PHYSICAL_TAKEN_PERMILLE,
	SHIELD_GAIN_PERMILLE,
	SKILL_POWER_PERMILLE,
	SPEED,
	STARTING_SHIELD,
	STATUS_DURATION_PERMILLE,
	STATUS_HIT_PERMILLE,
	STATUS_RESIST_PERMILLE,
	SUMMON_POWER_PERMILLE,
	THREAT,
	WATER_RESIST_PERMILLE,
]
