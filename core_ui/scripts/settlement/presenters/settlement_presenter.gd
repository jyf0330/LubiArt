extends "res://core_ui/scripts/settlement/controllers/settlement_controller.gd"

## Canonical reward and terminal presentation models.


func reward_cards(snapshot: Dictionary) -> Array:
	var result: Array = []
	var records := rewards(snapshot)
	for index in range(records.size()):
		var reward := Dictionary(records[index])
		result.append({
			"record": reward,
			"command": reward_command(reward, index),
		})
	return result


func terminal_card(snapshot: Dictionary, new_run_seed: String) -> Dictionary:
	var action := terminal_action(snapshot, new_run_seed)
	return {
		"record": {},
		"title": String(action.get("title", "继续")),
		"command": Dictionary(action.get("command", {})),
	}
