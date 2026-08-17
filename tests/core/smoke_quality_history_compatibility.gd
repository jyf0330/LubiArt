extends SceneTree

const RegistryScript := preload("res://core/battle/quality/quality_effect_registry.gd")
const LegacyCatalogScript := preload("res://core/battle/quality/legacy_quality_runtime_catalog.gd")

var _failed := false


func _initialize() -> void:
	_verify_current_v1_uses_embedded_operations()
	_verify_current_missing_version_fails_closed()
	_verify_future_version_uses_explicit_operations()
	_verify_persisted_legacy_maps_only_frozen_ids()
	_verify_persisted_v1_never_falls_back()
	_verify_invalid_identifiers_fail_closed()
	_verify_non_finite_params_fail_closed()
	if _failed:
		quit(1)
		return
	print("SMOKE_QUALITY_HISTORY_COMPATIBILITY_OK current=v1 legacy_ids=68 new_id=closed")
	quit(0)


func _verify_current_v1_uses_embedded_operations() -> void:
	var registry: QualityEffectRegistry = RegistryScript.new()
	var prepared := registry.prepare_configuration([{
		"id": "quality_current_fixture",
		"runtime_operations": [
			_operation("quality_current_fixture.add", "modify_hit_damage", "damage_add_when", 100, {"when": {}, "value": 4}),
		],
	}], 1, RegistryScript.CURRENT_ASSEMBLY)
	_expect(bool(prepared.get("ok", false)), "current v1 candidate accepts embedded runtime operations")
	registry.commit_configuration(Dictionary(prepared.get("candidate", {})))
	_expect(registry.effect_for_id("quality_current_fixture").modify_hit_damage({"damage": 5}) == 9, "current v1 executes the embedded operation")


func _verify_current_missing_version_fails_closed() -> void:
	var registry: QualityEffectRegistry = RegistryScript.new()
	var prepared := registry.prepare_configuration(
		[{"id": "S01"}],
		0,
		RegistryScript.CURRENT_ASSEMBLY
	)
	_expect(not bool(prepared.get("ok", true)), "current assembly rejects a missing runtime schema version")
	_expect(not registry.is_configured() and registry.registered_effect_ids().is_empty(), "failed current bootstrap exposes no implicit legacy table")


func _verify_future_version_uses_explicit_operations() -> void:
	for source_kind in [RegistryScript.CURRENT_ASSEMBLY, RegistryScript.PERSISTED_SNAPSHOT]:
		var registry: QualityEffectRegistry = RegistryScript.new()
		var prepared := registry.prepare_configuration([{
			"id": "quality_future_fixture",
			"runtime_operations": [
				_operation("quality_future_fixture.add", "modify_hit_damage", "damage_add_when", 100, {"when": {}, "value": 2}),
			],
		}], 2, source_kind)
		_expect(bool(prepared.get("ok", false)), "versioned quality schema 1+ accepts explicit operations for %s" % String(source_kind))
		registry.commit_configuration(Dictionary(prepared.get("candidate", {})))
		_expect(registry.effect_for_id("quality_future_fixture").modify_hit_damage({"damage": 5}) == 7, "versioned quality schema 1+ executes only its explicit operations")


func _verify_persisted_legacy_maps_only_frozen_ids() -> void:
	var registry: QualityEffectRegistry = RegistryScript.new()
	var legacy_ids: Array = []
	for upgrade_value in LegacyCatalogScript.upgrades():
		legacy_ids.append({"id": String(Dictionary(upgrade_value).get("id", ""))})
	var prepared := registry.prepare_configuration(
		legacy_ids,
		0,
		RegistryScript.PERSISTED_SNAPSHOT
	)
	_expect(bool(prepared.get("ok", false)), "persisted snapshot without a version maps frozen legacy ids")
	registry.commit_configuration(Dictionary(prepared.get("candidate", {})))
	_expect(registry.registered_effect_ids().size() == 68, "legacy snapshot maps the complete frozen 68-id catalog")
	_expect(registry.effect_for_id("G03").modify_hit_damage({"damage": 10, "core_cell": true}) == 13, "legacy snapshot preserves frozen behavior")

	var rejected: QualityEffectRegistry = RegistryScript.new()
	var new_id := rejected.prepare_configuration(
		[{"id": "quality_added_after_v1"}],
		0,
		RegistryScript.PERSISTED_SNAPSHOT
	)
	_expect(not bool(new_id.get("ok", true)), "unversioned persisted snapshots cannot route a new id through the legacy catalog")
	_expect(not rejected.is_configured(), "unknown legacy id leaves the registry inert")
	var whitespace_id := rejected.prepare_configuration(
		[{"id": " S01 "}],
		0,
		RegistryScript.PERSISTED_SNAPSHOT
	)
	_expect(not bool(whitespace_id.get("ok", true)), "legacy persisted ids must be canonical strings without surrounding whitespace")


