extends RefCounted

## Pure projection from structured command/trace data to player-readable battle
## description lines. It never owns authority state and never invents events.

const TRACE_TYPES_WITH_TEXT := [
	"MOVE_HERO",
	"MOVE_HERO_BLOCKED",
	"MOVE_MONSTER",
	"DAMAGE_APPLIED",
	"PETS_RESET",
	"ELEMENT_SETTLEMENT_START",
	"SKILL_TRIGGERED",
	"SKILL_COMBO_TRIGGERED",
	"TRAIT_TRIGGERED",
	"round_start",
	"ROUND_START",
	"ROUND_END",
	"BATTLE_END",
]


func auto_position_lines(snapshot: Dictionary) -> Array:
	var command_log := Array(snapshot.get("command_log", snapshot.get("commandLog", [])))
	if command_log.is_empty():
		return []
	var completed := Dictionary(command_log.back())
	var command_type := String(completed.get("type", completed.get("command", completed.get("commandType", ""))))
	if command_type != "AUTO_POSITION_HEROES":
		return []
	var result_value: Variant = snapshot.get("lastCommandResult", snapshot.get("last_command_result", {}))
	if not result_value is Dictionary:
		return []
	var result := Dictionary(result_value)
	if not bool(result.get("ok", false)):
		return []
	var moves := Array(result.get("moves", []))
	if moves.is_empty():
		moves = Array(Dictionary(result.get("plan", {})).get("moves", []))
	var round_number := int(snapshot.get("battleRound", snapshot.get("battle_round", 0)))
	var lines: Array = []
	for move_value in moves:
		var move := Dictionary(move_value)
		var unit_id := String(move.get("unitId", move.get("unit_id", "")))
		var unit_name := _unit_name(snapshot, unit_id)
		var from_text := _position_text(Dictionary(move.get("from", {})))
		var to_text := _position_text(Dictionary(move.get("to", {})))
		if unit_name == "" or from_text == "" or to_text == "":
			continue
		var reason_text := _plain_position_reason(String(move.get("reason", "")))
		lines.append("第%d回合 · 自动布置：%s从%s移动到%s%s" % [
			round_number,
			unit_name,
			from_text,
			to_text,
			reason_text,
		])
	return lines


func trace_lines(events: Array) -> Array:
	var lines: Array = []
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event := Dictionary(event_value)
		var event_type := String(event.get("type", event.get("kind", "")))
		var line := ""
		if event_type == "ELEMENT_APPLIED":
			line = _element_line(event)
		elif event_type == "DAMAGE_APPLIED":
			line = _damage_line(event)
		elif event_type == "SKILL_TRIGGERED":
			line = _skill_line(event)
		elif event_type == "SKILL_COMBO_TRIGGERED":
			line = _skill_combo_line(event)
		elif event_type == "TRAIT_TRIGGERED":
			line = _trait_line(event)
		elif event_type in ["MOVE_HERO", "MOVE_HERO_BLOCKED", "MOVE_MONSTER"]:
			line = _move_line(event)
		elif TRACE_TYPES_WITH_TEXT.has(event_type):
			line = _text_event_line(event)
		if line != "":
			lines.append(line)
	return lines


func _element_line(event: Dictionary) -> String:
	var payload := Dictionary(event.get("payload", {}))
	var actor := Dictionary(event.get("actor", {}))
	var actor_name := _unit_display(actor, "单位")
	var element := String(payload.get("element", ""))
	var layers: int = maxi(1, int(payload.get("layers", 1)))
	var changes: Array[String] = []
	for target_value in Array(payload.get("targets", [])):
		if not target_value is Dictionary:
			continue
		var position := _position_text(Dictionary(target_value))
		if position != "":
			changes.append("%s（+%d层）" % [position, layers])
	if changes.is_empty():
		for change_value in Array(event.get("changes", [])):
			if not change_value is Dictionary:
				continue
			var change := Dictionary(change_value)
			var position := _position_from_change_path(String(change.get("path", "")))
			if position != "":
				var delta: int = int(change.get("delta", layers))
				var delta_text := "+%d" % delta if delta >= 0 else "%d" % delta
				changes.append("%s（%s层）" % [position, delta_text])
	if changes.is_empty():
		return _text_event_line(event)
	return "第%d回合 · %s铺设%d层%s：%s" % [
		int(event.get("round", 0)),
		actor_name,
		layers,
		element,
		"、".join(changes),
	]


