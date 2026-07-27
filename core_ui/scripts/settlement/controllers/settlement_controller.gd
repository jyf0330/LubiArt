extends RefCounted

## Owns reward/terminal ViewModel commands without touching authored nodes.


func rewards(snapshot: Dictionary) -> Array:
	return Array(snapshot.get("reward_options", [])).duplicate(true)


func reward_command(reward: Dictionary, index: int) -> Dictionary:
	var command := {"type": "PICK_REWARD", "index": index}
	if String(reward.get("id", "")) != "":
		command["id"] = String(reward.get("id", ""))
	return command


func terminal_action(snapshot: Dictionary, new_run_seed: String) -> Dictionary:
	match String(snapshot.get("phase", "")):
		"battle_end":
			return {"title": "继续结算", "command": {"type": "CONTINUE_AFTER_BATTLE"}}
		"day_end":
			return {
				"title": "下一天",
				"command": {"type": "START_NEXT_DAY", "day": int(snapshot.get("day", 1)) + 1},
			}
		_:
			return {"title": "重新开局", "command": {"type": "NEW_RUN", "seed": new_run_seed}}
