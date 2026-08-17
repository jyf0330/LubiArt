extends SceneTree

const RegistryScript := preload("res://core/battle/quality/quality_effect_registry.gd")
const LegacyCatalogScript := preload("res://core/battle/quality/legacy_quality_runtime_catalog.gd")
const RuntimeServiceScript := preload("res://core/battle/quality/quality_runtime_service.gd")

var failed := false


func _initialize() -> void:
	var unconfigured := RuntimeServiceScript.new()
	var untouched := {"quality_upgrade": {"id": "G02"}, "quality_runtime": {"flags": {"keep": true}}}
	var untouched_before: Dictionary = untouched.duplicate(true)
	_expect(unconfigured.mode_options(untouched).is_empty(), "unconfigured runtime fails closed for mode options")
	_expect(not bool(unconfigured.try_set_mode(untouched, "爆").get("ok", true)), "unconfigured runtime rejects mode writes")
	_expect(untouched == untouched_before, "unconfigured runtime does not mutate the unit")

	var registry := _legacy_registry()
	var service := RuntimeServiceScript.new().configure(registry)
	var mode_unit := {
		"quality_upgrade": {"id": "G02"},
		"quality_runtime": {"flags": {"keep": true}},
	}
	_expect(service.mode_options(mode_unit) == ["稳", "爆"], "runtime exposes strategy mode options")
	_expect(service.stored_mode(mode_unit) == "", "stored mode preserves the raw empty runtime value")
	_expect(service.display_mode(mode_unit) == "稳", "display mode uses the first option fallback")
	var mode_result: Dictionary = service.try_set_mode(mode_unit, "burst")
	_expect(bool(mode_result.get("ok", false)) and String(mode_result.get("mode", "")) == "爆", "mode aliases normalize before write")
	_expect(service.stored_mode(mode_unit) == "爆" and service.display_mode(mode_unit) == "爆", "valid mode becomes the stored and displayed value")
	var mode_runtime := Dictionary(mode_unit.get("quality_runtime", {}))
	_expect(bool(mode_runtime.get("mode_explicit", false)), "valid mode records explicit player intent")
	_expect(bool(Dictionary(mode_runtime.get("flags", {})).get("keep", false)), "mode write preserves other quality runtime fields")

	var invalid_before: Dictionary = mode_unit.duplicate(true)
	_expect(not bool(service.try_set_mode(mode_unit, "not-a-mode").get("ok", true)), "unknown mode is rejected")
	_expect(mode_unit == invalid_before, "unknown mode rejection is non-mutating")
	var unsupported := {"quality_upgrade": {"id": "G03"}, "quality_runtime": {}}
	var unsupported_before: Dictionary = unsupported.duplicate(true)
	_expect(not bool(service.try_set_mode(unsupported, "攻").get("ok", true)), "unit without mode capability is rejected")
	_expect(unsupported == unsupported_before, "unsupported mode rejection is non-mutating")

	var mark_unit := {
		"quality_upgrade": {"id": "G22"},
		"quality_runtime": {"mode": "保留", "flags": {"keep": true}},
	}
	_expect(service.supports_mark(mark_unit), "runtime reads mark capability from the strategy")
	var mark_result: Dictionary = service.try_set_mark(mark_unit, 4, 5, 2, 3)
	var expected_mark := {"x": 4, "y": 5, "c": 4, "r": 5, "key": "4,5", "slot_index": 2, "round": 3}
	_expect(bool(mark_result.get("ok", false)), "valid mark write succeeds")
	_expect(service.mark_for_unit(mark_unit) == expected_mark, "mark schema preserves every compatibility field")
	_expect(service.mark_matches_cell({"x": 4, "y": 5}, 4, 5), "x/y mark coordinates match")
	_expect(service.mark_matches_cell({"c": 4, "r": 5}, 4, 5), "c/r compatibility coordinates match")
	_expect(service.mark_matches_unit(expected_mark, {"x": 4, "y": 5}), "mark matches an explicit unit position")
	var mark_copy: Dictionary = service.mark_for_unit(mark_unit)
	mark_copy["x"] = 99
	_expect(int(service.mark_for_unit(mark_unit).get("x", -1)) == 4, "mark reads are deep-copy isolated")
	_expect(service.clear_mark(mark_unit), "clear mark reports a removed mark")
	var cleared_runtime := Dictionary(mark_unit.get("quality_runtime", {}))
	_expect(not cleared_runtime.has("marked_cell"), "clear mark removes only the marked cell")
	_expect(String(cleared_runtime.get("mode", "")) == "保留", "clear mark preserves stored mode")
	_expect(bool(Dictionary(cleared_runtime.get("flags", {})).get("keep", false)), "clear mark preserves strategy flags")

	var equivalent_a := {"quality_upgrade": {"id": "G24"}, "quality_runtime": {}}
	var equivalent_b: Dictionary = equivalent_a.duplicate(true)
	var second_service := RuntimeServiceScript.new().configure(_legacy_registry())
	_expect(service.try_set_mode(equivalent_a, "main").get("mode") == second_service.try_set_mode(equivalent_b, "main").get("mode"), "equivalent inputs produce deterministic mode output")
	_expect(equivalent_a == equivalent_b, "separate runtime instances produce identical authoritative writes")

	if failed:
		quit(1)
		return
	print("SMOKE_QUALITY_RUNTIME_SERVICE_OK mode=%s mark_fields=%d" % [
		String(mode_result.get("mode", "")),
		expected_mark.size(),
	])
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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
