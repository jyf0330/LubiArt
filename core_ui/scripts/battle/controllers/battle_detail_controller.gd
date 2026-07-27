extends RefCounted

## Builds the stable data contract consumed by the shared pet-detail prefab.


func pet_record(unit: Dictionary, skill_description: String, attack_shape: Dictionary) -> Dictionary:
	var max_ap := int(unit.get("ap", unit.get("max_ap", unit.get("maxAp", 0))))
	var current_ap := int(unit.get("available_ap", unit.get("availableAp", max_ap)))
	return {
		"name": display_name(unit),
		"element": element(unit),
		"quality": quality(unit),
		"role": String(unit.get("role", side_label(String(unit.get("side", ""))))),
		"hp": int(unit.get("hp", 0)),
		"max_hp": int(unit.get("max_hp", unit.get("maxHp", unit.get("hp", 0)))),
		"ap": current_ap,
		"max_ap": max_ap,
		"attack": int(unit.get("atk", unit.get("attack", 0))),
		"defense": int(unit.get("def", unit.get("defense", 0))),
		"shield": max(0, int(unit.get("shield", 0))),
		"regen": int(unit.get("regen", unit.get("regeneration", 0))),
		"skill_description": skill_description,
		"attack_shape": attack_shape,
	}


func display_name(unit: Dictionary) -> String:
	return String(unit.get("displayName", unit.get("name", unit.get("id", "未命名宠物"))))


func element(unit: Dictionary) -> String:
	var element_types := Array(unit.get("element_types", []))
	if not element_types.is_empty():
		var labels: Array[String] = []
		for value in element_types:
			labels.append(String(value))
		return " / ".join(labels)
	return String(unit.get("element", unit.get("main_element", "-")))


func quality(unit: Dictionary) -> String:
	return String(unit.get("quality", "普通"))


func side_label(side: String) -> String:
	match side:
		"player", "hero", "hero_leader":
			return "我方"
		"enemy", "monster", "enemy_leader":
			return "敌方"
		_:
			return side if side != "" else "-"


func resolve_detail(snap: Dictionary, active_grid: Vector2i, active_unit_id: String) -> Dictionary:
	var has_request := active_grid.x >= 0 or active_unit_id != ""
	var detail := dict_value(snap.get("lastCommandResult", snap.get("last_command_result", {}))).duplicate(true) if has_request else {}
	var unit := dict_value(detail.get("unit", {}))
	if unit.is_empty() and active_grid.x >= 0:
		detail = detail_from_board_cell(snap, active_grid)
		unit = dict_value(detail.get("unit", {}))
	if unit.is_empty() and active_unit_id != "":
		unit = unit_by_id(snap, active_unit_id)
		detail["unit"] = unit
	if unit.is_empty() and not has_visible_elements(dict_value(detail.get("elements", {}))):
		return {}
	if unit.is_empty():
		return detail
	var full_unit := unit_by_id(snap, String(unit.get("id", unit.get("unitId", active_unit_id))))
	if not full_unit.is_empty():
		var merged := full_unit.duplicate(true)
		merged.merge(unit, true)
		detail["unit"] = merged
	return detail


func detail_from_board_cell(snap: Dictionary, grid: Vector2i) -> Dictionary:
	var board := dict_value(snap.get("board", {}))
	for value in Array(board.get("cells", [])):
		var cell := Dictionary(value)
		var x := int(cell.get("x", cell.get("c", -1)))
		var y := int(cell.get("y", cell.get("r", -1)))
		if x != grid.x or y != grid.y:
			continue
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		return {
			"x": x,
			"y": y,
			"c": x,
			"r": y,
			"elements": dict_value(cell.get("elements", {})),
			"preview": dict_value(cell.get("preview", {})),
			"threat": dict_value(cell.get("threat", {})),
			"unit": unit_by_id(snap, unit_id),
		}
	return {}


func unit_by_id(snap: Dictionary, unit_id: String) -> Dictionary:
	if unit_id == "":
		return {}
	for value in Array(snap.get("units", [])):
		var unit := Dictionary(value)
		if String(unit.get("id", unit.get("unitId", ""))) == unit_id:
			return unit.duplicate(true)
	return {}


func dict_value(value: Variant) -> Dictionary:
	return Dictionary(value) if value is Dictionary else {}


func has_visible_elements(elements: Dictionary) -> bool:
	for amount in elements.values():
		if int(amount) > 0:
			return true
	return false


