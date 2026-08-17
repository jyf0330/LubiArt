extends RefCounted

## Outer run-flow application service. It coordinates route, shop, reward,
## battle-result, and day transitions only through the explicit session port.


func run_full_day(port: RefCounted) -> bool:
	var phase: String = String(port.phase())
	if phase == "day_end":
		port.log("完整日流程：第%d天已经结束。" % port.day())
		return true
	if phase == "game_over":
		port.log("完整日流程：单局已经结束。")
		return true
	var target_day: int = int(port.day())
	var guard := 0
	while port.day() == target_day and port.phase() not in ["day_end", "game_over"] and guard < 80:
		guard += 1
		phase = port.phase()
		match phase:
			"route":
				var options: Array = Array(port.route_options())
				if options.is_empty():
					if port.is_current_day_route_complete():
						port.set_day_end()
						continue
					port.log("完整日流程停止：当前没有路线候选。")
					return false
				var chosen := false
				var attempted_ids: Array[String] = []
				for option_value in options:
					var option := Dictionary(option_value)
					var option_id := String(option.get("id", option.get("nodeId", "")))
					if option_id == "":
						continue
					attempted_ids.append(option_id)
					if port.choose_route(option_id):
						chosen = true
						break
				if not chosen:
					port.log("完整日流程停止：路线节点均不可用 %s。" % ",".join(attempted_ids))
					return false
			"shop":
				port.back_to_route()
			"reward":
				if port.reward_options_empty():
					port.return_to_route_or_day_end()
				elif not port.pick_first_reward():
					port.log("完整日流程停止：奖励领取失败。")
					return false
			"battle":
				var battle_succeeded: bool = bool(port.run_battle_auto())
				if not battle_succeeded and port.phase() not in ["battle_end", "game_over"]:
					port.log("完整日流程停止：自动战斗失败。")
					return false
			"battle_end":
				if not port.continue_after_battle():
					port.log("完整日流程停止：战斗结算确认失败。")
					return false
			_:
				port.log("完整日流程停止：未知阶段 %s。" % phase)
				return false
	if guard >= 80:
		port.log("完整日流程停止：超过保护步数。")
		return false
	port.log("完整日流程执行 %d 步，当前阶段 %s。" % [guard, port.phase()])
	return port.phase() in ["day_end", "game_over"]


func run_full_run(port: RefCounted) -> bool:
	if port.phase() == "game_over":
		port.log("完整单局流程：单局已经结束。")
		return true
	var guard := 0
	while port.phase() != "game_over" and guard < 240:
		guard += 1
		if port.phase() == "day_end":
			var next_day: int = int(port.day()) + 1
			if next_day <= port.max_scheduled_day() and port.has_schedule_for_day(next_day):
				if not port.start_next_day(next_day):
					port.log("完整单局流程停止：无法进入第%d天。" % next_day)
					return false
				continue
			port.log("完整单局流程执行 %d 步，停在第%d天日结。" % [guard, port.day()])
			return true
		if not run_full_day(port):
			port.log("完整单局流程停止：第%d天自动流程失败。" % port.day())
			return false
	port.log("完整单局流程执行 %d 步，当前阶段 %s。" % [guard, port.phase()])
	return port.phase() in ["day_end", "game_over"]
