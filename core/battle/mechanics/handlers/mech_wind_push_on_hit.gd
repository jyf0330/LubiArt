extends RefCounted


func plugin_id() -> String:
	return "mech_wind_push_on_hit"


func attacker_after_hit(port: RefCounted, attacker: Dictionary, target: Dictionary, _amount: int, element: String, direction: String, mechanism: Dictionary) -> Array:
	var distance: int = max(1, int(port.mechanic_param_int(attacker, mechanism, "distance", 1)))
	var delta := Vector2i(port.direction_delta(direction))
	var before_x := int(target.get("x", 0))
	var before_y := int(target.get("y", 0))
	var next_x := before_x + delta.x * distance
	var next_y := before_y + delta.y * distance
	if bool(port.inside(next_x, next_y)) and Dictionary(port.unit_at(next_x, next_y)).is_empty():
		target["x"] = next_x
		target["y"] = next_y
		return ["%s 触发%s：%s元素推动%s%d格，(%d,%d)→(%d,%d)。" % [
			String(attacker.get("name", "单位")), String(mechanism.get("name", plugin_id())), element,
			String(target.get("name", "目标")), distance, before_x + 1, before_y + 1, next_x + 1, next_y + 1,
		]]
	return ["%s 触发%s：%s元素推动%s%d格受阻。" % [
		String(attacker.get("name", "单位")), String(mechanism.get("name", plugin_id())), element,
		String(target.get("name", "目标")), distance,
	]]
