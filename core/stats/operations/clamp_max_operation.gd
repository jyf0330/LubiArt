extends RefCounted
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")
func plugin_id() -> String: return StatOperationIdsScript.CLAMP_MAX
func order() -> int: return 600
func apply(current: int, modifier: Dictionary) -> int: return min(current, int(modifier.get("value", current)))
