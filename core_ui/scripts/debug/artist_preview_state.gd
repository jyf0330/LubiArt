extends RefCounted

var _snapshot_data: Dictionary = {}


func _init(snapshot_data: Dictionary = {}) -> void:
	_snapshot_data = snapshot_data.duplicate(true)


func snapshot() -> Dictionary:
	return _snapshot_data.duplicate(true)


func is_static_artist_preview() -> bool:
	return true


func dispatch(_command: Dictionary) -> bool:
	return false


func run_command(_command: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "artist_preview_read_only", "snapshot": snapshot()}


func save_to_user() -> bool:
	return false


func load_from_user() -> bool:
	return false


func save_replay_to_user() -> bool:
	return false


func save_battle_trace_to_user() -> bool:
	return false
