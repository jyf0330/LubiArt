extends RefCounted

const SkillEffectPortScript := preload("res://core/ports/skill_effect_port.gd")
const BattleTraceFactoryScript := preload("res://core/battle/battle_trace_factory.gd")

const CONTRACT_ID := &"ysbzs.relic-combat-port.v1"

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func relic_inventory() -> Array:
	return Array(_authority.get("relic_inventory")).duplicate(true)


func game_data() -> Dictionary:
	return Dictionary(_authority.get("game_data"))


func phase() -> String:
	return String(_authority.get("phase"))


func relic_state() -> Dictionary:
	return Dictionary(_authority.get("relic_combat_state"))


func replace_relic_state(state: Dictionary) -> void:
	_authority.set("relic_combat_state", state)


func battle_round() -> int:
	return int(_authority.get("battle_round"))


func append_trace(event_type: String, instance: Dictionary, current_tick: int, trigger: Dictionary) -> void:
	var trace := Array(_authority.get("battle_trace"))
	trace.append(BattleTraceFactoryScript.relic_event(
		trace.size() + 1,
		battle_round(),
		phase(),
		event_type,
		instance,
		current_tick,
		trigger
	))
	_authority.set("battle_trace", trace)


func skill_effect_port() -> RefCounted:
	return SkillEffectPortScript.new(_authority)


func log_guard(reason: String) -> void:
	_authority.call("_log", "遗物事件链已停止：%s。" % reason)
