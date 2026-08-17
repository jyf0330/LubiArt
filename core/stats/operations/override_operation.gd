extends RefCounted
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")
func plugin_id() -> String: return StatOperationIdsScript.OVERRIDE
func order() -> int: return 400
func apply(current: int, modifier: Dictionary) -> int: return int(modifier.get("value", current))
