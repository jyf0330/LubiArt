extends RefCounted

## Explicit application-service port around the authoritative state. Dynamic
## compatibility access is localized here so BattleSession depends only on named
## capabilities rather than the complete legacy core surface.

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func phase() -> String:
	return String(_authority.get("phase"))


func day() -> int:
	return int(_authority.get("day"))


func battle_round() -> int:
	return int(_authority.get("battle_round"))


func battle_trace_size() -> int:
	return Array(_authority.get("battle_trace")).size()


func action_plan_size() -> int:
	return Array(_authority.get("auto_position_action_plan")).size()


func action_points() -> int:
	return int(_authority.get("ap"))


func hero_hp() -> int:
	return int(_authority.get("hero_hp"))


func enemy_hero_hp() -> int:
	return int(_authority.get("enemy_hero_hp"))


func living_unit_count(side: String) -> int:
	return int(_authority.call("_living_unit_count", side))


func reset_eligible(side: String) -> bool:
	return bool(Dictionary(_authority.get("pet_reset_eligible")).get(side, false))


func route_options() -> Array:
	return Array(_authority.get("route_options"))


func max_scheduled_day() -> int:
	return int(_authority.call("_max_scheduled_day"))


func has_schedule_for_day(target_day: int) -> bool:
	return bool(_authority.call("_has_schedule_for_day", target_day))


func is_current_day_route_complete() -> bool:
	return bool(_authority.call("_is_current_day_route_complete"))


func start_battle() -> void:
	_authority.call("start_battle")


func run_player_all_out() -> void:
	_authority.call("run_player_all_out")


func end_player_turn() -> void:
	_authority.call("end_player_turn")


func reset_player_pets() -> bool:
	return bool(_authority.call("reset_player_pets"))


func auto_position_heroes() -> bool:
	return bool(_authority.call("auto_position_heroes"))


func run_battle_auto() -> bool:
	return bool(_authority.call("run_battle_auto"))


func choose_route(option_id: String) -> bool:
	return bool(_authority.call("choose_route", option_id))


func set_day_end() -> void:
	_authority.call("_set_day_end")


func back_to_route() -> void:
	_authority.call("back_to_route")


func return_to_route_or_day_end() -> void:
	_authority.call("_return_to_route_or_day_end")


func pick_first_reward() -> bool:
	return bool(_authority.call("pick_reward", {"index": 0}))


func reward_options_empty() -> bool:
	return Array(_authority.get("reward_options")).is_empty()


func continue_after_battle() -> bool:
	return bool(_authority.call("continue_after_battle"))


func start_next_day(target_day: int) -> bool:
	return bool(_authority.call("start_next_day", target_day))


func set_last_command_result(result: Dictionary) -> void:
	_authority.set("last_command_result", result)


func log(message: String) -> void:
	_authority.call("_log", message)
