extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")

var _failed := false


func _initialize() -> void:
	var state: RefCounted = StateScript.new()
	_expect(state.call("dispatch", {"type": "NEW_RUN", "seed": "snapshot-purity"}), "fixture starts a deterministic run")

	var clean_capture := AuthoritativeStateCodecScript.capture(state, false)
	var clean_hash := String(state.call("_state_hash"))
	var clean_version := int(state.get("state_version"))
	var clean_history := Dictionary(state.call("run_history_status"))
	var first_snapshot := Dictionary(state.call("snapshot"))
	var second_snapshot := Dictionary(state.call("snapshot"))
	var third_snapshot := Dictionary(state.call("snapshot"))

	_expect(first_snapshot == second_snapshot and second_snapshot == third_snapshot, "repeated Snapshot reads are deep-equal")
	_expect(AuthoritativeStateCodecScript.capture(state, false) == clean_capture, "repeated Snapshot reads do not mutate canonical authoritative fields")
	_expect(String(state.call("_state_hash")) == clean_hash, "repeated Snapshot reads preserve stateHash")
	_expect(int(state.get("state_version")) == clean_version, "repeated Snapshot reads preserve stateVersion")
	_expect(Dictionary(state.call("run_history_status")) == clean_history, "repeated Snapshot reads preserve history metadata")

	var dirty_roster := _duplicate_active_slot_fixture(Array(state.get("roster")))
	state.set("roster", dirty_roster.duplicate(true))
	var dirty_capture := AuthoritativeStateCodecScript.capture(state, false)
	var dirty_hash := String(state.call("_state_hash"))
	var dirty_version := int(state.get("state_version"))
	var dirty_history := Dictionary(state.call("run_history_status"))
	state.call("snapshot")
	state.call("snapshot")

	_expect(AuthoritativeStateCodecScript.capture(state, false) == dirty_capture, "Snapshot does not repair a malformed roster as a hidden write")
	_expect(String(state.call("_state_hash")) == dirty_hash, "Snapshot preserves the malformed fixture hash")
	_expect(int(state.get("state_version")) == dirty_version, "Snapshot preserves the malformed fixture version")
	_expect(Dictionary(state.call("run_history_status")) == dirty_history, "Snapshot preserves malformed fixture history metadata")
	_expect(_active_slots(Array(state.get("roster"))) == [1, 1], "malformed duplicate active slots remain visible until an explicit write boundary")

	state.call("_normalize_roster_slots")
	_expect(_active_slots(Array(state.get("roster"))) == [1, 2], "explicit roster normalization repairs duplicate active slots")

	state.set("roster", dirty_roster.duplicate(true))
	var document := Dictionary(state.call("save_document", "snapshot-purity"))
	var restored: RefCounted = StateScript.new()
	_expect(restored.call("load_document", document), "save with legacy malformed slots loads through the canonical restore boundary")
	_expect(_active_slots(Array(restored.get("roster"))) == [1, 2], "load restore normalizes roster slots before exposing state")
	var restored_capture := AuthoritativeStateCodecScript.capture(restored, false)
	var restored_hash := String(restored.call("_state_hash"))
	var restored_version := int(restored.get("state_version"))
	var restored_history := Dictionary(restored.call("run_history_status"))
	restored.call("snapshot")
	_expect(AuthoritativeStateCodecScript.capture(restored, false) == restored_capture, "Snapshot remains pure after load normalization")
	_expect(String(restored.call("_state_hash")) == restored_hash, "post-load Snapshot preserves stateHash")
	_expect(int(restored.get("state_version")) == restored_version, "post-load Snapshot preserves stateVersion")
	_expect(Dictionary(restored.call("run_history_status")) == restored_history, "post-load Snapshot preserves history metadata")

	if _failed:
		quit(1)
		return
	print("SMOKE_SNAPSHOT_PURITY_OK repeated=3 dirty_slots=preserved load_slots=normalized")
	quit(0)


func _duplicate_active_slot_fixture(source: Array) -> Array:
	var template := Dictionary(source[0]).duplicate(true) if not source.is_empty() else {
		"id": "snapshot_fixture_1",
		"pet_id": "snapshot_fixture",
		"name": "Snapshot Fixture",
	}
	var first := template.duplicate(true)
	first["id"] = "snapshot_fixture_1"
	first["active"] = true
	first["slot"] = 1
	first["bag_slot"] = 0
	var second := template.duplicate(true)
	second["id"] = "snapshot_fixture_2"
	second["active"] = true
	second["slot"] = 1
	second["bag_slot"] = 0
	return [first, second]


func _active_slots(source: Array) -> Array:
	var slots: Array = []
	for value in source:
		var pet := Dictionary(value)
		if bool(pet.get("active", false)):
			slots.append(int(pet.get("slot", 0)))
	return slots


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_SNAPSHOT_PURITY_FAIL: %s" % message)
