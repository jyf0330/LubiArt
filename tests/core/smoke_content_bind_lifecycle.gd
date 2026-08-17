extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const CoreCompositionScript := preload("res://core/composition/core_composition.gd")
const RepositoryScript := preload("res://persistence/game_data_repository.gd")
const LegacyCatalogScript := preload("res://core/battle/quality/legacy_quality_runtime_catalog.gd")
const AuthoritativeStateCodecScript := preload("res://persistence/authoritative_state_codec.gd")

const CURRENT_ASSEMBLY := &"current_assembly"
const PERSISTED_SNAPSHOT := &"persisted_snapshot"
const CONTENT_ROOT := "res://data/content"

var _failed := false


class FakeHistoryRepository extends RefCounted:
	var content_pack: Dictionary = {}
	var fail_begin := false
	var fail_checkpoint := false
	var created_runs := 0
	var checkpoint_writes := 0

	func _init(content: Dictionary, begin_failure: bool, checkpoint_failure: bool) -> void:
		content_pack = content.duplicate(true)
		fail_begin = begin_failure
		fail_checkpoint = checkpoint_failure

	func read_content_reference(_root: String, _determinism: Dictionary) -> Dictionary:
		return content_pack.duplicate(true)

	func read_content_pack(_root: String, _run_id: String) -> Dictionary:
		return content_pack.duplicate(true)

	func ensure_content_revision(_root: String, _content_hash: String, _content: Dictionary) -> Dictionary:
		if fail_begin:
			return {}
		return {"revision": 77, "contentPath": "content/revision_000077.json.zst"}

	func create_run(_root: String, _run_id: String, _manifest: Dictionary, _content: Dictionary) -> bool:
		created_runs += 1
		return true

	func write_checkpoint(
		_root: String,
		_run_id: String,
		_checkpoint_id: String,
		_document: Dictionary,
		_summary: Dictionary
	) -> bool:
		checkpoint_writes += 1
		return not fail_checkpoint


func _initialize() -> void:
	var repository := RepositoryScript.new()
	var modern_content := Dictionary(repository.read_content_pack(CONTENT_ROOT))
	_expect(repository.content_errors().is_empty() and not modern_content.is_empty(), "modern content loads through the production repository")
	_verify_modern_parity_and_composition_identity(modern_content)
	_verify_state_binding_atomicity(modern_content)
	_verify_injected_script_path_fails_closed(modern_content)
	_verify_injected_invalid_ids_fail_closed(modern_content)
	_verify_persisted_save_and_replay(modern_content)
	_verify_history_bind_failure(modern_content)
	_verify_history_rollback(modern_content, true, false)
	_verify_history_rollback(modern_content, false, true)
	_verify_all_writer_boundary()
	if _failed:
		quit(1)
		return
	print("SMOKE_CONTENT_BIND_LIFECYCLE_OK modern=68 identity=shared save=replay history=rollback writers=1")
	quit(0)


