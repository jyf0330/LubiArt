extends "res://session/game_session.gd"

const LocalAuthorityPortScript := preload("res://session/local_authority_port.gd")
const SessionProtocol := preload("res://session/session_protocol.gd")
const LOCAL_SAVE_SLOT_COUNT := 3

## In-process authoritative adapter. This is the single-player implementation
## of GameSession and deliberately owns no parallel gameplay state.

var _authority_port: RefCounted = LocalAuthorityPortScript.new()
var _command_scope := "player"
var _sequence := 0
var _confirmed_baseline: Dictionary = {}
var _confirmed_version := -1
var _presentation_snapshot: Dictionary = {}


func _init(authority: RefCounted = null, command_scope: String = "player") -> void:
	_command_scope = "developer" if command_scope == "developer" else "player"
	bind_authority(authority)


func bind_authority(authority: RefCounted) -> void:
	_authority_port.bind(authority)
	_confirmed_baseline = {}
	_confirmed_version = -1
	_presentation_snapshot = {}


func get_authority() -> RefCounted:
	return _authority_port.authority()


func submit_command(command: Dictionary) -> Dictionary:
	if not _authority_port.ready():
		return super.submit_command(command)
	var intent_error := SessionProtocol.validate_command_intent(command, _command_scope)
	if not intent_error.is_empty():
		return _reject_intent(command, intent_error)
	_sequence += 1
	var intent := command.duplicate(true)
	var command_id := "local:%d" % _sequence
	var incremental: bool = bool(_authority_port.can_run_incremental_command(intent))
	var safe_command: Dictionary
	if incremental:
		var base_version: int = _confirmed_version if _confirmed_version >= 0 else int(_authority_port.command_version())
		safe_command = SessionProtocol.make_incremental_authoritative_command(intent, base_version, command_id)
	else:
		var baseline := _confirmed_baseline
		if String(baseline.get("stateHash", "")) == "" or int(baseline.get("stateVersion", -1)) != _authority_port.command_version():
			baseline = _authority_port.command_baseline()
		safe_command = SessionProtocol.make_authoritative_command(intent, baseline, command_id)
	var action := _queue_submitted_action(intent, String(safe_command.get("commandId", "")))
	var action_id := String(action.get("id", ""))
	var response := Dictionary(
		_authority_port.run_incremental_command(safe_command)
		if incremental
		else _authority_port.run_command(safe_command)
	)
	response["pending"] = false
	response["status"] = "completed" if bool(response.get("accepted", false)) else "rejected"
	response["actionId"] = action_id
	response["actionStatus"] = String(response.get("status", ""))
	_settle_submitted_action(action_id, response)
	var response_snapshot := Dictionary(response.get("snapshot", {}))
	_remember_confirmed_baseline(response)
	if response.has("delta"):
		_apply_presentation_delta(Dictionary(response.get("delta", {})))
	elif not response_snapshot.is_empty():
		_presentation_snapshot = response_snapshot
	if bool(response.get("accepted", false)):
		command_completed.emit(intent, response)
		if not response_snapshot.is_empty():
			snapshot_received.emit(response_snapshot, _snapshot_metadata(response, &"command"))
	else:
		command_rejected.emit(intent, response)
	command_settled.emit(response)
	return response


func _reject_intent(command: Dictionary, error: Dictionary) -> Dictionary:
	var action := _queue_submitted_action(command)
	var action_id := String(action.get("id", ""))
	var response := {
		"accepted": false,
		"pending": false,
		"status": "rejected",
		"command": String(command.get("type", "")),
		"error": error.duplicate(true),
		"snapshot": current_snapshot(),
		"actionId": action_id,
		"actionStatus": "rejected",
	}
	_settle_submitted_action(action_id, response)
	command_rejected.emit(command, response)
	command_settled.emit(response)
	return response


func current_snapshot() -> Dictionary:
	var snap := Dictionary(_authority_port.snapshot())
	_remember_confirmed_baseline(snap)
	_presentation_snapshot = snap
	return snap


func current_presentation_snapshot() -> Dictionary:
	return _presentation_snapshot


func _remember_confirmed_baseline(source: Dictionary) -> void:
	if source.has("stateVersion"):
		_confirmed_version = int(source.get("stateVersion", _confirmed_version))
	var hash := String(source.get("stateHash", ""))
	if hash == "":
		_confirmed_baseline = {"stateVersion": _confirmed_version}
		return
	_confirmed_baseline = {
		"stateVersion": int(source.get("stateVersion", 0)),
		"stateHash": hash,
	}


func _apply_presentation_delta(delta: Dictionary) -> void:
	if _presentation_snapshot.is_empty():
		# A UI should normally adopt a complete connect snapshot first. If a test or
		# tool submits early, use one full calibration instead of inventing state.
		current_snapshot()
	var merged := _presentation_snapshot.duplicate(false)
	for key_value in delta.keys():
		var key := String(key_value)
		merged[key] = delta.get(key_value)
	merged["viewModel"] = _patched_view_model(Dictionary(merged.get("viewModel", {})), merged, delta)
	_presentation_snapshot = merged


