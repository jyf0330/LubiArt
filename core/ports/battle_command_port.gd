extends RefCounted

const CONTRACT_ID := &"ysbzs.battle-command-port.v1"
const PLAYER := "player"
const ENEMY := "enemy"

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func start_next_round() -> bool:
	return bool(_authority.call("_start_next_battle_round"))


func rewind_to_previous_round_start() -> bool:
	return bool(_authority.call("rewind_to_previous_round_start"))


func run_monster_turn() -> bool:
	_authority.call("_apply_mechanic_round_end", PLAYER)
	_authority.call("_enemy_turn")
	_authority.call("_apply_mechanic_round_end", ENEMY)
	_authority.call("_tick_board_traces")
	_authority.set("ap", int(_authority.call("_player_round_action_budget")))
	_authority.call("_reset_action_slots", PLAYER)
	_authority.set("team_placement_preview", {"activeUnitId": null, "movedUnitIds": []})
	_authority.call("_apply_mechanic_round_start", PLAYER)
	_authority.call("_apply_quality_round_start", PLAYER)
	clear_selection(false)
	_authority.call("_check_battle_end")
	return true


func selected_unit_id() -> String:
	return String(_authority.get("selected_unit_id"))


func select_unit(unit_id: String) -> bool:
	return bool(_authority.call("select_unit", unit_id))


func select_cell(x: int, y: int, has_requested_ap: bool, requested_ap: int) -> bool:
	if has_requested_ap and selected_unit_id() != "":
		_authority.call(
			"set_action_ap",
			selected_unit_id(),
			int(_authority.get("selected_action_slot_index")),
			requested_ap
		)
	return bool(_authority.call("select_cell", x, y))


func select_action_slot(slot_index: int) -> bool:
	return bool(_authority.call("select_action_slot", slot_index))


func set_action_direction(unit_id: String, slot_index: int, direction: String) -> bool:
	return bool(_authority.call("set_action_direction", unit_id, slot_index, direction))


func set_action_ap(unit_id: String, slot_index: int, requested_ap: int) -> bool:
	return bool(_authority.call("set_action_ap", unit_id, slot_index, requested_ap))


func set_skill_control_order(ordered_entry_ids: Array) -> bool:
	return bool(_authority.call("set_skill_control_order", ordered_entry_ids))


func set_quality_mode(unit_id: String, mode: String) -> bool:
	return bool(_authority.call("set_quality_mode", unit_id, mode))


func set_quality_mark(unit_id: String, x: int, y: int) -> bool:
	return bool(_authority.call("set_quality_mark", unit_id, x, y))


func use_action_slot(slot_index: int, requested_ap: int, target_id: String, has_cell: bool, x: int, y: int) -> bool:
	if not bool(_authority.call("select_action_slot", slot_index)):
		return false
	if requested_ap > 0 and not bool(_authority.call(
		"set_action_ap",
		selected_unit_id(),
		int(_authority.get("selected_action_slot_index")),
		requested_ap
	)):
		return false
	if target_id != "":
		return bool(_authority.call("attack_selected", target_id, requested_ap))
	if has_cell:
		return bool(_authority.call("select_cell", x, y))
	return bool(_authority.call("use_selected_action_slot", requested_ap))


func clear_selection(write_log: bool = true) -> bool:
	_authority.set("selected_unit_id", "")
	_authority.set("selected_action_slot_index", 0)
	if write_log:
		_authority.call("_log", "清除选择。")
	return true


func move_hero(x: int, y: int, requested_unit_id: String) -> bool:
	return bool(_authority.call("move_selected", x, y, requested_unit_id))


func auto_position_heroes() -> bool:
	return bool(_authority.call("auto_position_heroes"))


func run_player_all_out() -> bool:
	_authority.call("run_player_all_out")
	return true


func run_combat_round() -> bool:
	return bool(_authority.call("run_combat_round"))


func reset_pets() -> bool:
	return bool(_authority.call("reset_player_pets"))


func end_player_turn() -> bool:
	_authority.call("end_player_turn")
	return true