func _verify_modern_parity_and_composition_identity(modern_content: Dictionary) -> void:
	var modern_rows := _quality_runtime_rows(modern_content)
	var legacy_rows := _quality_runtime_rows({"quality": {"upgrades": LegacyCatalogScript.upgrades()}})
	_expect(modern_rows.size() == 68 and modern_rows == legacy_rows, "modern assembled operations exactly match the frozen 68-row behavior catalog")
	_expect(int(Dictionary(modern_content.get("quality", {})).get("runtime_schema_version", 0)) == 1, "modern assembly declares quality runtime schema v1")

	var composition: RefCounted = CoreCompositionScript.new()
	var registry: RefCounted = composition.quality_effect_registry
	var run_registry: RefCounted = composition.run_event_definition_registry
	_expect(not registry.is_configured() and not run_registry.is_configured(), "both composition registries are inert before content binding")
	var caller_content := modern_content.duplicate(true)
	var prepared := Dictionary(composition.prepare_content_binding(caller_content, CURRENT_ASSEMBLY))
	_expect(bool(prepared.get("ok", false)), "composition prepares a modern content candidate")
	_expect(not registry.is_configured() and not run_registry.is_configured(), "composition prepare does not expose either partial registry")
	var candidate := Dictionary(prepared.get("candidate", {}))
	_expect(candidate.size() == 1 and candidate.get("token") is RefCounted, "composition exposes only an opaque candidate token")
	caller_content["quality"]["upgrades"] = []
	caller_content["economy"]["events"] = []
	_expect(composition.commit_content_binding(candidate), "composition commits the detached candidate")
	_expect(composition.quality_effect_registry == registry and registry.registered_effect_ids().size() == 68, "content commit preserves the registry instance and activates 68 effects")
	_expect(composition.run_event_definition_registry == run_registry and not run_registry.operations_for_event("evt_discount").is_empty(), "content commit preserves the run-event registry instance and activates detached definitions")
	_expect(composition.quality_runtime_service.get("_registry") == registry, "quality runtime service shares the canonical registry instance")
	_expect(composition.battle_query_projector.get("_quality_effect_registry") == registry, "battle query projector shares the canonical registry instance")
	_expect(composition.auto_position_evaluator.get("_quality_effect_registry") == registry, "auto-position evaluator shares the canonical registry instance")
	_expect(not composition.commit_content_binding(candidate), "a consumed composition token cannot be replayed")
	var strategy: RefCounted = registry.effect_for_id("G03")
	var run_operations := Array(run_registry.operations_for_event("evt_discount"))
	var invalid := modern_content.duplicate(true)
	invalid["quality"]["runtime_schema_version"] = 0
	var rejected := Dictionary(composition.prepare_content_binding(invalid, CURRENT_ASSEMBLY))
	_expect(not bool(rejected.get("ok", true)), "invalid modern rebind fails during prepare")
	_expect(composition.quality_effect_registry == registry and registry.effect_for_id("G03") == strategy, "failed composition prepare preserves registry and strategy identity")
	_expect(composition.run_event_definition_registry == run_registry and run_registry.operations_for_event("evt_discount") == run_operations, "failed quality prepare preserves the run-event registry identity and behavior")

	var invalid_run := modern_content.duplicate(true)
	invalid_run["economy"]["events"][0].erase("event_operations")
	var rejected_run := Dictionary(composition.prepare_content_binding(invalid_run, CURRENT_ASSEMBLY))
	_expect(not bool(rejected_run.get("ok", true)), "invalid run-event rebind fails after quality prepare")
	_expect(registry.effect_for_id("G03") == strategy and run_registry.operations_for_event("evt_discount") == run_operations, "run-event prepare failure commits neither registry")

	var pending := Dictionary(composition.prepare_content_binding(modern_content, CURRENT_ASSEMBLY))
	_expect(bool(pending.get("ok", false)), "dual-registry stale-candidate fixture prepares")
	var superseding_run := Dictionary(run_registry.prepare_configuration(modern_content, CURRENT_ASSEMBLY))
	_expect(bool(superseding_run.get("ok", false)), "direct run-event prepare invalidates the composition-owned run candidate")
	_expect(not composition.commit_content_binding(Dictionary(pending.get("candidate", {}))), "composition rejects a stale child candidate before committing either registry")
	_expect(registry.effect_for_id("G03") == strategy and run_registry.operations_for_event("evt_discount") == run_operations, "stale child candidate preserves both committed registries")


