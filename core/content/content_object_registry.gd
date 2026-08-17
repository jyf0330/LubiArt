extends RefCounted

## Per-authority immutable object index. Callers resolve typed IDs and never need
## to know which legacy content table currently supplies a definition.

const SCHEMA := "ysbzs.object-catalog.v1"
const ENABLED_STATUS := "启用"
const KINDS := ["pet", "skill", "trait", "status", "relic", "encounter"]
const PET_BATTLE_FIELDS := [
	"id", "pet_id", "name", "element", "element_types", "secondary_elements",
	"quality", "role", "tags", "max_hp", "atk", "def", "shield", "ap",
	"base_stats", "skill", "skills", "traits", "shape", "range", "effect_score",
	"shape_id", "shape_name", "shape_class", "hit_cells", "slot_count",
	"slot_elements", "base_layers", "action_type", "mechanism_id", "status",
]
const PET_BASE_STAT_FIELDS := {
	"max_hp": "max_hp",
	"atk": "atk",
	"def": "def",
	"starting_shield": "shield",
	"action_points": "ap",
}

var _indexes: Dictionary = {}
var _source_kind: StringName = &""
var _configured := false
var _pending: Dictionary = {}


func prepare_configuration(content: Dictionary, source_kind: StringName) -> Dictionary:
	_pending.clear()
	var built := _build_indexes(content)
	if not bool(built.get("ok", false)):
		return built
	var token := RefCounted.new()
	_pending[token.get_instance_id()] = {
		"token": token,
		"indexes": Dictionary(built.get("indexes", {})).duplicate(true),
		"source_kind": source_kind,
	}
	return {"ok": true, "candidate": {"token": token}, "errors": []}


func commit_configuration(candidate: Dictionary) -> bool:
	var token_value: Variant = candidate.get("token")
	if not token_value is RefCounted:
		return false
	var token := token_value as RefCounted
	var token_id := token.get_instance_id()
	var pending_value: Variant = _pending.get(token_id)
	if not pending_value is Dictionary or Dictionary(pending_value).get("token") != token:
		return false
	var pending := Dictionary(pending_value)
	_pending.erase(token_id)
	_indexes = Dictionary(pending.get("indexes", {})).duplicate(true)
	_source_kind = StringName(pending.get("source_kind", &""))
	_configured = true
	return true


func _is_configuration_candidate_pending(candidate: Dictionary) -> bool:
	var token_value: Variant = candidate.get("token")
	if not token_value is RefCounted:
		return false
	var token := token_value as RefCounted
	return _pending.has(token.get_instance_id()) and Dictionary(_pending[token.get_instance_id()]).get("token") == token


func is_configured() -> bool:
	return _configured


func source_kind() -> StringName:
	return _source_kind


func kinds() -> Array[String]:
	return KINDS.duplicate()


func has_object(kind: String, object_id: String) -> bool:
	return Dictionary(_indexes.get(kind, {})).has(object_id)


func resolve(reference: Dictionary) -> Dictionary:
	var kind := String(reference.get("kind", "")).strip_edges()
	var object_id := String(reference.get("id", "")).strip_edges()
	if not KINDS.has(kind) or object_id == "":
		return {}
	return Dictionary(Dictionary(_indexes.get(kind, {})).get(object_id, {})).duplicate(true)


func definition(kind: String, object_id: String) -> Dictionary:
	return resolve({"kind": kind, "id": object_id})


func battle_template(reference: Dictionary) -> Dictionary:
	var object := resolve(reference)
	return Dictionary(object.get("battleTemplate", {})).duplicate(true)


func catalog(kind: String = "") -> Dictionary:
	var selected_kinds: Array = KINDS if kind == "" else [kind]
	var catalogs := {}
	for kind_value in selected_kinds:
		var kind_id := String(kind_value)
		if not KINDS.has(kind_id):
			continue
		var rows: Array = []
		var index := Dictionary(_indexes.get(kind_id, {}))
		var ids: Array = index.keys()
		ids.sort()
		for object_id_value in ids:
			var object := Dictionary(index[object_id_value])
			rows.append(Dictionary(object.get("catalog", {
				"kind": kind_id,
				"id": String(object_id_value),
				"name": String(object.get("name", object_id_value)),
			})).duplicate(true))
		catalogs[kind_id] = rows
	return {"schema": SCHEMA, "sourceKind": String(_source_kind), "objects": catalogs}


