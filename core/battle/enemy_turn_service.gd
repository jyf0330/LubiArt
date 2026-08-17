extends RefCounted

## Application service for enemy round-start effects, positioning, targeting, and
## action ordering. Target scoring and damage remain delegated through the port.


func run(port: RefCounted) -> void:
	port.reset_action_slots()
	port.begin_round()
	port.auto_position()
	var target_by_unit := {}
	var required_target_by_unit := {}
	var triggered_combos := {}
	var executed_skill_ids: Array[String] = []
	for step_value in port.skill_action_plan():
		var step := Dictionary(step_value)
		var enemy: Dictionary = port.unit_for_step(step)
		if enemy.is_empty():
			continue
		var enemy_id := String(enemy.get("id", ""))
		if not target_by_unit.has(enemy_id):
			var target: Dictionary = port.nearest_player(enemy)
			if target.is_empty():
				return
			target_by_unit[enemy_id] = target
			var required_target: Dictionary = {}
			var taunt_redirect := Dictionary(enemy.get("target_select_redirect", {}))
			if not taunt_redirect.is_empty():
				required_target = target
				port.log("%s 被%s嘲讽，优先攻击%s。" % [
					String(enemy.get("name", "敌人")),
					String(taunt_redirect.get("mechanic_name", "嘲讽守护")),
					String(target.get("name", "守护者"))
				])
				enemy.erase("target_select_redirect")
			required_target_by_unit[enemy_id] = required_target
		var skill_id := String(step.get("skillId", ""))
		var required_target := Dictionary(required_target_by_unit.get(enemy_id, {}))
		if not port.execute_skill_step(enemy, step, required_target):
			continue
		executed_skill_ids.append(skill_id)
		if port.hero_hp() <= 0 or port.phase() != "battle":
			return
		for combo_value in port.skill_combos(executed_skill_ids, executed_skill_ids.size() - 1, triggered_combos):
			var combo := Dictionary(combo_value)
			if port.execute_combo(enemy, combo, required_target):
				triggered_combos[String(combo.get("id", ""))] = true
			if port.hero_hp() <= 0 or port.phase() != "battle":
				return
