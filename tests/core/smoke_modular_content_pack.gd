extends SceneTree

const RepositoryScript := preload("res://persistence/game_data_repository.gd")
const DocumentCodecScript := preload("res://persistence/save_codec.gd")
const RegistryScript := preload("res://persistence/content_pack_registry.gd")
const AssemblerScript := preload("res://persistence/content_pack_assembler.gd")
const ValidatorScript := preload("res://persistence/content_pack_validator.gd")
const CONTENT_ROOT := "res://data/content"
const GENERATED_ROOT := CONTENT_ROOT + "/generated"
const RUN_EVENT_EXTENSION_PATH := CONTENT_ROOT + "/extensions/run_event_operations.json"
const EXPECTED_CONTENT_SHA256 := "c5f14d2cca55e3b46fe225fe7b63bed51c5571f5f853b65766fe89debb62308e"
const EXPECTED_STABLE_CONTENT_SHA256 := "0abf5fb7efc61d7196c39c5e264dae9b9f2c93add438381ad5529188e0436a5f"
const EXPECTED_ECONOMY_SHA256 := "e8ea6fbe9764d3ff51252a87e97e790da5dff7adf4719486cd67db92398c032f"
const EXPECTED_ROUTE_SHA256 := "bf19ac1b61f82399e8a489e880a5dfe17d7f151961b518a4d88b89428ff1d500"
const EXPECTED_DOMAINS := [
	"source", "route_options", "player", "roster", "shop_offers", "economy",
	"battle", "skill_catalog", "trait_catalog", "skill_combo_catalog",
	"stat_catalog", "status_catalog", "route", "quality", "mechanism_status",
	"runtime_database",
]

var failed := false


func _initialize() -> void:
	var repository := RepositoryScript.new()
	var data := Dictionary(repository.read_content_pack(CONTENT_ROOT))
	if not repository.content_errors().is_empty():
		push_error("Content pack errors: %s" % JSON.stringify(repository.content_errors()))
	_expect(not data.is_empty(), "modular content pack assembles runtime data")
	_expect(repository.content_errors().is_empty(), "formal content packages pass fail-closed validation")
	var fingerprint := JSON.stringify(data).sha256_text()
	_expect(fingerprint == EXPECTED_CONTENT_SHA256, "assembled content keeps the verified migration fingerprint expected=%s actual=%s" % [EXPECTED_CONTENT_SHA256, fingerprint])
	var stable_fingerprint := DocumentCodecScript.stable_json(data).sha256_text()
	_expect(stable_fingerprint == EXPECTED_STABLE_CONTENT_SHA256, "assembled content keeps the authoritative stable-json fingerprint expected=%s actual=%s" % [EXPECTED_STABLE_CONTENT_SHA256, stable_fingerprint])
	_verify_single_file_trait(data)
	_verify_duplicate_package_fails_closed()
	_verify_duplicate_set_fails_closed()
	_verify_missing_attachment_fails_closed()
	_verify_fractional_runtime_priority_fails_closed()
	_verify_manifest_dependency_and_override_contract(data)
	_verify_generated_domain_packages()
	_verify_run_event_operations_package(data)
	if failed:
		quit(1)
		return
	print("SMOKE_MODULAR_CONTENT_PACK_OK sha256=%s stable_sha256=%s" % [fingerprint, stable_fingerprint])
	quit(0)


func _verify_single_file_trait(data: Dictionary) -> void:
	var trait_definition := Dictionary(Dictionary(data.get("trait_catalog", {})).get("trait_bloodthirst", {}))
	_expect(String(trait_definition.get("name", "")) == "嗜血", "one extension file registers the bloodthirst Type Object")
	var owner_pet := {}
	for item_value in Array(Dictionary(data.get("economy", {})).get("shop_items", [])):
		var item := Dictionary(item_value)
		if String(item.get("id", "")) == "pal_005":
			owner_pet = item
			break
	_expect(Array(owner_pet.get("traits", [])).has("trait_bloodthirst"), "the same extension file attaches its trait to pal_005")


func _verify_duplicate_package_fails_closed() -> void:
	var root_path := "user://duplicate_content_pack"
	var absolute := ProjectSettings.globalize_path(root_path)
	DirAccess.make_dir_recursive_absolute(absolute)
	var package := {
		"schema": "ysbzs.content-package.v1",
		"package_id": "duplicate",
		"operations": [{"op": "set", "path": ["value"], "value": 1}],
	}
	for name in ["a.json", "b.json"]:
		var file := FileAccess.open(root_path.path_join(name), FileAccess.WRITE)
		file.store_string(JSON.stringify(package))
		file.close()
	var repository := RepositoryScript.new()
	_expect(repository.read_content_pack(root_path).is_empty(), "duplicate package ids expose no partial content")
	_expect(repository.content_errors().has("DUPLICATE_PACKAGE_ID:duplicate"), "duplicate package ids report a deterministic error")
	for name in ["a.json", "b.json"]:
		DirAccess.remove_absolute(absolute.path_join(name))
	DirAccess.remove_absolute(absolute)


