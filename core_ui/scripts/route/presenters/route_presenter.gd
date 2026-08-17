extends "res://core_ui/scripts/route/controllers/route_controller.gd"

## Canonical route presentation model. Authored views only resolve textures and
## bind the already-normalized command carried by each card.


func cards(snapshot: Dictionary) -> Array:
	var result: Array = []
	for value in options(snapshot):
		var option := Dictionary(value)
		var kind := kind_for(option)
		result.append({
			"record": option,
			"kind": kind,
			"command": choose_command(option),
		})
	return result


func kind_for(option: Dictionary) -> String:
	var explicit_kind := String(option.get("kind", "")).strip_edges()
	if ["shop", "reward", "battle", "event", "rest"].has(explicit_kind):
		return explicit_kind
	var text := "%s %s %s" % [
		String(option.get("id", "")),
		String(option.get("title", "")),
		String(option.get("nodeId", option.get("node_id", ""))),
	]
	var lower := text.to_lower()
	if lower.contains("shop") or text.contains("商店"):
		return "shop"
	if lower.contains("battle") or lower.contains("encounter") or text.contains("战斗"):
		return "battle"
	if lower.contains("reward") or text.contains("奖励"):
		return "reward"
	return "event"
