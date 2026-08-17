extends RefCounted

## Pure command-protocol helpers for the YSBZS authoritative core.
## This module never reads or mutates game state; callers supply the current
## version/hash and receive JSON-safe protocol values back.

const REPLAY_INITIAL_OPTION_KEYS := [
	"activePets",
	"battleId",
	"boardHeight",
	"boardWidth",
	"day",
	"enemyLeader",
	"gold",
	"maxRounds",
	"mode",
	"period",
	"playerId",
	"playerLeader",
	"playerName",
	"players",
	"seed",
	"teams",
	"turn",
	"scenarioId",
	"scenarioVersion",
	"scenarioProvenance"
]

const REPLAY_COMMAND_EXCLUDE_KEYS := [
	"accepted",
	"authoritativeState",
	"defaultPayload",
	"error",
	"events",
	"flowCommand",
	"label",
	"manualFlowPreview",
	"ok",
	"pressurePreview",
	"readOnly",
	"result",
	"rolledBack",
	"stateHash",
	"stateVersion",
	"trace",
	"viewModel"
]

const ACTION_ALIASES := {
	"startBattle": "START_BATTLE",
	"startNextRound": "START_NEXT_ROUND",
	"rewindToPreviousRoundStart": "REWIND_TO_PREVIOUS_ROUND_START",
	"startNextDay": "START_NEXT_DAY",
	"enterShop": "ENTER_SHOP",
	"exitShop": "EXIT_SHOP",
	"buyOffer": "BUY_OFFER",
	"dropItemOnTarget": "DROP_ITEM_ON_TARGET",
	"generateNodeOptions": "GENERATE_NODE_OPTIONS",
	"generateBattleOptions": "GENERATE_BATTLE_OPTIONS",
	"rewardOptions": "REWARD_OPTIONS",
	"pickNode": "PICK_NODE",
	"pickBattleEncounter": "PICK_BATTLE_ENCOUNTER",
	"pickReward": "PICK_REWARD",
	"claimRouteReward": "CLAIM_ROUTE_REWARD",
	"runRouteFixedBattle": "RUN_ROUTE_FIXED_BATTLE",
	"runBattle": "RUN_BATTLE",
	"runFullDay": "RUN_FULL_DAY",
	"runFullPlayerDayFlow": "RUN_FULL_DAY",
	"runFullRun": "RUN_FULL_RUN",
	"newRun": "NEW_RUN",
	"setDifficulty": "SET_DIFFICULTY",
	"runPlayerAllOut": "RUN_PLAYER_ALL_OUT",
	"runCombatRound": "RUN_COMBAT_ROUND",
	"resetPets": "RESET_PETS",
	"endPlayerTurn": "END_PLAYER_TURN",
	"runMonsterTurn": "RUN_MONSTER_TURN",
	"selectUnit": "SELECT_UNIT",
	"selectHero": "SELECT_HERO",
	"selectCell": "SELECT_CELL",
	"selectSlot": "SELECT_SLOT",
	"selectActionSlot": "SELECT_ACTION_SLOT",
	"useSlot": "USE_SLOT",
	"useActionSlot": "USE_ACTION_SLOT",
	"setActionDirection": "SET_ACTION_DIRECTION",
	"setSlotDir": "SET_SLOT_DIR",
	"setActionAp": "SET_ACTION_AP",
	"setSkillControlOrder": "SET_SKILL_CONTROL_ORDER",
	"setQualityMode": "SET_QUALITY_MODE",
	"setQualityMark": "SET_QUALITY_MARK",
	"clearSelection": "CLEAR_SELECTION",
	"moveHero": "MOVE_HERO",
	"autoPositionHeroes": "AUTO_POSITION_HEROES",
	"buildPreview": "BUILD_PREVIEW",
	"getCellDetail": "GET_CELL_DETAIL",
	"previewManualFlow": "PREVIEW_MANUAL_FLOW",
	"exportReplay": "EXPORT_REPLAY",
	"exportBattleTrace": "EXPORT_BATTLE_TRACE",
	"replayBattleTrace": "REPLAY_BATTLE_TRACE",
	"rollShop": "ROLL_SHOP",
	"applyShopEvent": "APPLY_SHOP_EVENT",
	"applyRouteEvent": "APPLY_ROUTE_EVENT",
	"freezeOffer": "FREEZE_OFFER",
	"unfreezeOffer": "UNFREEZE_OFFER",
	"sellUnit": "SELL_UNIT",
	"toggleUnitActive": "TOGGLE_UNIT_ACTIVE",
	"continueAfterBattle": "CONTINUE_AFTER_BATTLE"
}

