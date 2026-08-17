extends RefCounted
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")
func plugin_id() -> String: return StatOperationIdsScript.FLAT_ADD
func order() -> int: return 100
func apply(current: int, modifier: Dictionary) -> int: return current + int(modifier.get("value", 0))