func _verify_persisted_v1_never_falls_back() -> void:
	var registry: QualityEffectRegistry = RegistryScript.new()
	var prepared := registry.prepare_configuration([{
		"id": "S01",
		"runtime_operations": [
			_operation("S01.persisted_override", "modify_hit_damage", "damage_add_when", 100, {"when": {}, "value": 9}),
		],
	}], 1, RegistryScript.PERSISTED_SNAPSHOT)
	_expect(bool(prepared.get("ok", false)), "persisted v1 accepts its embedded operation table")
	registry.commit_configuration(Dictionary(prepared.get("candidate", {})))
	_expect(registry.effect_for_id("S01").modify_hit_damage({"damage": 5}) == 14, "persisted v1 trusts the snapshot operation instead of the frozen fallback")


func _verify_invalid_identifiers_fail_closed() -> void:
	var fixtures := [
		{"target": "upgrade", "value": 7, "label": "numeric upgrade id"},
		{"target": "upgrade", "value": " fixture_quality ", "label": "whitespace upgrade id"},
		{"target": "id", "value": RefCounted.new(), "label": "object operation id"},
		{"target": "id", "value": " fixture.operation ", "label": "whitespace operation id"},
		{"target": "hook", "value": &"profile", "label": "StringName hook"},
		{"target": "hook", "value": " profile ", "label": "whitespace hook"},
		{"target": "operation", "value": &"boolean_profile", "label": "StringName operation"},
		{"target": "operation", "value": " boolean_profile ", "label": "whitespace operation"},
	]
	for fixture_value in fixtures:
		var fixture := Dictionary(fixture_value)
		var operation := _operation("fixture.operation", "profile", "boolean_profile", 100, {"preview_damage": false})
		var upgrade := {"id": "fixture_quality", "runtime_operations": [operation]}
		if String(fixture.get("target", "")) == "upgrade":
			upgrade["id"] = fixture.get("value")
		else:
			operation[String(fixture.get("target", ""))] = fixture.get("value")
			upgrade["runtime_operations"] = [operation]
		var registry: QualityEffectRegistry = RegistryScript.new()
		var prepared := registry.prepare_configuration([upgrade], 1, RegistryScript.CURRENT_ASSEMBLY)
		_expect(not bool(prepared.get("ok", true)) and not registry.is_configured(), "%s fails closed at the domain registry" % String(fixture.get("label", "invalid identifier")))


func _verify_non_finite_params_fail_closed() -> void:
	for invalid_value in [NAN, INF, -INF]:
		var registry: QualityEffectRegistry = RegistryScript.new()
		var prepared := registry.prepare_configuration([{
			"id": "quality_non_finite_fixture",
			"runtime_operations": [
				_operation("quality_non_finite_fixture.damage", "modify_hit_damage", "damage_add_when", 100, {
					"when": {"damage_min": invalid_value},
					"value": 1,
				}),
			],
		}], 1, RegistryScript.CURRENT_ASSEMBLY)
		_expect(not bool(prepared.get("ok", true)), "current candidate rejects non-finite JSON params")
		var found_json_error := false
		for error_value in Array(prepared.get("errors", [])):
			if String(error_value).contains("params must be JSON-compatible"):
				found_json_error = true
		_expect(found_json_error and not registry.is_configured(), "non-finite params fail at the JSON boundary without a partial registry")


func _operation(id: String, hook: String, operation: String, priority: int, params: Dictionary) -> Dictionary:
	return {
		"id": id,
		"hook": hook,
		"operation": operation,
		"priority": priority,
		"params": params,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_QUALITY_HISTORY_COMPATIBILITY_FAIL: %s" % message)
