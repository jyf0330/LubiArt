extends RefCounted

## Value-only implementation of DamageResolver's preview contract. It owns a
## deep-copied query context and stat services, never a GameState authority.

const CONTRACT_ID := &"ysbzs.damage-preview-port.v1"
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const PLAYER := "player"
const ENEMY := "enemy"

var _context: Dictionary
var _stat_query_service: RefCounted
var _stat_semantic_pipeline: RefCounted


func _init(
	context: Dictionary,
	stat_query_service: RefCounted,
	stat_semantic_pipeline: RefCounted
) -> void:
	# The projector validates and owns the call lifetime. Borrowing this immutable
	# value avoids copying the full content catalog for every projected hit.
	_context = context
	_stat_query_service = stat_query_service
	_stat_semantic_pipeline = stat_semantic_pipeline


func contract_id() -> StringName:
	return CONTRACT_ID


func leader_guard_active(target: Dictionary) -> bool:
	var side := _leader_guard_side(target)
	if side == "":
		return false
	for value in Array(_context.get("units", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var unit := Dictionary(value)
		if String(unit.get("side", "")) == side and int(unit.get("hp", 0)) > 0:
			return true
	return false


func leader_guarded_damage_packet(target: Dictionary, amount: int) -> int:
	return mini(maxi(0, amount), 4) if leader_guard_active(target) else maxi(0, amount)


func stat_value(unit: Dictionary, stat_id: String, context: Dictionary, fallback: int) -> int:
	if unit.is_empty() or _stat_query_service == null:
		return fallback
	return _resolved_stat_value(unit, stat_id, context)


func apply_stat_semantics(event_id: String, context: Dictionary) -> Dictionary:
	if _stat_semantic_pipeline == null:
		return context.duplicate(true)
	var effective := context.duplicate(true)
	effective["stat_value"] = Callable(self, "_resolved_stat_value")
	var result := Dictionary(_stat_semantic_pipeline.call("apply", event_id, effective))
	# The callback is an internal implementation detail and must never escape a
	# value projection result.
	result.erase("stat_value")
	return result


func is_boss(unit: Dictionary) -> bool:
	if String(unit.get("id", "")) == "enemy_boss":
		return true
	if String(unit.get("side", "")) != ENEMY:
		return false
	for key in ["is_boss", "isBoss", "boss"]:
		if bool(unit.get(key, false)):
			return true
	var role_text := "%s %s %s %s" % [
		String(unit.get("role", "")),
		String(unit.get("enemy_role", "")),
		String(unit.get("enemyType", "")),
		String(unit.get("type", "")),
	]
	if role_text.to_lower().find("boss") >= 0 or role_text.find("首领") >= 0:
		return true
	var identity_text := "%s %s" % [String(unit.get("id", "")), String(unit.get("name", ""))]
	return identity_text.to_lower().find("boss") >= 0 or identity_text.find("首领") >= 0


func _resolved_stat_value(unit: Dictionary, stat_id: String, context: Dictionary = {}) -> int:
	var hook := String(context.get("hook", EffectHookIdsScript.BATTLE))
	return int(_stat_query_service.call(
		"value",
		unit,
		Dictionary(_context.get("gameData", {})),
		stat_id,
		hook,
		context
	))


func _leader_guard_side(target: Dictionary) -> String:
	match String(target.get("id", "")):
		"player_hero":
			return PLAYER
		"enemy_boss":
			return ENEMY
	return ""