func _verify_missing_attachment_fails_closed() -> void:
	var root_path := "user://missing_attachment_content_pack"
	var absolute := ProjectSettings.globalize_path(root_path)
	DirAccess.make_dir_recursive_absolute(absolute)
	var package := {
		"schema": "ysbzs.content-package.v1",
		"package_id": "missing_attachment",
		"operations": [{
			"op": "attach_unique", "path": ["items"], "match_key": "id",
			"match_value": "missing", "field": "traits", "value": "trait_x",
		}],
	}
	var file := FileAccess.open(root_path.path_join("missing.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(package))
	file.close()
	var repository := RepositoryScript.new()
	_expect(repository.read_content_pack(root_path).is_empty(), "missing attachment targets expose no partial content")
	_expect(not repository.content_errors().is_empty(), "missing attachment targets report a validation error")
	DirAccess.remove_absolute(absolute.path_join("missing.json"))
	DirAccess.remove_absolute(absolute)


func _verify_duplicate_set_fails_closed() -> void:
	var root_path := "user://duplicate_set_content_pack"
	var absolute := ProjectSettings.globalize_path(root_path)
	DirAccess.make_dir_recursive_absolute(absolute)
	for name in ["first", "second"]:
		var package := {
			"schema": "ysbzs.content-package.v1",
			"package_id": name,
			"operations": [{"op": "set", "path": ["value"], "value": name}],
		}
		var file := FileAccess.open(root_path.path_join("%s.json" % name), FileAccess.WRITE)
		file.store_string(JSON.stringify(package))
		file.close()
	var repository := RepositoryScript.new()
	_expect(repository.read_content_pack(root_path).is_empty(), "duplicate set paths expose no partial content")
	_expect(repository.content_errors().has("DUPLICATE_PATH:second:value"), "duplicate set paths report a deterministic error")
	for name in ["first", "second"]:
		DirAccess.remove_absolute(absolute.path_join("%s.json" % name))
	DirAccess.remove_absolute(absolute)


func _verify_fractional_runtime_priority_fails_closed() -> void:
	var root_path := "user://fractional_runtime_priority_content_pack"
	var absolute := ProjectSettings.globalize_path(root_path)
	DirAccess.make_dir_recursive_absolute(absolute)
	var package := {
		"schema": "ysbzs.content-package.v1",
		"package_id": "fractional_runtime_priority",
		"operations": [{
			"op": "set",
			"path": ["fixture"],
			"value": {
				"runtime_operations": [{
					"id": "fixture.fractional",
					"hook": "profile",
					"operation": "boolean_profile",
					"priority": 1.5,
					"params": {"preview_damage": false},
				}],
			},
		}],
	}
	var file_path := root_path.path_join("fractional.json")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(package))
	file.close()
	var repository := RepositoryScript.new()
	_expect(repository.read_content_pack(root_path).is_empty(), "fractional JSON runtime priority fails closed")
	_expect(repository.content_errors().has("RUNTIME_OPERATION_PRIORITY_INVALID:content.fixture.runtime_operations[0]"), "fractional JSON runtime priority reports its exact path")
	DirAccess.remove_absolute(absolute.path_join("fractional.json"))
	DirAccess.remove_absolute(absolute)


func _verify_manifest_dependency_and_override_contract(data: Dictionary) -> void:
	var manifest := Dictionary(data.get("_content_manifest", {}))
	_expect(String(manifest.get("schema", "")) == "ysbzs.content-assembly.v1", "assembled content carries an immutable package provenance manifest")
	_expect(Array(manifest.get("packages", [])).size() > 0, "content manifest records each resolved package in assembly order")

	var base := {
		"schema": "ysbzs.content-package.v1", "package_id": "base", "version": "1.2.0", "priority": 100,
		"operations": [{"op": "set", "path": ["fixture"], "value": {"value": 1}}],
	}
	var extension := {
		"schema": "ysbzs.content-package.v1", "package_id": "extension", "version": "2.0.0", "priority": -100,
		"dependencies": [{"id": "base", "min_version": "1.1.0"}],
		"capabilities": ["content.override"],
		"operations": [{"op": "replace", "path": ["fixture", "value"], "value": 2}],
	}
	var registered := Dictionary(RegistryScript.new().register([extension, base]))
	_expect(bool(registered.get("ok", false)), "valid manifest dependencies register")
	var ordered := Array(registered.get("packages", []))
	_expect(ordered.size() == 2 and String(Dictionary(ordered[0]).get("package_id", "")) == "base", "dependency order wins over package priority")
	var assembled := Dictionary(AssemblerScript.new().assemble(ordered))
	_expect(bool(assembled.get("ok", false)) and int(Dictionary(Dictionary(assembled.get("data", {})).get("fixture", {})).get("value", 0)) == 2, "explicit override capability replaces an existing target")
	_expect(Array(Dictionary(Dictionary(assembled.get("data", {})).get("_content_manifest", {})).get("packages", [])).size() == 2, "fixture assembly records both package versions and order")

	var missing := extension.duplicate(true)
	missing["dependencies"] = [{"id": "missing", "min_version": "1.0.0"}]
	var missing_result := Dictionary(RegistryScript.new().register([missing]))
	_expect(Array(missing_result.get("errors", [])).has("MISSING_DEPENDENCY:extension:missing"), "missing package dependencies fail closed")
	var incompatible := extension.duplicate(true)
	incompatible["dependencies"] = [{"id": "base", "min_version": "1.3.0"}]
	_expect(Array(Dictionary(RegistryScript.new().register([base, incompatible])).get("errors", [])).has("DEPENDENCY_VERSION_UNSUPPORTED:extension:base:1.3.0:1.2.0"), "dependency minimum versions fail closed")
	var future := base.duplicate(true)
	future["package_id"] = "future"
	future["min_game_version"] = "2.0.0"
	_expect(Array(Dictionary(RegistryScript.new().register([future], {"gameVersion": "1.0.0"})).get("errors", [])).has("GAME_VERSION_UNSUPPORTED:future:2.0.0:1.0.0"), "minimum game versions fail closed")
	var conflicting := extension.duplicate(true)
	conflicting["conflicts"] = ["base"]
	_expect(Array(Dictionary(RegistryScript.new().register([base, conflicting])).get("errors", [])).has("PACKAGE_CONFLICT:extension:base"), "declared package conflicts fail closed")
	var soft_after := {
		"schema": "ysbzs.content-package.v1", "package_id": "soft_after", "version": "1.0.0", "priority": -200,
		"load_after": ["base"], "operations": [{"op": "set", "path": ["after"], "value": true}],
	}
	var soft_order := Array(Dictionary(RegistryScript.new().register([soft_after, base])).get("packages", []))
	_expect(soft_order.size() == 2 and String(Dictionary(soft_order[1]).get("package_id", "")) == "soft_after", "soft load_after ordering is deterministic without becoming a hard dependency")
	var cycle_a := base.duplicate(true)
	cycle_a["package_id"] = "cycle_a"
	cycle_a["dependencies"] = [{"id": "cycle_b"}]
	var cycle_b := base.duplicate(true)
	cycle_b["package_id"] = "cycle_b"
	cycle_b["dependencies"] = [{"id": "cycle_a"}]
	var cycle_result := Dictionary(RegistryScript.new().register([cycle_a, cycle_b]))
	_expect(Array(cycle_result.get("errors", [])).has("DEPENDENCY_CYCLE:cycle_a,cycle_b"), "dependency cycles fail closed deterministically")
	var unauthorized := extension.duplicate(true)
	unauthorized.erase("capabilities")
	_expect(not ValidatorScript.new().validate(unauthorized).is_empty(), "replace operations require the explicit content.override capability")
	var invalid_version := base.duplicate(true)
	invalid_version["version"] = "1.0.0-01"
	_expect(not ValidatorScript.new().validate(invalid_version).is_empty(), "package versions use strict semantic-version syntax")


func _verify_generated_domain_packages() -> void:
	var directory := DirAccess.open(GENERATED_ROOT)
	_expect(directory != null, "generated content root is readable")
	if directory == null:
		return
	var found_domains: Array[String] = []
	directory.list_dir_begin()
	var name := directory.get_next()
	while name != "":
		if name.begins_with("."):
			name = directory.get_next()
			continue
		var child := GENERATED_ROOT.path_join(name)
		_expect(not directory.current_is_dir(), "generated packages do not use line-count shard directories: %s" % child)
		if not directory.current_is_dir() and name.get_extension().to_lower() == "json":
			var package_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(child))
			_expect(package_value is Dictionary, "generated domain package is valid JSON: %s" % child)
			if package_value is Dictionary:
				var package := Dictionary(package_value)
				var operations := Array(package.get("operations", []))
				_expect(operations.size() == 1, "generated domain package owns one root operation: %s" % child)
				if operations.size() == 1:
					var operation := Dictionary(operations[0])
					var path := Array(operation.get("path", []))
					_expect(String(operation.get("op", "")) == "set" and path.size() == 1, "generated package sets one business domain: %s" % child)
					if path.size() == 1:
						found_domains.append(String(path[0]))
		name = directory.get_next()
	directory.list_dir_end()
	found_domains.sort()
	var expected := EXPECTED_DOMAINS.duplicate()
	expected.sort()
	_expect(found_domains == expected, "generated package ownership matches top-level business domains")


