extends SceneTree

const SessionFactoryScript := preload("res://session/session_factory.gd")

const PLAYER_IDS := ["pal_001", "pal_002", "pal_003", "pal_004"]
const ENEMY_IDS := ["pal_005", "pal_006", "pal_007", "pal_008"]
const MASTER_FIRST_EIGHT := {
	"pal_001": {"name": "棉角羊", "element": "水", "quality": "青铜", "role": "治疗", "maxHp": 28, "atk": 8, "shield": 2, "ap": 3},
	"pal_002": {"name": "灰尾狸", "element": "水", "quality": "黄金", "role": "治疗", "maxHp": 58, "atk": 18, "shield": 6, "ap": 3},
	"pal_003": {"name": "芦花鸡", "element": "雷", "quality": "白银", "role": "机动", "maxHp": 40, "atk": 12, "shield": 0, "ap": 5},
	"pal_004": {"name": "青藤鼠", "element": "雷", "quality": "白银", "role": "机动", "maxHp": 40, "atk": 12, "shield": 0, "ap": 5},
	"pal_005": {"name": "赤尾狐", "element": "雷", "quality": "黄金", "role": "输出", "maxHp": 58, "atk": 26, "shield": 0, "ap": 2},
	"pal_006": {"name": "碧水鸭", "element": "地", "quality": "青铜", "role": "坦克", "maxHp": 42, "atk": 6, "shield": 6, "ap": 3},
	"pal_007": {"name": "雷须猫", "element": "地", "quality": "青铜", "role": "输出", "maxHp": 22, "atk": 14, "shield": 0, "ap": 3},
	"pal_008": {"name": "藤甲猿", "element": "水", "quality": "青铜", "role": "机动", "maxHp": 28, "atk": 6, "shield": 0, "ap": 5},
}
const DEBUG_SEED := "smoke-debug-first-battle-eight-pets"

var failed := false


func _initialize() -> void:
	_test_developer_catalog_and_start()
	_test_scope_and_atomic_rejection()
	if failed:
		quit(1)
		return
	print("SMOKE_DEBUG_FIRST_BATTLE_SETUP_OK")
	quit(0)


