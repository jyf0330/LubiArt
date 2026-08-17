extends RefCounted
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")
func plugin_id() -> String: return StatOperationIdsScript.MULTIPLIER
func order() -> int: return 300
func apply(current: int, modifier: Dictionary) -> int:
	var product := current * int(modifier.get("value", 1000))
	return int((product + 500) / 1000) if product >= 0 else -int((-product + 500) / 1000)
