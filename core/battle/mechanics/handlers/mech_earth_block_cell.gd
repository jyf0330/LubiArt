extends RefCounted


func plugin_id() -> String:
	return "mech_earth_block_cell"


func after_element(port: RefCounted, caster: Dictionary, target: Dictionary, _element: String, _layers: int, cell: Dictionary, mechanism: Dictionary) -> Array:
	var logs: Array = []
	var x := int(cell.get("x", -1))
	var y := int(cell.get("y", -1))
	if bool(port.inside(x, y)) and target.is_empty():
		var wall_hp: int = max(1, int(port.mechanic_param_int(caster, mechanism, "hp", 8)))
		var wall_duration: int = max(1, int(port.mechanic_param_int(caster, mechanism, "duration", 2)))
		var wall := Dictionary(port.summon_wall(caster, {"x": x, "y": y}, wall_hp, wall_duration))
		if not wall.is_empty():
			logs.append("%s 触发%s：在(%d,%d)生成土墙，HP%d，持续%d回合。" % [
				String(caster.get("name", "单位")), String(mechanism.get("name", plugin_id())), x + 1, y + 1,
				int(wall.get("hp", 0)), int(wall.get("wall_duration", 0)),
			])
	logs.append("%s 触发%s，已写入事件流。" % [String(caster.get("name", "单位")), String(mechanism.get("name", plugin_id()))])
	return logs
