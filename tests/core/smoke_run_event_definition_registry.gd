extends SceneTree

const RegistryScript := preload("res://core/run/events/run_event_definition_registry.gd")
const RepositoryScript := preload("res://persistence/game_data_repository.gd")

const CONTENT_ROOT := "res://data/content"
const PACKAGE_PATH := "res://data/content/extensions/run_event_operations.json"
const EVENT_IDS := [
	"evt_shop_fire",
	"evt_shop_water",
	"evt_shop_wind",
	"evt_shop_earth",
	"evt_role_summon",
	"evt_role_tank",
	"evt_free_roll",
	"evt_discount",
	"evt_duplicate",
	"evt_upgrade_offer",
	"evt_battle_bonus",
	"evt_battle_fail",
	"evt_trap_bonus",
	"evt_shield_bless",
	"evt_curse_gold",
	"evt_elite_reward",
]
const REST_NODE_IDS := [
	"node_rest_gold",
	"node_d02_rest_gold",
	"node_d03_rest_gold",
	"node_d04_rest_gold",
	"node_d05_rest_gold",
	"node_d06_rest_gold",
	"node_d07_rest_gold",
	"node_d08_rest_gold",
	"node_d09_rest_gold",
	"node_d10_rest_gold",
]
const TRIGGER_IDS := [
	"evt_battle_bonus.fast_clear",
	"evt_battle_fail.lose",
]

var _failed := false


func _initialize() -> void:
	var repository := RepositoryScript.new()
	var modern_content := Dictionary(repository.read_content_pack(CONTENT_ROOT))
	_expect(not modern_content.is_empty(), "formal modern content assembles")
	_expect(repository.content_errors().is_empty(), "formal modern content has no repository errors")
	if modern_content.is_empty():
		quit(1)
		return

	_verify_package_contract()
	_verify_modern_and_legacy_parity(modern_content)
	_verify_schema_matrix(modern_content)
	_verify_public_query_contract(modern_content)
	_verify_candidate_atomicity()
	_verify_trigger_order_and_transient_boundary()
	_verify_invalid_definitions()

	if _failed:
		quit(1)
		return
	print("SMOKE_RUN_EVENT_DEFINITION_REGISTRY_OK events=16 rest=10 operations=50 triggers=2")
	quit(0)


func _verify_package_contract() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE_PATH))
	_expect(parsed is Dictionary, "run event extension package is valid JSON")
	if not parsed is Dictionary:
		return
	var package := Dictionary(_normalize_json_numbers(parsed))
	_expect(String(package.get("schema", "")) == "ysbzs.content-package.v1", "package schema is frozen")
	_expect(String(package.get("package_id", "")) == "extension.run_event_operations.v1", "package id is frozen")
	_expect(_integral(package.get("priority", null)) and int(package.get("priority", 0)) == 100, "package priority is frozen")
	var package_operations := Array(package.get("operations", []))
	_expect(package_operations.size() == 53, "package has one schema set plus 52 independent appends")
	if package_operations.is_empty():
		return
	_expect(Dictionary(package_operations[0]) == {
		"op": "set",
		"path": ["economy", "runtime_schema_version"],
		"value": 1,
	}, "package first operation independently sets runtime schema version 1")

	var expected_operations := _expected_event_operations()
	var expected_operation_by_id := {}
	var expected_owner_by_id := {}
	for event_id in EVENT_IDS:
		for operation_value in Array(expected_operations[event_id]):
			var operation := Dictionary(operation_value)
			var operation_id := String(operation.get("id", ""))
			expected_operation_by_id[operation_id] = operation
			expected_owner_by_id[operation_id] = event_id
	for node_id in REST_NODE_IDS:
		for operation_value in _expected_rest_operations(node_id):
			var operation := Dictionary(operation_value)
			var operation_id := String(operation.get("id", ""))
			expected_operation_by_id[operation_id] = operation
			expected_owner_by_id[operation_id] = node_id
	var expected_trigger_by_id := _expected_trigger_definitions()
	var expected_trigger_owner := {
		"evt_battle_bonus.fast_clear": "evt_battle_bonus",
		"evt_battle_fail.lose": "evt_battle_fail",
	}
	var observed_ids: Array[String] = []
	var observed_operation_ids: Array[String] = []
	var observed_trigger_ids: Array[String] = []
	for operation_index in range(1, package_operations.size()):
		var append_operation := Dictionary(package_operations[operation_index])
		_expect(String(append_operation.get("op", "")) == "append_to", "package item %d is an independent append_to" % operation_index)
		var field := String(append_operation.get("field", ""))
		var value := Dictionary(append_operation.get("value", {}))
		var value_id := String(value.get("id", ""))
		observed_ids.append(value_id)
		if field == "event_operations":
			observed_operation_ids.append(value_id)
			_expect(expected_operation_by_id.has(value_id), "package declares only frozen operation id %s" % value_id)
			if expected_operation_by_id.has(value_id):
				_expect(value == Dictionary(expected_operation_by_id[value_id]), "package operation %s keeps exact typed definition" % value_id)
				var owner_id := String(expected_owner_by_id[value_id])
				var is_rest := REST_NODE_IDS.has(owner_id)
				var expected_path := ["route", "node_pool"] if is_rest else ["economy", "events"]
				var expected_key := "nodeId" if is_rest else "id"
				_expect(Array(append_operation.get("path", [])) == expected_path, "package operation %s targets the owning domain" % value_id)
				_expect(String(append_operation.get("match_key", "")) == expected_key, "package operation %s uses the owning key" % value_id)
				_expect(String(append_operation.get("match_value", "")) == owner_id, "package operation %s targets its exact owner" % value_id)
		elif field == "event_triggers":
			observed_trigger_ids.append(value_id)
			_expect(expected_trigger_by_id.has(value_id), "package declares only frozen trigger id %s" % value_id)
			if expected_trigger_by_id.has(value_id):
				var expected_trigger := Dictionary(expected_trigger_by_id[value_id])
				_expect(value == expected_trigger, "package trigger %s keeps exact structured definition" % value_id)
				_expect(Array(append_operation.get("path", [])) == ["economy", "events"], "package trigger %s targets economy events" % value_id)
				_expect(String(append_operation.get("match_key", "")) == "id", "package trigger %s matches event id" % value_id)
				_expect(String(append_operation.get("match_value", "")) == String(expected_trigger_owner.get(value_id, "")), "package trigger %s targets its exact event" % value_id)
		else:
			_expect(false, "package item %d has a supported append field" % operation_index)
	_expect(observed_operation_ids.size() == 50, "package declares exactly 50 operation IDs")
	_expect(_unique_count(observed_operation_ids) == 50, "all 50 package operation IDs are unique")
	_expect(observed_trigger_ids == TRIGGER_IDS, "package declares the two frozen trigger IDs in source order")
	_expect(observed_ids == _expected_package_append_ids(), "all 52 appends keep the frozen source order")


