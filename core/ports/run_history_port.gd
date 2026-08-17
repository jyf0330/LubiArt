extends RefCounted

## Five-capability adapter for deterministic history commits. All dynamic
## access to the authoritative facade is confined to this versioned Port.

const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")
const CONTRACT_ID := &"ysbzs.run-history-port.v1"
const PATCH_FIELDS := {
	"historyRunId": "history_run_id",
	"historyBranchId": "history_branch_id",
	"historyParentRunId": "history_parent_run_id",
	"historyParentCheckpointId": "history_parent_checkpoint_id",
	"historyCommandIndex": "history_command_index",
	"historyContentRevision": "history_content_revision",
	"historyContentPath": "history_content_path",
}

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func capture_context(scope: StringName = &"status") -> Dictionary:
	var context := {
		"historyRecordingEnabled": bool(_authority.get("history_recording_enabled")),
		"historySuspended": bool(_authority.get("_history_suspended")),
		"historyRunId": String(_authority.get("history_run_id")),
		"phase": String(_authority.get("phase")),
	}
	if scope == &"status":
		return context
	context.merge({
		"historyRoot": String(_authority.get("history_root")),
		"historyBranchId": String(_authority.get("history_branch_id")),
		"historyParentRunId": String(_authority.get("history_parent_run_id")),
		"historyParentCheckpointId": String(_authority.get("history_parent_checkpoint_id")),
		"historyCommandIndex": int(_authority.get("history_command_index")),
		"historyContentRevision": int(_authority.get("history_content_revision")),
		"historyContentPath": String(_authority.get("history_content_path")),
	})
	if scope == &"metadata":
		return context
	context.merge({
		"day": int(_authority.get("day")),
		"stateVersion": int(_authority.get("state_version")),
		"lastCommandResult": _authority.call("_replay_json_safe", _authority.get("last_command_result")),
	})
	if scope == &"record":
		return context
	context["determinism"] = Dictionary(_authority.call("_determinism_context", false))
	if scope == &"checkpoint":
		context["stateHash"] = String(_authority.call("_state_hash"))
		return context
	if scope == &"begin":
		context["runSeed"] = String(_authority.get("run_seed"))
		context["gameData"] = Dictionary(_authority.get("game_data")).duplicate(true)
		context["contentHash"] = String(_authority.call("_content_hash"))
	return context


func apply_patch(patch: Dictionary) -> void:
	for key_value in patch:
		var key := String(key_value)
		if PATCH_FIELDS.has(key):
			_authority.set(String(PATCH_FIELDS[key]), patch[key_value])


func checksum(value: Variant) -> String:
	return String(_authority.call("_checksum", value))


func capture_checkpoint_state() -> Dictionary:
	return AuthoritativeStateCodecScript.capture_checkpoint(_authority)
