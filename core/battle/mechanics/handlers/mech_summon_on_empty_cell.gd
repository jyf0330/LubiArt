extends RefCounted


func plugin_id() -> String:
	return "mech_summon_on_empty_cell"


func after_element(port: RefCounted, caster: Dictionary, target: Dictionary, _element: String, _layers: int, cell: Dictionary, mechanism: Dictionary) -> Array:
	var logs: Array = []
	if target.is_empty():
		var summoned := Dictionary(port.summon_unit(caster, mechanism, cell))
		if not summoned.is_empty():
			logs.append("%s 触发%s：在(%d,%d)召唤小灵，HP%d。" % [
				String(caster.get("name", "单位")), String(mechanism.get("name", plugin_id())),
				int(summoned.get("x", 0)) + 1, int(summoned.get("y", 0)) + 1, int(summoned.get("hp", 0)),
			])
	logs.append("%s 触发%s，已写入事件流。" % [String(caster.get("name", "单位")), String(mechanism.get("name", plugin_id()))])
	return logs