const REMOVED_TRIAL_ALIASES := [
	"setupDay7FireTrial",
	"runDay7FireTurn1",
	"runDay7FireTrialAll"
]

const AUTOMATION_ALIASES := [
	"runFullDay",
	"runFullPlayerDayFlow",
	"runFullRun"
]

const VIEW_STATE_ACTIONS := [
	"GET_DEVELOPER_OBJECT_CATALOG",
	"GET_DEBUG_PET_CATALOG",
	"GENERATE_NODE_OPTIONS",
	"GENERATE_BATTLE_OPTIONS",
	"REWARD_OPTIONS",
	"BUILD_PREVIEW",
	"GET_CELL_DETAIL",
	"PREVIEW_MANUAL_FLOW",
	"EXPORT_REPLAY",
	"EXPORT_BATTLE_TRACE",
	"REPLAY_BATTLE_TRACE"
]

const STRICT_VERSION_ACTIONS := [
	"START_DEVELOPER_SCENARIO",
	"START_DEBUG_FIRST_BATTLE",
	"CHOOSE_ROUTE",
	"PICK_NODE",
	"CLAIM_ROUTE_REWARD",
	"PICK_REWARD",
	"PICK_BATTLE_ENCOUNTER",
	"RUN_ROUTE_FIXED_BATTLE",
	"ENTER_SHOP",
	"BACK_TO_ROUTE",
	"EXIT_SHOP",
	"BUY_OFFER",
	"DROP_ITEM_ON_TARGET",
	"ROLL_SHOP",
	"APPLY_SHOP_EVENT",
	"APPLY_ROUTE_EVENT",
	"FREEZE_OFFER",
	"UNFREEZE_OFFER",
	"SELL_UNIT",
	"TOGGLE_UNIT_ACTIVE",
	"CONTINUE_AFTER_BATTLE",
	"START_BATTLE",
	"RUN_BATTLE",
	"RUN_FULL_DAY",
	"RUN_FULL_RUN",
	"NEW_RUN",
	"SET_DIFFICULTY",
	"SET_BOARD_DIMENSIONS",
	"START_NEXT_DAY",
	"START_NEXT_ROUND",
	"REWIND_TO_PREVIOUS_ROUND_START",
	"RUN_MONSTER_TURN",
	"SELECT_UNIT",
	"SELECT_HERO",
	"SELECT_CELL",
	"SELECT_SLOT",
	"SELECT_ACTION_SLOT",
	"SET_ACTION_DIRECTION",
	"SET_SLOT_DIR",
	"SET_ACTION_AP",
	"SET_SKILL_CONTROL_ORDER",
	"SET_QUALITY_MODE",
	"SET_QUALITY_MARK",
	"USE_ACTION_SLOT",
	"USE_SLOT",
	"MOVE_HERO",
	"AUTO_POSITION_HEROES",
	"RUN_PLAYER_ALL_OUT",
	"RUN_COMBAT_ROUND",
	"RESET_PETS",
	"END_PLAYER_TURN",
	"CLEAR_SELECTION"
]

const READ_ONLY_ACTIONS := [
	"GET_DEVELOPER_OBJECT_CATALOG",
	"GET_DEBUG_PET_CATALOG",
	"EXPORT_REPLAY",
	"EXPORT_BATTLE_TRACE",
	"REPLAY_BATTLE_TRACE",
	"GET_CELL_DETAIL",
	"BUILD_PREVIEW",
	"PREVIEW_MANUAL_FLOW",
	"GENERATE_NODE_OPTIONS",
	"GENERATE_BATTLE_OPTIONS",
	"REWARD_OPTIONS"
]

const PLAYER_ACTIONS := [
	"CHOOSE_ROUTE", "CLAIM_ROUTE_REWARD", "PICK_REWARD", "APPLY_ROUTE_EVENT",
	"EXIT_SHOP", "BUY_OFFER", "DROP_ITEM_ON_TARGET", "ROLL_SHOP", "APPLY_SHOP_EVENT",
	"FREEZE_OFFER", "UNFREEZE_OFFER", "SELL_UNIT", "TOGGLE_UNIT_ACTIVE",
	"CONTINUE_AFTER_BATTLE", "NEW_RUN", "SET_DIFFICULTY", "START_NEXT_DAY",
	"SELECT_UNIT", "SELECT_HERO", "SELECT_CELL", "SELECT_ACTION_SLOT", "SELECT_SLOT",
	"SET_ACTION_DIRECTION", "SET_SLOT_DIR", "SET_ACTION_AP", "SET_SKILL_CONTROL_ORDER",
	"SET_QUALITY_MODE", "SET_QUALITY_MARK", "USE_ACTION_SLOT", "USE_SLOT",
	"CLEAR_SELECTION", "MOVE_HERO", "AUTO_POSITION_HEROES", "RUN_PLAYER_ALL_OUT",
	"RUN_COMBAT_ROUND", "RESET_PETS", "END_PLAYER_TURN", "RUN_MONSTER_TURN",
	"REWIND_TO_PREVIOUS_ROUND_START",
	"GET_CELL_DETAIL"
]

