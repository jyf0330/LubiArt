extends RefCounted

## Owns reward/terminal ViewModel commands without touching authored nodes.


func rewards(snapshot: Dictionary) -> Array:
	return Array(snapshot.get("reward_options", [])).duplicate(true)


func reward_command(reward: Dictionary) -> Dictionary:
	return {"type": "PICK_REWARD", "rewardId": String(reward.get("id", ""))}


func terminal_action(snapshot: Dictionary, new_run_seed: String) -> Dictionary:
	match String(snapshot.get("phase", "")):
		"battle_end":
			return {"title": "继续结算", "command": {"type": "CONTINUE_AFTER_BATTLE"}}
		"day_end":
			return {
				"title": "下一天",
				"command": {"type": "START_NEXT_DAY"},
			}
		_:
			return {"title": "重新开局", "command": {"type": "NEW_RUN", "seed": new_run_seed}}
