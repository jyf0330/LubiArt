extends SceneTree

const SaveMigrationsScript := preload("res://persistence/migrations/save_migrations.gd")
const StateScript := preload("res://core/state/game_state.gd")


func _init() -> void:
	var ok := true
	var source: RefCounted = StateScript.new()
	var legacy_v0 := Dictionary(source.call("save_document", "migration-smoke")).duplicate(true)
	var state := Dictionary(legacy_v0.get("state", {})).duplicate(true)
	state.erase("stateVersion")
	state.erase("coins")
	legacy_v0["state"] = state
	legacy_v0.erase("schemaVersion")
	legacy_v0.erase("viewStates")
	legacy_v0["checksum"] = "stale-v0-checksum"

	var migrated := SaveMigrationsScript.normalize_document(legacy_v0)
	ok = _expect(SaveMigrationsScript.migration_path(0) == [1, 2], "v0 migration path is explicit") and ok
	ok = _expect(int(migrated.get("schemaVersion", 0)) == 2, "v0 migrates through schema v2") and ok
	ok = _expect(String(migrated.get("checksum", "invalid")) == "", "migration clears stale checksum") and ok
	ok = _expect(Dictionary(migrated.get("state", {})).has("stateVersion"), "migration restores canonical stateVersion") and ok
	ok = _expect(Dictionary(migrated.get("state", {})).has("coins"), "migration restores canonical coins") and ok
	ok = _expect(Dictionary(migrated.get("state", {})).has("placement_damage_by_unit"), "migration supplies the placement projection state") and ok

	var loaded: RefCounted = StateScript.new()
	ok = _expect(bool(loaded.call("load_document", legacy_v0)), "load_document runs migration before validation") and ok
	ok = _expect(int(Dictionary(loaded.call("snapshot")).get("coins", -1)) == int(state.get("gold", -2)), "migrated state preserves gold") and ok

	var future := Dictionary(source.call("save_document")).duplicate(true)
	future["schemaVersion"] = 999
	var untouched_future := SaveMigrationsScript.normalize_document(future)
	ok = _expect(int(untouched_future.get("schemaVersion", 0)) == 999, "future version is not down-migrated") and ok
	var future_target_path := SaveMigrationsScript.migration_path(2, 999)
	ok = _expect(future_target_path.is_empty(), "unsupported target has no migration path") and ok

	print("SMOKE_SAVE_MIGRATIONS_%s" % ["OK" if ok else "FAIL"])
	quit(0 if ok else 1)


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Failed: %s" % label)
	return condition
