extends PanelContainer

signal command_requested(command: Dictionary)

const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")

@onready var title_label: Label = $Margin/Content/Title
@onready var summary_label: Label = $Margin/Content/Summary
@onready var refresh_button: Button = $Margin/Content/Actions/RefreshButton
@onready var primary_button: Button = $Margin/Content/Actions/PrimaryButton

var _refresh_command := {}
var _primary_command := {}
var _pending_snapshot := {}
var _pending_view := &"three_option"
var _feedback_text := ""
var _feedback_success := true


func _ready() -> void:
	RuntimeUiPolicy.install()
	refresh_button.text = RuntimeUiPolicy.text("UI_REFRESH_SHOP")
	primary_button.text = RuntimeUiPolicy.text("UI_CONTINUE")
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
	_pending_snapshot = snap.duplicate(true)
	_pending_view = view
	var phase := String(snap.get("phase", "route"))
	var header := "%s\n%s" % [
		RuntimeUiPolicy.text("UI_DAY_NODE_GOLD", [
			int(snap.get("day", 1)),
			int(snap.get("node_index", 1)),
			int(snap.get("coins", 0)),
		]),
		_roster_summary(snap),
	]
	_refresh_command = {}
	_primary_command = {}
	refresh_button.visible = false
	primary_button.visible = false
	if view == &"bag":
		title_label.text = "%s\n%s" % [header, RuntimeUiPolicy.text("UI_BAG_TITLE")]
		summary_label.text = _with_feedback(_bag_summary(snap))
		var page_count := _bag_page_count(snap)
		if page_count > 1:
			var page := int(snap.get("ui_bag_page", 0))
			_primary_command = {"type": "UI_SET_BAG_PAGE", "page": (page + 1) % page_count, "label": RuntimeUiPolicy.text("UI_BAG_NEXT")}
			primary_button.text = RuntimeUiPolicy.text("UI_BAG_NEXT_PAGE", [page + 1, page_count])
			primary_button.visible = true
	else:
		_render_phase_snapshot(snap, phase, header)
	visible = view != &"battle"


func _render_phase_snapshot(snap: Dictionary, phase: String, header: String) -> void:
	match phase:
		"shop":
			title_label.text = "%s\n%s" % [header, RuntimeUiPolicy.text("UI_SHOP_TITLE")]
			summary_label.text = _with_feedback(_shop_summary(snap))
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
			title_label.text = "%s\n%s" % [header, RuntimeUiPolicy.text("UI_REWARD_TITLE")]
			summary_label.text = _with_feedback(_reward_summary(snap))
		"battle_end", "day_end", "game_over":
			title_label.text = "%s\n%s" % [header, _terminal_title(phase)]
			summary_label.text = _with_feedback(_terminal_summary(snap, phase))
			_primary_command = _terminal_command(snap, phase)
			primary_button.text = String(_primary_command.get("label", RuntimeUiPolicy.text("UI_CONTINUE")))
			primary_button.visible = not _primary_command.is_empty()
		_:
			title_label.text = "%s\n%s" % [header, RuntimeUiPolicy.text("UI_ROUTE_TITLE")]
			summary_label.text = _with_feedback(_route_summary(snap))


func get_summary_text() -> String:
	return "%s\n%s" % [title_label.text, summary_label.text]


func show_command_feedback(message: String, success: bool) -> void:
	_feedback_text = message.strip_edges()
	_feedback_success = success
	if not _pending_snapshot.is_empty():
		render_snapshot(_pending_snapshot, _pending_view)
	elif is_node_ready() and _feedback_text != "":
		summary_label.text = _with_feedback(summary_label.text)


func focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for button in [refresh_button, primary_button]:
		if button != null and button.visible and not button.disabled:
			controls.append(button)
	return controls


func _route_summary(snap: Dictionary) -> String:
	var lines := [RuntimeUiPolicy.text("UI_ROUTE_PROMPT")]
	for value in Array(snap.get("route_options", [])):
		var option := Dictionary(value)
		var kind := _route_kind(option)
		var title := String(option.get("title", option.get("id", "-")))
		var description := String(option.get("desc", "")).strip_edges()
		var benefit := description if description != "" else RuntimeUiPolicy.text("UI_ROUTE_BENEFIT_%s" % kind.to_upper())
		lines.append(RuntimeUiPolicy.text("UI_ROUTE_ENTRY", [
			title,
			RuntimeUiPolicy.text("UI_ROUTE_KIND_%s" % kind.to_upper()),
			benefit,
			RuntimeUiPolicy.text("UI_ROUTE_RISK_%s" % kind.to_upper()),
		]))
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
	var coins := int(snap.get("coins", 0))
	var lines := [RuntimeUiPolicy.text("UI_STALL", [stall_name])]
	if not tag_labels.is_empty():
		lines.append(RuntimeUiPolicy.text("UI_TAGS", [" / ".join(tag_labels)]))
	lines.append(RuntimeUiPolicy.text("UI_REFRESH_FREE", [free_rolls]) if free_rolls > 0 else RuntimeUiPolicy.text("UI_REFRESH_COST", [refresh_cost]))
	for value in Array(snap.get("shop_offers", [])).slice(0, 5):
		var offer := Dictionary(value)
		var name := String(offer.get("name", offer.get("id", "-")))
		if bool(offer.get("sold", false)):
			lines.append(RuntimeUiPolicy.text("UI_OFFER_SOLD", [name]))
			continue
		var item_type := String(offer.get("item_type", "宠物"))
		var label := item_type if item_type != "宠物" else String(offer.get("quality", "-"))
		var price := int(offer.get("price", 0))
		lines.append(RuntimeUiPolicy.text("UI_OFFER_AVAILABLE", [name, label, price]) if coins >= price else RuntimeUiPolicy.text("UI_OFFER_UNAFFORDABLE", [name, label, price, price - coins]))
		var effect_text := String(offer.get("effect_text", "")).strip_edges()
		if effect_text != "":
			lines.append(RuntimeUiPolicy.text("UI_OFFER_EFFECT", [effect_text]))
	return "\n".join(lines)


