extends PanelContainer

signal command_requested(command: Dictionary)

@onready var title_label: Label = $Margin/Content/Title
@onready var summary_label: Label = $Margin/Content/Summary
@onready var refresh_button: Button = $Margin/Content/Actions/RefreshButton
@onready var primary_button: Button = $Margin/Content/Actions/PrimaryButton

var _refresh_command := {}
var _primary_command := {}
var _pending_snapshot := {}
var _pending_view := &"three_option"


func _ready() -> void:
	refresh_button.pressed.connect(_on_refresh_pressed)
	primary_button.pressed.connect(_on_primary_pressed)
	_apply_style()
	if not _pending_snapshot.is_empty():
		render_snapshot(_pending_snapshot, _pending_view)


func render_snapshot(snap: Dictionary, view: StringName) -> void:
	if not is_node_ready():
		_pending_snapshot = snap.duplicate(true)
		_pending_view = view
		return
	var phase := String(snap.get("phase", "route"))
	var header := "第%d天 · 节点%d · 金币%d\n%s" % [
		int(snap.get("day", 1)),
		int(snap.get("node_index", 1)),
		int(snap.get("coins", 0)),
		_roster_summary(snap)
	]
	_refresh_command = {}
	_primary_command = {}
	refresh_button.visible = false
	primary_button.visible = false
	if view == &"bag":
		title_label.text = "%s\n候补背包" % header
		summary_label.text = _bag_summary(snap)
		var page_count := _bag_page_count(snap)
		if page_count > 1:
			var page := int(snap.get("ui_bag_page", 0))
			_primary_command = {"type": "UI_SET_BAG_PAGE", "page": (page + 1) % page_count, "label": "下一页"}
			primary_button.text = "下一页（%d/%d）" % [page + 1, page_count]
			primary_button.visible = true
	else:
		_render_phase_snapshot(snap, phase, header)
	visible = view != &"battle"


func _render_phase_snapshot(snap: Dictionary, phase: String, header: String) -> void:
	match phase:
		"shop":
			title_label.text = "%s\n商店" % header
			summary_label.text = _shop_summary(snap)
			_refresh_command = {
				"type": "ROLL_SHOP",
				"slots": int(Dictionary(snap.get("active_stall", {})).get("slots", 10))
			}
			refresh_button.visible = true
			var events := Array(snap.get("shop_events", []))
			if not events.is_empty():
				var event := Dictionary(events[0])
				_primary_command = {"type": "APPLY_SHOP_EVENT", "eventId": String(event.get("id", event.get("eventId", ""))), "label": String(event.get("name", "商店事件"))}
				primary_button.text = String(_primary_command.get("label", "商店事件"))
				primary_button.visible = not String(_primary_command.get("eventId", "")).is_empty()
		"reward":
			title_label.text = "%s\n奖励选择" % header
			summary_label.text = _reward_summary(snap)
		"battle_end", "day_end", "game_over":
			title_label.text = "%s\n%s" % [header, _terminal_title(phase)]
			summary_label.text = _terminal_summary(snap, phase)
			_primary_command = _terminal_command(snap, phase)
			primary_button.text = String(_primary_command.get("label", "继续"))
			primary_button.visible = not _primary_command.is_empty()
		_:
			title_label.text = "%s\n路线选择" % header
			summary_label.text = _route_summary(snap)


func get_summary_text() -> String:
	return "%s\n%s" % [title_label.text, summary_label.text]


func _route_summary(snap: Dictionary) -> String:
	var lines := ["选择下一站："]
	for value in Array(snap.get("route_options", [])):
		var option := Dictionary(value)
		lines.append("%s：%s" % [String(option.get("title", option.get("id", "节点"))), String(option.get("desc", ""))])
	return "\n".join(lines)


