extends RefCounted

## Hook IDs that content may subscribe to. Trigger hooks publish executable
## trait/status effects. Stat-query hooks publish scoped modify_stat lookups.

const ALWAYS := "always"
const SKILL := "skill"
const COMBO := "combo"
const BEFORE_SKILL := "before_skill"
const BEFORE_COMBO := "before_combo"
const AFTER_SKILL := "after_skill"
const AFTER_COMBO := "after_combo"
const ROUND_START := "round_start"
const ROUND_END := "round_end"
const ACTION_COUNT := "action_count"
const ACTION_COST := "action_cost"
const ACTION_ORDER := "action_order"
const ACTION_PROJECTION := "action_projection"
const BEFORE_DAMAGE := "before_damage"
const BATTLE := "battle"
const CELL_DETAIL := "cell_detail"
const COOLDOWN := "cooldown"
const COUNTER_ATTACK := "counter_attack"
const DAMAGE_AFTER := "damage_after"
const DAMAGE_INCOMING := "damage_incoming"
const DAMAGE_OUTGOING := "damage_outgoing"
const DAMAGE_PREVIEW := "damage_preview"
const EFFECT := "effect"
const EFFECT_TARGET := "effect_target"
const ENEMY_PET_ACTION := "enemy_pet_action"
const ENEMY_TARGETING := "enemy_targeting"
const HEALING := "healing"
const MOVEMENT := "movement"
const MOVEMENT_COST := "movement_cost"
const NORMAL_ATTACK := "normal_attack"
const QUALITY_REPEAT := "quality_repeat"
const RETALIATION_PREVIEW := "retaliation_preview"
const SNAPSHOT := "snapshot"
const STATUS_INCOMING := "status_incoming"
const STATUS_OUTGOING := "status_outgoing"
const SUMMON := "summon"
const THREAT_PROJECTION := "threat_projection"

const TRIGGER_HOOKS := [
	SKILL,
	COMBO,
	BEFORE_SKILL,
	BEFORE_COMBO,
	AFTER_SKILL,
	AFTER_COMBO,
	ROUND_START,
	ROUND_END,
]

const STAT_QUERY_HOOKS := [
	ACTION_COUNT,
	ACTION_COST,
	ACTION_ORDER,
	ACTION_PROJECTION,
	BEFORE_DAMAGE,
	BATTLE,
	CELL_DETAIL,
	COOLDOWN,
	COUNTER_ATTACK,
	DAMAGE_AFTER,
	DAMAGE_INCOMING,
	DAMAGE_OUTGOING,
	DAMAGE_PREVIEW,
	EFFECT,
	EFFECT_TARGET,
	ENEMY_PET_ACTION,
	ENEMY_TARGETING,
	HEALING,
	MOVEMENT,
	MOVEMENT_COST,
	NORMAL_ATTACK,
	QUALITY_REPEAT,
	RETALIATION_PREVIEW,
	SNAPSHOT,
	STATUS_INCOMING,
	STATUS_OUTGOING,
	SUMMON,
	THREAT_PROJECTION,
]

static var MODIFIER_HOOKS: Array[String] = _concat_hooks([ALWAYS], TRIGGER_HOOKS, STAT_QUERY_HOOKS)
static var ALL: Array[String] = MODIFIER_HOOKS.duplicate()


static func _concat_hooks(a: Array, b: Array, c: Array) -> Array[String]:
	var result: Array[String] = []
	result.append_array(a)
	result.append_array(b)
	result.append_array(c)
	return result
