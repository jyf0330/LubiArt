extends RefCounted

const SCHEMA := "ysbzs_view_model"
const VERSION := 1

const REQUIRED_TYPES := {
	"phase": TYPE_STRING,
	"stateVersion": TYPE_INT,
	"stateHash": TYPE_STRING,
	"dayRoute": TYPE_DICTIONARY,
	"shop": TYPE_DICTIONARY,
	"inventory": TYPE_DICTIONARY,
	"leaders": TYPE_DICTIONARY,
	"heroes": TYPE_ARRAY,
	"enemies": TYPE_ARRAY,
	"units": TYPE_ARRAY,
	"board": TYPE_DICTIONARY,
	"selected": TYPE_DICTIONARY,
	"nextActions": TYPE_ARRAY,
	"battleResult": TYPE_DICTIONARY,
	"battleTrace": TYPE_ARRAY,
}


static func normalize(source: Dictionary) -> Dictionary:
	var model := source.duplicate(true)
	model["schema"] = SCHEMA
	model["schemaVersion"] = VERSION
	return model


static func validate(model: Dictionary) -> Dictionary:
	if String(model.get("schema", "")) != SCHEMA:
		return _error("VIEW_MODEL_SCHEMA_INVALID", "ViewModel schema identifier is missing or unsupported.")
	if int(model.get("schemaVersion", 0)) != VERSION:
		return _error("VIEW_MODEL_VERSION_UNSUPPORTED", "ViewModel schemaVersion is unsupported.")
	for key in REQUIRED_TYPES:
		if not model.has(key):
			return _error("VIEW_MODEL_FIELD_REQUIRED", "ViewModel is missing required field: %s." % key, key)
		var expected_type := int(REQUIRED_TYPES[key])
		if typeof(model.get(key)) != expected_type:
			return _error("VIEW_MODEL_FIELD_TYPE_INVALID", "ViewModel field has an invalid type: %s." % key, key)
	return {}


static func _error(code: String, message: String, field: String = "") -> Dictionary:
	var result := {"code": code, "message": message}
	if field != "":
		result["field"] = field
	return result