## Keys accepted from presentation before Session adds the authoritative
## command envelope. Each entry is deliberately canonical: compatibility
## aliases remain available only to direct core/test callers.
const INTENT_FIELDS := {
	"GET_DEVELOPER_OBJECT_CATALOG": [],
	"START_DEVELOPER_SCENARIO": ["scenarioId", "seed", "playerRefs", "enemyRefs"],
	"GET_DEBUG_PET_CATALOG": [],
	"START_DEBUG_FIRST_BATTLE": ["seed", "playerPetIds", "enemyPetIds"],
	"CHOOSE_ROUTE": ["option_id"],
	"PICK_NODE": ["option_id"],
	"CLAIM_ROUTE_REWARD": ["rewardId"],
	"PICK_REWARD": ["rewardId"],
	"PICK_BATTLE_ENCOUNTER": ["option_id"],
	"RUN_ROUTE_FIXED_BATTLE": ["option_id"],
	"APPLY_ROUTE_EVENT": ["eventId"],
	"ENTER_SHOP": ["poolId", "slots", "seedContext"],
	"BACK_TO_ROUTE": [],
	"EXIT_SHOP": [],
	"BUY_OFFER": ["offer_id"],
	"DROP_ITEM_ON_TARGET": ["offer_id", "unitId", "target_type", "target_index"],
	"ROLL_SHOP": [],
	"APPLY_SHOP_EVENT": ["eventId"],
	"FREEZE_OFFER": ["offer_id"],
	"UNFREEZE_OFFER": ["offer_id"],
	"SELL_UNIT": ["unitId"],
	"TOGGLE_UNIT_ACTIVE": ["unitId"],
	"CONTINUE_AFTER_BATTLE": [],
	"START_BATTLE": ["boardWidth", "boardHeight"],
	"RUN_BATTLE": [],
	"RUN_FULL_DAY": [],
	"RUN_FULL_RUN": [],
	"NEW_RUN": ["seed"],
	"SET_DIFFICULTY": ["difficulty"],
	"SET_BOARD_DIMENSIONS": ["width", "height"],
	"START_NEXT_DAY": [],
	"START_NEXT_ROUND": [],
	"REWIND_TO_PREVIOUS_ROUND_START": [],
	"RUN_MONSTER_TURN": [],
	"SELECT_UNIT": ["unitId"],
	"SELECT_HERO": ["heroId"],
	"SELECT_CELL": ["x", "y", "ap"],
	"SELECT_ACTION_SLOT": ["slotId"],
	"SELECT_SLOT": ["slotId"],
	"SET_ACTION_DIRECTION": ["unitId", "slotId", "dir"],
	"SET_SLOT_DIR": ["unitId", "slotId", "dir"],
	"SET_ACTION_AP": ["unitId", "slotId", "ap"],
	"SET_SKILL_CONTROL_ORDER": ["orderedEntryIds"],
	"SET_QUALITY_MODE": ["unitId", "mode"],
	"SET_QUALITY_MARK": ["unitId", "x", "y"],
	"USE_ACTION_SLOT": ["unitId", "slotId", "ap", "targetId", "x", "y"],
	"USE_SLOT": ["unitId", "slotId", "ap", "targetId", "x", "y"],
	"CLEAR_SELECTION": [],
	"MOVE_HERO": ["unitId", "x", "y"],
	"AUTO_POSITION_HEROES": [],
	"RUN_PLAYER_ALL_OUT": [],
	"RUN_COMBAT_ROUND": [],
	"RESET_PETS": [],
	"END_PLAYER_TURN": [],
	"BUILD_PREVIEW": ["unitId", "slotId", "dir", "ap", "x", "y", "targetId"],
	"GET_CELL_DETAIL": ["x", "y"],
	"PREVIEW_MANUAL_FLOW": ["unitId", "x", "y"],
	"EXPORT_REPLAY": [],
	"EXPORT_BATTLE_TRACE": [],
	"REPLAY_BATTLE_TRACE": ["events"],
	"GENERATE_NODE_OPTIONS": [],
	"GENERATE_BATTLE_OPTIONS": [],
	"REWARD_OPTIONS": []
}