func _verify_state_binding_atomicity(modern_content: Dictionary) -> void:
	var state: RefCounted = _test_state(modern_content, CURRENT_ASSEMBLY)
	_expect(state.is_initialized(), "test authority initializes from explicit modern content")
	var composition: RefCounted = state.get("_core_composition")
	var registry: RefCounted = composition.quality_effect_registry
	var run_registry: RefCounted = composition.run_event_definition_registry
	var strategy: RefCounted = registry.effect_for_id("G03")
	var run_operations := Array(run_registry.operations_for_event("evt_discount"))
	var before_content := Dictionary(state.get("game_data")).duplicate(true)
	var before_source := StringName(state.content_source_kind())
	var before_content_hash := String(state.call("_content_hash"))
	var before_state_hash := String(state.call("_state_hash"))
	state.set("_content_hash_cache", "")
	var before_cache := String(state.get("_content_hash_cache"))
	var invalid := before_content.duplicate(true)
	invalid["quality"]["runtime_schema_version"] = 0
	_expect(not state.replace_game_data_for_test(invalid, CURRENT_ASSEMBLY), "test helper rejects an invalid current content replacement")
	_expect(state.get("_core_composition").quality_effect_registry == registry, "failed state replacement preserves the exact registry instance")
	_expect(state.get("_core_composition").run_event_definition_registry == run_registry, "failed state replacement preserves the exact run-event registry instance")
	_expect(registry.effect_for_id("G03") == strategy, "failed state replacement preserves the exact active strategy instance")
	_expect(run_registry.operations_for_event("evt_discount") == run_operations, "failed state replacement preserves active run-event behavior")
	_expect(Dictionary(state.get("game_data")) == before_content and state.content_source_kind() == before_source, "failed state replacement preserves content and source kind")
	_expect(String(state.get("_content_hash_cache")) == before_cache, "failed state replacement preserves an originally empty content-hash cache")
	_expect(String(state.call("_content_hash")) == before_content_hash, "failed state replacement preserves the content hash")
	_expect(String(state.call("_state_hash")) == before_state_hash, "failed state replacement preserves the authoritative state hash")
	_expect(not Array(state.get("_content_binding_errors")).is_empty(), "failed state replacement retains deterministic binding diagnostics")

	var production: RefCounted = StateScript.new()
	_expect(not production.replace_game_data_for_test(Dictionary(production.get("game_data")), CURRENT_ASSEMBLY), "production authority rejects the test-only replacement helper")
	var production_composition: RefCounted = production.get("_core_composition")
	production.configure_core_services({"quality_effect_registry": RefCounted.new()})
	_expect(production.get("_core_composition") == production_composition, "production authority rejects an unbindable quality-registry override")
	production.configure_core_services({"run_event_definition_registry": RefCounted.new()})
	_expect(production.get("_core_composition") == production_composition, "production authority rejects an unbindable run-event-registry override")

	var invalid_run := before_content.duplicate(true)
	invalid_run["economy"]["events"][0].erase("event_operations")
	_expect(not state.replace_game_data_for_test(invalid_run, CURRENT_ASSEMBLY), "test helper rejects an invalid run-event content replacement")
	_expect(state.get("_core_composition").quality_effect_registry == registry and registry.effect_for_id("G03") == strategy, "run-event replacement failure preserves the quality registry")
	_expect(state.get("_core_composition").run_event_definition_registry == run_registry and run_registry.operations_for_event("evt_discount") == run_operations, "run-event replacement failure preserves the run-event registry")


func _verify_injected_script_path_fails_closed(modern_content: Dictionary) -> void:
	for script_path in ["res://forbidden_runtime.gd", "uid://forbidden-runtime-script"]:
		var injected := _content_with_narrow_mode(modern_content, script_path)
		_expect(not injected.is_empty(), "script-path fixture locates a string-valued registered operation")
		var state: RefCounted = _test_state(injected, CURRENT_ASSEMBLY)
		_expect(not state.is_initialized(), "test-mode injected content rejects runtime script path %s" % script_path)
		var found_script_path_error := false
		for error_value in Array(Dictionary(state.initialization_result()).get("errors", [])):
			if String(error_value).begins_with("RUNTIME_OPERATION_SCRIPT_PATH_FORBIDDEN:"):
				found_script_path_error = true
		_expect(found_script_path_error and Dictionary(state.get("game_data")).is_empty(), "script-path injection fails at Composition before authority content assignment")


func _verify_injected_invalid_ids_fail_closed(modern_content: Dictionary) -> void:
	var fixtures := [
		{"label": "numeric upgrade id", "content": _content_with_invalid_quality_field(modern_content, "owner_id", 7)},
		{"label": "object operation id", "content": _content_with_invalid_quality_field(modern_content, "id", RefCounted.new())},
		{"label": "whitespace operation id", "content": _content_with_invalid_quality_field(modern_content, "id", " invalid.operation ")},
		{"label": "whitespace operation selector", "content": _content_with_invalid_quality_field(modern_content, "operation", " damage_add_when ")},
		{"label": "whitespace runtime handler", "content": _content_with_invalid_runtime_handler(modern_content)},
	]
	for fixture_value in fixtures:
		var fixture := Dictionary(fixture_value)
		var state: RefCounted = _test_state(Dictionary(fixture.get("content", {})), CURRENT_ASSEMBLY)
		_expect(not state.is_initialized(), "%s fails closed before authority initialization" % String(fixture.get("label", "invalid id")))
		_expect(Dictionary(state.get("game_data")).is_empty(), "%s cannot enter authoritative game data" % String(fixture.get("label", "invalid id")))