func _verify_run_event_operations_package(data: Dictionary) -> void:
	var package_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN_EVENT_EXTENSION_PATH))
	_expect(package_value is Dictionary, "run-event extension is valid JSON")
	if not package_value is Dictionary:
		return
	var package := Dictionary(package_value)
	_expect(String(package.get("schema", "")) == "ysbzs.content-package.v1", "run-event extension uses the content package schema")
	_expect(String(package.get("package_id", "")) == "extension.run_event_operations.v1", "run-event extension keeps its versioned package id")
	_expect(int(package.get("priority", -1)) == 100, "run-event extension keeps priority 100")
	var operations := Array(package.get("operations", []))
	_expect(operations.size() == 53, "run-event extension contains 1 schema set plus 52 independent attachments")
	var set_count := 0
	var append_count := 0
	var event_operation_count := 0
	var trigger_count := 0
	var event_targets: Array[String] = []
	var rest_targets: Array[String] = []
	for operation_index in range(operations.size()):
		var operation_value: Variant = operations[operation_index]
		if not operation_value is Dictionary:
			continue
		var operation := Dictionary(operation_value)
		var op := String(operation.get("op", ""))
		if op == "set":
			set_count += 1
			_expect(operation_index == 0, "run-event runtime schema is set before every attachment")
			_expect(Array(operation.get("path", [])) == ["economy", "runtime_schema_version"] and int(operation.get("value", 0)) == 1, "run-event schema set is the first-class economy version gate")
		elif op == "append_to":
			append_count += 1
			_expect(operation_index > 0, "run-event definitions append only after the schema gate")
		else:
			_expect(false, "run-event package contains no operation other than set/append_to")
		var field := String(operation.get("field", ""))
		if field == "event_operations":
			event_operation_count += 1
			var target := String(operation.get("match_value", ""))
			var path := Array(operation.get("path", []))
			if path == ["economy", "events"] and not event_targets.has(target):
				event_targets.append(target)
			elif path == ["route", "node_pool"] and not rest_targets.has(target):
				rest_targets.append(target)
		elif field == "event_triggers":
			trigger_count += 1
	_expect(set_count == 1 and append_count == 52, "run-event package keeps one set followed by append-only definitions")
	_expect(event_operation_count == 50 and trigger_count == 2, "run-event package declares 50 operations and 2 structured triggers")
	_expect(event_targets.size() == 16 and rest_targets.size() == 10, "run-event package covers the frozen 16 events and 10 rest nodes")

	var economy := Dictionary(data.get("economy", {}))
	_expect(int(economy.get("runtime_schema_version", 0)) == 1, "assembled economy exposes run-event runtime schema v1")
	var assembled_event_operations := 0
	var assembled_triggers := 0
	for event_value in Array(economy.get("events", [])):
		var event := Dictionary(event_value)
		assembled_event_operations += Array(event.get("event_operations", [])).size()
		assembled_triggers += Array(event.get("event_triggers", [])).size()
	_expect(assembled_event_operations == 30 and assembled_triggers == 2, "assembled economy owns the 30 event operations and 2 triggers")
	var assembled_rest_operations := 0
	for node_value in Array(Dictionary(data.get("route", {})).get("node_pool", [])):
		var node := Dictionary(node_value)
		if String(node.get("nodeType", "")) == "rest":
			assembled_rest_operations += Array(node.get("event_operations", [])).size()
	_expect(assembled_rest_operations == 20, "assembled route owns two operations for each frozen rest node")
	_expect(FileAccess.get_file_as_string(GENERATED_ROOT + "/006_economy.json").sha256_text() == EXPECTED_ECONOMY_SHA256, "generated economy package remains read-only")
	_expect(FileAccess.get_file_as_string(GENERATED_ROOT + "/013_route.json").sha256_text() == EXPECTED_ROUTE_SHA256, "generated route package remains read-only")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