func _verify_modern_and_legacy_parity(modern_content: Dictionary) -> void:
	var modern_registry := RegistryScript.new()
	var modern_prepared := modern_registry.prepare_configuration(modern_content, RegistryScript.CURRENT_ASSEMBLY)
	_expect(bool(modern_prepared.get("ok", false)), "formal schema-1 current content prepares")
	modern_registry.commit_configuration(Dictionary(modern_prepared.get("candidate", {})))
	_expect(modern_registry.is_configured(), "formal schema-1 current content commits")
	_verify_exact_frozen_contract(modern_registry, "modern")

	var legacy_content := _legacy_snapshot(modern_content)
	var legacy_registry := RegistryScript.new()
	var legacy_prepared := legacy_registry.prepare_configuration(legacy_content, RegistryScript.PERSISTED_SNAPSHOT)
	_expect(bool(legacy_prepared.get("ok", false)), "unversioned persisted snapshot prepares through frozen legacy catalog")
	legacy_registry.commit_configuration(Dictionary(legacy_prepared.get("candidate", {})))
	_expect(legacy_registry.is_configured(), "unversioned persisted snapshot commits")
	_verify_exact_frozen_contract(legacy_registry, "legacy")

	for event_id in EVENT_IDS:
		_expect(
			legacy_registry.operations_for_event(event_id) == modern_registry.operations_for_event(event_id),
			"%s modern and legacy event operations are identical" % event_id
		)
	for node_id in REST_NODE_IDS:
		_expect(
			legacy_registry.operations_for_rest_node(node_id) == modern_registry.operations_for_rest_node(node_id),
			"%s modern and legacy rest operations are identical" % node_id
		)
	for result_code in ["WIN_FAST", "LOSE", "WIN_NORMAL", ""]:
		_expect(
			legacy_registry.matching_post_battle_events(result_code) == modern_registry.matching_post_battle_events(result_code),
			"%s modern and legacy trigger projection is identical" % result_code
		)


func _verify_exact_frozen_contract(registry: RefCounted, label: String) -> void:
	var expected_events := _expected_event_operations()
	var all_operation_ids: Array[String] = []
	_expect(expected_events.size() == 16, "%s expected table has exactly 16 formal events" % label)
	for event_id in EVENT_IDS:
		var actual := Array(registry.operations_for_event(event_id))
		_expect(actual == Array(expected_events[event_id]), "%s %s keeps its exact operation blueprint" % [label, event_id])
		for operation_value in actual:
			all_operation_ids.append(String(Dictionary(operation_value).get("id", "")))
	var expected_rest := [
		_operation("rest.heal", "heal_hero", 100, {"amount": 4}),
		_operation("rest.add_coins", "add_coins", 100, {"amount": 2}),
	]
	for node_id in REST_NODE_IDS:
		var actual := Array(registry.operations_for_rest_node(node_id))
		var expected := _expected_rest_operations(node_id)
		_expect(actual == expected, "%s %s always heals 4 before adding 2 coins" % [label, node_id])
		_expect(
			String(Dictionary(expected[0]).get("operation", "")) == String(Dictionary(expected_rest[0]).get("operation", "")) \
				and String(Dictionary(expected[1]).get("operation", "")) == String(Dictionary(expected_rest[1]).get("operation", "")),
			"%s %s operation kind order is frozen" % [label, node_id]
		)
		for operation_value in actual:
			all_operation_ids.append(String(Dictionary(operation_value).get("id", "")))
	_expect(all_operation_ids.size() == 50, "%s registry publishes exactly 50 operation IDs" % label)
	_expect(_unique_count(all_operation_ids) == 50, "%s registry publishes 50 unique operation IDs" % label)
	var sorted_actual := all_operation_ids.duplicate()
	sorted_actual.sort()
	var sorted_expected := _expected_all_operation_ids()
	sorted_expected.sort()
	_expect(sorted_actual == sorted_expected, "%s registry publishes the exact frozen 50 operation IDs" % label)

	var win_events := Array(registry.matching_post_battle_events("WIN_FAST"))
	var lose_events := Array(registry.matching_post_battle_events("LOSE"))
	_expect(win_events.size() == 1, "%s WIN_FAST has one structured trigger" % label)
	_expect(lose_events.size() == 1, "%s LOSE has one structured trigger" % label)
	if win_events.size() == 1:
		_expect(Dictionary(win_events[0]) == _expected_trigger_projection(
			"evt_battle_bonus", "evt_battle_bonus.fast_clear", 10, "fast_clear_win",
			Array(expected_events["evt_battle_bonus"])
		), "%s WIN_FAST trigger keeps exact public projection" % label)
	if lose_events.size() == 1:
		_expect(Dictionary(lose_events[0]) == _expected_trigger_projection(
			"evt_battle_fail", "evt_battle_fail.lose", 11, "battle_loss",
			Array(expected_events["evt_battle_fail"])
		), "%s LOSE trigger keeps exact public projection" % label)
	_expect(registry.matching_post_battle_events("WIN_NORMAL").is_empty(), "%s unknown result has no implicit trigger" % label)


