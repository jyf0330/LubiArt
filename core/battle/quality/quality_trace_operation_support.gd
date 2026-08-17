extends RefCounted

const LEGACY_STATE_SCHEMA_PARAM := "__legacy_state_schema"


static func trace_profile(
	handler_id: String,
	params: Dictionary,
	default_duration: int,
	default_persistent: bool
) -> Dictionary:
	if bool(params.get(LEGACY_STATE_SCHEMA_PARAM, false)):
		var legacy_trace := {
			"kind": handler_id,
			"duration": max(1, int(params.get("duration", default_duration))),
		}
		if bool(params.get("persistent", default_persistent)):
			legacy_trace["persistent"] = true
		return legacy_trace
	return {
		"handler_id": handler_id,
		"params": behavior_params(params),
		"duration": max(1, int(params.get("duration", default_duration))),
		"persistent": bool(params.get("persistent", default_persistent)),
	}


static func place_after_attack(
	handler: RefCounted,
	context: RefCounted,
	attacker: Dictionary,
	option: Dictionary,
	params: Dictionary,
	default_duration: int,
	default_persistent: bool
) -> Array:
	var logs: Array = []
	if (
		handler == null
		or context == null
		or not handler.has_method(&"plugin_id")
		or not context.has_method(&"set_board_trace")
		or not context.has_method(&"unit_at")
	):
		return logs
	var upgrade := Dictionary(attacker.get("quality_upgrade", {}))
	var trace_id := String(params.get("__trace_id", upgrade.get("id", "")))
	var trace_name := String(upgrade.get(
		"name",
		params.get("__trace_name", trace_id if trace_id != "" else "痕迹")
	))
	if trace_name == "":
		trace_name = trace_id if trace_id != "" else "痕迹"
	var handler_id := String(handler.call(&"plugin_id"))
	var duration: int = max(1, int(params.get("duration", default_duration)))
	var persistent := bool(params.get("persistent", default_persistent))
	var behavior := behavior_params(params)
	var trace: Dictionary
	if bool(params.get(LEGACY_STATE_SCHEMA_PARAM, false)):
		trace = {
			"kind": handler_id,
			"duration": duration,
			"id": trace_id,
			"name": trace_name,
		}
		if persistent:
			trace["persistent"] = true
	else:
		trace = {
			"handler_id": handler_id,
			"params": behavior,
			"id": trace_id,
			"name": trace_name,
			"duration": duration,
			"persistent": persistent,
		}
	var applied := 0
	for cell_value in Array(option.get("cells", [])):
		if typeof(cell_value) != TYPE_DICTIONARY:
			continue
		var cell := Dictionary(cell_value)
		var x := int(cell.get("x", -1))
		var y := int(cell.get("y", -1))
		if not bool(context.call(&"set_board_trace", x, y, trace.duplicate(true))):
			continue
		applied += 1
		if not handler.has_method(&"trace_enter"):
			continue
		var unit_value = context.call(&"unit_at", x, y)
		var unit := Dictionary(unit_value) if typeof(unit_value) == TYPE_DICTIONARY else {}
		var trigger_log := String(handler.call(
			&"trace_enter",
			context,
			unit,
			trace.duplicate(true),
			behavior.duplicate(true)
		))
		if trigger_log != "":
			logs.append(trigger_log)
	if applied > 0:
		logs.push_front("%s：留下%d个战斗痕迹。" % [trace_name, applied])
	return logs


static func behavior_params(params: Dictionary) -> Dictionary:
	var result := params.duplicate(true)
	for key in ["duration", "persistent", "__trace_id", "__trace_name", LEGACY_STATE_SCHEMA_PARAM]:
		result.erase(key)
	return result


static func is_live_side(unit: Dictionary, expected_side: String) -> bool:
	return (
		not unit.is_empty()
		and int(unit.get("hp", 0)) > 0
		and String(unit.get("side", "")) == expected_side
	)


static func trace_name(trace: Dictionary) -> String:
	return String(trace.get("name", trace.get("id", "痕迹")))


static func unit_name(unit: Dictionary, fallback: String) -> String:
	return String(unit.get("name", fallback))
