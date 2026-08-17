extends RefCounted

## Application service for the player's complete action phase. It owns ordering,
## not authoritative state or combat math.


func run_all_out(port: RefCounted) -> void:
	if port.phase() != "battle":
		return
	port.set_resolving(true)
	var original_unit_id: String = port.selected_unit_id()
	var original_slot_index: int = port.selected_slot_index()
	var trigger_count := 0
	var triggered_combos := {}
	var executed_skill_ids: Array[String] = []
	for step_value in port.skill_action_plan():
		var step := Dictionary(step_value)
		var unit: Dictionary = port.unit_for_step(step)
		if unit.is_empty():
			continue
		var unit_id := String(unit.get("id", ""))
		port.set_selection(unit_id, 0)
		if port.phase() != "battle":
			break
		var skill_id := String(step.get("skillId", ""))
		if not port.execute_skill_step(unit, step):
			continue
		executed_skill_ids.append(skill_id)
		trigger_count += 1
		for combo_value in port.skill_combos(executed_skill_ids, executed_skill_ids.size() - 1, triggered_combos):
			if port.phase() != "battle":
				break
			var combo := Dictionary(combo_value)
			if port.execute_combo(unit, combo):
				triggered_combos[String(combo.get("id", ""))] = true
				trigger_count += 1
	if trigger_count == 0:
		port.log("没有可触发技能：请检查宠物技能配置。")
	else:
		port.log("全部出击结束：按 4 宠物共享技能条触发 %d 个技能/组合。" % trigger_count)
	port.finish_skill_phase()
	port.settle_elements()
	port.set_selection(original_unit_id, original_slot_index)
	port.set_resolving(false)
