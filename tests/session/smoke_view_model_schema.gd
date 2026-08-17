extends SceneTree

const GameStateScript := preload("res://core/state/game_state.gd")
const SnapshotProjectorScript := preload("res://core/commands/snapshot_projector.gd")
const ViewModelSchemaScript := preload("res://session/view_model_schema.gd")

var _failed := false


func _initialize() -> void:
	var state := GameStateScript.new()
	var snapshot := state.snapshot()
	var model := Dictionary(snapshot.get("viewModel", {}))
	_expect(String(model.get("schema", "")) == ViewModelSchemaScript.SCHEMA, "snapshot publishes the stable ViewModel schema id")
	_expect(int(model.get("schemaVersion", 0)) == ViewModelSchemaScript.VERSION, "snapshot publishes the stable ViewModel schema version")
	_expect(ViewModelSchemaScript.validate(model).is_empty(), "full authoritative snapshot projects a valid ViewModel")

	var minimal := SnapshotProjectorScript.new().project({
		"phase": "route",
		"stateVersion": 3,
		"stateHash": "stable-hash",
	}, "player", "enemy")
	_expect(ViewModelSchemaScript.validate(minimal).is_empty(), "minimal source snapshot still produces every required ViewModel field")
	_expect(Dictionary(minimal.get("dayRoute", {})).has("options"), "route collection has a stable container")
	_expect(Dictionary(minimal.get("selected", {})).has("unitId"), "selection has a stable identity field")

	var invalid := minimal.duplicate(true)
	invalid.erase("board")
	var error := ViewModelSchemaScript.validate(invalid)
	_expect(String(error.get("code", "")) == "VIEW_MODEL_FIELD_REQUIRED", "validator rejects a missing required field")
	_expect(String(error.get("field", "")) == "board", "validator identifies the unstable field")

	if _failed:
		quit(1)
		return
	print("SMOKE_VIEW_MODEL_SCHEMA_OK version=%d fields=%d" % [
		ViewModelSchemaScript.VERSION,
		ViewModelSchemaScript.REQUIRED_TYPES.size()
	])
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_VIEW_MODEL_SCHEMA_FAIL: %s" % message)
