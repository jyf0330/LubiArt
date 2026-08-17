extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const SEED := "codex-text-battle-20260812-v1"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := StateScript.new()
	state.set_run_seed(SEED)
	var responses: Array = []
	responses.append(state.run_command({"type": "START_BATTLE", "commandId": "text_start"}))
	for action_type in _requested_commands():
		responses.append(state.run_command({
			"type": action_type,
			"commandId": "text_%02d_%s" % [responses.size(), action_type.to_lower()],
		}))
	var snapshot := state.snapshot()
	print("TEXT_BATTLE_CORE_JSON %s" % JSON.stringify({
		"seed": SEED,
		"responses": _response_summaries(responses),
		"snapshot": _snapshot_summary(snapshot),
	}))
	quit(0)


func _requested_commands() -> Array[String]:
	var result: Array[String] = []
	for arg_value in OS.get_cmdline_user_args():
		var arg := String(arg_value)
		if not arg.begins_with("--commands="):
			continue
		for command in arg.trim_prefix("--commands=").split(",", false):
			result.append(command.strip_edges().to_upper())
	return result


func _response_summaries(responses: Array) -> Array:
	var result: Array = []
	for response_value in responses:
		var response := Dictionary(response_value)
		result.append({
			"command": String(response.get("command", "")),
			"accepted": bool(response.get("accepted", false)),
			"stateVersion": int(response.get("stateVersion", -1)),
			"events": Array(response.get("events", [])).duplicate(true),
			"result": response.get("result", null),
		})
	return result


func _snapshot_summary(snapshot: Dictionary) -> Dictionary:
	return {
		"phase": String(snapshot.get("phase", "")),
		"stateVersion": int(snapshot.get("stateVersion", -1)),
		"stateHash": String(snapshot.get("stateHash", "")),
		"round": int(snapshot.get("battle_round", 0)),
		"period": String(snapshot.get("battle_period", "")),
		"ap": int(snapshot.get("ap", 0)),
		"heroHp": int(snapshot.get("hero_hp", 0)),
		"enemyHeroHp": int(snapshot.get("enemy_hero_hp", 0)),
		"units": Array(snapshot.get("units", [])).duplicate(true),
		"leaders": snapshot.get("leaders", {}).duplicate(true),
		"petReset": Dictionary(snapshot.get("pet_reset", {})).duplicate(true),
		"nextActions": Array(snapshot.get("next_actions", [])).duplicate(true),
		"logLines": Array(snapshot.get("log_lines", [])).duplicate(true),
		"battleResult": Dictionary(snapshot.get("battle_result", {})).duplicate(true),
	}
