extends RefCounted

## Shared fail-closed adapter for every production repository capability. A
## simulation is valid only when attempts() stays empty for its entire lifetime.

const ERROR := "SIMULATION_IO_FORBIDDEN"

var _attempts: Array = []


func attempts() -> Array:
	return _attempts.duplicate(true)


func clear() -> void:
	_attempts.clear()


# SaveRepository API.
func write_slot(document: Dictionary, slot: int, config: Dictionary) -> Dictionary:
	_record("save_repository", "write_slot", [document, slot, config])
	return {"ok": false, "error": ERROR}


func read_slot(slot: int, config: Dictionary) -> Dictionary:
	_record("save_repository", "read_slot", [slot, config])
	return {}


func read_first(paths: Array) -> Dictionary:
	_record("save_repository", "read_first", [paths])
	return {}


func valid_slot(slot: int, slot_count: int) -> bool:
	_record("save_repository", "valid_slot", [slot, slot_count])
	return false


func slot_path(slot: int, pattern: String) -> String:
	_record("save_repository", "slot_path", [slot, pattern])
	return ""


func write_text(path: String, value: String) -> bool:
	_record("save_repository", "write_text", [path, value])
	return false


func read_document(path: String) -> Dictionary:
	_record("save_repository", "read_document", [path])
	return {}


func remove_path(path: String) -> bool:
	_record("save_repository", "remove_path", [path])
	return false


# ReplayRepository API.
func write_document(path: String, document: Dictionary) -> bool:
	_record("replay_repository", "write_document", [path, document])
	return false


# RunHistoryRepository API.
func ensure_content_revision(root: String, content_hash: String, content_pack: Dictionary) -> Dictionary:
	_record("run_history_repository", "ensure_content_revision", [root, content_hash, content_pack])
	return {"ok": false, "error": ERROR}


func read_content_reference(root: String, reference: Dictionary) -> Dictionary:
	_record("run_history_repository", "read_content_reference", [root, reference])
	return {}


func create_run(root: String, run_id: String, manifest: Dictionary, content_pack: Dictionary) -> bool:
	_record("run_history_repository", "create_run", [root, run_id, manifest, content_pack])
	return false


func append_command(root: String, run_id: String, entry: Dictionary) -> bool:
	_record("run_history_repository", "append_command", [root, run_id, entry])
	return false


func write_checkpoint(root: String, run_id: String, checkpoint_id: String, document: Dictionary, summary: Dictionary) -> bool:
	_record("run_history_repository", "write_checkpoint", [root, run_id, checkpoint_id, document, summary])
	return false


func list_runs(root: String) -> Array:
	_record("run_history_repository", "list_runs", [root])
	return []


func list_checkpoints(root: String, run_id: String) -> Array:
	_record("run_history_repository", "list_checkpoints", [root, run_id])
	return []


func checkpoint_for_day(root: String, run_id: String, day: int, kind: String = "start") -> Dictionary:
	_record("run_history_repository", "checkpoint_for_day", [root, run_id, day, kind])
	return {}


func read_manifest(root: String, run_id: String) -> Dictionary:
	_record("run_history_repository", "read_manifest", [root, run_id])
	return {}


func read_run_header(root: String, run_id: String) -> Dictionary:
	_record("run_history_repository", "read_run_header", [root, run_id])
	return {}


# Shared name: GameDataRepository calls with one argument; RunHistoryRepository
# calls with two. The same guard instance deliberately supports both surfaces.
func read_content_pack(path_or_root: String, run_id: String = "") -> Dictionary:
	var repository := "game_data_repository" if run_id == "" else "run_history_repository"
	var arguments: Array = [path_or_root] if run_id == "" else [path_or_root, run_id]
	_record(repository, "read_content_pack", arguments)
	return {}


func read_checkpoint(root: String, run_id: String, checkpoint_id: String) -> Dictionary:
	_record("run_history_repository", "read_checkpoint", [root, run_id, checkpoint_id])
	return {}


func read_checkpoint_item(root: String, run_id: String, item: Dictionary) -> Dictionary:
	_record("run_history_repository", "read_checkpoint_item", [root, run_id, item])
	return {}


func command_count(root: String, run_id: String) -> int:
	_record("run_history_repository", "command_count", [root, run_id])
	return 0


# GameDataRepository API.
func read_dictionary(path: String) -> Dictionary:
	_record("game_data_repository", "read_dictionary", [path])
	return {}


func content_errors() -> Array[String]:
	_record("game_data_repository", "content_errors", [])
	return [ERROR]


# OperationLogRepository API.
func append(path: String, entry: Dictionary) -> bool:
	_record("operation_log_repository", "append", [path, entry])
	return false


func _record(repository: String, method: String, arguments: Array) -> void:
	_attempts.append({
		"repository": repository,
		"method": method,
		"arguments": arguments.duplicate(true),
	})