func _verify_persisted_save_and_replay(modern_content: Dictionary) -> void:
	var legacy_content := _legacy_snapshot_content(modern_content)
	var legacy_state: RefCounted = _test_state(legacy_content, PERSISTED_SNAPSHOT)
	_expect(legacy_state.is_initialized(), "persisted legacy authority initializes through the frozen fallback")
	_expect(legacy_state.content_source_kind() == PERSISTED_SNAPSHOT, "persisted legacy authority retains its explicit source kind")
	_expect(legacy_state.get("_core_composition").quality_effect_registry.registered_effect_ids().size() == 68, "persisted legacy authority binds all frozen quality ids")
	_expect(not legacy_state.get("_core_composition").run_event_definition_registry.operations_for_event("evt_discount").is_empty(), "persisted legacy authority binds the frozen run-event catalog")

	var document := Dictionary(legacy_state.save_document("q1-persisted"))
	var restored: RefCounted = _test_state(modern_content, CURRENT_ASSEMBLY)
	var restored_registry: RefCounted = restored.get("_core_composition").quality_effect_registry
	var restored_run_registry: RefCounted = restored.get("_core_composition").run_event_definition_registry
	_expect(restored.load_document(document), "portable save loads its embedded legacy content snapshot")
	_expect(restored.content_source_kind() == PERSISTED_SNAPSHOT and Dictionary(restored.get("game_data")) == legacy_content, "save load records persisted source and exact embedded content")
	_expect(restored.get("_core_composition").quality_effect_registry == restored_registry, "save load reconfigures the existing registry instance")
	_expect(restored.get("_core_composition").run_event_definition_registry == restored_run_registry, "save load reconfigures the existing run-event registry instance")
	_expect(restored_registry.registered_effect_ids().size() == 68, "save load activates the frozen legacy registry")
	_expect(not restored_run_registry.operations_for_rest_node("node_rest_gold").is_empty(), "save load activates frozen legacy rest definitions")

	var replay := Dictionary(legacy_state.replay_document())
	var verification := Dictionary(legacy_state.verify_replay_document(replay))
	_expect(bool(verification.get("ok", false)), "persisted legacy replay verifies through an explicitly sourced simulation authority")

	var rejected_target: RefCounted = _test_state(modern_content, CURRENT_ASSEMBLY)
	var rejected_registry: RefCounted = rejected_target.get("_core_composition").quality_effect_registry
	var rejected_run_registry: RefCounted = rejected_target.get("_core_composition").run_event_definition_registry
	var rejected_run_operations := Array(rejected_run_registry.operations_for_event("evt_discount"))
	var rejected_content := Dictionary(rejected_target.get("game_data")).duplicate(true)
	var rejected_hash := String(rejected_target.call("_state_hash"))
	var invalid_document := document.duplicate(true)
	invalid_document["state"]["phase"] = "invalid_phase"
	invalid_document["checksum"] = rejected_target.call("_save_checksum", invalid_document)
	_expect(not rejected_target.load_document(invalid_document), "save schema validation fails before persisted content binding")
	_expect(rejected_target.get("_core_composition").quality_effect_registry == rejected_registry and Dictionary(rejected_target.get("game_data")) == rejected_content, "rejected save preserves registry identity and current content")
	_expect(rejected_target.get("_core_composition").run_event_definition_registry == rejected_run_registry and rejected_run_registry.operations_for_event("evt_discount") == rejected_run_operations, "rejected save preserves run-event registry identity and behavior")
	_expect(rejected_target.content_source_kind() == CURRENT_ASSEMBLY and String(rejected_target.call("_state_hash")) == rejected_hash, "rejected save preserves source kind and authoritative hash")


