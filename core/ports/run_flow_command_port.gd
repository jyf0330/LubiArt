extends RefCounted

const BoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")

const CONTRACT_ID := &"ysbzs.run-flow-command-port.v1"
const DIFFICULTY_EASY := "easy"
const DIFFICULTY_NORMAL := "normal"

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func continue_after_battle() -> bool:
	return bool(_authority.call("continue_after_battle"))


func start_battle(action: Dictionary) -> bool:
	if action.has("boardWidth") or action.has("board_width") or action.has("boardHeight") or action.has("board_height"):
		if not bool(_authority.call(
			"set_board_dimensions",
			int(action.get("boardWidth", action.get("board_width", _authority.get("board_width")))),
			int(action.get("boardHeight", action.get("board_height", _authority.get("board_height"))))
		)):
			return false
	_authority.call("start_battle")
	return true


func start_developer_scenario(action: Dictionary) -> bool:
	return bool(_authority.call("start_developer_scenario", action))


func start_debug_first_battle(action: Dictionary) -> bool:
	return bool(_authority.call("start_debug_first_battle", action))


func run_battle() -> bool:
	return bool(_authority.call("run_battle_auto"))


func run_full_day() -> bool:
	return bool(_authority.call("run_full_day"))


func run_full_run() -> bool:
	return bool(_authority.call("run_full_run"))


func new_run(action: Dictionary) -> bool:
	_authority.call("reset")
	_authority.call("set_difficulty", String(action.get("difficulty", DIFFICULTY_NORMAL)))
	if not bool(_authority.call(
		"set_board_dimensions",
		int(action.get("boardWidth", action.get("board_width", BoardDimensionsScript.DEFAULT_WIDTH))),
		int(action.get("boardHeight", action.get("board_height", BoardDimensionsScript.DEFAULT_HEIGHT)))
	)):
		return false
	if action.has("seed"):
		_authority.call("set_run_seed", String(action.get("seed", "")))
	return true


func set_difficulty(action: Dictionary) -> bool:
	_authority.call("set_difficulty", String(action.get("difficulty", DIFFICULTY_NORMAL)))
	var current := String(_authority.get("difficulty"))
	_authority.call("_log", "摆位难度切换为%s。" % ["简单" if current == DIFFICULTY_EASY else "普通"])
	return true


func set_board_dimensions(action: Dictionary) -> bool:
	return bool(_authority.call(
		"set_board_dimensions",
		int(action.get("width", action.get("boardWidth", action.get("board_width", _authority.get("board_width"))))),
		int(action.get("height", action.get("boardHeight", action.get("board_height", _authority.get("board_height")))))
	))


func start_next_day(action: Dictionary) -> bool:
	return bool(_authority.call("start_next_day", int(action.get("day", action.get("targetDay", action.get("target_day", 0))))))
