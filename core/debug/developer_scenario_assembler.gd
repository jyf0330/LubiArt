extends RefCounted

## Pure Fixture -> authoritative setup assembler. It resolves typed object
## references through the content registry and returns one all-or-nothing plan.

const SaveCodecScript := preload("res://persistence/save_codec.gd")
const SCENARIO_SCHEMA := "ysbzs.developer-scenario.v1"
const SETUP_SCHEMA := "ysbzs.developer-scenario-setup.v1"
const PROVENANCE_SCHEMA := "ysbzs.scenario-provenance.v1"


func prepare(
	object_registry: RefCounted,
	definition: Dictionary,
	intent: Dictionary,
	content_manifest: Dictionary = {}
) -> Dictionary:
	if object_registry == null or not bool(object_registry.call("is_configured")):
		return _error("SCENARIO_OBJECT_REGISTRY_UNAVAILABLE", "Developer object registry is unavailable.")
	if String(definition.get("schema", "")) != SCENARIO_SCHEMA or String(definition.get("scenarioId", "")) == "":
		return _error("SCENARIO_DEFINITION_INVALID", "Developer scenario definition is invalid.")
	if String(definition.get("kind", "")) != "battle":
		return _error("SCENARIO_KIND_UNSUPPORTED", "Only battle developer scenarios are currently supported.")
	var seed := String(intent.get("seed", "")).strip_edges()
	if seed == "":
		return _error("SCENARIO_SEED_REQUIRED", "Developer scenario seed is required.")
	var team_size := int(definition.get("teamSize", 0))
	var player_result := _resolve_team(object_registry, definition, Array(intent.get("playerRefs", [])), "player", team_size)
	if not bool(player_result.get("ok", false)):
		return player_result
	var enemy_result := _resolve_team(object_registry, definition, Array(intent.get("enemyRefs", [])), "enemy", team_size)
	if not bool(enemy_result.get("ok", false)):
		return enemy_result
	var player_refs := Array(player_result.get("refs", []))
	var enemy_refs := Array(enemy_result.get("refs", []))
	if bool(definition.get("uniqueAcrossTeams", false)):
		var keys: Array[String] = []
		for ref_value in player_refs + enemy_refs:
			var ref := Dictionary(ref_value)
			var key := "%s:%s" % [String(ref.get("kind", "")), String(ref.get("id", ""))]
			if keys.has(key):
				return _error("SCENARIO_OBJECT_REF_DUPLICATE", "Each selected object must be unique across both teams: %s." % key)
			keys.append(key)
	var scenario_id := String(definition.get("scenarioId", ""))
	var player_templates: Array = []
	var enemy_templates: Array = []
	for index in range(team_size):
		var player_template := Dictionary(object_registry.call("battle_template", Dictionary(player_refs[index])))
		player_template["id"] = String(Dictionary(player_refs[index]).get("id", ""))
		player_template["pet_id"] = String(Dictionary(player_refs[index]).get("id", ""))
		player_template["active"] = true
		player_template["slot"] = index + 1
		player_template["bag_slot"] = 0
		player_templates.append(player_template)

		var enemy_ref := Dictionary(enemy_refs[index])
		var enemy_template := Dictionary(object_registry.call("battle_template", enemy_ref))
		enemy_template["id"] = "scenario:%s:enemy:%02d:%s" % [scenario_id, index + 1, String(enemy_ref.get("id", ""))]
		enemy_template["pet_id"] = String(enemy_ref.get("id", ""))
		enemy_template["source_pet_id"] = String(enemy_ref.get("id", ""))
		enemy_template["move_range"] = max(0, int(enemy_template.get("ap", 0)))
		enemy_template["attack_count"] = max(1, int(Dictionary(definition.get("battle", {})).get("enemyAttackCount", 1)))
		enemy_templates.append(enemy_template)
	var board := Dictionary(definition.get("board", {}))
	if int(board.get("width", 0)) < 1 or int(board.get("height", 0)) < 1:
		return _error("SCENARIO_BOARD_INVALID", "Developer scenario board dimensions must be positive.")
	var battle := Dictionary(definition.get("battle", {}))
	var setup_core := {
		"schema": SETUP_SCHEMA,
		"scenarioId": scenario_id,
		"scenarioVersion": String(definition.get("version", "")),
		"seed": seed,
		"playerRefs": player_refs.duplicate(true),
		"enemyRefs": enemy_refs.duplicate(true),
		"board": board.duplicate(true),
		"battle": battle.duplicate(true),
		"playerTemplates": player_templates,
		"enemyTemplates": enemy_templates,
	}
	var provenance := {
		"schema": PROVENANCE_SCHEMA,
		"scenarioId": scenario_id,
		"scenarioVersion": String(definition.get("version", "")),
		"seed": seed,
		"objectRefs": {"player": player_refs.duplicate(true), "enemy": enemy_refs.duplicate(true)},
		"contentManifest": content_manifest.duplicate(true),
		"setupHash": _hash(setup_core),
	}
	var result := setup_core.duplicate(true)
	result["ok"] = true
	result["provenance"] = provenance
	result["playerPetIds"] = _ids(player_refs)
	result["enemyPetIds"] = _ids(enemy_refs)
	return result


func _resolve_team(object_registry: RefCounted, definition: Dictionary, refs: Array, side: String, team_size: int) -> Dictionary:
	if refs.size() != team_size:
		return _error("SCENARIO_TEAM_SIZE_INVALID", "%s team must contain exactly %d object references." % [side, team_size])
	var allowed := Array(Dictionary(definition.get("allowedKinds", {})).get(side, []))
	var normalized: Array = []
	var seen: Array[String] = []
	for ref_value in refs:
		if typeof(ref_value) != TYPE_DICTIONARY:
			return _error("SCENARIO_OBJECT_REF_INVALID", "%s team contains a non-object reference." % side)
		var ref := Dictionary(ref_value)
		var kind := String(ref.get("kind", "")).strip_edges()
		var object_id := String(ref.get("id", "")).strip_edges()
		if kind == "" or object_id == "" or not allowed.has(kind):
			return _error("SCENARIO_OBJECT_REF_INVALID", "%s reference kind/id is invalid: %s:%s." % [side, kind, object_id])
		var key := "%s:%s" % [kind, object_id]
		if seen.has(key):
			return _error("SCENARIO_OBJECT_REF_DUPLICATE", "%s team contains duplicate object: %s." % [side, key])
		if Dictionary(object_registry.call("resolve", {"kind": kind, "id": object_id})).is_empty():
			return _error("SCENARIO_OBJECT_REF_UNKNOWN", "Unknown %s object reference: %s." % [side, key])
		if Dictionary(object_registry.call("battle_template", {"kind": kind, "id": object_id})).is_empty():
			return _error("SCENARIO_OBJECT_NOT_BATTLE_CAPABLE", "%s object cannot enter battle: %s." % [side, key])
		seen.append(key)
		normalized.append({"kind": kind, "id": object_id})
	return {"ok": true, "refs": normalized}


func _hash(value: Variant) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return SaveCodecScript.checksum(value)
	context.update(SaveCodecScript.stable_json(value).to_utf8_buffer())
	return context.finish().hex_encode()


func _ids(refs: Array) -> Array:
	var ids: Array = []
	for ref_value in refs:
		ids.append(String(Dictionary(ref_value).get("id", "")))
	return ids


func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}
