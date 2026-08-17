extends RefCounted

const CONTRACT_ID := &"ysbzs.query-replay-command-port.v1"

var _authority: Object


func _init(authority: Object) -> void:
	_authority = authority


func contract_id() -> StringName:
	return CONTRACT_ID


func set_result(value: Variant) -> void:
	_authority.set("last_command_result", value)


func developer_object_catalog() -> Dictionary:
	return Dictionary(_authority.call("developer_object_catalog"))


func debug_pet_catalog() -> Dictionary:
	return Dictionary(_authority.call("debug_pet_catalog"))


func build_preview(action: Dictionary) -> Array:
	return Array(_authority.call("_battle_query_action_grid", action)).duplicate(true)


func cell_detail(action: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("battle_query_cell_detail", action))


func preview_manual_flow(action: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("_manual_flow_preview", action))


func replay_document(action: Dictionary) -> Dictionary:
	return Dictionary(_authority.call("replay_document", action))


func battle_trace_events() -> Array:
	return Array(_authority.call("_export_battle_trace_events"))


func log_compatibility(action_type: String) -> void:
	_authority.call("_log", "兼容命令 %s：当前 Godot 路线候选已在本地状态中。" % action_type)