func _test_developer_catalog_and_start() -> void:
	var creation := Dictionary(SessionFactoryScript.create_isolated_developer_result({"run_seed": DEBUG_SEED}))
	_expect(bool(creation.get("ok", false)), "isolated developer Scenario Session initializes")
	var session := creation.get("session") as RefCounted
	if session == null:
		return
	_expect(not bool(session.call("supports_persistence")), "isolated Scenario Session cannot advertise persistence")
	_expect(not bool(session.call("supports_run_history")), "isolated Scenario Session cannot advertise run history")
	_expect(not bool(session.call("save_to_slot", 1)) and not bool(session.call("export_replay")), "isolated Scenario Session rejects direct persistence calls")
	_expect(Array(session.call("run_history_runs")).is_empty() and Dictionary(session.call("run_history_checkpoint_for_day", "missing", 1)).is_empty(), "isolated Scenario Session rejects direct history reads")
	var catalog_response := Dictionary(session.call("submit_command", {"type": "GET_DEVELOPER_OBJECT_CATALOG"}))
	_expect(bool(catalog_response.get("accepted", false)), "developer query reads the authoritative typed object catalog")
	var catalog := Dictionary(catalog_response.get("result", {}))
	_expect(String(catalog.get("schema", "")) == "ysbzs.developer-scenario-catalog.v1", "Scenario catalog exposes a stable schema")
	_expect(Array(catalog.get("pets", [])).size() == 369, "catalog projects all enabled current content pets")
	_expect(Array(Dictionary(Dictionary(catalog.get("objectCatalog", {})).get("objects", {})).get("pet", [])).size() == 369, "typed object catalog exposes pets without a debug-only data table")
	_expect(Array(catalog.get("scenarios", [])).size() == 1, "catalog exposes the built-in first-battle Scenario")
	_expect(Array(Dictionary(catalog.get("defaults", {})).get("playerPetIds", [])) == PLAYER_IDS, "catalog owns the recommended player ids")
	_expect(Array(Dictionary(catalog.get("defaults", {})).get("enemyPetIds", [])) == ENEMY_IDS, "catalog owns the recommended enemy ids")
	_assert_master_first_eight(Array(catalog.get("pets", [])))

	var start_response := Dictionary(session.call("submit_command", {
		"type": "START_DEVELOPER_SCENARIO",
		"scenarioId": "debug_first_battle",
		"seed": DEBUG_SEED,
		"playerRefs": _pet_refs(PLAYER_IDS),
		"enemyRefs": _pet_refs(ENEMY_IDS),
	}))
	_expect(bool(start_response.get("accepted", false)), "generic developer Scenario command starts the configured first battle")
	var result := Dictionary(start_response.get("result", {}))
	_expect(String(result.get("schema", "")) == "ysbzs.developer-scenario-setup.v1", "start result reports the generic resolved setup schema")
	_expect(Array(result.get("playerPetIds", [])) == PLAYER_IDS and Array(result.get("enemyPetIds", [])) == ENEMY_IDS, "result echoes canonical ids instead of UI-authored stats")
	var provenance := Dictionary(result.get("provenance", {}))
	_expect(String(provenance.get("scenarioId", "")) == "debug_first_battle" and String(provenance.get("setupHash", "")).length() == 64, "result pins Scenario identity and resolved setup hash")
	var snapshot := Dictionary(session.call("current_snapshot"))
	_expect(String(snapshot.get("phase", "")) == "battle", "configured command enters the formal battle phase")
	_expect(String(snapshot.get("run_seed", "")) == DEBUG_SEED, "configured seed reaches authoritative battle state")
	var player_units: Array = []
	var enemy_units: Array = []
	for unit_value in Array(snapshot.get("units", [])):
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == "player":
			player_units.append(unit)
		elif String(unit.get("side", "")) == "enemy":
			enemy_units.append(unit)
	_expect(player_units.size() == 4 and enemy_units.size() == 4, "formal Snapshot contains exactly four player and four enemy pets")
	_expect(_pet_ids(player_units) == PLAYER_IDS, "player Snapshot units keep the four selected canonical pet ids")
	_expect(_pet_ids(enemy_units) == ENEMY_IDS, "enemy Snapshot units keep the four selected canonical pet ids")
	_expect(_unit_stat(player_units, "pal_001", "max_hp") == 28, "player pal_001 health comes from the first master-table row")
	_expect(_unit_stat(player_units, "pal_002", "max_hp") >= 58, "player pal_002 starts from current master-table content before the existing quality progression")
	_expect(_unit_stat(enemy_units, "pal_005", "atk") >= 26, "enemy pal_005 attack starts from the fifth master-table row")
	_expect(_unit_stat(enemy_units, "pal_006", "atk") == 6, "enemy pal_006 attack comes from current content")
	_expect(_unit_stat(enemy_units, "pal_006", "move_range") == 3, "enemy movement comes from selected pet AP")
	_expect(Dictionary(snapshot.get("scenario", {})) == provenance, "Snapshot exposes the authoritative Scenario provenance")
	var authority := session.call("get_authority") as RefCounted
	var replay := Dictionary(authority.call("replay_document"))
	_expect(Dictionary(replay.get("scenario", {})) == provenance, "Replay pins the same Scenario provenance")
	var replay_verification := Dictionary(authority.call("verify_replay_document", replay))
	_expect(bool(replay_verification.get("ok", false)), "Scenario command stream replays deterministically on a fresh isolated authority")
	var save_doc := Dictionary(authority.call("save_document"))
	_expect(Dictionary(Dictionary(save_doc.get("state", {})).get("scenario_provenance", {})) == provenance, "Save/checkpoint state pins the same Scenario provenance")
	var restore_creation := Dictionary(SessionFactoryScript.create_isolated_developer_result({"run_seed": "restore-target"}))
	var restore_session := restore_creation.get("session") as RefCounted
	if restore_session != null:
		var restore_authority := restore_session.call("get_authority") as RefCounted
		_expect(bool(restore_authority.call("load_document", save_doc)), "Scenario save document restores on a fresh isolated authority")
		_expect(Dictionary(Dictionary(restore_session.call("current_snapshot")).get("scenario", {})) == provenance, "restored Snapshot retains Scenario provenance")
		_expect(Array((restore_creation.get("ioGuard") as RefCounted).call("attempts")).is_empty(), "Scenario restore performs zero external I/O")
	var guard := creation.get("ioGuard") as RefCounted
	_expect(guard != null and Array(guard.call("attempts")).is_empty(), "catalog, Scenario start, Snapshot, replay build, and save build perform zero external I/O")