func _verify_schema_matrix(modern_content: Dictionary) -> void:
	var current_unversioned := modern_content.duplicate(true)
	_erase_runtime_schema(current_unversioned)
	_expect_prepare_failure(current_unversioned, RegistryScript.CURRENT_ASSEMBLY, "unversioned current content")
	var current_zero := _with_runtime_schema(modern_content, 0)
	_expect_prepare_failure(current_zero, RegistryScript.CURRENT_ASSEMBLY, "schema-0 current content")
	var current_fractional := _with_runtime_schema(modern_content, 1.5)
	_expect_prepare_failure(current_fractional, RegistryScript.CURRENT_ASSEMBLY, "fractional current schema")
	var current_string := _with_runtime_schema(modern_content, "1")
	_expect_prepare_failure(current_string, RegistryScript.CURRENT_ASSEMBLY, "string current schema")

	for version in [1, 2, 9]:
		var explicit_current := _with_runtime_schema(modern_content, version)
		_expect_prepare_success(explicit_current, RegistryScript.CURRENT_ASSEMBLY, "schema-%d current content" % version)
		var explicit_persisted := _with_runtime_schema(modern_content, version)
		_expect_prepare_success(explicit_persisted, RegistryScript.PERSISTED_SNAPSHOT, "schema-%d persisted content" % version)

	var legacy_content := _legacy_snapshot(modern_content)
	_expect_prepare_success(legacy_content, RegistryScript.PERSISTED_SNAPSHOT, "unversioned persisted content")
	_expect_prepare_success(_with_runtime_schema(legacy_content, 0), RegistryScript.PERSISTED_SNAPSHOT, "schema-0 persisted content")
	_expect_prepare_success(_with_runtime_schema(legacy_content, -3), RegistryScript.PERSISTED_SNAPSHOT, "negative-schema persisted content")
	_expect_prepare_failure(_with_runtime_schema(legacy_content, 1), RegistryScript.PERSISTED_SNAPSHOT, "schema-1 persisted content missing explicit definitions")

	var explicit_new := _with_runtime_schema(modern_content, 2)
	var economy := Dictionary(explicit_new.get("economy", {})).duplicate(true)
	var events := Array(economy.get("events", [])).duplicate(true)
	events.append(_event("evt_new_explicit", [_operation("evt_new_explicit.noop", "noop", 100, {})]))
	economy["events"] = events
	explicit_new["economy"] = economy
	_expect_prepare_success(explicit_new, RegistryScript.CURRENT_ASSEMBLY, "new explicit current event under future schema")
	_expect_prepare_success(explicit_new, RegistryScript.PERSISTED_SNAPSHOT, "new explicit persisted event under future schema")

	var legacy_new_event := legacy_content.duplicate(true)
	var legacy_economy := Dictionary(legacy_new_event.get("economy", {})).duplicate(true)
	var legacy_events := Array(legacy_economy.get("events", [])).duplicate(true)
	legacy_events.append(_event("evt_new_legacy", [_operation("evt_new_legacy.noop", "noop", 100, {})]))
	legacy_economy["events"] = legacy_events
	legacy_new_event["economy"] = legacy_economy
	_expect_prepare_failure(legacy_new_event, RegistryScript.PERSISTED_SNAPSHOT, "new event cannot use legacy fallback")

	var legacy_new_rest := legacy_content.duplicate(true)
	var route := Dictionary(legacy_new_rest.get("route", {})).duplicate(true)
	var nodes := Array(route.get("node_pool", [])).duplicate(true)
	nodes.append(_rest_node("node_new_legacy", [_operation("node_new_legacy.noop", "noop", 100, {})]))
	route["node_pool"] = nodes
	legacy_new_rest["route"] = route
	_expect_prepare_failure(legacy_new_rest, RegistryScript.PERSISTED_SNAPSHOT, "new rest node cannot use legacy fallback")

	_expect_prepare_failure(modern_content, &"", "empty source kind")
	_expect_prepare_failure(modern_content, &"guessed_from_content", "unknown source kind")


