extends SceneTree

const ContextScript := preload("res://core/battle/quality/quality_effect_context.gd")
const RegistryScript := preload("res://core/battle/quality/quality_effect_registry.gd")
const LegacyCatalogScript := preload("res://core/battle/quality/legacy_quality_runtime_catalog.gd")
const SaveCodecScript := preload("res://persistence/save_codec.gd")
const StateScript := preload("res://core/state/game_state.gd")

const TRACE_CASES := [
	["D21", "fire_trace", 1, false],
	["D22", "water_trace", 1, false],
	["D23", "wind_trace", 1, false],
	["D24", "earth_trace", 1, false],
	["D25", "metal_trace", 1, false],
	["D26", "wood_trace", 2, false],
	["D27", "buddha_trace", 1, false],
	["D28", "sand_trace", 1, false],
	["D29", "demon_trace", 1, false],
	["D30", "talisman_trace", 1, true],
]

var _failed := false


func _initialize() -> void:
	var actual := StateScript.new()
	var legacy_control := StateScript.new()
	actual.set_run_seed("quality-board-trace-authority-parity")
	legacy_control.set_run_seed("quality-board-trace-authority-parity")
	_expect(actual.dispatch({"type": "START_BATTLE"}), "actual authority starts battle")
	_expect(legacy_control.dispatch({"type": "START_BATTLE"}), "legacy control starts battle")
	var actual_unit := _first_player_unit(actual)
	var control_unit := _first_player_unit(legacy_control)
	var cells := _empty_cells(actual, TRACE_CASES.size())
	_expect(not actual_unit.is_empty() and not control_unit.is_empty(), "both authorities expose a player unit")
	_expect(cells.size() == TRACE_CASES.size(), "fixture exposes ten empty trace cells")
	if actual_unit.is_empty() or control_unit.is_empty() or cells.size() != TRACE_CASES.size():
		quit(1)
		return

	var registry: QualityEffectRegistry = _legacy_registry()
	var context := ContextScript.new().configure_for_core(actual)
	for index in range(TRACE_CASES.size()):
		var trace_case := Array(TRACE_CASES[index])
		var effect_id := String(trace_case[0])
		var handler_id := String(trace_case[1])
		var duration := int(trace_case[2])
		var persistent := bool(trace_case[3])
		var trace_name := "legacy-%s" % effect_id
		actual_unit["quality_upgrade"] = {"id": effect_id, "name": trace_name}
		control_unit["quality_upgrade"] = {"id": effect_id, "name": trace_name}
		var cell := Dictionary(cells[index])
		registry.effect_for_id(effect_id).on_after_attack(
			context,
			actual_unit,
			{"cells": [cell.duplicate(true)]},
			[]
		)
		var expected_trace := {
			"kind": handler_id,
			"duration": duration,
			"id": effect_id,
			"name": trace_name,
			"x": int(cell.get("x", -1)),
			"y": int(cell.get("y", -1)),
		}
		if persistent:
			expected_trace["persistent"] = true
		legacy_control.call(
			"_set_board_trace",
			int(cell.get("x", -1)),
			int(cell.get("y", -1)),
			expected_trace
		)
		var key := "%d,%d" % [int(cell.get("x", -1)), int(cell.get("y", -1))]
		var stored_rows := Array(Dictionary(actual.get("board_traces")).get(key, []))
		_expect(stored_rows.size() == 1, "%s places one authoritative trace" % effect_id)
		if stored_rows.size() == 1:
			var stored := Dictionary(stored_rows[0])
			_expect(stored == expected_trace, "%s keeps the exact pre-Q0 physical value" % effect_id)
			_expect(not stored.has("handler_id") and not stored.has("params"), "%s leaks no modern runtime keys" % effect_id)
			_expect(persistent or not stored.has("persistent"), "%s omits persistent=false" % effect_id)

	_expect(
		Dictionary(actual.get("board_traces")) == Dictionary(legacy_control.get("board_traces")),
		"all D21-D30 traces equal the frozen legacy authority table"
	)
	var actual_hash := String(actual.call("_state_hash"))
	var control_hash := String(legacy_control.call("_state_hash"))
	_expect(actual_hash == control_hash, "D21-D30 stateHash matches the frozen legacy control")

	var save_meta := {"createdAt": "quality-board-trace-authority-parity", "embedContentPack": false}
	var actual_save := Dictionary(actual.save_document("quality-trace", save_meta))
	var control_save := Dictionary(legacy_control.save_document("quality-trace", save_meta))
	_expect(
		Dictionary(actual_save.get("state", {})).get("board_traces", {})
			== Dictionary(control_save.get("state", {})).get("board_traces", {}),
		"save payload keeps the legacy trace table"
	)
	_expect(
		SaveCodecScript.stable_json(actual_save) == SaveCodecScript.stable_json(control_save),
		"save document and checksum remain legacy-identical"
	)

	var actual_replay := Dictionary(actual.replay_document({"playerId": "quality-trace"}))
	var control_replay := Dictionary(legacy_control.replay_document({"playerId": "quality-trace"}))
	_expect(
		String(Dictionary(actual_replay.get("final", {})).get("stateHash", "")) == actual_hash,
		"replay final records the authoritative trace hash"
	)
	_expect(
		SaveCodecScript.stable_json(actual_replay) == SaveCodecScript.stable_json(control_replay),
		"replay document and checksum remain legacy-identical"
	)

	if _failed:
		quit(1)
		return
	print("SMOKE_QUALITY_BOARD_TRACE_AUTHORITY_PARITY_OK traces=10 hash=%s" % actual_hash)
	quit(0)


func _legacy_registry() -> QualityEffectRegistry:
	var registry: QualityEffectRegistry = RegistryScript.new()
	var prepared := registry.prepare_configuration(
		LegacyCatalogScript.upgrades(),
		0,
		RegistryScript.PERSISTED_SNAPSHOT
	)
	_expect(bool(prepared.get("ok", false)), "legacy fixture configuration prepares")
	registry.commit_configuration(Dictionary(prepared.get("candidate", {})))
	_expect(registry.is_configured(), "legacy fixture configuration commits")
	return registry


func _first_player_unit(state: RefCounted) -> Dictionary:
	for unit_value in Array(state.get("units")):
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == "player" and int(unit.get("hp", 0)) > 0:
			return unit
	return {}


func _empty_cells(state: RefCounted, count: int) -> Array:
	var result: Array = []
	for y in range(int(state.get("board_height"))):
		for x in range(int(state.get("board_width"))):
			if not Dictionary(state.call("unit_at", x, y)).is_empty():
				continue
			result.append({"x": x, "y": y})
			if result.size() == count:
				return result
	return result


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_QUALITY_BOARD_TRACE_AUTHORITY_PARITY_FAIL: %s" % label)
