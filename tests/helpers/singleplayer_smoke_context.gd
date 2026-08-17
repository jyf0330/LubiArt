extends RefCounted

const StateScript := preload("res://core/state/game_state.gd")

## Shared lifecycle and assertion context for the grouped single-player smoke.

var _failures: Array[String] = []


func new_legacy_state() -> StateScript:
	var state: StateScript = StateScript.new()
	state.call("set_board_dimensions", 8, 8)
	return state


func expect(_tree: SceneTree, condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append("Smoke failed: %s" % message)


func has_failures() -> bool:
	return not _failures.is_empty()


func failure_messages() -> Array[String]:
	return _failures.duplicate()
