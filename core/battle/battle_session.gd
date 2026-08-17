extends RefCounted

const GameLogScript := preload("res://core/logging/game_log.gd")

## Application service / explicit state-machine orchestrator. Damage, elements,
## movement, rewards, and authoritative writes remain behind the core port.


func run_combat_round(port: RefCounted, player_side: String, enemy_side: String) -> bool:
	if port.phase() != "battle":
		GameLogScript.warning("战斗/开始行动", "请求被阶段拦截", {"当前阶段": port.phase()})
		return false
	var starting_round: int = int(port.battle_round())
	var trace_before: int = int(port.battle_trace_size())
	GameLogScript.info("战斗/开始行动", "开始结算本回合双方行动", {
		"回合": starting_round,
		"我方存活": port.living_unit_count(player_side),
		"敌方存活": port.living_unit_count(enemy_side),
		"已规划行动": port.action_plan_size(),
		"行动力": port.action_points()
	})
	port.run_player_all_out()
	if port.phase() == "battle" and port.battle_round() == starting_round:
		port.end_player_turn()
	GameLogScript.info("战斗/开始行动", "本次行动结算完成", {
		"起始回合": starting_round,
		"当前回合": port.battle_round(),
		"当前阶段": port.phase(),
		"新增表现事件": port.battle_trace_size() - trace_before,
		"我方英雄生命": port.hero_hp(),
		"敌方英雄生命": port.enemy_hero_hp()
	})
	return true


func run_battle_auto(port: RefCounted, player_side: String) -> bool:
	if port.phase() != "battle":
		port.start_battle()
	var guard := 0
	while port.phase() == "battle" and guard < 40:
		guard += 1
		if port.reset_eligible(player_side):
			port.reset_player_pets()
		port.auto_position_heroes()
		port.run_player_all_out()
		if port.phase() != "battle":
			break
		port.end_player_turn()
	port.log("自动战斗执行 %d 步。" % guard)
	var completed: bool = String(port.phase()) != "battle"
	port.set_last_command_result({
		"ok": completed,
		"completed": completed,
		"steps": guard,
		"autoPositioned": true,
		"phase": port.phase()
	})
	return completed