func _verify_public_query_contract(modern_content: Dictionary) -> void:
	var registry := _configured_registry(modern_content, RegistryScript.CURRENT_ASSEMBLY)
	_expect(registry != null, "public query fixture configures")
	if registry == null:
		return
	_expect(registry.operations_for_event("unknown_event").is_empty(), "unknown event query is empty")
	_expect(registry.operations_for_rest_node("unknown_rest").is_empty(), "unknown rest query is empty")
	_expect(registry.matching_post_battle_events("unknown_result").is_empty(), "unknown result query is empty")

	var event_operations := Array(registry.operations_for_event("evt_shop_fire"))
	_expect(event_operations.size() == 2, "event query returns the frozen two blueprints")
	if event_operations.size() == 2:
		_expect(_sorted_keys(Dictionary(event_operations[0])) == ["id", "operation", "params", "priority"], "operation without contexts exposes only public keys")
		_expect(_sorted_keys(Dictionary(event_operations[1])) == ["contexts", "id", "operation", "params", "priority"], "context-bound operation exposes only public keys")
		var refill := Dictionary(event_operations[1]).duplicate(true)
		var params := Dictionary(refill.get("params", {})).duplicate(true)
		params["pool_id"] = "forged_pool"
		refill["params"] = params
		var contexts := Array(refill.get("contexts", [])).duplicate()
		contexts.append("route_event")
		refill["contexts"] = contexts
		event_operations[1] = refill
		_expect(registry.operations_for_event("evt_shop_fire") == Array(_expected_event_operations()["evt_shop_fire"]), "event query is a recursive deep copy")

	var rest_operations := Array(registry.operations_for_rest_node("node_rest_gold"))
	if rest_operations.size() == 2:
		var heal := Dictionary(rest_operations[0]).duplicate(true)
		var heal_params := Dictionary(heal.get("params", {})).duplicate(true)
		heal_params["amount"] = 999
		heal["params"] = heal_params
		rest_operations[0] = heal
	_expect(registry.operations_for_rest_node("node_rest_gold") == _expected_rest_operations("node_rest_gold"), "rest query is a recursive deep copy")

	var triggers := Array(registry.matching_post_battle_events("WIN_FAST"))
	if triggers.size() == 1:
		var trigger := Dictionary(triggers[0]).duplicate(true)
		_expect(_sorted_keys(trigger) == [
			"condition_label", "event_id", "operations", "priority", "source_index", "trigger_id", "trigger_index",
		], "trigger query exposes exactly the frozen transient envelope")
		_expect(not trigger.has("conditions") and not trigger.has("result_codes") and not trigger.has("hook"), "trigger query does not leak matcher internals")
		var projected_operations := Array(trigger.get("operations", [])).duplicate(true)
		var first := Dictionary(projected_operations[0]).duplicate(true)
		var first_params := Dictionary(first.get("params", {})).duplicate(true)
		first_params["pool_id"] = "forged_reward"
		first["params"] = first_params
		projected_operations[0] = first
		trigger["operations"] = projected_operations
		triggers[0] = trigger
	_expect(
		registry.matching_post_battle_events("WIN_FAST") == [_expected_trigger_projection(
			"evt_battle_bonus",
			"evt_battle_bonus.fast_clear",
			10,
			"fast_clear_win",
			Array(_expected_event_operations()["evt_battle_bonus"])
		)],
		"trigger query is a recursive deep copy"
	)


func _verify_candidate_atomicity() -> void:
	var registry := RegistryScript.new()
	_expect(not registry.is_configured(), "fresh registry is inert before explicit commit")
	_expect(registry.operations_for_event("fixture_atomic").is_empty(), "inert registry exposes no partial table")
	var source := _minimal_content([
		_event("fixture_atomic", [_operation("fixture_atomic.add", "add_coins", 100, {"amount": 1})]),
	])
	var prepared := registry.prepare_configuration(source, RegistryScript.CURRENT_ASSEMBLY)
	_expect(bool(prepared.get("ok", false)), "valid candidate prepares")
	var candidate := Dictionary(prepared.get("candidate", {})).duplicate()
	var replayed_candidate := candidate.duplicate()
	_expect(registry._is_configuration_candidate_pending(candidate), "fresh opaque candidate is pending")
	_expect(not registry.is_configured(), "prepare does not publish candidate")
	_expect(registry.operations_for_event("fixture_atomic").is_empty(), "prepare leaves public table inert")

	var source_economy := Dictionary(source.get("economy", {})).duplicate(true)
	var source_events := Array(source_economy.get("events", [])).duplicate(true)
	var source_event := Dictionary(source_events[0]).duplicate(true)
	var source_operations := Array(source_event.get("event_operations", [])).duplicate(true)
	var source_operation := Dictionary(source_operations[0]).duplicate(true)
	var source_params := Dictionary(source_operation.get("params", {})).duplicate(true)
	source_params["amount"] = 999
	source_operation["params"] = source_params
	source_operations[0] = source_operation
	source_event["event_operations"] = source_operations
	source_events[0] = source_event
	source_economy["events"] = source_events
	source["economy"] = source_economy
	registry.commit_configuration(candidate)
	_expect(registry.is_configured(), "valid candidate commits")
	_expect(not registry._is_configuration_candidate_pending(candidate), "commit consumes the opaque candidate")
	_expect(registry.operations_for_event("fixture_atomic") == [
		_operation("fixture_atomic.add", "add_coins", 100, {"amount": 1}),
	], "committed table is detached from caller-owned source")

	candidate["token"] = RefCounted.new()
	candidate["forged_table"] = {"fixture_atomic": []}
	_expect(int(Dictionary(registry.operations_for_event("fixture_atomic")[0]).get("params", {}).get("amount", -1)) == 1, "post-commit candidate mutation cannot reach active table")
	registry.commit_configuration(replayed_candidate)
	_expect(int(Dictionary(registry.operations_for_event("fixture_atomic")[0]).get("params", {}).get("amount", -1)) == 1, "consumed candidate cannot replay")

	var stale := registry.prepare_configuration(_minimal_content([
		_event("fixture_stale", [_operation("fixture_stale.noop", "noop", 100, {})]),
	]), RegistryScript.CURRENT_ASSEMBLY)
	var stale_candidate := Dictionary(stale.get("candidate", {}))
	_expect(registry._is_configuration_candidate_pending(stale_candidate), "first replacement candidate is initially pending")
	var current := registry.prepare_configuration(_minimal_content([
		_event("fixture_current", [_operation("fixture_current.noop", "noop", 100, {})]),
	]), RegistryScript.CURRENT_ASSEMBLY)
	var current_candidate := Dictionary(current.get("candidate", {}))
	_expect(not registry._is_configuration_candidate_pending(stale_candidate), "new prepare invalidates an older candidate")
	_expect(registry._is_configuration_candidate_pending(current_candidate), "latest candidate remains pending")
	registry.commit_configuration(stale_candidate)
	_expect(not registry.operations_for_event("fixture_atomic").is_empty(), "stale candidate cannot replace last-good")
	registry.commit_configuration({"token": RefCounted.new(), "event_operations": {"forged": []}})
	_expect(not registry.operations_for_event("fixture_atomic").is_empty(), "foreign candidate cannot replace last-good")
	registry.commit_configuration({"event_operations": {"forged": []}})
	_expect(not registry.operations_for_event("fixture_atomic").is_empty(), "malformed candidate cannot replace last-good")
	registry.commit_configuration(current_candidate)
	_expect(not registry.operations_for_event("fixture_current").is_empty(), "latest pending candidate commits")
	registry.commit_configuration(current_candidate)
	_expect(not registry.operations_for_event("fixture_current").is_empty(), "same candidate cannot be consumed twice")

	var invalidating := registry.prepare_configuration(_minimal_content([
		_event("fixture_never_commits", [_operation("fixture_never_commits.noop", "noop", 100, {})]),
	]), RegistryScript.CURRENT_ASSEMBLY)
	var invalidating_candidate := Dictionary(invalidating.get("candidate", {}))
	var failed := registry.prepare_configuration(_minimal_content([
		_event("fixture_bad", [_operation("fixture_bad.unknown", "missing_handler", 100, {})]),
	]), RegistryScript.CURRENT_ASSEMBLY)
	_expect(not bool(failed.get("ok", false)), "invalid replacement prepare fails")
	_expect(not registry._is_configuration_candidate_pending(invalidating_candidate), "failed prepare also invalidates earlier uncommitted candidates")
	registry.commit_configuration(invalidating_candidate)
	_expect(not registry.operations_for_event("fixture_current").is_empty(), "invalidated candidate cannot replace last-good")
	_expect(registry.operations_for_event("fixture_bad").is_empty(), "failed prepare publishes no partial definition")