func _patched_view_model(source: Dictionary, snapshot: Dictionary, delta: Dictionary) -> Dictionary:
	var view_model := source.duplicate(false)
	view_model["phase"] = String(snapshot.get("phase", ""))
	view_model["stateVersion"] = int(snapshot.get("stateVersion", 0))
	view_model["stateHash"] = ""
	if delta.has("coins"):
		view_model["gold"] = int(snapshot.get("coins", 0))
		view_model["coins"] = int(snapshot.get("coins", 0))
	if delta.has("inventory"):
		view_model["inventory"] = Dictionary(snapshot.get("inventory", {})).duplicate(true)
	view_model["nextActions"] = Array(snapshot.get("nextActions", [])).duplicate(true)
	view_model["next_actions"] = Array(snapshot.get("next_actions", [])).duplicate(true)
	view_model["logLines"] = Array(snapshot.get("log_lines", [])).duplicate(true)
	var shop_keys := [
		"shop_offers", "shop_events", "active_shop_pool", "active_stall",
		"shop_refresh", "shop_seen_pet_ids", "shop_seed_audit",
	]
	var patch_shop := false
	for key in shop_keys:
		if delta.has(key):
			patch_shop = true
			break
	if patch_shop:
		var shop := Dictionary(view_model.get("shop", {})).duplicate(false)
		if delta.has("shop_offers"):
			shop["offers"] = Array(snapshot.get("shop_offers", [])).duplicate(true)
		if delta.has("shop_events"):
			shop["events"] = Array(snapshot.get("shop_events", [])).duplicate(true)
		if delta.has("active_shop_pool"):
			shop["activePool"] = String(snapshot.get("active_shop_pool", ""))
		if delta.has("active_stall"):
			shop["activeStall"] = Dictionary(snapshot.get("active_stall", {})).duplicate(true)
		if delta.has("shop_refresh"):
			shop["refreshState"] = Dictionary(snapshot.get("shop_refresh", {})).duplicate(true)
		if delta.has("shop_seen_pet_ids"):
			shop["dailySeenPetIds"] = Array(snapshot.get("shop_seen_pet_ids", [])).duplicate(true)
			shop["dailySeenCount"] = Array(snapshot.get("shop_seen_pet_ids", [])).size()
		if delta.has("shop_seed_audit"):
			shop["seedAudit"] = Array(snapshot.get("shop_seed_audit", [])).duplicate(true)
		view_model["shop"] = shop
	if delta.has("route_options"):
		var day_route := Dictionary(view_model.get("dayRoute", {})).duplicate(false)
		day_route["options"] = Array(snapshot.get("route_options", [])).duplicate(true)
		view_model["dayRoute"] = day_route
	return view_model


func connect_session() -> bool:
	return _authority_port.ready()


func is_session_connected() -> bool:
	return _authority_port.ready()


func supports_persistence() -> bool:
	return _authority_port.supports_persistence()


func persistence_slot_count() -> int:
	return LOCAL_SAVE_SLOT_COUNT if supports_persistence() else 0


func save_to_slot(slot: int = 1) -> bool:
	return _authority_port.save_to_slot(slot)


func load_from_slot(slot: int = 1) -> bool:
	var loaded := bool(_authority_port.load_from_slot(slot))
	if loaded:
		var snap := current_snapshot()
		snapshot_received.emit(snap, _snapshot_metadata(snap, &"load"))
	return loaded


func export_replay() -> bool:
	return _authority_port.export_replay()


func export_battle_trace() -> bool:
	return _authority_port.export_battle_trace()

func supports_run_history() -> bool:
	return _authority_port.supports_run_history()

func run_history_runs() -> Array:
	return _authority_port.run_history_runs()

func run_history_checkpoints(run_id: String = "") -> Array:
	return _authority_port.run_history_checkpoints(run_id)

func run_history_checkpoint_for_day(run_id: String, day: int, kind: String = "start") -> Dictionary:
	return _authority_port.run_history_checkpoint_for_day(run_id, day, kind)

func resume_from_run_history(run_id: String, checkpoint_id: String) -> bool:
	var resumed: bool = bool(_authority_port.resume_from_run_history(run_id, checkpoint_id))
	if resumed:
		var snap := current_snapshot()
		snapshot_received.emit(snap, _snapshot_metadata(snap, &"history_resume"))
	return resumed

func resume_from_run_history_day(run_id: String, day: int, kind: String = "start") -> bool:
	var resumed: bool = bool(_authority_port.resume_from_run_history_day(run_id, day, kind))
	if resumed:
		var snap := current_snapshot()
		snapshot_received.emit(snap, _snapshot_metadata(snap, &"history_resume"))
	return resumed


func _snapshot_metadata(source: Dictionary, reason: StringName) -> Dictionary:
	return {
		"adapter": "local",
		"asynchronous": false,
		"reason": String(reason),
		"stateVersion": int(source.get("stateVersion", -1)),
		"stateHash": String(source.get("stateHash", ""))
	}