func _verify_history_rollback(modern_content: Dictionary, fail_begin: bool, fail_checkpoint: bool) -> void:
	var state: RefCounted = _test_state(modern_content, CURRENT_ASSEMBLY)
	state.set("history_recording_enabled", true)
	state.set("history_root", "user://q1_history_rollback")
	state.set("history_run_id", "before-run")
	state.set("history_branch_id", "before-branch")
	state.set("history_parent_run_id", "before-parent")
	state.set("history_parent_checkpoint_id", "before-checkpoint")
	state.set("history_command_index", 9)
	state.set("history_content_revision", 5)
	state.set("history_content_path", "before-content")
	state.set("_history_suspended", false)
	state.set("last_command_result", {"fixture": "before"})
	state.set("log_lines", ["before diagnostic"])
	var checkpoint_document := Dictionary(state.save_document("q1-history", {
		"embedContentPack": false,
		"historyCheckpoint": true,
	}))
	var run_header := {"determinism": Dictionary(state.call("_determinism_context", false))}
	var checkpoint_summary := {"stateHash": String(state.call("_state_hash"))}
	var repository := FakeHistoryRepository.new(modern_content, fail_begin, fail_checkpoint)
	state.configure_core_services({"run_history_repository": repository})
	var registry: RefCounted = state.get("_core_composition").quality_effect_registry
	var run_registry: RefCounted = state.get("_core_composition").run_event_definition_registry
	var strategy_damage := int(registry.effect_for_id("G03").modify_hit_damage({"damage": 10, "core_cell": true}))
	var run_operations := Array(run_registry.operations_for_event("evt_discount"))
	var before_payload := AuthoritativeStateCodecScript.capture(state, false)
	var before_content := Dictionary(state.get("game_data")).duplicate(true)
	var before_source := StringName(state.content_source_kind())
	var before_content_hash := String(state.call("_content_hash"))
	var before_cache := String(state.get("_content_hash_cache"))
	var before_state_hash := String(state.call("_state_hash"))
	var before_history := _history_fields(state)
	var before_last_result: Variant = Dictionary(state.get("last_command_result")).duplicate(true)
	var resumed := bool(state.call(
		"_resume_from_history_checkpoint",
		"source-run",
		"source-checkpoint",
		run_header,
		checkpoint_summary,
		checkpoint_document
	))
	var label := "begin" if fail_begin else "checkpoint"
	_expect(not resumed, "%s failure aborts history resume" % label)
	_expect(state.get("_core_composition").quality_effect_registry == registry, "%s failure restores the same registry instance" % label)
	_expect(state.get("_core_composition").run_event_definition_registry == run_registry, "%s failure restores the same run-event registry instance" % label)
	_expect(int(registry.effect_for_id("G03").modify_hit_damage({"damage": 10, "core_cell": true})) == strategy_damage, "%s failure restores the previous registry behavior" % label)
	_expect(run_registry.operations_for_event("evt_discount") == run_operations, "%s failure restores the previous run-event registry behavior" % label)
	_expect(Dictionary(state.get("game_data")) == before_content and state.content_source_kind() == before_source, "%s failure restores content and source kind" % label)
	_expect(String(state.call("_content_hash")) == before_content_hash and String(state.get("_content_hash_cache")) == before_cache, "%s failure restores content hash and cache" % label)
	_expect(String(state.call("_state_hash")) == before_state_hash, "%s failure restores the authoritative hash" % label)
	_expect(_history_fields(state) == before_history, "%s failure restores every history field" % label)
	_expect(state.get("last_command_result") == before_last_result, "%s failure restores last command result" % label)
	var after_payload := AuthoritativeStateCodecScript.capture(state, false)
	after_payload["log_lines"] = Array(before_payload.get("log_lines", [])).duplicate(true)
	_expect(after_payload == before_payload, "%s failure restores the codec payload before adding diagnostics" % label)
	_expect(not Array(state.get("log_lines")).is_empty() and String(Array(state.get("log_lines"))[0]).contains("失败"), "%s failure retains an explicit diagnostic after rollback" % label)
	if fail_begin:
		_expect(repository.created_runs == 0 and repository.checkpoint_writes == 0, "begin failure creates no branch artifact")
	else:
			_expect(repository.created_runs == 1 and repository.checkpoint_writes == 1, "checkpoint failure occurs after one append-only branch creation")


