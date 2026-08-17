extends RefCounted

## Central migration entrypoint. Version-specific migrations can be appended
## here without leaking schema handling into UI or feature code.

const CURRENT_SCHEMA := "ysbzs.save"
const LEGACY_SCHEMA := "ysbzs.godot.save"
const CURRENT_VERSION := 2


static func normalize_document(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true)
	if String(migrated.get("schema", "")) != CURRENT_SCHEMA:
		return migrated
	var source_version := int(migrated.get("schemaVersion", 0))
	if source_version < 0 or source_version > CURRENT_VERSION:
		return migrated
	for target_version in range(source_version + 1, CURRENT_VERSION + 1):
		migrated = _apply_step(target_version, migrated)
		if int(migrated.get("schemaVersion", source_version)) != target_version:
			return document.duplicate(true)
	return migrated


static func migration_path(source_version: int, target_version: int = CURRENT_VERSION) -> Array[int]:
	var path: Array[int] = []
	if source_version < 0 or target_version > CURRENT_VERSION or source_version > target_version:
		return path
	for version in range(source_version + 1, target_version + 1):
		path.append(version)
	return path


static func _apply_step(target_version: int, document: Dictionary) -> Dictionary:
	match target_version:
		1:
			return _migrate_v0_to_v1(document)
		2:
			return _migrate_v1_to_v2(document)
		_:
			return document.duplicate(true)


static func _migrate_v0_to_v1(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true)
	var state := Dictionary(migrated.get("state", {})).duplicate(true)
	if not state.has("stateVersion") and state.has("state_version"):
		state["stateVersion"] = int(state.get("state_version", 0))
	if not state.has("state_version") and state.has("stateVersion"):
		state["state_version"] = int(state.get("stateVersion", 0))
	if not state.has("coins") and state.has("gold"):
		state["coins"] = int(state.get("gold", 0))
	if not state.has("gold") and state.has("coins"):
		state["gold"] = int(state.get("coins", 0))
	if not migrated.has("viewStates"):
		migrated["viewStates"] = {}
	migrated["state"] = state
	migrated["schemaVersion"] = 1
	# A checksum from the old shape is no longer authoritative. The loader accepts
	# an empty checksum and the next save emits a checksum for the current shape.
	migrated["checksum"] = ""
	return migrated


static func _migrate_v1_to_v2(document: Dictionary) -> Dictionary:
	var migrated := document.duplicate(true)
	var state := Dictionary(migrated.get("state", {})).duplicate(true)
	if not state.has("defeated_units"):
		state["defeated_units"] = []
	if not state.has("auto_position_action_plan"):
		state["auto_position_action_plan"] = []
	if not state.has("auto_position_applied_result"):
		state["auto_position_applied_result"] = {}
	if not state.has("placement_damage_by_unit"):
		state["placement_damage_by_unit"] = {}
	if not state.has("player_elements_settled_this_round"):
		state["player_elements_settled_this_round"] = false
	if not state.has("battle_trace"):
		state["battle_trace"] = []
	if not state.has("replay_debug_timeline"):
		state["replay_debug_timeline"] = []
	migrated["state"] = state
	migrated["determinism"] = Dictionary(migrated.get("determinism", {})).duplicate(true)
	migrated["history"] = Dictionary(migrated.get("history", {})).duplicate(true)
	migrated["schemaVersion"] = 2
	migrated["checksum"] = ""
	return migrated