func _damage_line(event: Dictionary) -> String:
	var actor := Dictionary(event.get("actor", {}))
	var target := Dictionary(event.get("target", {}))
	var payload := Dictionary(event.get("payload", {}))
	var changes: Array[String] = []
	if int(payload.get("shieldDamage", 0)) > 0:
		changes.append("护盾%d→%d" % [int(payload.get("shieldFrom", 0)), int(payload.get("shieldTo", 0))])
	if int(payload.get("hpDamage", 0)) > 0:
		changes.append("生命%d→%d" % [int(payload.get("hpFrom", 0)), int(payload.get("hpTo", 0))])
	return "第%d回合 · %s%s%s：%d点伤害（%s）" % [
		int(event.get("round", 0)),
		_unit_display(actor, "环境"),
		_damage_action_text(String(payload.get("sourceType", "action"))),
		_unit_display(target, "目标"),
		int(payload.get("finalDamage", 0)),
		"，".join(changes),
	]


func _skill_line(event: Dictionary) -> String:
	var payload := Dictionary(event.get("payload", {}))
	return "第%d回合 · %s发动技能【%s】" % [
		int(event.get("round", 0)),
		_unit_display(Dictionary(event.get("actor", {})), "宠物"),
		String(payload.get("skillName", "未知技能")),
	]


func _skill_combo_line(event: Dictionary) -> String:
	var payload := Dictionary(event.get("payload", {}))
	return "第%d回合 · %s发动组合技【%s】" % [
		int(event.get("round", 0)),
		_unit_display(Dictionary(event.get("actor", {})), "宠物"),
		String(payload.get("comboName", "未知组合技")),
	]


func _trait_line(event: Dictionary) -> String:
	var payload := Dictionary(event.get("payload", {}))
	var names := PackedStringArray(Array(payload.get("traitNames", [])))
	return "第%d回合 · %s的特性【%s】生效" % [
		int(event.get("round", 0)),
		_unit_display(Dictionary(event.get("actor", {})), "宠物"),
		"、".join(names),
	]


func _move_line(event: Dictionary) -> String:
	var actor_name := _unit_display(Dictionary(event.get("actor", {})), "宠物")
	var from_text := _position_text(Dictionary(event.get("from", {})))
	var to_text := _position_text(Dictionary(event.get("to", {})))
	if from_text == "" or to_text == "":
		return _text_event_line(event)
	if String(event.get("type", "")) == "MOVE_HERO_BLOCKED":
		return "第%d回合 · %s没能从%s移动到%s" % [int(event.get("round", 0)), actor_name, from_text, to_text]
	return "第%d回合 · %s从%s移动到%s" % [int(event.get("round", 0)), actor_name, from_text, to_text]


func _text_event_line(event: Dictionary) -> String:
	var text := String(event.get("text", "")).strip_edges()
	if text == "":
		return ""
	var actor := Dictionary(event.get("actor", {}))
	var side_text := _side_text(String(actor.get("side", "")))
	if side_text != "" and not text.begins_with(side_text):
		text = "%s%s" % [side_text, text]
	return "第%d回合 · %s" % [int(event.get("round", 0)), text]


func _unit_display(unit: Dictionary, fallback: String) -> String:
	var name := String(unit.get("name", unit.get("id", fallback)))
	return "%s%s" % [_side_text(String(unit.get("side", ""))), name]


func _side_text(side: String) -> String:
	match side:
		"player":
			return "我方"
		"enemy":
			return "敌方"
		_:
			return ""


func _damage_action_text(source_type: String) -> String:
	match source_type:
		"action":
			return "攻击"
		"skill":
			return "使用技能攻击"
		"skill_combo":
			return "使用组合技攻击"
		"relic":
			return "使用遗物攻击"
		"element_settlement":
			return "元素结算伤害"
		"element_trap":
			return "元素陷阱伤害"
		_:
			return "攻击"


func _unit_name(snapshot: Dictionary, unit_id: String) -> String:
	for unit_value in Array(snapshot.get("units", [])):
		if not unit_value is Dictionary:
			continue
		var unit := Dictionary(unit_value)
		if String(unit.get("id", unit.get("unitId", ""))) == unit_id:
			return String(unit.get("name", unit_id))
	return unit_id


func _position_text(position: Dictionary) -> String:
	var x := int(position.get("x", position.get("c", -1)))
	var y := int(position.get("y", position.get("r", -1)))
	if x < 0 or y < 0:
		return ""
	return "第%d行第%d列" % [y + 1, x + 1]


func _position_from_change_path(path: String) -> String:
	var parts := path.split(".")
	if parts.size() < 2:
		return ""
	var coordinates := String(parts[1]).split(",")
	if coordinates.size() != 2 or not String(coordinates[0]).is_valid_int() or not String(coordinates[1]).is_valid_int():
		return ""
	return "第%d行第%d列" % [int(coordinates[1]) + 1, int(coordinates[0]) + 1]


func _plain_position_reason(reason: String) -> String:
	if reason.strip_edges() == "":
		return ""
	if reason.contains("击杀"):
		return "（这样更容易击败敌人）"
	if reason.contains("掉血") or reason.contains("受伤"):
		return "（这样可以少受伤）"
	return "（选择了更合适的位置）"