func _test_scope_and_atomic_rejection() -> void:
	var player_session := _session("player")
	if player_session != null:
		var player_query := Dictionary(player_session.call("submit_command", {"type": "GET_DEVELOPER_OBJECT_CATALOG"}))
		_expect(String(Dictionary(player_query.get("error", {})).get("code", "")) == "COMMAND_SCOPE_FORBIDDEN", "player UI cannot query developer content tooling")
		var player_start := Dictionary(player_session.call("submit_command", {
			"type": "START_DEVELOPER_SCENARIO",
			"scenarioId": "debug_first_battle",
			"seed": DEBUG_SEED,
			"playerRefs": _pet_refs(PLAYER_IDS),
			"enemyRefs": _pet_refs(ENEMY_IDS),
		}))
		_expect(String(Dictionary(player_start.get("error", {})).get("code", "")) == "COMMAND_SCOPE_FORBIDDEN", "player UI cannot start a debug battle")

	var generic_session := _session("developer")
	if generic_session != null:
		var generic_before := Dictionary(generic_session.call("current_snapshot"))
		var generic_rejected := Dictionary(generic_session.call("submit_command", {
			"type": "START_DEVELOPER_SCENARIO",
			"scenarioId": "debug_first_battle",
			"seed": DEBUG_SEED,
			"playerRefs": _pet_refs(["pal_001", "pal_002", "pal_003", "pal_missing"]),
			"enemyRefs": _pet_refs(ENEMY_IDS),
		}))
		var generic_after := Dictionary(generic_session.call("current_snapshot"))
		_expect(not bool(generic_rejected.get("accepted", true)), "generic Scenario rejects an unknown typed object reference")
		_expect(String(generic_after.get("stateHash", "")) == String(generic_before.get("stateHash", "missing")), "generic Scenario rejection is atomic")

	var compatibility_session := _session("developer")
	if compatibility_session != null:
		var compatibility_response := Dictionary(compatibility_session.call("submit_command", {
			"type": "START_DEBUG_FIRST_BATTLE", "seed": DEBUG_SEED,
			"playerPetIds": PLAYER_IDS, "enemyPetIds": ENEMY_IDS,
		}))
		_expect(bool(compatibility_response.get("accepted", false)), "legacy first-battle Command remains a supported compatibility adapter")
		_expect(String(Dictionary(compatibility_response.get("result", {})).get("schema", "")) == "ysbzs.debug-first-battle-setup.v1", "legacy Command retains its result schema")

	for invalid_player_ids in [
		["pal_001", "pal_002", "pal_003"],
		["pal_001", "pal_001", "pal_003", "pal_004"],
		["pal_001", "pal_002", "pal_003", "pal_missing"],
	]:
		var developer_session := _session("developer")
		if developer_session == null:
			continue
		var before := Dictionary(developer_session.call("current_snapshot"))
		var rejected := Dictionary(developer_session.call("submit_command", {
			"type": "START_DEBUG_FIRST_BATTLE",
			"seed": DEBUG_SEED,
			"playerPetIds": invalid_player_ids,
			"enemyPetIds": ENEMY_IDS,
		}))
		var after := Dictionary(developer_session.call("current_snapshot"))
		_expect(not bool(rejected.get("accepted", true)), "invalid debug team rejects")
		_expect(int(after.get("stateVersion", -1)) == int(before.get("stateVersion", -2)), "invalid debug team preserves authoritative version")
		_expect(String(after.get("stateHash", "")) == String(before.get("stateHash", "missing")), "invalid debug team rolls back all authoritative writes")

	var typed_session := _session("developer")
	if typed_session != null:
		var type_before := Dictionary(typed_session.call("current_snapshot"))
		var type_rejected := Dictionary(typed_session.call("submit_command", {
			"type": "START_DEBUG_FIRST_BATTLE",
			"seed": DEBUG_SEED,
			"playerPetIds": "pal_001",
			"enemyPetIds": ENEMY_IDS,
		}))
		var type_after := Dictionary(typed_session.call("current_snapshot"))
		_expect(String(Dictionary(type_rejected.get("error", {})).get("code", "")) == "COMMAND_FIELD_TYPE_INVALID", "Session rejects malformed debug team types before authority dispatch")
		_expect(String(type_after.get("stateHash", "")) == String(type_before.get("stateHash", "missing")), "malformed debug team types perform zero authoritative writes")


func _session(scope: String) -> RefCounted:
	var creation := Dictionary(SessionFactoryScript.create_local_result({"command_scope": scope}))
	_expect(bool(creation.get("ok", false)), "%s Session initializes" % scope)
	return creation.get("session") as RefCounted


func _pet_refs(ids: Array) -> Array:
	var refs: Array = []
	for id_value in ids:
		refs.append({"kind": "pet", "id": String(id_value)})
	return refs


func _pet_ids(units: Array) -> Array:
	var ids: Array = []
	for unit_value in units:
		var unit := Dictionary(unit_value)
		ids.append(String(unit.get("pet_id", unit.get("source_pet_id", ""))))
	return ids


func _unit_stat(units: Array, pet_id: String, field: String) -> int:
	for unit_value in units:
		var unit := Dictionary(unit_value)
		if String(unit.get("pet_id", unit.get("source_pet_id", ""))) == pet_id:
			return int(unit.get(field, -1))
	return -1


func _assert_master_first_eight(catalog_pets: Array) -> void:
	var by_id := {}
	for pet_value in catalog_pets:
		if pet_value is Dictionary:
			var pet := Dictionary(pet_value)
			by_id[String(pet.get("id", ""))] = pet
	for pet_id_value in MASTER_FIRST_EIGHT.keys():
		var pet_id := String(pet_id_value)
		var actual := Dictionary(by_id.get(pet_id, {}))
		var expected := Dictionary(MASTER_FIRST_EIGHT[pet_id])
		_expect(not actual.is_empty(), "master-table pet %s is present in the developer catalog" % pet_id)
		for field in expected.keys():
			_expect(actual.get(field) == expected[field], "%s.%s matches the master table" % [pet_id, field])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
