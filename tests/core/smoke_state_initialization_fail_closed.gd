extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const ContentLoadServiceScript := preload("res://core/content/content_load_service.gd")
const ContentSourceConfigScript := preload("res://core/content/content_source_config.gd")
const SessionFactoryScript := preload("res://session/session_factory.gd")

var _failed := false


class FakeRepository extends RefCounted:
	var content_pack: Dictionary
	var content_error_values: Array[String]
	var supplement: Variant
	var content_reads := 0
	var supplement_reads := 0
	var content_paths: Array[String] = []
	var supplement_paths: Array[String] = []

	func _init(pack: Dictionary = {}, errors: Array[String] = [], supplement_value: Variant = {"nodes": []}) -> void:
		content_pack = pack.duplicate(true)
		content_error_values = errors.duplicate()
		supplement = supplement_value.duplicate(true) if typeof(supplement_value) == TYPE_DICTIONARY else supplement_value

	func read_content_pack(path: String) -> Dictionary:
		content_reads += 1
		content_paths.append(path)
		return content_pack.duplicate(true)

	func content_errors() -> Array[String]:
		return content_error_values.duplicate()

	func read_dictionary(path: String) -> Variant:
		supplement_reads += 1
		supplement_paths.append(path)
		return supplement.duplicate(true) if typeof(supplement) == TYPE_DICTIONARY else supplement


func _initialize() -> void:
	_test_production_success()
	_test_production_empty_fails_closed()
	_test_repository_errors_preserve_order()
	_test_simulation_is_injected_and_io_free()
	_test_simulation_requires_content()
	_test_supplement_merge_is_first_wins_unique()
	_test_service_contract_failures()

	if _failed:
		quit(1)
		return
	print("SMOKE_STATE_INITIALIZATION_FAIL_CLOSED_OK production=closed simulation_io=0 supplement=unique")
	quit(0)


func _test_production_success() -> void:
	var repository := FakeRepository.new(_fixture_pack())
	var state: RefCounted = StateScript.new({"core_overrides": {"game_data_repository": repository}})
	var result := Dictionary(state.call("initialization_result"))
	_expect(state.call("is_initialized"), "production state initializes from a valid canonical pack")
	_expect(String(result.get("schema", "")) == "ysbzs.init-result.v1", "state exposes the stable initialization schema")
	_expect(String(result.get("mode", "")) == "production", "production initialization reports its mode")
	_expect(String(result.get("source", "")) == ContentSourceConfigScript.CONTENT_PACK_PATH, "production initialization reports the canonical source")
	_expect(String(result.get("contentHash", "")) == String(state.call("_content_hash")), "initialization and authority use the same content hash")
	_expect(not result.has("contentPack"), "state initialization query does not duplicate the full content pack")
	_expect(repository.content_reads == 1 and repository.content_paths == [ContentSourceConfigScript.CONTENT_PACK_PATH], "production reads the canonical content path exactly once")
	_expect(repository.supplement_reads == 1 and repository.supplement_paths == [ContentSourceConfigScript.BAZAAR_DAY1_CATALOG_PATH], "production reads the configured supplement exactly once")
	result["errors"] = ["caller mutation"]
	_expect(Array(Dictionary(state.call("initialization_result")).get("errors", [])).is_empty(), "initialization result is deep-copy isolated")


func _test_production_empty_fails_closed() -> void:
	var repository := FakeRepository.new({})
	var state: RefCounted = StateScript.new({"core_overrides": {"game_data_repository": repository}})
	var result := Dictionary(state.call("initialization_result"))
	_expect(not state.call("is_initialized"), "empty production content does not initialize state")
	_expect(Array(result.get("errors", [])) == ["CONTENT_PACK_EMPTY"], "empty production content reports CONTENT_PACK_EMPTY")
	_expect(Dictionary(state.get("game_data")).is_empty(), "failed initialization exposes no fallback content")
	_expect(Array(state.get("roster")).is_empty() and Array(state.get("log_lines")).is_empty(), "failed initialization does not run reset")
	_expect(Dictionary(state.get("run_plan")).is_empty() and int(state.get("state_version")) == 0, "failed initialization leaves gameplay defaults untouched")
	_expect(repository.content_reads == 1 and repository.supplement_reads == 0, "empty canonical content does not probe a second path")
	var factory_repository := FakeRepository.new({})
	var factory_result := Dictionary(SessionFactoryScript.create_local_result({
		"core_overrides": {"game_data_repository": factory_repository},
	}))
	_expect(not bool(factory_result.get("ok", true)) and factory_result.get("session") == null, "SessionFactory never returns a half-initialized Session")
	_expect(Array(Dictionary(factory_result.get("initialization", {})).get("errors", [])) == ["CONTENT_PACK_EMPTY"], "SessionFactory preserves initialization failure details")


func _test_repository_errors_preserve_order() -> void:
	var repository := FakeRepository.new({}, ["FIRST_ERROR", "SECOND_ERROR"])
	var state: RefCounted = StateScript.new({"core_overrides": {"game_data_repository": repository}})
	_expect(Array(Dictionary(state.call("initialization_result")).get("errors", [])) == ["FIRST_ERROR", "SECOND_ERROR"], "repository errors preserve their original order")
	_expect(Dictionary(state.get("game_data")).is_empty(), "repository errors cannot fall back to fixture content")


