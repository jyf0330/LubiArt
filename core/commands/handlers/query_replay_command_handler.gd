extends RefCounted

const ACTION_TYPES: Array[String] = [
	"GET_DEVELOPER_OBJECT_CATALOG",
	"GET_DEBUG_PET_CATALOG",
	"BUILD_PREVIEW", "GET_CELL_DETAIL", "PREVIEW_MANUAL_FLOW",
	"EXPORT_REPLAY", "EXPORT_BATTLE_TRACE", "REPLAY_BATTLE_TRACE",
	"GENERATE_NODE_OPTIONS", "GENERATE_BATTLE_OPTIONS", "REWARD_OPTIONS"
]
const PORT_CONTRACT_ID := &"ysbzs.query-replay-command-port.v1"


func action_types() -> Array[String]:
	return ACTION_TYPES.duplicate()


func execute(port: RefCounted, action_type: String, action: Dictionary) -> bool:
	if not _accepts(port):
		return false
	match action_type:
		"GET_DEVELOPER_OBJECT_CATALOG":
			port.set_result(port.developer_object_catalog())
		"GET_DEBUG_PET_CATALOG":
			port.set_result(port.debug_pet_catalog())
		"BUILD_PREVIEW":
			port.set_result(port.build_preview(action))
		"GET_CELL_DETAIL":
			port.set_result(port.cell_detail(action))
		"PREVIEW_MANUAL_FLOW":
			port.set_result(port.preview_manual_flow(action))
		"EXPORT_REPLAY":
			port.set_result(port.replay_document(action))
		"EXPORT_BATTLE_TRACE":
			port.set_result({"events": port.battle_trace_events()})
		"REPLAY_BATTLE_TRACE":
			var fallback_events: Array = port.battle_trace_events()
			var events_value: Variant = action.get("events", fallback_events)
			var events: Array = Array(events_value).duplicate(true) if typeof(events_value) == TYPE_ARRAY else fallback_events
			port.set_result({"replayed": true, "events": events})
		"GENERATE_NODE_OPTIONS", "GENERATE_BATTLE_OPTIONS", "REWARD_OPTIONS":
			port.log_compatibility(action_type)
		_:
			return false
	return true


func _accepts(port: RefCounted) -> bool:
	return port != null and port.has_method(&"contract_id") and StringName(port.contract_id()) == PORT_CONTRACT_ID
