extends RefCounted

## Pure command-commit lifecycle. Hashing and command_log publication happen
## before this plan is consumed; repositories/checkpoints are applied afterward.


func plan(action_type: String, has_run: bool, before_phase: String, after_phase: String) -> Dictionary:
	var begin_reason := ""
	if action_type == "NEW_RUN":
		begin_reason = "new_run"
	elif not has_run:
		begin_reason = "implicit"
	var checkpoint_kinds: Array[String] = []
	if action_type == "NEW_RUN" or action_type == "START_NEXT_DAY":
		checkpoint_kinds.append("start")
	if action_type == "RUN_FULL_DAY" and after_phase != "game_over":
		checkpoint_kinds.append("end")
	elif after_phase == "day_end" and before_phase != "day_end":
		checkpoint_kinds.append("end")
	elif after_phase == "game_over" and before_phase != "game_over":
		checkpoint_kinds.append("terminal")
	return {
		"beginReason": begin_reason,
		"checkpointKinds": checkpoint_kinds,
	}
