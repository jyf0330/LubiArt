extends RefCounted

const DamagePropsScript := preload("res://core/battle/damage_props.gd")


func plugin_id() -> String:
	return "mech_thorns_percent"


func after_hit(port: RefCounted, target: Dictionary, source: Dictionary, amount: int, _damage_props: Dictionary, mechanism: Dictionary) -> Array:
	var reflect := int(ceil(float(amount) * 0.5))
	var hp_before := int(source.get("hp", 0))
	var result := Dictionary(port.deal_damage(target, source, reflect, String(target.get("element", "")), {"sourceType": plugin_id()}, DamagePropsScript.non_move_unpowered()))
	var logs: Array = ["%s 触发%s：反伤%d给%s，HP %d→%d。" % [
		String(target.get("name", "单位")), String(mechanism.get("name", plugin_id())), int(result.get("final", reflect)),
		String(source.get("name", "攻击者")), hp_before, int(source.get("hp", 0)),
	]]
	for line in Array(result.get("mechanic_logs", [])):
		logs.append(String(line))
	return logs