func _verify_history_bind_failure(modern_content: Dictionary) -> void:
	var state: RefCounted = _test_state(modern_content, CURRENT_ASSEMBLY)
	state.set("_content_binding_errors", ["before-binding-diagnostic"])
	state.set("_history_suspended", false)
	state.set("last_command_result", {"fixture": "before-bind-failure"})
	state.set("log_lines", ["before bind failure"])
	var invalid_content := modern_content.duplicate(true)
	var invalid_quality := Dictionary(invalid_content.get("quality", {})).duplicate(true)
	var invalid_upgrades := Array(invalid_quality.get("upgrades", [])).duplicate(true)
	var invalid_upgrade := Dictionary(invalid_upgrades[0]).duplicate(true)
	invalid_upgrade.erase("runtime_operations")
	invalid_upgrades[0] = invalid_upgrade
	invalid_quality["upgrades"] = invalid_upgrades
	invalid_content["quality"] = invalid_quality
	var document := Dictionary(state.save_document("q1-history-bind", {
		"embedContentPack": false,
		"historyCheckpoint": true,
	}))
	var run_header := {"determinism": {
		"rulesVersion": StateScript.RULES_VERSION,
		"rngVersion": String(state.call("_determinism_context", false).get("rngVersion", "")),
		"contentHash": String(state.call("_content_hash_for", invalid_content)),
	}}
	var repository := FakeHistoryRepository.new(invalid_content, false, false)
	state.configure_core_services({"run_history_repository": repository})
	var registry: RefCounted = state.get("_core_composition").quality_effect_registry
	var run_registry: RefCounted = state.get("_core_composition").run_event_definition_registry
	var strategy: RefCounted = registry.effect_for_id("G03")
	var run_operations := Array(run_registry.operations_for_event("evt_discount"))
	var before_payload := AuthoritativeStateCodecScript.capture(state, false)
	var before_content := Dictionary(state.get("game_data")).duplicate(true)
	var before_source := StringName(state.content_source_kind())
	var before_content_hash := String(state.call("_content_hash"))
	var before_state_hash := String(state.call("_state_hash"))
	state.set("_content_hash_cache", "")
	var before_cache := String(state.get("_content_hash_cache"))
	var before_history := _history_fields(state)
	var before_binding_errors := Array(state.get("_content_binding_errors")).duplicate()
	var before_last_result := Dictionary(state.get("last_command_result")).duplicate(true)
	var resumed := bool(state.call(
		"_resume_from_history_checkpoint",
		"source-run",
		"source-checkpoint",
		run_header,
		{"stateHash": before_state_hash},
		document
	))
	_expect(not resumed, "history content-bind failure aborts before checkpoint restore")
	_expect(state.get("_core_composition").quality_effect_registry == registry and registry.effect_for_id("G03") == strategy, "history content-bind failure preserves registry and exact Strategy identity")
	_expect(state.get("_core_composition").run_event_definition_registry == run_registry and run_registry.operations_for_event("evt_discount") == run_operations, "history content-bind failure preserves run-event registry identity and behavior")
	_expect(Dictionary(state.get("game_data")) == before_content and state.content_source_kind() == before_source, "history content-bind failure preserves last-good content and source")
	_expect(String(state.get("_content_hash_cache")) == before_cache, "history content-bind failure restores an originally empty content-hash cache")
	_expect(String(state.call("_content_hash")) == before_content_hash, "history content-bind failure preserves the content hash")
	_expect(String(state.call("_state_hash")) == before_state_hash and _history_fields(state) == before_history, "history content-bind failure preserves authority hash and history flags")
	_expect(Array(state.get("_content_binding_errors")) == before_binding_errors and state.get("last_command_result") == before_last_result, "history content-bind failure restores prior diagnostics and last result")
	var after_payload := AuthoritativeStateCodecScript.capture(state, false)
	after_payload["log_lines"] = Array(before_payload.get("log_lines", [])).duplicate(true)
	_expect(after_payload == before_payload, "history content-bind failure preserves the codec payload before adding diagnostics")
	_expect(repository.created_runs == 0 and repository.checkpoint_writes == 0, "history content-bind failure creates no branch artifact")


