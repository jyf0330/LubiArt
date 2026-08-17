extends RefCounted

## Lightweight phase contract. It keeps transition and phase-owned command
## rules explicit without introducing a second mutable state machine.

const PHASES := [&"route", &"shop", &"reward", &"battle", &"battle_end", &"day_end", &"game_over"]

const TRANSITIONS := {
	&"route": [&"shop", &"reward", &"battle", &"day_end"],
	&"shop": [&"route", &"day_end"],
	&"reward": [&"route", &"day_end"],
	&"battle": [&"battle_end"],
	&"battle_end": [&"reward", &"route", &"day_end", &"game_over"],
	&"day_end": [&"route"],
	&"game_over": [&"route"]
}

const COMMAND_PHASES := {
	"CHOOSE_ROUTE": [&"route"],
	"PICK_NODE": [&"route"],
	"PICK_BATTLE_ENCOUNTER": [&"route"],
	"RUN_ROUTE_FIXED_BATTLE": [&"route"],
	"ENTER_SHOP": [&"route"],
	"APPLY_ROUTE_EVENT": [&"route"],
	"CLAIM_ROUTE_REWARD": [&"reward"],
	"PICK_REWARD": [&"reward"],
	"BACK_TO_ROUTE": [&"shop"],
	"EXIT_SHOP": [&"shop"],
	"BUY_OFFER": [&"shop"],
	"DROP_ITEM_ON_TARGET": [&"shop"],
	"ROLL_SHOP": [&"shop"],
	"APPLY_SHOP_EVENT": [&"shop"],
	"FREEZE_OFFER": [&"shop"],
	"UNFREEZE_OFFER": [&"shop"],
	"START_BATTLE": [&"route"],
	"START_DEVELOPER_SCENARIO": [&"route"],
	"START_DEBUG_FIRST_BATTLE": [&"route"],
	"START_NEXT_DAY": [&"day_end"],
	"CONTINUE_AFTER_BATTLE": [&"battle_end"],
	"START_NEXT_ROUND": [&"battle"],
	"REWIND_TO_PREVIOUS_ROUND_START": [&"battle"],
	"RUN_MONSTER_TURN": [&"battle"],
	"SELECT_CELL": [&"battle"],
	"SET_ACTION_DIRECTION": [&"battle"],
	"SET_SLOT_DIR": [&"battle"],
	"SET_ACTION_AP": [&"battle"],
	"SET_SKILL_CONTROL_ORDER": [&"battle"],
	"SET_QUALITY_MODE": [&"battle"],
	"SET_QUALITY_MARK": [&"battle"],
	"USE_ACTION_SLOT": [&"battle"],
	"USE_SLOT": [&"battle"],
	"MOVE_HERO": [&"battle"],
	"AUTO_POSITION_HEROES": [&"battle"],
	"RUN_PLAYER_ALL_OUT": [&"battle"],
	"RUN_COMBAT_ROUND": [&"battle"],
	"RESET_PETS": [&"battle"],
	"END_PLAYER_TURN": [&"battle"]
}


static func is_known_phase(value: StringName) -> bool:
	return PHASES.has(value)


static func can_transition(from_phase: StringName, to_phase: StringName) -> bool:
	if from_phase == to_phase:
		return is_known_phase(from_phase)
	if not is_known_phase(from_phase) or not is_known_phase(to_phase):
		return false
	return Array(TRANSITIONS.get(from_phase, [])).has(to_phase)


static func can_execute(phase: StringName, action_type: String) -> bool:
	if not is_known_phase(phase):
		return false
	if not COMMAND_PHASES.has(action_type):
		return true
	return Array(COMMAND_PHASES.get(action_type, [])).has(phase)


static func allowed_phases(action_type: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in Array(COMMAND_PHASES.get(action_type, [])):
		result.append(StringName(value))
	return result