func _build_indexes(content: Dictionary) -> Dictionary:
	var indexes := {}
	for kind in KINDS:
		indexes[kind] = {}
	var errors: Array[String] = []
	_index_pets(content, Dictionary(indexes["pet"]), errors)
	_index_dictionary_catalog(content, "skill", "skill_catalog", Dictionary(indexes["skill"]), errors)
	_index_dictionary_catalog(content, "trait", "trait_catalog", Dictionary(indexes["trait"]), errors)
	_index_dictionary_catalog(content, "status", "status_catalog", Dictionary(indexes["status"]), errors)
	_index_relics(content, Dictionary(indexes["relic"]), errors)
	_index_encounters(content, Dictionary(indexes["encounter"]), errors)
	_validate_pet_references(Dictionary(indexes["pet"]), Dictionary(indexes["skill"]), Dictionary(indexes["trait"]), errors)
	errors.sort()
	return {"ok": errors.is_empty(), "candidate": {}, "indexes": indexes if errors.is_empty() else {}, "errors": errors}


func _index_pets(content: Dictionary, output: Dictionary, errors: Array[String]) -> void:
	for row_value in Array(Dictionary(content.get("economy", {})).get("shop_items", [])):
		if not row_value is Dictionary:
			continue
		var row := Dictionary(row_value)
		var object_id := String(row.get("pet_id", row.get("id", ""))).strip_edges()
		if object_id == "" or String(row.get("status", "")) != ENABLED_STATUS:
			continue
		if output.has(object_id):
			errors.append("OBJECT_ID_DUPLICATE:pet:%s" % object_id)
			continue
		var base_stats_value: Variant = row.get("base_stats")
		if not base_stats_value is Dictionary:
			errors.append("PET_BASE_STATS_MISSING:%s" % object_id)
			continue
		var base_stats := Dictionary(base_stats_value)
		var stats_valid := true
		for stat_key in PET_BASE_STAT_FIELDS:
			var top_level_key := String(PET_BASE_STAT_FIELDS[stat_key])
			if not base_stats.has(stat_key) or not row.has(top_level_key):
				errors.append("PET_BASE_STATS_FIELD_MISSING:%s:%s" % [object_id, stat_key])
				stats_valid = false
				continue
			var base_value: Variant = base_stats[stat_key]
			var top_level_value: Variant = row[top_level_key]
			if typeof(base_value) not in [TYPE_INT, TYPE_FLOAT] or typeof(top_level_value) not in [TYPE_INT, TYPE_FLOAT]:
				errors.append("PET_BASE_STATS_FIELD_INVALID:%s:%s" % [object_id, stat_key])
				stats_valid = false
				continue
			if int(base_value) != int(top_level_value):
				errors.append("PET_BASE_STATS_FIELD_MISMATCH:%s:%s" % [object_id, stat_key])
				stats_valid = false
		if not stats_valid:
			continue
		var battle_template := {}
		for field in PET_BATTLE_FIELDS:
			if row.has(field):
				battle_template[field] = _copy(row[field])
		battle_template["id"] = object_id
		battle_template["pet_id"] = object_id
		output[object_id] = {
			"kind": "pet",
			"id": object_id,
			"name": String(row.get("name", object_id)),
			"sourceAdapter": "legacy.economy.shop_items",
			"battleTemplate": battle_template,
			"catalog": {
				"kind": "pet", "id": object_id, "petId": object_id,
				"name": String(row.get("name", object_id)),
				"element": String(row.get("element", "")),
				"quality": String(row.get("quality", "")),
				"role": String(row.get("role", "")),
				"maxHp": int(base_stats["max_hp"]),
				"atk": int(base_stats["atk"]),
				"def": int(base_stats["def"]),
				"shield": int(base_stats["starting_shield"]),
				"ap": int(base_stats["action_points"]),
				"skills": Array(row.get("skills", [])).duplicate(),
			},
		}