func action_slots(unit: Dictionary, snap: Dictionary, selected_unit_id: String) -> Array:
	var slots := Array(unit.get("action_slots", unit.get("actionSlots", unit.get("slots", []))))
	if not slots.is_empty():
		return slots
	if String(unit.get("id", "")) == selected_unit_id:
		return Array(snap.get("selected_action_slots", snap.get("selectedActionSlots", [])))
	return []


func attack_range_text(detail: Dictionary, unit: Dictionary, snap: Dictionary) -> String:
	var shape := attack_shape(detail, unit, snap)
	if shape.is_empty():
		return ""
	var shape_id := String(shape.get("shape_id", shape.get("shapeId", "")))
	var label := String(shape.get("label", shape.get("shape_name", "攻击形状")))
	var targets: Array[String] = []
	for value in Array(shape.get("offsets", [])):
		var offset := dict_value(value)
		var dr := int(offset.get("dr", 0))
		var dc := int(offset.get("dc", 0))
		if dr != 0 or dc != 0:
			targets.append(attack_offset_label(dr, dc))
	var note := String(shape.get("note", "")).strip_edges()
	var header := label if shape_id == "" else "%s · %s" % [shape_id, label]
	var target_text := "无有效目标格" if targets.is_empty() else "目标格：%s" % "、".join(targets)
	return "%s\n%s%s" % [header, target_text, "\n%s" % note if note != "" else ""]


func attack_shape(detail: Dictionary, unit: Dictionary, snap: Dictionary) -> Dictionary:
	var shape := dict_value(detail.get("attack_shape", unit.get("attack_shape", {}))).duplicate(true)
	if not shape.is_empty():
		return shape
	var shape_id := String(unit.get("shape_id", unit.get("shapeId", ""))).strip_edges()
	var shape_text := String(unit.get("shape", "")).strip_edges()
	for value in Array(dict_value(snap.get("battle", {})).get("shape_catalog", [])):
		var candidate := dict_value(value)
		var candidate_id := String(candidate.get("shape_id", candidate.get("shapeId", ""))).strip_edges()
		var candidate_label := String(candidate.get("label", "")).strip_edges()
		if candidate_id != "" and (candidate_id == shape_id or shape_text == candidate_id or shape_text == candidate_label or shape_text.contains(candidate_id)):
			return candidate.duplicate(true)
	return {}


func attack_offset_label(dr: int, dc: int) -> String:
	var vertical := ""
	if dr < 0:
		vertical = "上%d" % abs(dr)
	elif dr > 0:
		vertical = "下%d" % dr
	var horizontal := ""
	if dc < 0:
		horizontal = "左%d" % abs(dc)
	elif dc > 0:
		horizontal = "右%d" % dc
	return "%s%s" % [vertical, horizontal]


func skill_text(unit: Dictionary, snap: Dictionary, selected_unit_id: String) -> String:
	var selected_skill := dict_value(snap.get("selected_skill", snap.get("selectedSkill", {})))
	if String(unit.get("id", "")) == selected_unit_id and not selected_skill.is_empty():
		var selected_name := String(selected_skill.get("name", selected_skill.get("label", "")))
		var selected_desc := String(selected_skill.get("description", selected_skill.get("desc", "")))
		return selected_name if selected_desc == "" else "%s：%s" % [selected_name, selected_desc]
	var skill_value: Variant = unit.get("skill", "")
	if skill_value is Dictionary:
		var skill := Dictionary(skill_value)
		var skill_name := String(skill.get("name", skill.get("label", "")))
		var skill_desc := String(skill.get("description", skill.get("desc", "")))
		return skill_name if skill_desc == "" else "%s：%s" % [skill_name, skill_desc]
	return String(skill_value)


func mechanics_text(unit: Dictionary) -> String:
	var parts: Array[String] = []
	for value in Array(unit.get("mechanicStatus", unit.get("mechanic_status", unit.get("mechanics", [])))):
		if value is Dictionary:
			var row := Dictionary(value)
			var label := String(row.get("label", row.get("name", row.get("id", ""))))
			if label != "":
				parts.append(label)
		else:
			var text := String(value)
			if text != "":
				parts.append(text)
	return "、".join(parts)


func slot_summary(slot: Dictionary) -> String:
	var index := int(slot.get("index", slot.get("slotId", 0))) + 1
	var label := String(slot.get("label", slot.get("name", "行动块")))
	var element_name := String(slot.get("element", "-"))
	var layers := int(slot.get("layers", slot.get("base_layers", 0)))
	var used := "已用" if bool(slot.get("used", false)) else "可用"
	return "%d. %s · %s%d层 · %s · %s" % [index, label, element_name, layers, direction_label(String(slot.get("direction", "right"))), used]