func _verify_trigger_order_and_transient_boundary() -> void:
	var ordered_content := _minimal_content([
		_event(
			"trigger_source_a",
			[_operation("trigger_source_a.reward", "select_reward_pool", 100, {"pool_id": "reward_a"})],
			[
				_trigger("trigger_source_a.late", 200, ["MATCH"], "late"),
				_trigger("trigger_source_a.first", 100, ["MATCH"], "first"),
			]
		),
		_event(
			"trigger_source_b",
			[_operation("trigger_source_b.reward", "select_reward_pool", 100, {"pool_id": "reward_b"})],
			[_trigger("trigger_source_b.second", 100, ["MATCH"], "second")]
		),
		_event(
			"trigger_source_c",
			[_operation("trigger_source_c.reward", "select_reward_pool", 100, {"pool_id": "reward_c"})],
			[_trigger("trigger_source_c.earliest", 50, ["MATCH"], "earliest")]
		),
	])
	var registry := _configured_registry(ordered_content, RegistryScript.CURRENT_ASSEMBLY)
	_expect(registry != null, "multi-trigger fixture configures")
	if registry != null:
		var matches := Array(registry.matching_post_battle_events("MATCH"))
		var ids: Array[String] = []
		for match_value in matches:
			ids.append(String(Dictionary(match_value).get("trigger_id", "")))
		_expect(ids == [
			"trigger_source_c.earliest",
			"trigger_source_a.first",
			"trigger_source_b.second",
			"trigger_source_a.late",
		], "multi-trigger query sorts by priority/source_index/trigger_index before IDs")
		_expect(registry.matching_post_battle_events("OTHER").is_empty(), "trigger matching depends only on structured result codes")

	var transient_ok := _minimal_content([
		_event(
			"trigger_transient",
			[_operation("trigger_transient.reward", "select_reward_pool", 100, {"pool_id": "reward_fixture"})],
			[_trigger("trigger_transient.match", 100, ["MATCH"], "match")]
		),
	])
	_expect_prepare_success(transient_ok, RegistryScript.CURRENT_ASSEMBLY, "post-battle trigger with transient reward selection")
	var authority_mutation := _minimal_content([
		_event(
			"trigger_mutation",
			[_operation("trigger_mutation.add", "add_coins", 100, {"amount": 1})],
			[_trigger("trigger_mutation.match", 100, ["MATCH"], "match")]
		),
	])
	_expect_prepare_failure(authority_mutation, RegistryScript.CURRENT_ASSEMBLY, "post-battle trigger with authority mutation")