func _index_dictionary_catalog(content: Dictionary, kind: String, key: String, output: Dictionary, errors: Array[String]) -> void:
	var raw: Variant = content.get(key, {})
	if not raw is Dictionary:
		return
	for object_id_value in Dictionary(raw).keys():
		var object_id := String(object_id_value).strip_edges()
		if object_id == "" or not Dictionary(raw)[object_id_value] is Dictionary:
			continue
		if output.has(object_id):
			errors.append("OBJECT_ID_DUPLICATE:%s:%s" % [kind, object_id])
			continue
		var definition := Dictionary(Dictionary(raw)[object_id_value]).duplicate(true)
		definition["id"] = String(definition.get("id", object_id))
		output[object_id] = {
			"kind": kind,
			"id": object_id,
			"name": String(definition.get("name", object_id)),
			"definition": definition,
			"catalog": {"kind": kind, "id": object_id, "name": String(definition.get("name", object_id))},
		}


func _index_relics(content: Dictionary, output: Dictionary, errors: Array[String]) -> void:
	var raw: Variant = Dictionary(content.get("economy", {})).get("relics", [])
	var rows: Array = []
	if raw is Dictionary:
		for object_id_value in Dictionary(raw).keys():
			var row := Dictionary(Dictionary(raw)[object_id_value]).duplicate(true)
			row["id"] = String(row.get("id", row.get("relic_id", object_id_value)))
			rows.append(row)
	elif raw is Array:
		rows = Array(raw)
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row := Dictionary(row_value).duplicate(true)
		var object_id := String(row.get("id", row.get("relic_id", ""))).strip_edges()
		if object_id == "":
			continue
		if output.has(object_id):
			errors.append("OBJECT_ID_DUPLICATE:relic:%s" % object_id)
			continue
		output[object_id] = {
			"kind": "relic", "id": object_id, "name": String(row.get("name", row.get("relic_name", object_id))),
			"definition": row,
			"catalog": {"kind": "relic", "id": object_id, "name": String(row.get("name", row.get("relic_name", object_id)))},
		}


func _index_encounters(content: Dictionary, output: Dictionary, errors: Array[String]) -> void:
	for row_value in Array(Dictionary(content.get("route", {})).get("encounter_pool", [])):
		if not row_value is Dictionary:
			continue
		var row := Dictionary(row_value).duplicate(true)
		var object_id := String(row.get("encounterId", row.get("encounter_id", row.get("id", "")))).strip_edges()
		if object_id == "":
			continue
		if output.has(object_id):
			errors.append("OBJECT_ID_DUPLICATE:encounter:%s" % object_id)
			continue
		output[object_id] = {
			"kind": "encounter", "id": object_id, "name": String(row.get("name", object_id)),
			"definition": row,
			"catalog": {"kind": "encounter", "id": object_id, "name": String(row.get("name", object_id))},
		}


func _validate_pet_references(pets: Dictionary, skills: Dictionary, traits: Dictionary, errors: Array[String]) -> void:
	for pet_id_value in pets.keys():
		var template := Dictionary(Dictionary(pets[pet_id_value]).get("battleTemplate", {}))
		for skill_id_value in Array(template.get("skills", [])):
			var skill_id := String(skill_id_value)
			if skill_id != "" and not skills.has(skill_id):
				errors.append("OBJECT_REFERENCE_UNKNOWN:pet:%s:skill:%s" % [pet_id_value, skill_id])
		for trait_id_value in Array(template.get("traits", [])):
			var trait_id := String(trait_id_value)
			if trait_id != "" and not traits.has(trait_id):
				errors.append("OBJECT_REFERENCE_UNKNOWN:pet:%s:trait:%s" % [pet_id_value, trait_id])


func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
