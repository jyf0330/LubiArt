extends RefCounted

## Immutable built-in developer fixtures. These definitions select canonical
## content objects; they never author gameplay stats or mutate authority state.

const CATALOG_SCHEMA := "ysbzs.developer-scenario-catalog.v1"
const SCENARIO_SCHEMA := "ysbzs.developer-scenario.v1"
const FIRST_BATTLE_ID := "debug_first_battle"
const FIRST_BATTLE_VERSION := "1.0.0"

const DEFAULT_PLAYER_REFS := [
	{"kind": "pet", "id": "pal_001"},
	{"kind": "pet", "id": "pal_002"},
	{"kind": "pet", "id": "pal_003"},
	{"kind": "pet", "id": "pal_004"},
]
const DEFAULT_ENEMY_REFS := [
	{"kind": "pet", "id": "pal_005"},
	{"kind": "pet", "id": "pal_006"},
	{"kind": "pet", "id": "pal_007"},
	{"kind": "pet", "id": "pal_008"},
]


func definition(scenario_id: String) -> Dictionary:
	if scenario_id != FIRST_BATTLE_ID:
		return {}
	return {
		"schema": SCENARIO_SCHEMA,
		"scenarioId": FIRST_BATTLE_ID,
		"version": FIRST_BATTLE_VERSION,
		"name": "Debug 第一场战斗",
		"kind": "battle",
		"teamSize": 4,
		"uniqueAcrossTeams": true,
		"allowedKinds": {"player": ["pet"], "enemy": ["pet"]},
		"board": {"width": 8, "height": 7},
		"battle": {
			"day": 1,
			"period": "上午",
			"encounter": {"id": FIRST_BATTLE_ID, "name": "Debug 第一场战斗", "kind": "debug"},
			"enemyAttackCount": 1,
		},
		"defaults": {
			"playerRefs": DEFAULT_PLAYER_REFS.duplicate(true),
			"enemyRefs": DEFAULT_ENEMY_REFS.duplicate(true),
		},
	}


func catalog(object_registry: RefCounted, content_manifest: Dictionary = {}) -> Dictionary:
	var object_catalog := Dictionary(object_registry.call("catalog")) if object_registry != null else {}
	var pet_rows := Array(Dictionary(object_catalog.get("objects", {})).get("pet", [])).duplicate(true)
	var scenario := definition(FIRST_BATTLE_ID)
	return {
		"schema": CATALOG_SCHEMA,
		"objectCatalog": object_catalog,
		"scenarios": [{
			"scenarioId": FIRST_BATTLE_ID,
			"version": FIRST_BATTLE_VERSION,
			"name": String(scenario.get("name", "")),
			"kind": String(scenario.get("kind", "")),
			"teamSize": int(scenario.get("teamSize", 0)),
			"defaults": Dictionary(scenario.get("defaults", {})).duplicate(true),
		}],
		"contentManifest": content_manifest.duplicate(true),
		# Compatibility projection consumed by the current debug setup panel.
		"teamSize": int(scenario.get("teamSize", 0)),
		"pets": pet_rows,
		"defaults": {
			"playerPetIds": _ids(DEFAULT_PLAYER_REFS),
			"enemyPetIds": _ids(DEFAULT_ENEMY_REFS),
		},
	}


func normalize_intent(action: Dictionary) -> Dictionary:
	var scenario_id := String(action.get("scenarioId", FIRST_BATTLE_ID)).strip_edges()
	var player_refs: Array = []
	var enemy_refs: Array = []
	if typeof(action.get("playerRefs")) == TYPE_ARRAY:
		player_refs = Array(action.get("playerRefs", [])).duplicate(true)
	elif typeof(action.get("playerPetIds")) == TYPE_ARRAY:
		player_refs = _pet_refs(Array(action.get("playerPetIds", [])))
	if typeof(action.get("enemyRefs")) == TYPE_ARRAY:
		enemy_refs = Array(action.get("enemyRefs", [])).duplicate(true)
	elif typeof(action.get("enemyPetIds")) == TYPE_ARRAY:
		enemy_refs = _pet_refs(Array(action.get("enemyPetIds", [])))
	return {
		"scenarioId": scenario_id,
		"seed": String(action.get("seed", "")),
		"playerRefs": player_refs,
		"enemyRefs": enemy_refs,
	}


func _pet_refs(ids: Array) -> Array:
	var refs: Array = []
	for id_value in ids:
		refs.append({"kind": "pet", "id": String(id_value)})
	return refs


func _ids(refs: Array) -> Array:
	var ids: Array = []
	for ref_value in refs:
		ids.append(String(Dictionary(ref_value).get("id", "")))
	return ids