func _verify_invalid_definitions() -> void:
	var registry := _configured_registry(_minimal_content([
		_event("last_good", [_operation("last_good.noop", "noop", 100, {})]),
	]), RegistryScript.CURRENT_ASSEMBLY)
	_expect(registry != null, "invalid-definition guard registry configures")
	if registry == null:
		return
	var valid_operation := _operation("fixture.noop", "noop", 100, {})
	var valid_trigger := _trigger("fixture.match", 100, ["MATCH"], "match")

	_expect_invalid(registry, {}, "missing economy and route")
	_expect_invalid(registry, {"economy": {}, "route": {"node_pool": []}}, "missing events")
	_expect_invalid(registry, {"economy": {"runtime_schema_version": 1, "events": []}, "route": {"node_pool": []}}, "empty events")
	_expect_invalid(registry, {"economy": {"runtime_schema_version": 1, "events": [_event("fixture", [valid_operation])]}}, "missing route")
	_expect_invalid(registry, {"economy": {"runtime_schema_version": 1, "events": [_event("fixture", [valid_operation])]}, "route": {"node_pool": {}}}, "non-array node_pool")
	_expect_invalid(registry, _minimal_content(["not-an-event"]), "non-dictionary event")
	_expect_invalid(registry, _minimal_content([
		_event("duplicate", [valid_operation]),
		_event("duplicate", [_operation("fixture.second", "noop", 100, {})]),
	]), "duplicate event id")
	_expect_invalid(registry, _minimal_content([{"id": "missing_operations", "event_triggers": []}]), "event missing operations")
	_expect_invalid(registry, _minimal_content([_event("fixture", ["not-an-operation"])]), "non-dictionary operation")

	var missing_id := valid_operation.duplicate(true)
	missing_id.erase("id")
	_expect_invalid(registry, _minimal_content([_event("fixture", [missing_id])]), "operation missing required id")
	var unknown_key := valid_operation.duplicate(true)
	unknown_key["handler"] = "noop"
	_expect_invalid(registry, _minimal_content([_event("fixture", [unknown_key])]), "operation unknown key")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		valid_operation,
		valid_operation.duplicate(true),
	])]), "duplicate operation id")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.unknown", "missing_handler", 100, {}),
	])]), "unknown operation handler")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.bad_params", "add_coins", 100, {"amount": -1}),
	])]), "handler semantic params")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.non_json", "noop", 100, {"value": Vector2i.ONE}),
	])]), "non-JSON params")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.fractional", "noop", 1.5, {}),
	])]), "fractional operation priority")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.context_empty", "noop", 100, {}, []),
	])]), "empty contexts")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.context_unknown", "noop", 100, {}, ["battle"]),
	])]), "unknown context")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.context_space", "noop", 100, {}, [" shop_event"]),
	])]), "whitespace context")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.context_duplicate", "noop", 100, {}, ["shop_event", "shop_event"]),
	])]), "duplicate context")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.context_type", "noop", 100, {}, [1]),
	])]), "non-string context")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.reserved", "noop", 100, {"nested": {"__authority": true}}),
	])]), "reserved nested params key")
	_expect_invalid(registry, _minimal_content([_event("fixture", [
		_operation("fixture.script", "noop", 100, {"nested": ["res://bad.gd"]}),
	])]), "script path in params")
	for invalid_number in [NAN, INF, -INF]:
		_expect_invalid(registry, _minimal_content([_event("fixture", [
			_operation("fixture.nonfinite", "add_coins", 100, {"amount": invalid_number}),
		])]), "non-finite params %s" % str(invalid_number))

	_expect_invalid(registry, _minimal_content([
		_event("fixture", [valid_operation]),
	], [_rest_node("duplicate_rest", [_operation("duplicate_rest.noop_a", "noop", 100, {})]), _rest_node("duplicate_rest", [_operation("duplicate_rest.noop_b", "noop", 100, {})])]), "duplicate rest id")
	_expect_invalid(registry, _minimal_content([
		_event("fixture", [valid_operation]),
	], [{"nodeId": "missing_rest_operations", "nodeType": "rest"}]), "rest missing operations")

	var trigger_base := _event(
		"fixture_trigger",
		[_operation("fixture_trigger.reward", "select_reward_pool", 100, {"pool_id": "reward_fixture"})],
		[valid_trigger]
	)
	var trigger_not_array := trigger_base.duplicate(true)
	trigger_not_array["event_triggers"] = {}
	_expect_invalid(registry, _minimal_content([trigger_not_array]), "non-array triggers")
	var trigger_not_dictionary := trigger_base.duplicate(true)
	trigger_not_dictionary["event_triggers"] = ["not-a-trigger"]
	_expect_invalid(registry, _minimal_content([trigger_not_dictionary]), "non-dictionary trigger")
	var trigger_missing := valid_trigger.duplicate(true)
	trigger_missing.erase("condition_label")
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [trigger_missing])]), "trigger missing required field")
	var trigger_unknown_key := valid_trigger.duplicate(true)
	trigger_unknown_key["script"] = "res://bad.gd"
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [trigger_unknown_key])]), "trigger unknown key")
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [valid_trigger, valid_trigger.duplicate(true)])]), "duplicate trigger id")
	var trigger_hook := valid_trigger.duplicate(true)
	trigger_hook["hook"] = "before_battle"
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [trigger_hook])]), "unknown trigger hook")
	var trigger_priority := valid_trigger.duplicate(true)
	trigger_priority["priority"] = 1.5
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [trigger_priority])]), "fractional trigger priority")
	var trigger_conditions := valid_trigger.duplicate(true)
	trigger_conditions["conditions"] = {"result_codes": ["MATCH"], "authority": true}
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [trigger_conditions])]), "trigger conditions extra key")
	var trigger_empty_codes := valid_trigger.duplicate(true)
	trigger_empty_codes["conditions"] = {"result_codes": []}
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [trigger_empty_codes])]), "trigger empty result codes")
	var trigger_duplicate_codes := valid_trigger.duplicate(true)
	trigger_duplicate_codes["conditions"] = {"result_codes": ["MATCH", "MATCH"]}
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [trigger_duplicate_codes])]), "trigger duplicate result codes")
	var trigger_non_string_code := valid_trigger.duplicate(true)
	trigger_non_string_code["conditions"] = {"result_codes": [INF]}
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [trigger_non_string_code])]), "trigger non-finite non-string result code")
	var trigger_script_code := valid_trigger.duplicate(true)
	trigger_script_code["conditions"] = {"result_codes": ["res://bad.gd"]}
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [trigger_script_code])]), "trigger script path")
	var trigger_empty_label := valid_trigger.duplicate(true)
	trigger_empty_label["condition_label"] = ""
	_expect_invalid(registry, _minimal_content([_event("fixture_trigger", Array(trigger_base["event_operations"]), [trigger_empty_label])]), "trigger empty condition label")


func _expect_invalid(registry: RefCounted, content: Dictionary, label: String) -> void:
	var before: Array = Array(registry.call(&"operations_for_event", "last_good"))
	var prepared: Dictionary = Dictionary(registry.call(&"prepare_configuration", content, RegistryScript.CURRENT_ASSEMBLY))
	_expect(not bool(prepared.get("ok", false)), "%s fails closed" % label)
	_expect(Dictionary(prepared.get("candidate", {})).is_empty(), "%s exposes no partial candidate" % label)
	_expect(Array(registry.call(&"operations_for_event", "last_good")) == before, "%s preserves last-good table" % label)


