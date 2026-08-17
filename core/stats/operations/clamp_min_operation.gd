extends RefCounted
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")
func plugin_id() -> String: return StatOperationIdsScript.CLAMP_MIN
func order() -> int: return 500
func apply(current: int, modifier: Dictionary) -> int: return max(current, int(modifier.get("value", current)))
