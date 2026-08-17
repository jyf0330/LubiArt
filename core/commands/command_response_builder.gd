extends RefCounted

## Pure response-envelope projection for local and remote GameSession adapters.


func build(context: Dictionary) -> Dictionary:
	var accepted := bool(context.get("accepted", false))
	var before_version := int(context.get("beforeVersion", 0))
	var before_hash := String(context.get("beforeHash", ""))
	var snapshot := Dictionary(context.get("snapshot", {}))
	var response := {
		"ok": accepted,
		"accepted": accepted,
		"command": String(context.get("command", "")),
		"commandEnvelope": Dictionary(context.get("commandEnvelope", {})).duplicate(true),
		"stateVersion": int(snapshot.get("stateVersion", before_version)),
		"stateHash": String(snapshot.get("stateHash", before_hash)),
		"result": _duplicate_value(context.get("result")),
		"events": Array(context.get("events", [])).duplicate(true),
		"trace": Array(context.get("trace", [])).duplicate(true),
		"viewModel": Dictionary(snapshot.get("viewModel", {})).duplicate(true),
		"snapshot": snapshot,
		"timing": Dictionary(context.get("timing", {})).duplicate(true)
	}
	if bool(context.get("ephemeral", false)):
		response["ephemeral"] = true
	if bool(context.get("readOnly", false)):
		response["readOnly"] = true
	if not accepted:
		response["stateVersion"] = before_version
		response["stateHash"] = before_hash
		response["error"] = Dictionary(context.get("error", {})).duplicate(true)
		response["result"] = {}
	var manual_flow_preview := Dictionary(context.get("manualFlowPreview", {}))
	if not manual_flow_preview.is_empty():
		response["manualFlowPreview"] = manual_flow_preview.duplicate(true)
	return response


func build_incremental(context: Dictionary) -> Dictionary:
	var accepted := bool(context.get("accepted", false))
	var before_version := int(context.get("beforeVersion", 0))
	var after_version := int(context.get("afterVersion", before_version)) if accepted else before_version
	var response := {
		"ok": accepted,
		"accepted": accepted,
		"command": String(context.get("command", "")),
		"commandEnvelope": Dictionary(context.get("commandEnvelope", {})).duplicate(true),
		"stateVersion": after_version,
		"result": _duplicate_value(context.get("result")),
		"events": Array(context.get("events", [])).duplicate(true),
		"trace": Array(context.get("trace", [])).duplicate(true),
		# The authority creates this projection specifically for the response and
		# never mutates it afterwards; keep the immutable reference across the local
		# boundary instead of cloning roster/offer payloads a second time.
		"delta": Dictionary(context.get("delta", {})),
		"snapshotMode": "delta",
		"timing": Dictionary(context.get("timing", {})).duplicate(true),
	}
	if not accepted:
		response["error"] = Dictionary(context.get("error", {})).duplicate(true)
		response["result"] = {}
	return response


func _duplicate_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return Dictionary(value).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return Array(value).duplicate(true)
	return value