func _expect_prepare_success(content: Dictionary, source_kind: StringName, label: String) -> void:
	var registry := RegistryScript.new()
	var prepared := registry.prepare_configuration(content, source_kind)
	_expect(bool(prepared.get("ok", false)), "%s prepares" % label)
	if bool(prepared.get("ok", false)):
		var candidate := Dictionary(prepared.get("candidate", {}))
		_expect(registry._is_configuration_candidate_pending(candidate), "%s candidate is pending" % label)
		registry.commit_configuration(candidate)
		_expect(registry.is_configured(), "%s commits" % label)


func _expect_prepare_failure(content: Dictionary, source_kind: StringName, label: String) -> void:
	var registry := RegistryScript.new()
	var prepared := registry.prepare_configuration(content, source_kind)
	_expect(not bool(prepared.get("ok", false)), "%s fails closed" % label)
	_expect(Dictionary(prepared.get("candidate", {})).is_empty(), "%s exposes no candidate" % label)
	_expect(not registry.is_configured(), "%s leaves registry inert" % label)


func _configured_registry(content: Dictionary, source_kind: StringName) -> RefCounted:
	var registry := RegistryScript.new()
	var prepared := registry.prepare_configuration(content, source_kind)
	if not bool(prepared.get("ok", false)):
		return null
	registry.commit_configuration(Dictionary(prepared.get("candidate", {})))
	return registry if registry.is_configured() else null


func _legacy_snapshot(modern_content: Dictionary) -> Dictionary:
	var result := modern_content.duplicate(true)
	_erase_runtime_schema(result)
	var economy := Dictionary(result.get("economy", {})).duplicate(true)
	var events := Array(economy.get("events", [])).duplicate(true)
	for index in events.size():
		var event := Dictionary(events[index]).duplicate(true)
		event.erase("event_operations")
		event.erase("event_triggers")
		events[index] = event
	economy["events"] = events
	result["economy"] = economy
	var route := Dictionary(result.get("route", {})).duplicate(true)
	var nodes := Array(route.get("node_pool", [])).duplicate(true)
	for index in nodes.size():
		if not nodes[index] is Dictionary:
			continue
		var node := Dictionary(nodes[index]).duplicate(true)
		node.erase("event_operations")
		nodes[index] = node
	route["node_pool"] = nodes
	result["route"] = route
	return result


func _with_runtime_schema(content: Dictionary, version: Variant) -> Dictionary:
	var result := content.duplicate(true)
	var economy := Dictionary(result.get("economy", {})).duplicate(true)
	economy["runtime_schema_version"] = version
	result["economy"] = economy
	return result


func _erase_runtime_schema(content: Dictionary) -> void:
	var economy := Dictionary(content.get("economy", {})).duplicate(true)
	economy.erase("runtime_schema_version")
	content["economy"] = economy


func _minimal_content(events: Array, nodes: Array = []) -> Dictionary:
	return {
		"economy": {
			"runtime_schema_version": 1,
			"events": events.duplicate(true),
		},
		"route": {"node_pool": nodes.duplicate(true)},
	}


func _event(id: String, operations: Array, triggers: Array = []) -> Dictionary:
	return {
		"id": id,
		"event_operations": operations.duplicate(true),
		"event_triggers": triggers.duplicate(true),
	}


func _rest_node(id: String, operations: Array) -> Dictionary:
	return {
		"nodeId": id,
		"nodeType": "rest",
		"event_operations": operations.duplicate(true),
	}


func _operation(
	id: String,
	operation: String,
	priority: Variant,
	params: Variant,
	contexts: Variant = null
) -> Dictionary:
	var result := {
		"id": id,
		"operation": operation,
		"priority": priority,
		"params": params,
	}
	if contexts != null:
		result["contexts"] = contexts
	return result


func _trigger(id: String, priority: Variant, result_codes: Array, condition_label: String) -> Dictionary:
	return {
		"id": id,
		"hook": "post_battle",
		"priority": priority,
		"conditions": {"result_codes": result_codes.duplicate()},
		"condition_label": condition_label,
	}


