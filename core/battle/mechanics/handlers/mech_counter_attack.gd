extends RefCounted

const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const DamagePropsScript := preload("res://core/battle/damage_props.gd")


func plugin_id() -> String:
	return "mech_counter_attack"


func after_hit(port: RefCounted, target: Dictionary, source: Dictionary, _amount: int, _damage_props: Dictionary, mechanism: Dictionary) -> Array:
	var flags := Dictionary(target.get("flags", {}))
	if int(flags.get("counterAttackRound", -1)) == int(port.battle_round()):
		return []
	var ap_cost: int = max(0, int(port.mechanic_param_int(target, mechanism, "ap_cost", 1)))
	if int(target.get("ap", 0)) < ap_cost:
		return []
	var damage_param := String(port.mechanic_param_string(target, mechanism, "damage", "atk"))
	var counter_damage := int(port.resolved_stat_value(target, "atk", {"hook": EffectHookIdsScript.COUNTER_ATTACK, "target": source}))
	if damage_param != "" and damage_param != "atk":
		counter_damage = max(0, int(float(damage_param)))
	if counter_damage <= 0:
		return []
	var target_ap_before := int(target.get("ap", 0))
	var source_hp_before := int(source.get("hp", 0))
	target["ap"] = max(0, target_ap_before - ap_cost)
	flags["counterAttackRound"] = int(port.battle_round())
	target["flags"] = flags
	var result := Dictionary(port.deal_damage(
		target,
		source,
		counter_damage,
		String(target.get("element", "")),
		{"sourceType": "counter_attack"},
		DamagePropsScript.move_damage()
	))
	var logs: Array = ["%s 触发%s：立即反击%s，AP %d→%d，HP %d→%d。" % [
		String(target.get("name", "单位")), String(mechanism.get("name", plugin_id())),
		String(source.get("name", "攻击者")), target_ap_before, int(target.get("ap", 0)),
		source_hp_before, int(source.get("hp", 0)),
	]]
	for line in Array(result.get("mechanic_logs", [])):
		logs.append(String(line))
	return logs
