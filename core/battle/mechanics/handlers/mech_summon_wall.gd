extends "res://core/battle/mechanics/handlers/bases/lifecycle_handler_base.gd"


func plugin_id() -> String:
	return "mech_summon_wall"


func after_action(port: RefCounted, actor: Dictionary, mechanism: Dictionary) -> Array:
	if not _accepts_lifecycle_port(port) or actor.is_empty() or int(actor.get("hp", 0)) <= 0:
		return []
	var cell := Dictionary(port.first_adjacent_empty(actor))
	if cell.is_empty():
		return ["%s 触发%s：召唤障碍没有可用空格。" % [
			String(actor.get("name", "单位")), String(mechanism.get("name", plugin_id()))
		]]
	var hp: int = max(1, int(port.mechanic_param_int(actor, mechanism, "hp", 8)))
	var duration: int = max(1, int(port.mechanic_param_int(actor, mechanism, "duration", 2)))
	var wall := Dictionary(port.summon_wall(actor, cell, hp, duration))
	if wall.is_empty():
		return []
	return ["%s 触发%s：召唤障碍%s，落点(%d,%d)，HP%d，持续%d回合。" % [
		String(actor.get("name", "单位")),
		String(mechanism.get("name", plugin_id())),
		String(wall.get("name", "障碍")),
		int(wall.get("x", 0)) + 1,
		int(wall.get("y", 0)) + 1,
		int(wall.get("hp", 0)),
		int(wall.get("wall_duration", 0)),
	]]
