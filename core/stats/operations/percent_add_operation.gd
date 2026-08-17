extends RefCounted
const StatOperationIdsScript := preload("res://core/stats/stat_operation_ids.gd")
func plugin_id() -> String: return StatOperationIdsScript.PERCENT_ADD
func order() -> int: return 200
func apply(current: int, modifier: Dictionary) -> int: return _round(current, 1000 + int(modifier.get("value", 0)))
func _round(value: int, permille: int) -> int:
	var product := value * permille
	return int((product + 500) / 1000) if product >= 0 else -int((-product + 500) / 1000)