func _roster_summary(snap: Dictionary) -> String:
	var active := 0
	var bench := 0
	for value in Array(snap.get("roster", [])):
		if bool(Dictionary(value).get("active", false)):
			active += 1
		else:
			bench += 1
	return RuntimeUiPolicy.text("UI_TEAM_BENCH", [active, bench])


func _bag_page_count(snap: Dictionary) -> int:
	return max(1, int(ceil(float(_bench_count(snap)) / 5.0)))


func _bag_summary(snap: Dictionary) -> String:
	var page := int(snap.get("ui_bag_page", 0))
	return RuntimeUiPolicy.text("UI_BAG_SUMMARY", [
		_bench_count(snap),
		page + 1,
		_bag_page_count(snap)
	])


func _bench_count(snap: Dictionary) -> int:
	var bench := 0
	for value in Array(snap.get("roster", [])):
		if not bool(Dictionary(value).get("active", false)):
			bench += 1
	return bench


func _reward_summary(snap: Dictionary) -> String:
	var lines := [RuntimeUiPolicy.text("UI_REWARD_PROMPT")]
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
		"battle_end": return RuntimeUiPolicy.text("UI_TERMINAL_BATTLE")
		"day_end": return RuntimeUiPolicy.text("UI_TERMINAL_DAY")
		_: return RuntimeUiPolicy.text("UI_TERMINAL_GAME")


func _terminal_summary(snap: Dictionary, phase: String) -> String:
	if phase != "battle_end":
		return RuntimeUiPolicy.text("UI_CURRENT_GOLD", [int(snap.get("coins", 0))])
	var result := Dictionary(snap.get("battle_result", {}))
	return RuntimeUiPolicy.text("UI_BATTLE_RESULT", [
		_battle_outcome_label(result),
		String(result.get("grade", "-")),
		int(result.get("gold_from", snap.get("coins", 0))),
		int(result.get("gold_to", snap.get("coins", 0))),
		int(result.get("battle_round", 0)),
		String(result.get("encounter_name", ""))
	])


func _battle_outcome_label(result: Dictionary) -> String:
	if bool(result.get("draw", false)) or String(result.get("code", "")).to_upper() == "DRAW":
		return RuntimeUiPolicy.text("UI_OUTCOME_DRAW")
	return RuntimeUiPolicy.text("UI_OUTCOME_WIN" if bool(result.get("win", false)) else "UI_OUTCOME_LOSS")


func _terminal_command(snap: Dictionary, phase: String) -> Dictionary:
	match phase:
		"battle_end": return {"type": "CONTINUE_AFTER_BATTLE", "label": RuntimeUiPolicy.text("UI_CONTINUE_SETTLEMENT")}
		"day_end": return {"type": "START_NEXT_DAY", "day": int(snap.get("day", 1)) + 1, "label": RuntimeUiPolicy.text("UI_NEXT_DAY")}
		_: return {"type": "NEW_RUN", "label": RuntimeUiPolicy.text("UI_NEW_RUN")}


func _on_refresh_pressed() -> void:
	if not _refresh_command.is_empty():
		command_requested.emit(_refresh_command.duplicate(true))


func _on_primary_pressed() -> void:
	if not _primary_command.is_empty():
		var command := _primary_command.duplicate(true)
		command.erase("label")
		command_requested.emit(command)


func _with_feedback(base_text: String) -> String:
	if _feedback_text == "":
		return base_text
	var key := "UI_RESULT_SUCCESS" if _feedback_success else "UI_RESULT_FAILURE"
	return "%s\n\n%s" % [base_text, RuntimeUiPolicy.text(key, [_feedback_text])]


func _route_kind(option: Dictionary) -> String:
	var explicit := String(option.get("kind", "")).to_lower()
	if ["battle", "shop", "reward", "event", "rest"].has(explicit):
		return explicit
	var searchable := "%s %s" % [String(option.get("id", "")), String(option.get("title", ""))]
	if searchable.to_lower().contains("shop") or searchable.contains("商店"):
		return "shop"
	if searchable.to_lower().contains("battle") or searchable.contains("战斗"):
		return "battle"
	if searchable.to_lower().contains("reward") or searchable.contains("奖励"):
		return "reward"
	if searchable.to_lower().contains("rest") or searchable.contains("休整"):
		return "rest"
	return "event"


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
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 17)