func _test_simulation_is_injected_and_io_free() -> void:
	var repository := FakeRepository.new(_fixture_pack(), [], {"nodes": [{"nodeId": "must_not_load"}]})
	var injected := _fixture_pack()
	injected["source"] = {"fixture": "simulation"}
	var state: RefCounted = StateScript.new({
		"mode": "simulation",
		"content_pack": injected,
		"core_overrides": {"game_data_repository": repository},
	})
	injected["source"]["fixture"] = "caller-mutated"
	var result := Dictionary(state.call("initialization_result"))
	_expect(state.call("is_initialized"), "simulation initializes from an injected pack")
	_expect(String(result.get("mode", "")) == "simulation" and String(result.get("source", "")) == "injected", "simulation reports injected source")
	_expect(repository.content_reads == 0 and repository.supplement_reads == 0, "simulation initialization performs zero repository reads")
	_expect(String(Dictionary(Dictionary(state.get("game_data")).get("source", {})).get("fixture", "")) == "simulation", "simulation content is deep-copy isolated at constructor entry")


func _test_simulation_requires_content() -> void:
	var repository := FakeRepository.new(_fixture_pack())
	var state: RefCounted = StateScript.new({
		"mode": "simulation",
		"content_pack": {},
		"core_overrides": {"game_data_repository": repository},
	})
	_expect(not state.call("is_initialized"), "simulation rejects an empty injected pack")
	_expect(Array(Dictionary(state.call("initialization_result")).get("errors", [])) == ["CONTENT_PACK_REQUIRED"], "simulation reports CONTENT_PACK_REQUIRED")
	_expect(repository.content_reads == 0 and repository.supplement_reads == 0, "failed simulation initialization still performs zero repository reads")


func _test_supplement_merge_is_first_wins_unique() -> void:
	var pack := _fixture_pack()
	pack["route"] = {"node_pool": [{"nodeId": "keep", "title": "canonical"}]}
	var repository := FakeRepository.new(pack, [], {"nodes": [
		{"nodeId": "keep", "title": "supplement must not replace"},
		{"nodeId": "add", "title": "first addition"},
		{"nodeId": "add", "title": "duplicate addition"},
	]})
	var state: RefCounted = StateScript.new({"core_overrides": {"game_data_repository": repository}})
	var nodes := Array(Dictionary(Dictionary(state.get("game_data")).get("route", {})).get("node_pool", []))
	_expect(nodes.size() == 2, "supplement appends each new nodeId exactly once")
	_expect(String(Dictionary(nodes[0]).get("title", "")) == "canonical", "canonical node wins over a duplicate supplement nodeId")
	_expect(String(Dictionary(nodes[1]).get("title", "")) == "first addition", "first unique supplement row is retained")


func _test_service_contract_failures() -> void:
	var service: RefCounted = ContentLoadServiceScript.new()
	var unavailable := Dictionary(service.call("load", {
		"mode": "production", "contentPath": "res://missing", "supplementPath": "",
	}, null))
	_expect(Array(unavailable.get("errors", [])) == ["CONTENT_REPOSITORY_UNAVAILABLE"], "production rejects a missing repository")
	var unsupported := Dictionary(service.call("load", {"mode": "unknown"}, null))
	_expect(Array(unsupported.get("errors", [])) == ["INIT_MODE_UNSUPPORTED"], "content service rejects an unknown mode")
	_expect(String(unsupported.get("mode", "")) == "production", "failed InitResult keeps the documented mode vocabulary")
	var invalid_supplement_repository := FakeRepository.new(_fixture_pack(), [], null)
	var invalid_supplement := Dictionary(service.call("load", {
		"mode": "production",
		"contentPath": "res://fixture",
		"supplementPath": "res://invalid-supplement",
	}, invalid_supplement_repository))
	_expect(Array(invalid_supplement.get("errors", [])) == ["CONTENT_SUPPLEMENT_INVALID"], "non-empty invalid supplement path fails closed")


func _fixture_pack() -> Dictionary:
	return {
		"source": {"fixture": "initialization"},
		"player": {"coins": 16, "hero_hp": 80, "heroMaxHp": 80, "ap": 3},
		"route_options": [],
		"route": {"schedule": [], "node_pool": []},
		"roster": [],
		"shop_offers": [],
		"battle": {"rules": {}},
		"economy": {
			"runtime_schema_version": 1,
			"events": [{
				"id": "fixture_event",
				"event_operations": [{
					"id": "fixture_event.noop",
					"operation": "noop",
					"priority": 100,
					"params": {},
				}],
			}],
		},
		"quality": {
			"runtime_schema_version": 1,
			"upgrades": [{
				"id": "fixture_quality",
				"runtime_operations": [{
					"id": "fixture_quality.profile",
					"hook": "profile",
					"operation": "boolean_profile",
					"priority": 100,
					"params": {"preview_damage": false},
				}],
			}],
		},
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_STATE_INITIALIZATION_FAIL_CLOSED_FAIL: %s" % message)
