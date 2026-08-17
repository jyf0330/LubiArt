extends RefCounted

## Pure JSON document helpers for authoritative state, save, and replay data.
## File I/O and game-state validation stay outside this module.


static func build_save_document(
		schema: String,
		schema_version: int,
		state_payload: Dictionary,
		player_id: String,
		meta: Dictionary,
		summary: Dictionary
	) -> Dictionary:
	var payload := {
		"schema": schema,
		"schemaVersion": schema_version,
		"createdAt": meta.get("createdAt", null),
		"gameVersion": String(meta.get("gameVersion", "godot-singleplayer")),
		"playerId": player_id,
		"sessionId": meta.get("sessionId", null),
		"state": state_payload,
		"viewStates": Dictionary(meta.get("viewStates", {})).duplicate(true),
		"summary": summary,
		"summaryText": String(summary.get("text", ""))
	}
	payload["checksum"] = save_checksum(payload)
	return payload


static func replay_checksum(doc: Dictionary) -> String:
	var payload := doc.duplicate(true)
	payload.erase("checksum")
	return checksum(payload)


static func save_checksum(doc: Dictionary) -> String:
	var payload := doc.duplicate(true)
	payload.erase("checksum")
	return checksum(payload)


static func checksum(value: Variant) -> String:
	var text := stable_json(value)
	var hash := 2166136261
	for index in range(text.length()):
		hash = _u32(hash ^ text.unicode_at(index))
		hash = _u32(hash * 16777619)
	return "%08x" % hash


static func stable_json(value: Variant) -> String:
	if typeof(value) == TYPE_ARRAY:
		var out: Array = []
		for item in Array(value):
			out.append(stable_json(item))
		return "[%s]" % ",".join(out)
	if typeof(value) == TYPE_DICTIONARY:
		var keys: Array = Dictionary(value).keys()
		keys.sort()
		var parts: Array = []
		for key in keys:
			parts.append("%s:%s" % [JSON.stringify(String(key)), stable_json(Dictionary(value).get(key))])
		return "{%s}" % ",".join(parts)
	if typeof(value) == TYPE_FLOAT:
		var number: float = float(value)
		var rounded: float = round(number)
		if is_equal_approx(number, rounded):
			return str(int(rounded))
	return JSON.stringify(value)


static func _u32(value: int) -> int:
	return value & 0xffffffff