const REQUIRED_INTENT_FIELDS := {
	"START_DEVELOPER_SCENARIO": ["scenarioId", "seed", "playerRefs", "enemyRefs"],
	"START_DEBUG_FIRST_BATTLE": ["seed", "playerPetIds", "enemyPetIds"],
	"CHOOSE_ROUTE": ["option_id"],
	"CLAIM_ROUTE_REWARD": ["rewardId"],
	"PICK_REWARD": ["rewardId"],
	"APPLY_ROUTE_EVENT": ["eventId"],
	"BUY_OFFER": ["offer_id"],
	"APPLY_SHOP_EVENT": ["eventId"],
	"FREEZE_OFFER": ["offer_id"],
	"UNFREEZE_OFFER": ["offer_id"],
	"SELL_UNIT": ["unitId"],
	"TOGGLE_UNIT_ACTIVE": ["unitId"],
	"SET_DIFFICULTY": ["difficulty"],
	"SELECT_UNIT": ["unitId"],
	"SELECT_HERO": ["heroId"],
	"SELECT_CELL": ["x", "y"],
	"SELECT_ACTION_SLOT": ["slotId"],
	"SELECT_SLOT": ["slotId"],
	"SET_ACTION_DIRECTION": ["unitId", "slotId", "dir"],
	"SET_SLOT_DIR": ["unitId", "slotId", "dir"],
	"SET_ACTION_AP": ["unitId", "slotId", "ap"],
	"SET_SKILL_CONTROL_ORDER": ["orderedEntryIds"],
	"SET_QUALITY_MODE": ["unitId", "mode"],
	"SET_QUALITY_MARK": ["unitId", "x", "y"],
	"USE_ACTION_SLOT": ["unitId", "slotId", "ap"],
	"USE_SLOT": ["unitId", "slotId", "ap"],
	"MOVE_HERO": ["unitId", "x", "y"],
	"GET_CELL_DETAIL": ["x", "y"]
}


static func normalize_action_type(raw_type: String) -> String:
	return String(ACTION_ALIASES.get(raw_type, raw_type))


static func validate_intent(command: Dictionary, scope: String = "player") -> Dictionary:
	var raw_type := String(command.get("type", "")).strip_edges()
	if raw_type.is_empty():
		return _error("COMMAND_TYPE_REQUIRED", "Command type is required.")
	var action_type := normalize_action_type(raw_type)
	if not INTENT_FIELDS.has(action_type):
		return _error("COMMAND_TYPE_UNSUPPORTED", "Command %s is not part of the public command contract." % action_type)
	if scope != "developer" and not PLAYER_ACTIONS.has(action_type):
		return _error("COMMAND_SCOPE_FORBIDDEN", "Player UI cannot submit command %s." % action_type)
	var allowed_fields: Array = Array(INTENT_FIELDS[action_type])
	for raw_key in command.keys():
		var key := String(raw_key)
		if key != "type" and not allowed_fields.has(key):
			return _error("COMMAND_FIELD_NOT_ALLOWED", "Field %s does not belong to UI intent %s." % [key, action_type])
	for required_key in Array(REQUIRED_INTENT_FIELDS.get(action_type, [])):
		if not command.has(required_key):
			return _error("COMMAND_FIELD_REQUIRED", "Field %s is required for UI intent %s." % [required_key, action_type])
	if action_type == "START_DEVELOPER_SCENARIO":
		if typeof(command.get("scenarioId")) != TYPE_STRING or typeof(command.get("seed")) != TYPE_STRING:
			return _error("COMMAND_FIELD_TYPE_INVALID", "Scenario id and seed must be strings for UI intent START_DEVELOPER_SCENARIO.")
		if typeof(command.get("playerRefs")) != TYPE_ARRAY or typeof(command.get("enemyRefs")) != TYPE_ARRAY:
			return _error("COMMAND_FIELD_TYPE_INVALID", "Scenario team references must be arrays for UI intent START_DEVELOPER_SCENARIO.")
	if action_type == "START_DEBUG_FIRST_BATTLE":
		if typeof(command.get("seed")) != TYPE_STRING:
			return _error("COMMAND_FIELD_TYPE_INVALID", "Field seed must be a string for UI intent START_DEBUG_FIRST_BATTLE.")
		if typeof(command.get("playerPetIds")) != TYPE_ARRAY or typeof(command.get("enemyPetIds")) != TYPE_ARRAY:
			return _error("COMMAND_FIELD_TYPE_INVALID", "Debug team fields must be arrays for UI intent START_DEBUG_FIRST_BATTLE.")
	if action_type == "DROP_ITEM_ON_TARGET":
		var has_offer := not String(command.get("offer_id", "")).is_empty()
		var has_unit := not String(command.get("unitId", "")).is_empty()
		if has_offer == has_unit:
			return _error("COMMAND_SOURCE_ID_INVALID", "DROP_ITEM_ON_TARGET requires exactly one offer_id or unitId.")
		if String(command.get("target_type", "")).is_empty():
			return _error("COMMAND_FIELD_REQUIRED", "Field target_type is required for UI intent DROP_ITEM_ON_TARGET.")
	return {}