func preview_summary(preview: Dictionary) -> String:
	var actor := String(preview.get("actorName", preview.get("actorId", "")))
	var damage := int(preview.get("predictedDamage", preview.get("damage", 0)))
	if actor == "":
		actor = "当前行动"
	return "%s %s%s" % [actor, direction_label(String(preview.get("direction", ""))), "，预计伤害 %d" % damage if damage > 0 else ""]


func threat_summary(threat: Dictionary) -> String:
	var damage := incoming_damage(threat)
	var actor := String(threat.get("actorName", threat.get("sourceName", threat.get("enemyName", "敌方"))))
	return "%s 预计造成 %d 点伤害" % [actor, damage] if damage > 0 else "%s 有威胁覆盖" % actor


func incoming_damage(threat: Dictionary) -> int:
	return max(0, int(threat.get("totalDamage", threat.get("damage", threat.get("threat", threat.get("atk", 0))))))


func max_hp(unit: Dictionary) -> int:
	return int(unit.get("max_hp", unit.get("maxHp", unit.get("hp", 0))))


func attack(unit: Dictionary) -> int:
	return int(unit.get("atk", unit.get("attack", 0)))


func ap_summary(unit: Dictionary, snap: Dictionary) -> String:
	var maximum: int = max(0, int(unit.get("ap", snap.get("ap", 0))))
	var available: int = max(0, int(unit.get("available_ap", unit.get("availableAp", snap.get("ap", maximum)))))
	return "%d/%d" % [available, maximum] if maximum > 0 else str(available)


func move_range(unit: Dictionary) -> int:
	for key in ["move_range", "moveRange", "move_ap", "moveAp"]:
		if unit.has(key):
			return max(0, int(unit.get(key, 0)))
	return max(0, int(unit.get("ap", 0)))


func state_text(unit: Dictionary) -> String:
	var alive := bool(unit.get("alive", int(unit.get("hp", 0)) > 0))
	var active := bool(unit.get("active", true))
	var status := "正常" if alive and active else ("退场" if not alive else "未上阵")
	var side := String(unit.get("side", unit.get("camp", "")))
	var side_text := "我方" if ["player", "hero"].has(side) else ("敌方" if side == "enemy" else side)
	var x := int(unit.get("x", -1))
	var y := int(unit.get("y", -1))
	var position_text := "未在棋盘" if x < 0 or y < 0 else "第%d行 · 第%d列" % [y + 1, x + 1]
	return "%s · %s · %s" % [status, side_text if side_text != "" else "阵营未知", position_text]


func quality_effect_text(unit: Dictionary) -> String:
	var unit_quality := quality(unit)
	var upgrade := dict_value(unit.get("quality_upgrade", unit.get("qualityUpgrade", {})))
	var progression := dict_value(unit.get("quality_progression", unit.get("qualityProgression", {})))
	var upgrade_name := String(upgrade.get("name", progression.get("upgrade_name", progression.get("upgradeName", "")))).strip_edges()
	var effect := String(upgrade.get("effect", progression.get("upgrade_effect", progression.get("upgradeEffect", "")))).strip_edges()
	if upgrade_name == "" and effect == "":
		return "%s · 属性已按当前品质结算" % unit_quality
	var title := unit_quality if upgrade_name == "" else "%s · %s" % [unit_quality, upgrade_name]
	return title if effect == "" else "%s\n%s" % [title, effect]


func element_summary(elements: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["无", "火", "水", "草", "雷", "冰", "地", "暗", "龙", "neutral", "fire", "water", "grass", "electric", "ice", "ground", "dark", "dragon"]:
		var amount := int(elements.get(key, 0))
		if amount > 0:
			parts.append("%s%d" % [element_label(key), amount])
	return "无" if parts.is_empty() else " ".join(parts)


func element_label(element_name: String) -> String:
	var labels := {
		"neutral": "无",
		"fire": "火",
		"water": "水",
		"grass": "草",
		"electric": "雷",
		"ice": "冰",
		"ground": "地",
		"dark": "暗",
		"dragon": "龙",
	}
	return String(labels.get(element_name, element_name))


func direction_label(direction: String) -> String:
	var labels := {"right": "向右", "left": "向左", "up": "向上", "down": "向下"}
	return String(labels.get(direction, direction))