func _expected_event_operations() -> Dictionary:
	return {
		"evt_shop_fire": [
			_operation("evt_shop_fire.cost", "spend_coins", 0, {"amount": 1}),
			_operation("evt_shop_fire.refill", "refill_shop_pool", 100, {"pool_id": "elem_火", "minimum_slots": 3}, ["shop_event"]),
		],
		"evt_shop_water": [
			_operation("evt_shop_water.cost", "spend_coins", 0, {"amount": 1}),
			_operation("evt_shop_water.refill", "refill_shop_pool", 100, {"pool_id": "elem_水", "minimum_slots": 3}, ["shop_event"]),
		],
		"evt_shop_wind": [
			_operation("evt_shop_wind.cost", "spend_coins", 0, {"amount": 1}),
			_operation("evt_shop_wind.refill", "refill_shop_pool", 100, {"pool_id": "elem_雷", "minimum_slots": 3}, ["shop_event"]),
		],
		"evt_shop_earth": [
			_operation("evt_shop_earth.cost", "spend_coins", 0, {"amount": 1}),
			_operation("evt_shop_earth.refill", "refill_shop_pool", 100, {"pool_id": "elem_地", "minimum_slots": 3}, ["shop_event"]),
		],
		"evt_role_summon": [
			_operation("evt_role_summon.cost", "spend_coins", 0, {"amount": 2}),
			_operation("evt_role_summon.refill", "refill_shop_pool", 100, {"pool_id": "role_召唤", "minimum_slots": 3}, ["shop_event"]),
		],
		"evt_role_tank": [
			_operation("evt_role_tank.cost", "spend_coins", 0, {"amount": 2}),
			_operation("evt_role_tank.refill", "refill_shop_pool", 100, {"pool_id": "role_坦克", "minimum_slots": 3}, ["shop_event"]),
		],
		"evt_free_roll": [
			_operation("evt_free_roll.free_refresh", "add_free_refreshes", 100, {"amount": 1}),
		],
		"evt_discount": [
			_operation("evt_discount.cost", "spend_coins", 0, {"amount": 1}),
			_operation("evt_discount.discount", "set_next_discount", 100, {"percent": 50}),
		],
		"evt_duplicate": [
			_operation("evt_duplicate.cost", "spend_coins", 0, {"amount": 4}),
			_operation("evt_duplicate.duplicate", "duplicate_first_pet", 100, {}),
			_operation("evt_duplicate.refill", "refill_shop_pool", 100, {"pool_id": "special_merchant", "minimum_slots": 3}, ["shop_event"]),
		],
		"evt_upgrade_offer": [
			_operation("evt_upgrade_offer.cost", "spend_coins", 0, {"amount": 6}),
			_operation("evt_upgrade_offer.upgrade", "upgrade_first_eligible_pet", 100, {}),
			_operation("evt_upgrade_offer.refill", "refill_shop_pool", 100, {"pool_id": "special_merchant", "minimum_slots": 3}, ["shop_event"]),
		],
		"evt_battle_bonus": [
			_operation("evt_battle_bonus.reward_pool", "select_reward_pool", 100, {"pool_id": "reward_fast_clear"}),
		],
		"evt_battle_fail": [
			_operation("evt_battle_fail.reward_pool", "select_reward_pool", 100, {"pool_id": "reward_none"}),
		],
		"evt_trap_bonus": [
			_operation("evt_trap_bonus.cost", "spend_coins", 0, {"amount": 2}),
			_operation("evt_trap_bonus.trap_bonus", "queue_trap_damage_bonus", 100, {"amount": 1}),
		],
		"evt_shield_bless": [
			_operation("evt_shield_bless.cost", "spend_coins", 0, {"amount": 2}),
			_operation("evt_shield_bless.shield", "queue_battle_prep_shield", 100, {"amount": 2}),
		],
		"evt_curse_gold": [
			_operation("evt_curse_gold.add_coins", "add_coins", 100, {"amount": 4}),
			_operation("evt_curse_gold.reward_multiplier", "queue_reward_gold_multiplier", 100, {"percent": 90}),
		],
		"evt_elite_reward": [
			_operation("evt_elite_reward.noop", "noop", 100, {}),
		],
	}


func _expected_rest_operations(node_id: String) -> Array:
	return [
		_operation("%s.heal" % node_id, "heal_hero", 100, {"amount": 4}),
		_operation("%s.add_coins" % node_id, "add_coins", 100, {"amount": 2}),
	]


func _expected_trigger_definitions() -> Dictionary:
	return {
		"evt_battle_bonus.fast_clear": {
			"id": "evt_battle_bonus.fast_clear",
			"hook": "post_battle",
			"priority": 100,
			"conditions": {"result_codes": ["WIN_FAST"]},
			"condition_label": "fast_clear_win",
		},
		"evt_battle_fail.lose": {
			"id": "evt_battle_fail.lose",
			"hook": "post_battle",
			"priority": 100,
			"conditions": {"result_codes": ["LOSE"]},
			"condition_label": "battle_loss",
		},
	}


func _expected_trigger_projection(
	event_id: String,
	trigger_id: String,
	source_index: int,
	condition_label: String,
	operations: Array
) -> Dictionary:
	return {
		"event_id": event_id,
		"trigger_id": trigger_id,
		"priority": 100,
		"source_index": source_index,
		"trigger_index": 0,
		"condition_label": condition_label,
		"operations": operations.duplicate(true),
	}


func _expected_package_append_ids() -> Array[String]:
	var result: Array[String] = []
	var expected_events := _expected_event_operations()
	for event_id in EVENT_IDS:
		for operation_value in Array(expected_events[event_id]):
			result.append(String(Dictionary(operation_value).get("id", "")))
		if event_id == "evt_battle_bonus":
			result.append("evt_battle_bonus.fast_clear")
		elif event_id == "evt_battle_fail":
			result.append("evt_battle_fail.lose")
	for node_id in REST_NODE_IDS:
		for operation_value in _expected_rest_operations(node_id):
			result.append(String(Dictionary(operation_value).get("id", "")))
	return result


func _expected_all_operation_ids() -> Array[String]:
	var result: Array[String] = []
	var expected_events := _expected_event_operations()
	for event_id in EVENT_IDS:
		for operation_value in Array(expected_events[event_id]):
			result.append(String(Dictionary(operation_value).get("id", "")))
	for node_id in REST_NODE_IDS:
		for operation_value in _expected_rest_operations(node_id):
			result.append(String(Dictionary(operation_value).get("id", "")))
	return result


func _unique_count(values: Array[String]) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()


func _sorted_keys(value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_value in value.keys():
		result.append(String(key_value))
	result.sort()
	return result


func _integral(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (
		typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value))
	)


func _normalize_json_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and _integral(value):
		return int(value)
	if value is Array:
		var array_result: Array = []
		for item in Array(value):
			array_result.append(_normalize_json_numbers(item))
		return array_result
	if value is Dictionary:
		var dictionary_result := {}
		for key_value in Dictionary(value).keys():
			dictionary_result[String(key_value)] = _normalize_json_numbers(Dictionary(value)[key_value])
		return dictionary_result
	return value


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_RUN_EVENT_DEFINITION_REGISTRY_FAIL: %s" % label)
