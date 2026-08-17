extends RefCounted

## Product-level default locations. Repositories remain generic external-storage
## capabilities and receive these values through explicit config/path arguments.

const SAVE_PATH := "user://ysbzs_singleplayer_save.json"
const SAVE_BACKUP_PATH := "user://ysbzs_singleplayer_save.bak.json"
const SAVE_TEMP_PATH := "user://ysbzs_singleplayer_save.tmp.json"
const SAVE_SLOT_COUNT := 3
const SAVE_SLOT_PATH_PATTERN := "user://ysbzs_singleplayer_save_slot_%d.json"
const SAVE_SLOT_BACKUP_PATH_PATTERN := "user://ysbzs_singleplayer_save_slot_%d.bak.json"
const SAVE_SLOT_TEMP_PATH_PATTERN := "user://ysbzs_singleplayer_save_slot_%d.tmp.json"
const REPLAY_PATH := "user://ysbzs_singleplayer_replay.json"
const BATTLE_TRACE_PATH := "user://ysbzs_singleplayer_battle_trace.json"
const PLAYER_OPERATION_LOG_PATH := "user://ysbzs_player_operations.jsonl"


static func save_slot_config() -> Dictionary:
	return {
		"slotCount": SAVE_SLOT_COUNT,
		"pathPattern": SAVE_SLOT_PATH_PATTERN,
		"backupPattern": SAVE_SLOT_BACKUP_PATH_PATTERN,
		"tempPattern": SAVE_SLOT_TEMP_PATH_PATTERN,
		"legacyPaths": [SAVE_PATH, SAVE_BACKUP_PATH]
	}
