extends SceneTree

const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")
const ShopPresenterScript := preload("res://core_ui/scripts/shop/presenters/shop_presenter.gd")
const GameScene := preload("res://art/scenes/app/game.tscn")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	RuntimeUiPolicy.install(PackedStringArray(["--locale=zh_CN"]))
	_expect(not RuntimeUiPolicy.parse_developer_tools(PackedStringArray()), "player mode is the default")
	_expect(RuntimeUiPolicy.parse_developer_tools(PackedStringArray(["--developer-tools"])), "developer tools require an explicit switch")
	_expect(RuntimeUiPolicy.parse_locale(PackedStringArray(["--locale=en_US"])) == "en", "English locale aliases normalize")
	_expect(String(ProjectSettings.get_setting("gui/theme/custom_font", "")) == "res://art/images/shared/pets/info_card/fonts/fusion_pixel_zh_hans.ttf", "global font stays on the art-authoritative pixel font")

	var scene := GameScene.instantiate() as Control
	root.add_child(scene)
	await create_timer(1.0).timeout
	var middle := scene
	var view := scene.call("get_three_choice_view") as Control
	var panel := scene.find_child("BazaarInfoPanel", true, false)
	_expect(middle != null and view != null and panel != null, "formal Game, route surface and BazaarInfoPanel load")
	if middle == null or view == null or panel == null:
		_finish(scene)
		return

	_expect(scene.find_child("RunTools", true, false) == null, "player mode does not create save/export tools")
	var debug_button := view.get_node_or_null("MainBG/DebugButton") as Control
	var detail_panel := view.find_child("ArtistPetDetailPanel", true, false)
	var debug_toggle := detail_panel.find_child("DebugToggleButton", true, false) as Control if detail_panel != null else null
	_expect(debug_button == null or not debug_button.visible, "route debug entry is absent or hidden in player mode")
	_expect(debug_toggle == null or not debug_toggle.visible, "pet detail debug entry is absent or hidden in player mode")

	var route_summary := String(panel.call("get_summary_text"))
	_expect(route_summary.contains("收益：") and route_summary.contains("风险："), "route choices explain reward and risk")
	var route_buttons := _enabled_buttons(scene.find_child("Middle_Three_Option", true, false))
	_expect(route_buttons.size() >= 2, "route exposes multiple focusable choices")
	_expect(_has_closed_focus_ring(route_buttons), "route choices have explicit keyboard/gamepad neighbors")

	var state: RefCounted = middle.get("state")
	_expect(state.dispatch({"type": "ENTER_SHOP", "poolId": "night_base", "slots": 5}), "fixture enters shop")
	state.set("coins", 0)
	middle.call("render_current_view")
	await create_timer(0.3).timeout
	var cards := Array(ShopPresenterScript.new().cards(state.snapshot()))
	var first_card := Dictionary(cards[0]) if not cards.is_empty() else {}
	_expect(not first_card.is_empty() and bool(first_card.get("available", false)), "listed shop offer stays readable")
	_expect(not bool(first_card.get("affordable", true)) and not bool(first_card.get("purchasable", true)), "shop ViewModel separates listing from affordability")
	var shop_buttons := _enabled_buttons(scene.find_child("Middle_Shop", true, false))
	_expect(not shop_buttons.is_empty() and _has_closed_focus_ring(shop_buttons), "shop offers remain focusable with explicit neighbors")
	_expect(String(panel.call("get_summary_text")).contains("金币不足"), "shop summary exposes unaffordable state")
	view.call("_show_shop_unavailable_feedback", 0)
	_expect(String(panel.call("get_summary_text")).contains("未完成：") and String(panel.call("get_summary_text")).contains("价格"), "unaffordable action produces visible player feedback")

	var rejected: bool = bool(await view.call("_submit_core_command", Dictionary(first_card.get("command", {}))))
	_expect(not rejected, "authority still rejects an unaffordable purchase")
	_expect(String(panel.call("get_summary_text")).contains("操作") or String(panel.call("get_summary_text")).contains("金币不足"), "authority rejection remains visible outside RunTools")

	RuntimeUiPolicy.install(PackedStringArray(["--locale=en"]))
	panel.call("render_snapshot", state.snapshot(), &"shop")
	var english_summary := String(panel.call("get_summary_text"))
	_expect(english_summary.contains("Shop") and english_summary.contains("Need"), "critical shop dynamic text switches to English")
	RuntimeUiPolicy.install(PackedStringArray(["--locale=zh_CN"]))

	state.set("coins", 999)
	middle.call("render_current_view")
	await create_timer(0.3).timeout
	var keyboard_button := _enabled_buttons(scene.find_child("Middle_Shop", true, false))[0] as BaseButton
	var keyboard_offer := Dictionary(keyboard_button.get_meta("drag_record", {}))
	var accept_event := InputEventAction.new()
	accept_event.action = &"ui_accept"
	accept_event.pressed = true
	keyboard_button.emit_signal("gui_input", accept_event)
	await create_timer(1.0).timeout
	_expect(_offer_is_sold(state.snapshot(), String(keyboard_offer.get("id", ""))), "keyboard/gamepad confirm purchases the focused offer")
	_expect(String(panel.call("get_summary_text")).contains("已购买"), "keyboard purchase reports its result in BazaarInfoPanel")

	_finish(scene)


func _enabled_buttons(container: Node) -> Array[Control]:
	var out: Array[Control] = []
	if container == null:
		return out
	for value in container.find_children("*", "BaseButton", true, false):
		var button := value as BaseButton
		if button != null and button.visible and not button.disabled:
			out.append(button)
	return out


func _has_closed_focus_ring(controls: Array[Control]) -> bool:
	for control in controls:
		if control.focus_mode != Control.FOCUS_ALL:
			return false
		if control.focus_neighbor_left.is_empty() or control.focus_neighbor_right.is_empty() \
				or control.focus_next.is_empty() or control.focus_previous.is_empty():
			return false
	return not controls.is_empty()


func _offer_is_sold(snap: Dictionary, offer_id: String) -> bool:
	for value in Array(snap.get("shop_offers", [])):
		var offer := Dictionary(value)
		if String(offer.get("id", "")) == offer_id:
			return bool(offer.get("sold", false))
	return false


func _finish(scene: Node) -> void:
	if scene != null:
		scene.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("SMOKE_STS2_FULL_INTERACTION_CLOSURE_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_STS2_FULL_INTERACTION_CLOSURE_FAIL: %s" % message)
