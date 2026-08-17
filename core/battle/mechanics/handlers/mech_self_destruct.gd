extends "res://core/battle/mechanics/handlers/bases/lifecycle_death_explosion_handler_base.gd"

const ROUND_PORT_CONTRACT_ID := &"ysbzs.round-lifecycle-port.v1"


func plugin_id() -> String:
	return "mech_self_destruct"


func round_end(port: RefCounted, unit: Dictionary, _side: String, mechanism: Dictionary) -> Array:
	if not _accepts_round_port(port) or unit.is_empty():
		return []
	var flags := Dictionary(unit.get("flags", {}))
	if bool(flags.get("selfDestructResolved", false)):
		return []
	var rounds: int = max(1, int(port.mechanic_param_int(unit, mechanism, "rounds", 2)))
	var tick: int = int(flags.get("selfDestructTicks", 0)) + 1
	flags["selfDestructTicks"] = tick
	unit["flags"] = flags
	if tick < rounds:
		return ["%s 自爆倒计时 %d/%d。" % [String(unit.get("name", "单位")), tick, rounds]]
	var damage: int = max(1, int(port.mechanic_param_int(unit, mechanism, "damage", 8)))
	var label := "%s 自爆，造成 %d 点伤害" % [String(unit.get("name", "单位")), damage]
	var result := Dictionary(port.apply_cross_damage(
		unit,
		unit,
		damage,
		String(unit.get("element", "")),
		label,
		{"sourceType": plugin_id(), "sourceLabel": "自爆波及"}
	))
	var logs: Array = [{"line": "%s。" % label, "placement": "front"}]
	for line in Array(result.get("logs", [])):
		logs.append(String(line))
	flags = Dictionary(unit.get("flags", {}))
	flags["selfDestructResolved"] = true
	flags["onDeathMechanicsApplied"] = true
	unit["flags"] = flags
	unit["hp"] = 0
	if int(result.get("hit_count", 0)) <= 0:
		logs.append("自爆没有波及相邻敌对单位。")
	return logs


func project_death_preview(
	unit: Dictionary,
	mechanism: Dictionary,
	facts: Dictionary
) -> Dictionary:
	if not bool(facts.get("projected_dead", false)):
		return {}
	return {
		"radius": 1,
		"metric": "manhattan",
		"damage": max(1, _mechanic_param_int(unit, mechanism, "damage", 8)),
	}


func _mechanic_param_int(unit: Dictionary, mechanism: Dictionary, key: String, fallback: int) -> int:
	var unit_params := Dictionary(unit.get("mechanic_params", unit.get("mechanicParams", {})))
	if unit_params.has(key):
		return int(unit_params.get(key, fallback))
	for part in String(mechanism.get("default_params", "")).replace("；", ";").split(";", false):
		var text := String(part).strip_edges()
		var equals_index := text.find("=")
		if equals_index > 0 and text.substr(0, equals_index).strip_edges() == key:
			return int(float(text.substr(equals_index + 1).strip_edges()))
	return fallback


func _trace_source_label() -> String:
	return "自爆波及"


func _accepts_round_port(port: RefCounted) -> bool:
	return (
		port != null
		and port.has_method(&"contract_id")
		and StringName(port.call(&"contract_id")) == ROUND_PORT_CONTRACT_ID
	)
