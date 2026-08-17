extends RefCounted


static func normalized_shop_slots(requested: int, maximum: int) -> int:
	return clampi(requested, 0, maximum)


static func option_kind(node_type: String) -> String:
	return node_type if node_type in ["shop", "reward", "rest", "event"] else "reward"


static func day_expression_allows(day_expr: String, current_day: int) -> bool:
	var text := day_expr.strip_edges()
	if text == "":
		return true
	if text.begins_with("D"):
		text = text.substr(1)
	if text.find("-") >= 0:
		var parts := text.split("-", false, 2)
		if parts.size() == 2:
			var start_text := String(parts[0]).replace("D", "")
			var end_text := String(parts[1]).replace("D", "")
			return current_day >= int(start_text) and current_day <= int(end_text)
	return current_day == int(text)
