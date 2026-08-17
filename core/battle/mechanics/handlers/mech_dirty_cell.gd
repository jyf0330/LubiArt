extends RefCounted


func plugin_id() -> String:
	return "mech_dirty_cell"


func after_element(port: RefCounted, caster: Dictionary, target: Dictionary, _element: String, _layers: int, cell: Dictionary, mechanism: Dictionary) -> Array:
	var logs: Array = []
	var x := int(cell.get("x", -1))
	var y := int(cell.get("y", -1))
	if bool(port.inside(x, y)) and target.is_empty():
		var duration: int = max(1, int(port.mechanic_param_int(caster, mechanism, "duration", 2)))
		if bool(port.set_board_trace(x, y, {"id": plugin_id(), "name": String(mechanism.get("name", "污染格子")), "kind": "dirty_cell", "duration": duration})):
			logs.append("%s 触发%s：污染格子(%d,%d)，持续%d回合。" % [
				String(caster.get("name", "单位")), String(mechanism.get("name", plugin_id())), x + 1, y + 1, duration,
			])
	logs.append("%s 触发%s，已写入事件流。" % [String(caster.get("name", "单位")), String(mechanism.get("name", plugin_id()))])
	return logs
