extends RefCounted

const TraceSupportScript := preload("res://core/battle/quality/quality_trace_operation_support.gd")


func after_attack(
	context: RefCounted,
	attacker: Dictionary,
	option: Dictionary,
	_targets: Array,
	params: Dictionary
) -> Array:
	return TraceSupportScript.place_after_attack(
		self,
		context,
		attacker,
		option,
		params,
		_default_duration(),
		_default_persistent()
	)


func profile(params: Dictionary) -> Dictionary:
	return {
		"board_trace": TraceSupportScript.trace_profile(
			String(call(&"plugin_id")),
			params,
			_default_duration(),
			_default_persistent()
		),
	}


func _default_duration() -> int:
	return 1


func _default_persistent() -> bool:
	return false
