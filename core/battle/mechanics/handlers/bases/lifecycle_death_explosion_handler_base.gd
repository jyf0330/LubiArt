extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return ""


func on_death(port: RefCounted, unit: Dictionary, source: Dictionary, mechanism: Dictionary) -> Array:
	var logs: Array = []
	if not _accepts_lifecycle_port(port) or unit.is_empty() or int(unit.get("hp", 0)) > 0:
		return logs
	var damage: int = max(1, int(port.mechanic_param_int(unit, mechanism, "damage", 6)))
	var label := "%s %s，造成 %d 点伤害" % [
		String(unit.get("name", "单位")),
		String(mechanism.get("name", "死亡爆炸")),
		damage,
	]
	var result := Dictionary(port.cross_damage(
		unit,
		source,
		damage,
		String(unit.get("element", "")),
		label,
		{"sourceType": plugin_id(), "sourceLabel": _trace_source_label()}
	))
	logs.append("%s。" % label)
	for line in Array(result.get("logs", [])):
		logs.append(String(line))
	if int(result.get("hit_count", 0)) <= 0:
		logs.append("%s 没有波及相邻敌对单位。" % String(mechanism.get("name", plugin_id())))
	logs.append("%s 死亡爆发被记录，范围伤害进入事件流。" % String(unit.get("name", "单位")))
	return logs


func _trace_source_label() -> String:
	return ""