static func _error(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message}


static func base_state_version_mismatch(action: Dictionary, current_version: int) -> bool:
	if not action.has("baseStateVersion") and not action.has("base_state_version"):
		return false
	var base_version := int(action.get("baseStateVersion", action.get("base_state_version", current_version)))
	return base_version != current_version


static func baseline_error(action: Dictionary, current_version: int, current_hash: String) -> Dictionary:
	if base_state_version_mismatch(action, current_version):
		return _error("STATE_VERSION_MISMATCH", "Command was based on a stale stateVersion.")
	if action.has("baseStateHash") or action.has("base_state_hash"):
		var base_hash := String(action.get("baseStateHash", action.get("base_state_hash", current_hash)))
		if base_hash != current_hash:
			return _error("STATE_HASH_MISMATCH", "Command was based on a different authoritative stateHash.")
	return {}


static func command_envelope(action_type: String, action: Dictionary, before_version: int, before_hash: String) -> Dictionary:
	var payload := replayable_command(action_type, action, before_version)
	return {
		"type": action_type,
		"rawType": String(action.get("type", action_type)),
		"payload": payload,
		"commandId": String(action.get("commandId", action.get("command_id", ""))),
		"baseStateVersion": int(payload.get("baseStateVersion", before_version)),
		"baseStateHash": String(action.get("baseStateHash", action.get("base_state_hash", before_hash)))
	}


static func command_error(action_type: String, baseline: Dictionary = {}) -> Dictionary:
	if not baseline.is_empty():
		var error := baseline.duplicate(true)
		error["message"] = "Command %s: %s" % [action_type, String(error.get("message", "Baseline rejected."))]
		return error
	return {
		"code": "COMMAND_REJECTED",
		"message": "Command %s was rejected by the Godot core." % action_type
	}


static func is_read_only_action(action_type: String) -> bool:
	return READ_ONLY_ACTIONS.has(action_type)


static func is_view_state_action(action_type: String) -> bool:
	return VIEW_STATE_ACTIONS.has(action_type)


static func replayable_command(action_type: String, action: Dictionary, before_version: int) -> Dictionary:
	var sanitized: Variant = replay_json_safe(action)
	var command: Dictionary = {}
	if typeof(sanitized) == TYPE_DICTIONARY:
		command = Dictionary(sanitized)
	command["type"] = action_type
	command["baseStateVersion"] = int(command.get("baseStateVersion", command.get("base_state_version", before_version)))
	command.erase("base_state_version")
	return command


static func sanitize_replay_initial_options(options: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in REPLAY_INITIAL_OPTION_KEYS:
		if options.has(key):
			out[key] = replay_initial_json_safe(options.get(key))
	return out


static func replay_initial_json_safe(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var out: Array = []
		for item in Array(value):
			out.append(replay_initial_json_safe(item))
		return out
	if typeof(value) == TYPE_DICTIONARY:
		var out: Dictionary = {}
		for key in Dictionary(value).keys():
			var key_string := String(key)
			if key_string == "data" or key_string == "indexes":
				continue
			out[key] = replay_initial_json_safe(Dictionary(value).get(key))
		return out
	return value


static func replay_json_safe(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var out: Array = []
		for item in Array(value):
			out.append(replay_json_safe(item))
		return out
	if typeof(value) == TYPE_DICTIONARY:
		var out: Dictionary = {}
		for key in Dictionary(value).keys():
			var key_string := String(key)
			if REPLAY_COMMAND_EXCLUDE_KEYS.has(key_string) or key_string == "data" or key_string == "indexes":
				continue
			out[key] = replay_json_safe(Dictionary(value).get(key))
		return out
	return value
