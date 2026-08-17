extends RefCounted

const DamagePropsScript := preload("res://core/battle/damage_props.gd")


func plugin_id() -> String:
	return "mech_on_hit_blast"


func after_hit(port: RefCounted, target: Dictionary, _source: Dictionary, _amount: int, _damage_props: Dictionary, mechanism: Dictionary) -> Array:
	var logs: Array = []
	var flags := Dictionary(target.get("flags", {}))
	if bool(flags.get("onHitBlastResolving", false)):
		return logs
	var splash_damage: int = max(0, int(port.mechanic_param_int(target, mechanism, "damage", 2)))
	if splash_damage <= 0:
		return logs
	flags["onHitBlastResolving"] = true
	target["flags"] = flags
	var target_x := int(target.get("x", -1))
	var target_y := int(target.get("y", -1))
	var target_side := String(target.get("side", ""))
	var hit_count := 0
	var pending_deaths: Array = []
	for other_value in port.all_units():
		var adjacent := Dictionary(other_value)
		if String(adjacent.get("id", "")) == String(target.get("id", "")):
			continue
		if String(adjacent.get("side", "")) == target_side or int(adjacent.get("hp", 0)) <= 0:
			continue
		var distance: int = abs(int(adjacent.get("x", -1)) - target_x) + abs(int(adjacent.get("y", -1)) - target_y)
		if distance != 1:
			continue
		var hp_before := int(adjacent.get("hp", 0))
		var splash_result := Dictionary(port.deal_damage(
			target,
			adjacent,
			splash_damage,
			String(target.get("element", "")),
			{"sourceType": "mech_on_hit_blast", "deferDeathResolution": true},
			DamagePropsScript.non_move_unpowered()
		))
		if bool(splash_result.get("pending_death", false)):
			pending_deaths.append({"source": target, "target": adjacent, "result": splash_result})
		hit_count += 1
		logs.append("%s 触发%s：受击溅射%s，HP %d→%d。" % [
			String(target.get("name", "单位")), String(mechanism.get("name", plugin_id())),
			String(adjacent.get("name", "目标")), hp_before, int(adjacent.get("hp", 0)),
		])
		for line in Array(splash_result.get("mechanic_logs", [])):
			logs.append(String(line))
	for death_line in port.resolve_damage_deaths(pending_deaths):
		logs.append(String(death_line))
	flags = Dictionary(target.get("flags", {}))
	flags["onHitBlastResolving"] = false
	target["flags"] = flags
	if hit_count <= 0:
		logs.append("%s 触发%s：受击溅射没有命中相邻敌对单位。" % [
			String(target.get("name", "单位")), String(mechanism.get("name", plugin_id())),
		])
	return logs
