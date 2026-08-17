extends RefCounted


func plugin_id() -> String:
	return "mech_summon_trap"


func after_element(port: RefCounted, caster: Dictionary, target: Dictionary, element: String, layers: int, cell: Dictionary, mechanism: Dictionary) -> Array:
	var logs: Array = []
	var x := int(cell.get("x", -1))
	var y := int(cell.get("y", -1))
	if bool(port.inside(x, y)) and target.is_empty():
		var trap_element := String(port.mechanic_param_element(caster, mechanism, "element", element))
		var trap_layers: int = max(1, int(port.mechanic_param_int(caster, mechanism, "layers", layers)))
		port.apply_element_to_cell(x, y, trap_element, trap_layers)
		logs.append("%s 触发%s：在(%d,%d)生成%s陷阱%d层。" % [
			String(caster.get("name", "单位")), String(mechanism.get("name", plugin_id())),
			x + 1, y + 1, trap_element, trap_layers,
		])
	logs.append("%s 触发%s，已写入事件流。" % [String(caster.get("name", "单位")), String(mechanism.get("name", plugin_id()))])
	return logs