func _verify_all_writer_boundary() -> void:
	var facade_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	var assignment_count := 0
	var inside_replacement := false
	for line_value in facade_source.split("\n"):
		var line := String(line_value)
		if line.begins_with("func "):
			inside_replacement = line.begins_with("func _replace_game_" + "data(")
		if line.contains("game_" + "data ="):
			assignment_count += 1
			_expect(inside_replacement, "production game data assignment is confined to the replacement boundary")
	_expect(assignment_count == 1, "production has exactly one game data assignment")

	var direct_assignment := RegEx.new()
	direct_assignment.compile("\\.game_" + "data\\s*=")
	var nested_assignment := RegEx.new()
	nested_assignment.compile("\\.game_" + "data\\s*\\[[^\\n]+\\]\\s*=")
	var reflective_assignment := RegEx.new()
	reflective_assignment.compile("\\.set\\(\\s*[\"']game_" + "data[\"']")
	var alias_declaration := RegEx.new()
	alias_declaration.compile("(?m)^\\s*var\\s+([A-Za-z_][A-Za-z0-9_]*)(?:\\s*:\\s*Dictionary)?\\s*(?::=|=)\\s*Dictionary\\([^\\n]*game_" + "data[^\\n]*$")
	var violations: Array[String] = []
	for root in ["res://core", "res://session", "res://persistence", "res://tests", "res://tools"]:
		for path_value in _source_files(root):
			var path := String(path_value)
			var source := FileAccess.get_file_as_string(path)
			if direct_assignment.search(source) != null \
					or nested_assignment.search(source) != null \
					or reflective_assignment.search(source) != null:
				violations.append(path)
			for alias_match in alias_declaration.search_all(source):
				var declaration := alias_match.get_string(0)
				if declaration.contains(".duplicate("):
					continue
				var alias_name := alias_match.get_string(1)
				var alias_mutation := RegEx.new()
				alias_mutation.compile("(?m)^\\s*%s\\s*\\[[^\\n]+\\]\\s*=" % alias_name)
				var function_end := source.find("\nfunc ", alias_match.get_end())
				if function_end < 0:
					function_end = source.length()
				var function_tail := source.substr(alias_match.get_end(), function_end - alias_match.get_end())
				if alias_mutation.search(function_tail) != null:
					violations.append("%s:%s" % [path, alias_name])
	_expect(violations.is_empty(), "tests, tools, and services contain no direct or nested game data writers: %s" % str(violations))


func _quality_runtime_rows(content: Dictionary) -> Array:
	var result: Array = []
	for upgrade_value in Array(Dictionary(content.get("quality", {})).get("upgrades", [])):
		var upgrade := Dictionary(upgrade_value)
		result.append({
			"id": String(upgrade.get("id", "")),
			"runtime_operations": _normalize_integral_json(Array(upgrade.get("runtime_operations", []))),
		})
	return result


func _normalize_integral_json(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value)):
		return int(value)
	if value is Array:
		var array: Array = []
		for item in Array(value):
			array.append(_normalize_integral_json(item))
		return array
	if value is Dictionary:
		var dictionary := {}
		for key_value in Dictionary(value).keys():
			dictionary[String(key_value)] = _normalize_integral_json(Dictionary(value)[key_value])
		return dictionary
	return String(value) if typeof(value) == TYPE_STRING_NAME else value


