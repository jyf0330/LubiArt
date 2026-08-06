extends SceneTree

const LegacyCodeShopViewScript := preload("res://core_ui/scripts/shop/views/legacy_code_shop_view.gd")

var _commands: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	var view := LegacyCodeShopViewScript.new() as Control
	root.add_child(view)
	await process_frame
	view.configure(Callable())
	view.render_snapshot(_fixture_snapshot())
	view.visible = true
	view.command_requested.connect(_on_command_requested)
	await process_frame

	if not _label_contains(view, "元素背包史 · 商店") or not _label_contains(view, "本次可购买 2 件商品"):
		_fail("Standalone Mock should render the code-built shop hierarchy.")
		return
	for command_type in ["BUY_OFFER", "FREEZE_OFFER", "ROLL_SHOP", "APPLY_SHOP_EVENT", "EXIT_SHOP"]:
		var button := _find_command_button(view, command_type)
		if button == null:
			_fail("Missing public command button: %s" % command_type)
			return
		button.emit_signal("pressed")
	if _commands.size() != 5:
		_fail("Standalone Mock should emit exactly five player-intent commands.")
		return
	var actual_types: Array[String] = []
	for command in _commands:
		actual_types.append(String(command.get("type", "")))
	if actual_types != ["BUY_OFFER", "FREEZE_OFFER", "ROLL_SHOP", "APPLY_SHOP_EVENT", "EXIT_SHOP"]:
		_fail("Standalone Mock emitted unexpected command sequence: %s" % [actual_types])
		return
	var source := FileAccess.get_file_as_string("res://core_ui/scripts/shop/views/legacy_code_shop_view.gd")
	for forbidden in ["YsbzsState", ".dispatch(", "GameSession", "core/state"]:
		if source.contains(forbidden):
			_fail("Presentation-only shop source contains forbidden authority reference: %s" % forbidden)
			return
	print("SMOKE_LEGACY_CODE_SHOP_VIEW_OK five public intents")
	if DisplayServer.get_name() == "headless":
		quit(0)


func _fixture_snapshot() -> Dictionary:
	return {
		"phase": "shop",
		"day": 1,
		"node_index": 1,
		"coins": 16,
		"hero_hp": 80,
		"ap": 3,
		"active_stall": {"name": "夜市商人", "slots": 5},
		"shop_refresh": {"free_rolls": 1, "next_refresh_cost": 2, "next_discount": 0},
		"shop_offers": [
			{"id": "offer_fire", "name": "火角鹿", "element": "火", "quality": "青铜", "item_type": "宠物", "role": "输出", "max_hp": 22, "atk": 14, "shield": 0, "shape": "形状01", "range": "直线/1格", "price": 2, "sold": false, "frozen": false},
			{"id": "offer_relic", "name": "青铜护符", "element": "无", "quality": "青铜", "item_type": "遗物", "description": "购买后立即生效", "price": 3, "sold": false, "frozen": false},
		],
		"inventory": {"active_count": 1, "max_active": 4, "bench_count": 0, "max_bench": 24},
		"roster": [{"id": "pal_001", "name": "灰尾狸", "quality": "青铜", "active": true}],
		"shop_events": [{"id": "evt_fire", "name": "火元素补货", "cost": "金币-1", "gain": "刷新火系货架"}],
	}


func _on_command_requested(command: Dictionary) -> void:
	_commands.append(command.duplicate(true))


func _find_command_button(parent: Node, command_type: String) -> BaseButton:
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button != null and String(Dictionary(button.get_meta("command", {})).get("type", "")) == command_type:
			return button
	return null


func _label_contains(parent: Node, expected: String) -> bool:
	for node in parent.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text.contains(expected):
			return true
	return false


func _fail(message: String) -> void:
	push_error("SMOKE_LEGACY_CODE_SHOP_VIEW_FAIL: %s" % message)
	quit(1)