func _shop_summary(snap: Dictionary) -> String:
	var refresh := Dictionary(snap.get("shop_refresh", {}))
	var free_rolls := int(refresh.get("free_rolls", refresh.get("freeRolls", 0)))
	var refresh_cost := int(refresh.get("next_refresh_cost", refresh.get("nextRefreshCost", refresh.get("cost", refresh.get("refreshCost", 0)))))
	var stall := Dictionary(snap.get("active_stall", {}))
	var stall_name := String(stall.get("name", "当前商店"))
	var tag_labels: Array[String] = []
	for value in Array(stall.get("tags", [])):
		var label := String(value).strip_edges()
		if label != "":
			tag_labels.append(label)
	var lines := ["摊位：%s" % stall_name]
	if not tag_labels.is_empty():
		lines.append("倾向：%s" % " / ".join(tag_labels))
	lines.append("刷新：%s" % ("免费（剩余%d次）" % free_rolls if free_rolls > 0 else "%d金币" % refresh_cost))
	for value in Array(snap.get("shop_offers", [])).slice(0, 5):
		var offer := Dictionary(value)
		if bool(offer.get("sold", false)):
			continue
		var item_type := String(offer.get("item_type", "宠物"))
		lines.append("%s · %s · %d金币" % [
			String(offer.get("name", offer.get("id", "商品"))),
			item_type if item_type != "宠物" else String(offer.get("quality", "青铜")),
			int(offer.get("price", 0))
		])
		var effect_text := String(offer.get("effect_text", "")).strip_edges()
		if effect_text != "":
			lines.append("  %s" % effect_text)
	return "\n".join(lines)


func _roster_summary(snap: Dictionary) -> String:
	var active := 0
	var bench := 0
	for value in Array(snap.get("roster", [])):
		if bool(Dictionary(value).get("active", false)):
			active += 1
		else:
			bench += 1
	return "队伍%d/4 · 候补%d" % [active, bench]


func _bag_page_count(snap: Dictionary) -> int:
	return max(1, int(ceil(float(_bench_count(snap)) / 5.0)))


func _bag_summary(snap: Dictionary) -> String:
	var page := int(snap.get("ui_bag_page", 0))
	return "候补宠物共%d只，当前展示第%d/%d页。\n点击宠物查看详情，拖拽可上阵、换位或出售。" % [
		_bench_count(snap),
		page + 1,
		_bag_page_count(snap)
	]


func _bench_count(snap: Dictionary) -> int:
	var bench := 0
	for value in Array(snap.get("roster", [])):
		if not bool(Dictionary(value).get("active", false)):
			bench += 1
	return bench


func _reward_summary(snap: Dictionary) -> String:
	var lines := ["点击奖励卡查看属性，再确认选择："]
	for value in Array(snap.get("reward_options", [])):
		var reward := Dictionary(value)
		lines.append("%s · %s · %s" % [
			String(reward.get("name", reward.get("id", "宠物"))),
			String(reward.get("element", "")),
			String(reward.get("quality", ""))
		])
	return "\n".join(lines)


func _terminal_title(phase: String) -> String:
	match phase:
		"battle_end": return "战斗结算"
		"day_end": return "当日结算"
		_: return "本局结束"


func _terminal_summary(snap: Dictionary, phase: String) -> String:
	if phase != "battle_end":
		return "当前金币 %d。" % int(snap.get("coins", 0))
	var result := Dictionary(snap.get("battle_result", {}))
	return "%s · 评级%s\n金币 %d → %d\n回合 %d · %s" % [
		_battle_outcome_label(result),
		String(result.get("grade", "-")),
		int(result.get("gold_from", snap.get("coins", 0))),
		int(result.get("gold_to", snap.get("coins", 0))),
		int(result.get("battle_round", 0)),
		String(result.get("encounter_name", ""))
	]


func _battle_outcome_label(result: Dictionary) -> String:
	if bool(result.get("draw", false)) or String(result.get("code", "")).to_upper() == "DRAW":
		return "平局"
	return "胜利" if bool(result.get("win", false)) else "失败"


func _terminal_command(snap: Dictionary, phase: String) -> Dictionary:
	match phase:
		"battle_end": return {"type": "CONTINUE_AFTER_BATTLE", "label": "继续结算"}
		"day_end": return {"type": "START_NEXT_DAY", "day": int(snap.get("day", 1)) + 1, "label": "下一天"}
		_: return {"type": "NEW_RUN", "label": "重新开局"}


func _on_refresh_pressed() -> void:
	if not _refresh_command.is_empty():
		command_requested.emit(_refresh_command.duplicate(true))


func _on_primary_pressed() -> void:
	if not _primary_command.is_empty():
		var command := _primary_command.duplicate(true)
		command.erase("label")
		command_requested.emit(command)


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.065, 0.04, 0.9)
	style.border_color = Color(0.79, 0.6, 0.28, 0.95)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("ffe8b0"))
	summary_label.add_theme_font_size_override("font_size", 16)
	summary_label.add_theme_color_override("font_color", Color("f2ead7"))
	for button in [refresh_button, primary_button]:
		button.add_theme_font_size_override("font_size", 17)