func _content_with_narrow_mode(modern_content: Dictionary, mode: String) -> Dictionary:
	var result := modern_content.duplicate(true)
	var quality := Dictionary(result.get("quality", {})).duplicate(true)
	var upgrades := Array(quality.get("upgrades", [])).duplicate(true)
	for upgrade_index in range(upgrades.size()):
		var upgrade := Dictionary(upgrades[upgrade_index]).duplicate(true)
		var operations := Array(upgrade.get("runtime_operations", [])).duplicate(true)
		for operation_index in range(operations.size()):
			var operation := Dictionary(operations[operation_index]).duplicate(true)
			if String(operation.get("operation", "")) != "narrow_to_target_mode":
				continue
			operation["params"] = {"mode": mode}
			operations[operation_index] = operation
			upgrade["runtime_operations"] = operations
			upgrades[upgrade_index] = upgrade
			quality["upgrades"] = upgrades
			result["quality"] = quality
			return result
	return {}


func _content_with_invalid_quality_field(modern_content: Dictionary, field: String, invalid_value: Variant) -> Dictionary:
	var result := modern_content.duplicate(true)
	var quality := Dictionary(result.get("quality", {})).duplicate(true)
	var upgrades := Array(quality.get("upgrades", [])).duplicate(true)
	if upgrades.is_empty():
		return {}
	var upgrade := Dictionary(upgrades[0]).duplicate(true)
	if field == "owner_id":
		upgrade["id"] = invalid_value
	else:
		var operations := Array(upgrade.get("runtime_operations", [])).duplicate(true)
		if operations.is_empty():
			return {}
		var operation := Dictionary(operations[0]).duplicate(true)
		operation[field] = invalid_value
		operations[0] = operation
		upgrade["runtime_operations"] = operations
	upgrades[0] = upgrade
	quality["upgrades"] = upgrades
	result["quality"] = quality
	return result


func _content_with_invalid_runtime_handler(modern_content: Dictionary) -> Dictionary:
	var result := modern_content.duplicate(true)
	result["runtime_handler_fixture"] = {"runtime_handler": " handler_with_whitespace "}
	return result


func _legacy_snapshot_content(modern_content: Dictionary) -> Dictionary:
	var result := modern_content.duplicate(true)
	var quality := Dictionary(result.get("quality", {})).duplicate(true)
	quality.erase("runtime_schema_version")
	var upgrades: Array = []
	for upgrade_value in Array(quality.get("upgrades", [])):
		var upgrade := Dictionary(upgrade_value).duplicate(true)
		upgrade.erase("runtime_operations")
		upgrades.append(upgrade)
	quality["upgrades"] = upgrades
	result["quality"] = quality
	var economy := Dictionary(result.get("economy", {})).duplicate(true)
	economy.erase("runtime_schema_version")
	var events: Array = []
	for event_value in Array(economy.get("events", [])):
		var event := Dictionary(event_value).duplicate(true)
		event.erase("event_operations")
		event.erase("event_triggers")
		events.append(event)
	economy["events"] = events
	result["economy"] = economy
	var route := Dictionary(result.get("route", {})).duplicate(true)
	var nodes: Array = []
	for node_value in Array(route.get("node_pool", [])):
		var node := Dictionary(node_value).duplicate(true)
		node.erase("event_operations")
		nodes.append(node)
	route["node_pool"] = nodes
	result["route"] = route
	return result


func _test_state(content: Dictionary, source_kind: StringName) -> RefCounted:
	return StateScript.new({
		"mode": "test",
		"content_pack": content.duplicate(true),
		"content_source_kind": source_kind,
	})


func _history_fields(state: RefCounted) -> Dictionary:
	return {
		"recording": bool(state.get("history_recording_enabled")),
		"root": String(state.get("history_root")),
		"run": String(state.get("history_run_id")),
		"branch": String(state.get("history_branch_id")),
		"parent_run": String(state.get("history_parent_run_id")),
		"parent_checkpoint": String(state.get("history_parent_checkpoint_id")),
		"command_index": int(state.get("history_command_index")),
		"content_revision": int(state.get("history_content_revision")),
		"content_path": String(state.get("history_content_path")),
		"suspended": bool(state.get("_history_suspended")),
	}


func _source_files(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if not name.begins_with("."):
			var child := root.path_join(name)
			if directory.current_is_dir():
				result.append_array(_source_files(child))
			elif ["gd", "py", "sh"].has(name.get_extension().to_lower()):
				result.append(child)
		name = directory.get_next()
	directory.list_dir_end()
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_CONTENT_BIND_LIFECYCLE_FAIL: %s" % message)
