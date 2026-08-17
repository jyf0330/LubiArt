extends RefCounted

## Single parser for the stable Dictionary surface shared by effect handlers,
## traits, statuses, stat modifiers and content validation. Open plugin IDs are
## intentionally not duplicated here; their directories remain authoritative.

const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const StatIdsScript := preload("res://core/stats/stat_ids.gd")

const FIELD_TYPE := "type"
const FIELD_STAT := "stat"
const FIELD_STAT_ID := "stat_id"
const FIELD_OPERATION := "operation"
const FIELD_HOOK := "hook"
const FIELD_TARGET := "target"
const FIELD_CONDITION := "condition"
const FIELD_CONDITIONS := "conditions"
const FIELD_STATUS_ID := "status_id"

const TYPE_MODIFY_STAT := "modify_stat"
const TYPE_APPLY_STATUS := "apply_status"
const TYPE_REMOVE_STATUS := "remove_status"
const LEGACY_TYPE_PHYSICAL_POWER_BONUS := "physical_power_bonus_permille"
const LEGACY_TYPE_ELEMENT_LAYER_BONUS := "element_layer_bonus"
const CONDITION_ALWAYS := "always"
const CONDITION_ALL := "all"
const CONDITION_ANY := "any"
const CONDITION_NOT := "not"
const DEFAULT_TARGET := "self"
const DEFAULT_ACTION_TARGET := "targets"
const INVALID_CONDITION_TYPE := "__invalid_condition_shape__"
const OWNER_TRAIT_CATALOG := "trait_catalog"
const OWNER_STATUS_CATALOG := "status_catalog"
const OWNER_SKILL_CATALOG := "skill_catalog"
const OWNER_SKILL_COMBO_CATALOG := "skill_combo_catalog"
const OWNER_ECONOMY := "economy"
const OWNER_RELIC_CATALOG := "relic_catalog"
const HOOK_COLLECTION_OWNERS := [OWNER_TRAIT_CATALOG, OWNER_STATUS_CATALOG]
const DIRECT_EXECUTION_OWNERS := [OWNER_SKILL_CATALOG, OWNER_SKILL_COMBO_CATALOG, OWNER_RELIC_CATALOG]


static func text(source: Dictionary, key: String, fallback: String = "") -> String:
	var raw: Variant = source.get(key, fallback)
	if raw == null:
		return fallback
	var value := String(raw).strip_edges()
	return fallback if value == "" else value


static func effect_type(effect: Dictionary) -> String:
	return text(effect, FIELD_TYPE)


static func stat_id(effect: Dictionary) -> String:
	return text(effect, FIELD_STAT, text(effect, FIELD_STAT_ID))


static func operation_id(effect: Dictionary) -> String:
	return text(effect, FIELD_OPERATION) if effect.has(FIELD_OPERATION) else StatOperationIdsScript.FLAT_ADD


static func hook_id(effect: Dictionary) -> String:
	return text(effect, FIELD_HOOK) if effect.has(FIELD_HOOK) else EffectHookIdsScript.ALWAYS


static func target_id(effect: Dictionary, fallback: String = DEFAULT_TARGET) -> String:
	return text(effect, FIELD_TARGET) if effect.has(FIELD_TARGET) else fallback


static func status_id(effect: Dictionary) -> String:
	return text(effect, FIELD_STATUS_ID)


static func condition(effect: Dictionary) -> Dictionary:
	if not effect.has(FIELD_CONDITION):
		return {}
	var value: Variant = effect.get(FIELD_CONDITION, {})
	return Dictionary(value) if value is Dictionary else {FIELD_TYPE: INVALID_CONDITION_TYPE}


static func condition_type(condition_value: Dictionary) -> String:
	return text(condition_value, FIELD_TYPE) if condition_value.has(FIELD_TYPE) else CONDITION_ALWAYS


static func normalize_for_owner(effect: Dictionary, owner_scope: String) -> Dictionary:
	var result := effect.duplicate(true)
	if owner_scope != OWNER_TRAIT_CATALOG:
		return result
	match effect_type(result):
		LEGACY_TYPE_PHYSICAL_POWER_BONUS:
			result[FIELD_TYPE] = TYPE_MODIFY_STAT
			result[FIELD_STAT] = StatIdsScript.PHYSICAL_POWER_PERMILLE
			result[FIELD_OPERATION] = StatOperationIdsScript.FLAT_ADD
		LEGACY_TYPE_ELEMENT_LAYER_BONUS:
			result[FIELD_TYPE] = TYPE_MODIFY_STAT
			result[FIELD_STAT] = StatIdsScript.ELEMENT_LAYER_BONUS
			result[FIELD_OPERATION] = StatOperationIdsScript.FLAT_ADD
	return result
