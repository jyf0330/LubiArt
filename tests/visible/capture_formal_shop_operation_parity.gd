extends SceneTree

const MAIN_SCENE := preload("res://art/scenes/app/game.tscn")
const SessionFactoryScript := preload("res://session/session_factory.gd")
const WINDOW_SIZE := Vector2i(1920, 1080)
const OPTION_ID := "node_shop_basic"
const RUN_SEED := "shop-art-roundtrip-v1"
const NEUTRAL_MOUSE_POSITION := Vector2(1850.0, 1030.0)
const FIRST_OFFER_HOVER_POSITION := Vector2(578.0, 454.0)
const SECOND_OFFER_HOVER_POSITION := Vector2(902.0, 454.0)
const THIRD_OFFER_HOVER_POSITION := Vector2(1228.0, 470.0)
const FOURTH_EMPTY_SLOT_POSITION := Vector2(578.0, 704.0)
const FIFTH_EMPTY_SLOT_POSITION := Vector2(1228.0, 704.0)
const ENTRY_SECOND_EMPTY_PARTY_SLOT_POSITION := Vector2(820.0, 878.0)
const ENTRY_FOURTH_EMPTY_PARTY_SLOT_POSITION := Vector2(1176.0, 878.0)
const ENTRY_THIRD_EMPTY_PARTY_SLOT_POSITION := Vector2(996.0, 878.0)
const BAG_BUTTON_POSITION := Vector2(430.0, 892.0)
const COIN_PANEL_SAFE_POSITION := Vector2(1388.0, 930.0)
const COIN_EXIT_OVERLAP_POSITION := Vector2(1412.0, 930.0)
const EXIT_TRANSPARENT_GAP_POSITION := Vector2(1544.0, 500.0)

var _output_dir := ""
var _expected_project_root := ""
var _project_root := ""
var _git_root := ""
var _failed := false
var _game: Node = null
var _captures: Array = []
var _refresh_settle_frames := -1
var _paid_refresh_settle_frames := -1
var _exit_settle_frames := -1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = _argument_value("--output-dir=")
	_expected_project_root = _argument_value("--expected-project-root=").trim_suffix("/").simplify_path()
	_project_root = ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path()
	_git_root = _find_git_root(_project_root)
	_expect(_output_dir != "", "output directory is required")
	_expect(_expected_project_root != "", "expected project root is required")
	_expect(_project_root == _expected_project_root, "res root matches the expected formal project")
	_expect(_git_root == _project_root, "Git root and res root are identical")
	if _failed:
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_output_dir)
	DisplayServer.window_set_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE

	_game = MAIN_SCENE.instantiate()
	var creation := Dictionary(SessionFactoryScript.create_local_result({
		"run_seed": RUN_SEED,
		"command_scope": "developer",
	}))
	_expect(bool(creation.get("ok", false)), "fixed-seed formal LocalGameSession initializes")
	var session := creation.get("session") as RefCounted
	_expect(session != null, "fixed-seed formal LocalGameSession exists")
	if _failed:
		_finish()
		return
	_game.call("set_game_session", session)
	root.add_child(_game)
	await _settle(36)
	var route_button := _find_command_button(_game, "CHOOSE_ROUTE", OPTION_ID)
	_expect(route_button != null, "formal route exposes node_shop_basic")
	if route_button == null:
		_finish()
		return
	await _click(route_button)
	var shop := await _wait_for_shop(24)
	if shop == null:
		var route_confirm := _game.find_child("ExitButton", true, false) as TextureButton
		_expect(route_confirm != null, "route provides confirmation when selection is not immediate")
		if route_confirm != null:
			await _click(route_confirm)
			shop = await _wait_for_shop()
	_expect(shop != null, "real route pointer flow opens the formal shop view")
	if shop == null:
		_finish()
		return
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _release_focus()
	_expect(_enabled_command_buttons(shop, "BUY_OFFER").size() == 3, "formal basic shop exposes three real offers")
	await _capture("01_shop_entry", "进入基础商店")
	if not OS.get_cmdline_user_args().has("--diagnostic-full"):
		await _run_compact_acceptance(shop)
		return
	await _move_mouse(ENTRY_SECOND_EMPTY_PARTY_SLOT_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal entry second empty party aperture exposes no occupied party identity")
	await _capture("01b_entry_second_empty_party_slot_hover", "悬停入口第二个空队伍槽")
	var entry_empty_party_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _mouse_button(ENTRY_SECOND_EMPTY_PARTY_SLOT_POSITION, true)
	await process_frame
	await _mouse_button(ENTRY_SECOND_EMPTY_PARTY_SLOT_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == entry_empty_party_snapshot_before_click, "clicking the formal entry second empty party aperture leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal entry second empty party aperture click leaves no occupied party identity")
	await _capture("01b2_entry_second_empty_party_slot_click", "点击入口第二个空队伍槽")
	await _move_mouse(ENTRY_FOURTH_EMPTY_PARTY_SLOT_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal entry fourth empty party aperture exposes no occupied party identity")
	await _capture("01c_entry_fourth_empty_party_slot_hover", "悬停入口第四个空队伍槽")
	var entry_fourth_empty_party_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _mouse_button(ENTRY_FOURTH_EMPTY_PARTY_SLOT_POSITION, true)
	await process_frame
	await _mouse_button(ENTRY_FOURTH_EMPTY_PARTY_SLOT_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == entry_fourth_empty_party_snapshot_before_click, "clicking the formal entry fourth empty party aperture leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal entry fourth empty party aperture click leaves no occupied party identity")
	await _capture("01c2_entry_fourth_empty_party_slot_click", "点击入口第四个空队伍槽")
	await _move_mouse(ENTRY_THIRD_EMPTY_PARTY_SLOT_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal entry third empty party aperture exposes no occupied party identity")
	await _capture("01d_entry_third_empty_party_slot_hover", "悬停入口第三个空队伍槽")
	var entry_third_empty_party_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _mouse_button(ENTRY_THIRD_EMPTY_PARTY_SLOT_POSITION, true)
	await process_frame
	await _mouse_button(ENTRY_THIRD_EMPTY_PARTY_SLOT_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == entry_third_empty_party_snapshot_before_click, "clicking the formal entry third empty party aperture leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal entry third empty party aperture click leaves no occupied party identity")
	await _capture("01d2_entry_third_empty_party_slot_click", "点击入口第三个空队伍槽")
	var coin_panel := shop.find_child("CoinPanelArt", true, false) as Control
	var entry_exit_button := shop.find_child("ExitShopButton", true, false) as BaseButton
	_expect(coin_panel != null and coin_panel.get_global_rect().has_point(COIN_PANEL_SAFE_POSITION), "formal coin panel contains the safe parity pointer")
	_expect(entry_exit_button != null and not entry_exit_button.get_global_rect().has_point(COIN_PANEL_SAFE_POSITION), "formal coin safe parity pointer stays outside the exit rectangle")
	await _move_mouse(COIN_PANEL_SAFE_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal coin safe area exposes no semantic action")
	await _capture("01e_entry_coin_panel_hover", "悬停金币牌安全区")
	var entry_coin_panel_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _mouse_button(COIN_PANEL_SAFE_POSITION, true)
	await process_frame
	await _mouse_button(COIN_PANEL_SAFE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == entry_coin_panel_snapshot_before_click, "clicking the formal coin safe area leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal coin safe area click leaves no semantic identity")
	await _capture("01e2_entry_coin_panel_click", "点击金币牌安全区")
	_expect(coin_panel.get_global_rect().has_point(COIN_EXIT_OVERLAP_POSITION), "formal coin panel contains the shared overlap pointer")
	_expect(entry_exit_button.get_global_rect().has_point(COIN_EXIT_OVERLAP_POSITION), "formal exit rectangle contains the shared overlap pointer")
	await _move_mouse(COIN_EXIT_OVERLAP_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal coin panel blocks the covered exit edge from exposing an exit action")
	await _capture("01f_entry_coin_exit_overlap_hover", "悬停金币牌与退出牌交叠边缘")
	var entry_coin_exit_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _mouse_button(COIN_EXIT_OVERLAP_POSITION, true)
	await process_frame
	await _mouse_button(COIN_EXIT_OVERLAP_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == entry_coin_exit_snapshot_before_click, "clicking the formal coin-covered exit edge leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal coin-covered exit edge click leaves no exit identity")
	await _capture("01f2_entry_coin_exit_overlap_click", "点击金币牌与退出牌交叠边缘")
	_expect(entry_exit_button.get_global_rect().has_point(EXIT_TRANSPARENT_GAP_POSITION), "formal exit rectangle contains the shared transparent-gap pointer")
	_expect(not coin_panel.get_global_rect().has_point(EXIT_TRANSPARENT_GAP_POSITION), "formal exit transparent-gap pointer stays outside the coin panel")
	await _move_mouse(EXIT_TRANSPARENT_GAP_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal exit PNG transparent gap exposes no exit action")
	await _capture("01g_entry_exit_transparent_gap_hover", "悬停退出牌透明空隙")
	var entry_exit_transparent_gap_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _mouse_button(EXIT_TRANSPARENT_GAP_POSITION, true)
	await process_frame
	await _mouse_button(EXIT_TRANSPARENT_GAP_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == entry_exit_transparent_gap_snapshot_before_click, "clicking the formal exit PNG transparent gap leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal exit PNG transparent-gap click leaves no exit identity")
	await _capture("01g2_entry_exit_transparent_gap_click", "点击退出牌透明空隙")

	var buy_buttons := _enabled_command_buttons(shop, "BUY_OFFER")
	var first_buy := buy_buttons[0] as BaseButton
	await _move_mouse(first_buy.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("02_offer_hover", "悬停第一件商品")
	var first_offer_snapshot_before_press := JSON.stringify(_game.state.snapshot())
	await _mouse_button(FIRST_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == first_offer_snapshot_before_press, "formal first-offer mouse-down does not execute BUY_OFFER before release")
	_expect(first_buy.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal first-offer button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "formal first offer remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_001", "formal first offer keeps the synchronized offer identity while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "formal first offer receives action focus while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_001", "formal first offer receives synchronized offer focus while held")
	await _capture("02a_entry_first_offer_pressed", "按下第一件商品但尚未松开")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == first_offer_snapshot_before_press, "formal first-offer press cancelled outside the button leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal first-offer cancelled press leaves no purchase identity")
	var second_buy := buy_buttons[1] as BaseButton
	await _move_mouse(second_buy.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("02_entry_second_offer_hover", "悬停入口第二件商品")
	var second_offer_snapshot_before_press := JSON.stringify(_game.state.snapshot())
	await _mouse_button(SECOND_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == second_offer_snapshot_before_press, "formal second-offer mouse-down does not execute BUY_OFFER before release")
	_expect(second_buy.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal second-offer button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "formal second offer remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "formal second offer keeps the synchronized offer identity while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "formal second offer receives action focus while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "formal second offer receives synchronized offer focus while held")
	await _capture("02a2_entry_second_offer_pressed", "按下第二件商品但尚未松开")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == second_offer_snapshot_before_press, "formal second-offer press cancelled outside the button leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal second-offer cancelled press leaves no purchase identity")
	var third_buy := buy_buttons[2] as BaseButton
	_expect(third_buy.get_global_rect().has_point(THIRD_OFFER_HOVER_POSITION), "formal entry third offer contains the shared parity pointer")
	await _move_mouse(THIRD_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("02_entry_third_offer_hover", "悬停入口第三件商品")
	var third_offer_snapshot_before_press := JSON.stringify(_game.state.snapshot())
	await _mouse_button(THIRD_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == third_offer_snapshot_before_press, "formal third-offer mouse-down does not execute BUY_OFFER before release")
	_expect(third_buy.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal third-offer button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "formal third offer remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_003", "formal third offer keeps the synchronized offer identity while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "formal third offer receives action focus while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_003", "formal third offer receives synchronized offer focus while held")
	await _capture("02a3_entry_third_offer_pressed", "按下第三件商品但尚未松开")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == third_offer_snapshot_before_press, "formal third-offer press cancelled outside the button leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal third-offer cancelled press leaves no purchase identity")

	await _move_mouse(FOURTH_EMPTY_SLOT_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal fourth empty shelf aperture exposes no stale purchase action")
	await _capture("02c_entry_fourth_empty_slot_hover", "指针移入入口第四个空货孔")
	var fourth_empty_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _mouse_button(FOURTH_EMPTY_SLOT_POSITION, true)
	await process_frame
	await _mouse_button(FOURTH_EMPTY_SLOT_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == fourth_empty_snapshot_before_click, "clicking the formal fourth empty shelf aperture leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal fourth empty shelf aperture click leaves no purchase identity")
	await _capture("02c2_entry_fourth_empty_slot_click", "点击入口第四个空货孔")
	await _move_mouse(FIFTH_EMPTY_SLOT_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal fifth empty shelf aperture exposes no stale purchase action")
	await _capture("02d_entry_fifth_empty_slot_hover", "指针移入入口第五个空货孔")
	var fifth_empty_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _mouse_button(FIFTH_EMPTY_SLOT_POSITION, true)
	await process_frame
	await _mouse_button(FIFTH_EMPTY_SLOT_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == fifth_empty_snapshot_before_click, "clicking the formal fifth empty shelf aperture leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal fifth empty shelf aperture click leaves no purchase identity")
	await _capture("02d2_entry_fifth_empty_slot_click", "点击入口第五个空货孔")

	var refresh := _find_command_button(shop, "ROLL_SHOP")
	_expect(refresh != null, "formal shop exposes refresh")
	var refresh_position := refresh.get_global_rect().get_center()
	await _move_mouse(refresh_position)
	await _settle(8)
	await _release_focus()
	await _capture("02b_refresh_hover", "悬停刷新铃但不点击")
	var refresh_snapshot_before_press := JSON.stringify(_game.state.snapshot())
	await _mouse_button(refresh_position, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == refresh_snapshot_before_press, "formal refresh mouse-down does not execute ROLL_SHOP before release")
	_expect(refresh.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal refresh button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "ROLL_SHOP", "formal refresh remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "ROLL_SHOP", "formal refresh receives focus while held")
	await _capture("02b2_refresh_pressed", "按下刷新铃但尚未松开")
	await _mouse_button(refresh_position, false)
	await _settle(4)
	var curtain := shop.find_child("RefreshCurtain", true, false) as TextureRect
	_expect(curtain != null and curtain.visible, "formal refresh curtain is visible during the operation")
	await _release_focus()
	await _capture("03_refresh_curtain", "点击刷新后的红帘过程")
	_refresh_settle_frames = await _wait_for_control_hidden(curtain, 120)
	_expect(_refresh_settle_frames >= 0, "formal refresh curtain clears within 120 frames")
	if _refresh_settle_frames < 0:
		_finish()
		return
	_expect(not refresh.disabled, "formal refresh action unlocks after the curtain clears")
	_expect(_enabled_command_buttons(shop, "BUY_OFFER").size() == 3, "formal refresh keeps three offers")
	await _release_focus()
	await _capture("04_refresh_complete", "刷新动画完成")

	buy_buttons = _enabled_command_buttons(shop, "BUY_OFFER")
	_expect(buy_buttons.size() == 3, "formal free refresh exposes three offers")
	var refreshed_first_buy := buy_buttons[0] as BaseButton
	_expect(refreshed_first_buy.get_global_rect().has_point(FIRST_OFFER_HOVER_POSITION), "formal refreshed first offer contains the shared parity pointer")
	await _move_mouse(FIRST_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("04a_refresh_first_offer_hover", "悬停首次刷新后的第一件商品")
	var refreshed_second_buy := buy_buttons[1] as BaseButton
	_expect(refreshed_second_buy.get_global_rect().has_point(SECOND_OFFER_HOVER_POSITION), "formal refreshed second offer contains the shared parity pointer")
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("04b_refresh_second_offer_hover", "悬停首次刷新后的第二件商品")
	var refreshed_third_buy := buy_buttons[2] as BaseButton
	_expect(refreshed_third_buy.get_global_rect().has_point(THIRD_OFFER_HOVER_POSITION), "formal refreshed third offer contains the shared parity pointer")
	await _move_mouse(THIRD_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("04c_refresh_third_offer_hover", "悬停首次刷新后的第三件商品")
	first_buy = buy_buttons[0] as BaseButton
	var purchase_id := String(Dictionary(first_buy.get_meta("command", {})).get("offer_id", ""))
	var coins_before_purchase := int(Dictionary(_game.state.snapshot()).get("coins", 0))
	await _click(first_buy)
	await _settle(24)
	var purchased_snapshot := Dictionary(_game.state.snapshot())
	_expect(purchase_id != "" and _offer_is_sold(purchased_snapshot, purchase_id), "real click marks the captured first offer sold")
	_expect(int(purchased_snapshot.get("coins", 0)) < coins_before_purchase, "real purchase deducts formal coins")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _release_focus()
	await _capture("05_purchase_complete", "购买第一件商品完成")

	var party_slot := shop.find_child("PartySlotButton_0", true, false) as BaseButton
	_expect(party_slot != null, "formal shop exposes the first occupied party slot")
	await _move_mouse(party_slot.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("06_party_hover", "悬停第一名队伍宠物")
	var first_party_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _click(party_slot)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == first_party_snapshot_before_click, "clicking the first formal party slot leaves the authoritative snapshot unchanged")
	await _capture("06a_party_first_click", "点击第一名队伍宠物")
	var second_party_slot := shop.find_child("PartySlotButton_1", true, false) as BaseButton
	_expect(second_party_slot != null, "formal shop exposes the second occupied party slot")
	await _move_mouse(second_party_slot.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("06b_party_second_hover", "悬停第二名队伍宠物")
	var second_party_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _click(second_party_slot)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == second_party_snapshot_before_click, "clicking a formal party slot leaves the authoritative snapshot unchanged")
	await _capture("06c_party_second_click", "点击第二名队伍宠物")

	var bag_button := shop.find_child("ShopBagButton", true, false) as BaseButton
	_expect(bag_button != null, "formal shop exposes the shared bag action")
	_expect(bag_button.get_global_rect().has_point(BAG_BUTTON_POSITION), "formal closed bag contains the shared parity pointer")
	await _move_mouse(BAG_BUTTON_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("06d_bag_closed_hover", "悬停关闭态宝箱")
	var bag_snapshot_before_press := JSON.stringify(_game.state.snapshot())
	var bag_overlay := bag_button.get_parent().get_node("ShopBagOverlay") as Control
	_expect(bag_overlay != null and not bag_overlay.visible, "formal bag overlay starts hidden before the held-close probe")
	await _mouse_button(BAG_BUTTON_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == bag_snapshot_before_press, "formal closed-bag mouse-down leaves the authoritative snapshot unchanged")
	_expect(bag_overlay != null and not bag_overlay.visible, "formal closed-bag mouse-down does not open the bag before release")
	_expect(bag_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal closed bag exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "TOGGLE_BAG", "formal closed bag remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "TOGGLE_BAG", "formal closed bag receives focus while held")
	await _capture("06d2_bag_closed_pressed", "按下关闭态宝箱但尚未松开")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(4)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == bag_snapshot_before_press, "formal closed-bag cancel gesture leaves the authoritative snapshot unchanged")
	_expect(bag_overlay != null and not bag_overlay.visible, "formal closed-bag cancel gesture keeps the bag closed")
	await _click(bag_button)
	await _release_focus()
	await _capture("07_bag_open", "点击宝箱打开背包")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("07a_bag_open_hover_cleared", "鼠标移出打开态宝箱")
	await _move_mouse(BAG_BUTTON_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("07a2_bag_open_hover", "重新悬停打开态宝箱")
	var open_bag_snapshot_before_press := JSON.stringify(_game.state.snapshot())
	_expect(bag_overlay != null and bag_overlay.visible, "formal bag overlay remains visible before the held-open probe")
	await _mouse_button(BAG_BUTTON_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == open_bag_snapshot_before_press, "formal open-bag mouse-down leaves the authoritative snapshot unchanged")
	_expect(bag_overlay != null and bag_overlay.visible, "formal open-bag mouse-down does not close the bag before release")
	_expect(bag_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal open bag exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "TOGGLE_BAG", "formal open bag remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "TOGGLE_BAG", "formal open bag receives focus while held")
	await _capture("07a3_bag_open_pressed", "按下打开态宝箱但尚未松开")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(4)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == open_bag_snapshot_before_press, "formal open-bag cancel gesture leaves the authoritative snapshot unchanged")
	_expect(bag_overlay != null and bag_overlay.visible, "formal open-bag cancel gesture keeps the bag open")
	await _move_mouse(Vector2(628.0, 496.0))
	await _settle(8)
	await _release_focus()
	await _capture("07b_empty_bag_slot_hover", "悬停空背包第一槽")
	var empty_bag_slot := shop.find_child("BagSlotButton_0", true, false) as BaseButton
	_expect(empty_bag_slot != null and not empty_bag_slot.has_meta("bag_record"), "formal first bag slot is empty before the no-op click probe")
	var empty_bag_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _click(empty_bag_slot)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == empty_bag_snapshot_before_click, "clicking an empty formal bag slot leaves the authoritative snapshot unchanged")
	await _capture("07c_empty_bag_slot_click", "点击空背包第一槽")
	var eighth_empty_bag_slot := shop.find_child("BagSlotButton_7", true, false) as BaseButton
	_expect(eighth_empty_bag_slot != null and eighth_empty_bag_slot.get_global_rect() == Rect2(1106.0, 601.0, 154.0, 146.0), "formal eighth bag slot keeps the far authored rectangle")
	await _move_mouse(Vector2(1183.0, 674.0))
	await _settle(8)
	await _release_focus()
	await _capture("07d_empty_bag_eighth_slot_hover", "悬停空背包第八槽")
	await _click(bag_button)
	await _release_focus()
	await _capture("08_bag_closed", "再次点击宝箱关闭背包")

	buy_buttons = _enabled_command_buttons(shop, "BUY_OFFER")
	_expect(buy_buttons.size() == 2, "two unsold formal offers remain after the first purchase")
	await _click(buy_buttons[0] as BaseButton)
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _release_focus()
	var second_purchased_snapshot := Dictionary(_game.state.snapshot())
	_expect(Array(second_purchased_snapshot.get("roster", [])).size() == 3, "second formal purchase adds the third roster record")
	await _capture("09_second_purchase", "购买第二件商品完成")

	buy_buttons = _enabled_command_buttons(shop, "BUY_OFFER")
	_expect(buy_buttons.size() == 1, "one unsold formal offer remains after the second purchase")
	await _click(buy_buttons[0] as BaseButton)
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _release_focus()
	var party_full_snapshot := Dictionary(_game.state.snapshot())
	_expect(_active_roster_count(party_full_snapshot) == 4, "third formal purchase fills the four-member party")
	await _capture("10_party_full_purchase", "购买第三件商品填满队伍")
	var third_party_slot := shop.find_child("PartySlotButton_2", true, false) as BaseButton
	_expect(third_party_slot != null, "formal shop exposes the third occupied party slot")
	await _move_mouse(third_party_slot.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("10b_party_third_hover", "悬停第三名队伍宠物")
	var third_party_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _click(third_party_slot)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == third_party_snapshot_before_click, "clicking the third formal party slot leaves the authoritative snapshot unchanged")
	await _capture("10b2_party_third_click", "点击第三名队伍宠物")
	var fourth_party_slot := shop.find_child("PartySlotButton_3", true, false) as BaseButton
	_expect(fourth_party_slot != null, "formal shop exposes the fourth occupied party slot")
	await _move_mouse(fourth_party_slot.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("10c_party_fourth_hover", "悬停第四名队伍宠物")
	var fourth_party_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _click(fourth_party_slot)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == fourth_party_snapshot_before_click, "clicking the fourth formal party slot leaves the authoritative snapshot unchanged")
	await _capture("10c2_party_fourth_click", "点击第四名队伍宠物")

	await _move_mouse(refresh_position)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "ROLL_SHOP", "formal paid refresh hover exposes the refresh action")
	await _capture("10d_paid_refresh_hover", "悬停付费刷新铃但不点击")
	var paid_refresh_snapshot_before_press := JSON.stringify(_game.state.snapshot())
	await _mouse_button(refresh_position, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == paid_refresh_snapshot_before_press, "formal paid refresh mouse-down does not execute ROLL_SHOP before release")
	_expect(refresh.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal paid refresh button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "ROLL_SHOP", "formal paid refresh remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "ROLL_SHOP", "formal paid refresh receives focus while held")
	await _capture("10d2_paid_refresh_pressed", "按下付费刷新铃但尚未松开")
	await _mouse_button(refresh_position, false)
	await _settle(4)
	_expect(curtain.visible, "formal paid refresh curtain is visible during the operation")
	await _release_focus()
	await _capture("11_paid_refresh_curtain", "点击付费刷新后的红帘过程")
	_paid_refresh_settle_frames = await _wait_for_control_hidden(curtain, 120)
	_expect(_paid_refresh_settle_frames >= 0, "formal paid refresh curtain clears within 120 frames")
	if _paid_refresh_settle_frames < 0:
		_finish()
		return
	_expect(not refresh.disabled, "formal paid refresh unlocks after the curtain clears")
	await _release_focus()
	await _capture("12_paid_refresh_complete", "付费刷新动画完成")

	buy_buttons = _enabled_command_buttons(shop, "BUY_OFFER")
	_expect(buy_buttons.size() == 3, "paid formal refresh exposes three new offers")
	var paid_first_buy := buy_buttons[0] as BaseButton
	_expect(paid_first_buy.get_global_rect().has_point(FIRST_OFFER_HOVER_POSITION), "formal paid first offer contains the shared parity pointer")
	await _move_mouse(FIRST_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("12a_paid_refresh_first_offer_hover", "悬停付费刷新后的第一件商品")
	var paid_second_buy := buy_buttons[1] as BaseButton
	_expect(paid_second_buy.get_global_rect().has_point(SECOND_OFFER_HOVER_POSITION), "formal paid second offer contains the shared parity pointer")
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("12b_paid_refresh_second_offer_hover", "悬停付费刷新后的第二件商品")
	var paid_third_buy := buy_buttons[2] as BaseButton
	_expect(paid_third_buy.get_global_rect().has_point(THIRD_OFFER_HOVER_POSITION), "formal paid third offer contains the shared parity pointer")
	await _move_mouse(THIRD_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("12c_paid_refresh_third_offer_hover", "悬停付费刷新后的第三件商品")
	await _click(buy_buttons[0] as BaseButton)
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _release_focus()
	var bag_purchased_snapshot := Dictionary(_game.state.snapshot())
	_expect(_active_roster_count(bag_purchased_snapshot) == 4 and _inactive_roster_count(bag_purchased_snapshot) == 1, "fifth formal purchase enters the bag")
	await _capture("13_bag_pet_purchase", "购买第五只宠物进入背包")

	await _click(bag_button)
	await _release_focus()
	await _capture("14_bag_with_pet_open", "打开已有宠物的背包")
	var bag_pet := shop.find_child("BagPet_0", true, false) as Control
	_expect(bag_pet != null, "formal bag renders the captured inactive pet")
	if bag_pet != null:
		await _move_mouse(bag_pet.get_global_rect().get_center())
		await _settle(8)
		await _release_focus()
		await _capture("15_bag_pet_hover", "悬停背包第一只宠物")
	var occupied_bag_first_slot := shop.find_child("BagSlotButton_0", true, false) as BaseButton
	var mixed_bag_eighth_slot := shop.find_child("BagSlotButton_7", true, false) as BaseButton
	_expect(occupied_bag_first_slot != null and occupied_bag_first_slot.has_meta("bag_record"), "formal mixed bag keeps the occupied first slot record")
	_expect(mixed_bag_eighth_slot != null and not mixed_bag_eighth_slot.has_meta("bag_record"), "formal mixed bag keeps the eighth slot empty and interactive")
	await _move_mouse(Vector2(1183.0, 674.0))
	await _settle(8)
	await _release_focus()
	await _capture("15b_bag_pet_eighth_empty_slot_hover", "已有宠物时悬停背包第八空槽")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(8)
	await _release_focus()
	var mixed_bag_highlight := shop.find_child("BagSlotHoverHighlight", true, false) as CanvasItem
	_expect(mixed_bag_highlight != null and not mixed_bag_highlight.visible, "formal bag highlight clears after the pointer exits every slot")
	await _capture("15c_bag_hover_cleared", "移出背包清除槽高亮")
	var occupied_bag_snapshot_before_click := JSON.stringify(_game.state.snapshot())
	await _click(occupied_bag_first_slot)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == occupied_bag_snapshot_before_click, "clicking an occupied formal bag slot leaves the authoritative snapshot unchanged")
	_expect(mixed_bag_highlight != null and mixed_bag_highlight.visible, "formal occupied bag slot remains highlighted after click")
	await _capture("15d_bag_pet_click", "点击背包第一只宠物")
	await _click(bag_button)
	await _release_focus()
	await _capture("16_bag_with_pet_closed", "关闭已有宠物的背包")

	var exit_button := _find_command_button(shop, "EXIT_SHOP")
	_expect(exit_button != null, "formal shop exposes exit")
	var exit_position := exit_button.get_global_rect().get_center()
	await _move_mouse(exit_position)
	await _settle(8)
	await _release_focus()
	await _capture("17_exit_hover", "悬停商店退出牌")
	var exit_snapshot_before_press := JSON.stringify(_game.state.snapshot())
	await _mouse_button(exit_position, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == exit_snapshot_before_press, "formal exit mouse-down does not execute EXIT_SHOP before release")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal exit button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "EXIT_SHOP", "formal exit remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "formal exit receives focus while held")
	await _capture("17b_exit_pressed", "按下退出牌但尚未松开")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(8)
	_expect(shop.visible, "formal exit remains visible while the held pointer is outside")
	_expect(JSON.stringify(_game.state.snapshot()) == exit_snapshot_before_press, "moving the held formal exit pointer outside leaves the authoritative snapshot unchanged")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_NORMAL, "formal exit returns to its normal draw mode while held outside")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal exit held outside clears the hovered action")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "formal exit keeps focus while held outside")
	await _capture("17b2_exit_pressed_pointer_outside", "按住退出牌并移出")
	await _move_mouse(exit_position)
	await _settle(8)
	_expect(shop.visible, "formal exit remains visible when the held pointer re-enters")
	_expect(JSON.stringify(_game.state.snapshot()) == exit_snapshot_before_press, "re-entering the held formal exit leaves the authoritative snapshot unchanged")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal exit restores its pressed draw mode when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "EXIT_SHOP", "formal exit restores the hovered action when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "formal exit keeps focus when the held pointer re-enters")
	await _capture("17b3_exit_pressed_pointer_reentered", "按住退出牌移出后重新移入")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(8)
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_NORMAL, "formal exit returns to normal before the re-entered press is cancelled outside")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal exit clears hover again before the re-entered press is cancelled outside")
	_expect(shop.visible, "formal exit remains visible when the re-entered held pointer moves outside again")
	_expect(JSON.stringify(_game.state.snapshot()) == exit_snapshot_before_press, "moving the re-entered held formal exit pointer outside again leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "formal exit keeps focus when the re-entered held pointer moves outside again")
	await _capture("17b4_exit_pressed_pointer_outside_again", "按住退出牌重新移出但尚未松开")
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(8)
	await _release_focus()
	_expect(shop.visible, "formal exit remains visible after a held pointer moves away before release")
	_expect(JSON.stringify(_game.state.snapshot()) == exit_snapshot_before_press, "cancelling the formal exit press leaves the authoritative snapshot unchanged")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_NORMAL, "formal exit returns to its normal draw mode after a cancelled press")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal exit cancel clears the hovered action")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "formal exit cancel clears focus before capture")
	await _capture("17c_exit_press_cancelled", "移出退出牌并松开取消")
	await _move_mouse(exit_position)
	await _settle(8)
	var exit_snapshot_before_repress := JSON.stringify(_game.state.snapshot())
	await _mouse_button(exit_position, true)
	await _settle(2)
	_expect(shop.visible, "formal shop remains visible while the exit is pressed again after cancellation")
	_expect(JSON.stringify(_game.state.snapshot()) == exit_snapshot_before_repress, "formal exit repress does not execute EXIT_SHOP before release")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal exit restores its pressed draw mode on a new press after cancellation")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "EXIT_SHOP", "formal exit is hovered on a new press after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "formal exit receives focus on a new press after cancellation")
	await _capture("17d_exit_repressed_after_cancel", "取消后再次按住退出牌")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(8)
	_expect(shop.visible, "formal shop remains visible when the new exit press moves outside after cancellation")
	_expect(JSON.stringify(_game.state.snapshot()) == exit_snapshot_before_repress, "moving the new formal exit press outside after cancellation leaves the authoritative snapshot unchanged")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_NORMAL, "formal exit returns to normal when the new press moves outside after cancellation")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal exit clears hover when the new press moves outside after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "formal exit keeps focus when the new press moves outside after cancellation")
	await _capture("17e_exit_repressed_pointer_outside", "取消后再次按住退出牌并移出")
	await _move_mouse(exit_position)
	await _settle(8)
	_expect(shop.visible, "formal shop remains visible when the new exit press re-enters after cancellation")
	_expect(JSON.stringify(_game.state.snapshot()) == exit_snapshot_before_repress, "re-entering the new formal exit press after cancellation leaves the authoritative snapshot unchanged")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal exit restores pressed mode when the new press re-enters after cancellation")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "EXIT_SHOP", "formal exit restores hover when the new press re-enters after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "formal exit keeps focus when the new press re-enters after cancellation")
	await _capture("17f_exit_repressed_pointer_reentered", "取消后再次按住移出后重新移入")
	await _mouse_button(exit_position, false)
	_exit_settle_frames = await _wait_for_shop_hidden(shop)
	_expect(_exit_settle_frames >= 0, "formal exit hides the shop and returns to route within 240 frames")
	await _capture("18_exit_to_route", "退出商店返回路线")
	var reentry_route_button := _find_route_button_by_kind(_game, "shop")
	_expect(reentry_route_button != null, "formal route exposes a current node-2 shop after leaving the first shop")
	if reentry_route_button == null:
		_finish()
		return
	await _click(reentry_route_button)
	var reentered_shop := await _wait_for_shop(24)
	if reentered_shop == null:
		var reentry_confirm := _game.find_child("ExitButton", true, false) as TextureButton
		_expect(reentry_confirm != null, "formal route provides confirmation when shop re-entry is not immediate")
		if reentry_confirm != null:
			await _click(reentry_confirm)
			reentered_shop = await _wait_for_shop()
	_expect(reentered_shop != null, "real route pointer flow re-enters the formal shop after exit")
	if reentered_shop == null:
		_finish()
		return
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _release_focus()
	_expect(String(_game.state.snapshot().get("phase", "")) == "shop", "formal re-entry returns the authoritative snapshot to shop")
	await _capture("19_reenter_shop_after_exit", "退出后重新进入商店")
	var reentered_buy_buttons := _enabled_command_buttons(reentered_shop, "BUY_OFFER")
	_expect(reentered_buy_buttons.size() == 3, "formal re-entered shop exposes three synchronized offers")
	if reentered_buy_buttons.size() != 3:
		_finish()
		return
	var reentered_second_buy := reentered_buy_buttons[1] as BaseButton
	_expect(reentered_second_buy.get_global_rect().has_point(SECOND_OFFER_HOVER_POSITION), "formal re-entered second offer contains the shared parity pointer")
	var reentered_snapshot_before_hover := JSON.stringify(_game.state.snapshot())
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == reentered_snapshot_before_hover, "hovering the formal re-entered second offer leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "formal re-entered second offer exposes BUY_OFFER on hover")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "formal re-entered second offer keeps the synchronized offer identity")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "formal re-entered second-offer hover leaves keyboard focus clear")
	await _capture("19a_reentered_second_offer_hover", "重进商店后悬停第二件商品")
	var reentered_snapshot_before_press := JSON.stringify(_game.state.snapshot())
	await _mouse_button(SECOND_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == reentered_snapshot_before_press, "formal re-entered second-offer mouse-down does not execute BUY_OFFER before release")
	_expect(reentered_second_buy.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal re-entered second-offer button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "formal re-entered second offer remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "formal re-entered second offer keeps the synchronized hover identity while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "formal re-entered second offer receives action focus while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "formal re-entered second offer receives synchronized offer focus while held")
	await _capture("19b_reentered_second_offer_pressed", "重进商店后按下第二件商品但尚未松开")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == reentered_snapshot_before_press, "formal re-entered second-offer press cancelled outside leaves the authoritative snapshot unchanged")
	_expect(reentered_second_buy.get_draw_mode() == BaseButton.DRAW_NORMAL, "formal re-entered second-offer cancelled press restores its normal draw mode")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal re-entered second-offer cancelled press leaves no purchase hover identity")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "formal re-entered second-offer cancelled press leaves keyboard focus clear")
	await _capture("19c_reentered_second_offer_press_cancelled", "重进商店后移出并松开取消第二件商品")
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(60)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == reentered_snapshot_before_press, "rehovering the formal re-entered second offer after cancellation leaves the authoritative snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "formal re-entered second offer restores BUY_OFFER on a real rehover after cancellation")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "formal re-entered second offer restores the synchronized offer identity after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "formal re-entered second-offer rehover after cancellation leaves keyboard focus clear")
	await _capture("19d_reentered_second_offer_rehover_after_cancel", "取消后重新悬停重进商店第二件商品")
	var reentered_restored_tooltip := reentered_second_buy.tooltip_text
	_expect(reentered_restored_tooltip != "", "formal re-entered second offer restores its visual Tooltip before the second press")
	await _mouse_button(SECOND_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == reentered_snapshot_before_press, "formal re-entered second-offer repress after cancellation does not execute BUY_OFFER before release")
	_expect(reentered_second_buy.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal re-entered second-offer repress exposes its pressed draw mode")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "formal re-entered second offer remains the hovered action when repressed after cancellation")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "formal re-entered second offer keeps the synchronized hover identity when repressed after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "formal re-entered second offer regains action focus when repressed after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "formal re-entered second offer regains synchronized offer focus when repressed after cancellation")
	_expect(reentered_second_buy.tooltip_text == "", "formal re-entered second-offer repress hides the restored visual Tooltip")
	_expect(reentered_second_buy.accessibility_name == reentered_restored_tooltip, "formal re-entered second-offer repress preserves its accessibility label")
	await _capture("19e_reentered_second_offer_repressed_after_cancel", "取消后重新悬停并再次按住重进商店第二件商品")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == reentered_snapshot_before_press, "formal re-entered second-offer repress remains non-committing while held outside")
	_expect(reentered_second_buy.get_draw_mode() == BaseButton.DRAW_NORMAL, "formal re-entered second-offer repress restores normal draw mode while held outside")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal re-entered second-offer repress clears purchase hover identity while held outside")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "formal re-entered second-offer repress keeps action focus while held outside")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "formal re-entered second-offer repress keeps synchronized offer focus while held outside")
	_expect(reentered_second_buy.tooltip_text == "", "formal re-entered second-offer repress keeps the visual Tooltip hidden while held outside")
	_expect(reentered_second_buy.accessibility_name == reentered_restored_tooltip, "formal re-entered second-offer repress keeps its accessibility label while held outside")
	await _capture("19f_reentered_second_offer_repressed_pointer_outside", "取消后再次按住重进商店第二件商品并移出")
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == reentered_snapshot_before_press, "formal re-entered second-offer repress remains non-committing when the held pointer re-enters")
	_expect(reentered_second_buy.get_draw_mode() == BaseButton.DRAW_PRESSED, "formal re-entered second-offer repress restores pressed mode when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "formal re-entered second-offer repress restores purchase hover identity when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "formal re-entered second-offer repress restores synchronized hover identity when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "formal re-entered second-offer repress keeps action focus when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "formal re-entered second-offer repress keeps synchronized offer focus when the held pointer re-enters")
	_expect(reentered_second_buy.tooltip_text == "", "formal re-entered second-offer repress keeps the visual Tooltip hidden when the held pointer re-enters")
	_expect(reentered_second_buy.accessibility_name == reentered_restored_tooltip, "formal re-entered second-offer repress keeps its accessibility label when the held pointer re-enters")
	var reentered_second_freeze := reentered_second_buy.get_parent_control().find_child("FreezeOfferButton_*", true, false) as Button
	_expect(reentered_second_freeze != null and not reentered_second_freeze.visible, "formal active offer hold keeps the contextual lock hidden when the pointer re-enters")
	await _capture("19g_reentered_second_offer_repressed_pointer_reentered", "取消后再次按住移出并重新移入重进商店第二件商品")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == reentered_snapshot_before_press, "formal re-entered second-offer repress remains non-committing when the re-entered held pointer exits again")
	_expect(reentered_second_buy.get_draw_mode() == BaseButton.DRAW_NORMAL, "formal re-entered second-offer repress restores normal mode when the re-entered held pointer exits again")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal re-entered second-offer repress clears purchase hover identity when the re-entered held pointer exits again")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "formal re-entered second-offer repress keeps action focus when the re-entered held pointer exits again")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "formal re-entered second-offer repress keeps synchronized offer focus when the re-entered held pointer exits again")
	_expect(reentered_second_buy.tooltip_text == "", "formal re-entered second-offer repress keeps the visual Tooltip hidden when the re-entered held pointer exits again")
	_expect(reentered_second_buy.accessibility_name == reentered_restored_tooltip, "formal re-entered second-offer repress keeps its accessibility label when the re-entered held pointer exits again")
	_expect(reentered_second_freeze != null and not reentered_second_freeze.visible, "formal active offer hold keeps the contextual lock hidden when the re-entered pointer exits again")
	await _capture("19h_reentered_second_offer_repressed_pointer_outside_again", "取消后再次按住移出重新移入后再次移出重进商店第二件商品")
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == reentered_snapshot_before_press, "formal re-entered second-offer repress cancellation leaves the authoritative snapshot unchanged")
	_expect(reentered_second_buy.get_draw_mode() == BaseButton.DRAW_NORMAL, "formal re-entered second-offer repress cancellation keeps the offer in normal mode")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "formal re-entered second-offer repress cancellation leaves no purchase hover identity")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "formal re-entered second-offer repress cancellation clears keyboard focus")
	_expect(reentered_second_buy.tooltip_text == "", "formal re-entered second-offer repress cancellation keeps the visual Tooltip hidden")
	_expect(reentered_second_buy.accessibility_name == reentered_restored_tooltip, "formal re-entered second-offer repress cancellation keeps its accessibility label")
	_expect(reentered_second_freeze != null and not reentered_second_freeze.visible, "formal re-entered second-offer repress cancellation keeps the contextual lock hidden outside")
	await _capture("19i_reentered_second_offer_repress_cancelled_after_reentry_cycle", "再次按住移出重新移入再移出后松开取消重进商店第二件商品")
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(60)
	await _release_focus()
	_expect(JSON.stringify(_game.state.snapshot()) == reentered_snapshot_before_press, "formal re-entered second-offer rehover after repress-cycle cancellation leaves the authoritative snapshot unchanged")
	_expect(reentered_second_buy.get_draw_mode() == BaseButton.DRAW_HOVER, "formal re-entered second-offer rehover after repress-cycle cancellation restores hover mode")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "formal re-entered second-offer rehover after repress-cycle cancellation restores purchase hover identity")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "formal re-entered second-offer rehover after repress-cycle cancellation restores synchronized offer identity")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "formal re-entered second-offer rehover after repress-cycle cancellation leaves keyboard focus clear")
	_expect(reentered_second_buy.tooltip_text == reentered_restored_tooltip, "formal re-entered second-offer rehover after repress-cycle cancellation restores the visual Tooltip")
	_expect(reentered_second_buy.accessibility_name == reentered_restored_tooltip, "formal re-entered second-offer rehover after repress-cycle cancellation keeps its accessibility label")
	_expect(reentered_second_freeze != null and reentered_second_freeze.visible, "formal re-entered second-offer rehover after repress-cycle cancellation restores the contextual lock")
	await _capture("19j_reentered_second_offer_rehover_after_repress_cycle_cancel", "第二次按压往返取消后重新悬停重进商店第二件商品")
	_finish()


func _run_compact_acceptance(shop: Control) -> void:
	var buy_buttons := _enabled_command_buttons(shop, "BUY_OFFER")
	var first_buy := buy_buttons[0] as BaseButton
	await _move_mouse(first_buy.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("02_offer_hover", "悬停第一件商品")
	var entry_snapshot := JSON.stringify(_game.state.snapshot())
	await _mouse_button(FIRST_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(_game.state.snapshot()) == entry_snapshot, "compact first-offer mouse-down does not execute BUY_OFFER")
	_expect(first_buy.get_draw_mode() == BaseButton.DRAW_PRESSED, "compact first offer exposes pressed draw mode")
	await _capture("02a_entry_first_offer_pressed", "按下第一件商品但尚未松开")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()

	var refresh := _find_command_button(shop, "ROLL_SHOP")
	_expect(refresh != null, "compact formal shop exposes refresh")
	if refresh == null:
		_finish()
		return
	var refresh_position := refresh.get_global_rect().get_center()
	await _move_mouse(refresh_position)
	await _mouse_button(refresh_position, true)
	await _settle(2)
	await _mouse_button(refresh_position, false)
	await _settle(4)
	var curtain := shop.find_child("RefreshCurtain", true, false) as TextureRect
	_expect(curtain != null and curtain.visible, "compact free refresh curtain is visible")
	await _release_focus()
	await _capture("03_refresh_curtain", "点击刷新后的红帘过程")
	_refresh_settle_frames = await _wait_for_control_hidden(curtain, 120)
	_expect(_refresh_settle_frames >= 0, "compact free refresh curtain clears")
	if _refresh_settle_frames < 0:
		_finish()
		return
	await _release_focus()
	await _capture("04_refresh_complete", "刷新动画完成")

	buy_buttons = _enabled_command_buttons(shop, "BUY_OFFER")
	_expect(buy_buttons.size() == 3, "compact free refresh exposes three offers")
	if buy_buttons.size() != 3:
		_finish()
		return
	await _click(buy_buttons[0] as BaseButton)
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _release_focus()
	await _capture("05_purchase_complete", "购买第一件商品完成")

	buy_buttons = _enabled_command_buttons(shop, "BUY_OFFER")
	_expect(buy_buttons.size() == 2, "compact first purchase leaves two offers")
	await _click(buy_buttons[0] as BaseButton)
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _release_focus()
	await _capture("09_second_purchase", "购买第二件商品完成")

	buy_buttons = _enabled_command_buttons(shop, "BUY_OFFER")
	_expect(buy_buttons.size() == 1, "compact second purchase leaves one offer")
	await _click(buy_buttons[0] as BaseButton)
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _release_focus()
	var full_snapshot := Dictionary(_game.state.snapshot())
	_expect(_active_roster_count(full_snapshot) == 4, "compact third purchase fills the party")
	await _capture("10_party_full_purchase", "购买第三件商品填满队伍")

	await _click(refresh, false)
	await _settle(4)
	_paid_refresh_settle_frames = await _wait_for_control_hidden(curtain, 120)
	_expect(_paid_refresh_settle_frames >= 0, "compact paid refresh curtain clears")
	if _paid_refresh_settle_frames < 0:
		_finish()
		return
	await _release_focus()
	await _capture("12_paid_refresh_complete", "付费刷新动画完成")

	buy_buttons = _enabled_command_buttons(shop, "BUY_OFFER")
	_expect(buy_buttons.size() == 3, "compact paid refresh exposes three offers")
	await _click(buy_buttons[0] as BaseButton)
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _release_focus()
	var bag_snapshot := Dictionary(_game.state.snapshot())
	_expect(_active_roster_count(bag_snapshot) == 4 and _inactive_roster_count(bag_snapshot) == 1, "compact fifth purchase enters the bag")
	await _capture("13_bag_pet_purchase", "购买第五只宠物进入背包")

	var bag_button := shop.find_child("ShopBagButton", true, false) as BaseButton
	_expect(bag_button != null, "compact formal shop exposes the bag")
	await _click(bag_button)
	await _release_focus()
	await _capture("14_bag_with_pet_open", "打开已有宠物的背包")

	var exit_button := _find_command_button(shop, "EXIT_SHOP")
	_expect(exit_button != null, "compact formal shop exposes exit")
	var exit_position := exit_button.get_global_rect().get_center()
	await _move_mouse(exit_position)
	await _mouse_button(exit_position, true)
	await _settle(2)
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "compact exit exposes pressed draw mode")
	await _capture("17b_exit_pressed", "按下退出牌但尚未松开")
	await _mouse_button(exit_position, false)
	_exit_settle_frames = await _wait_for_shop_hidden(shop)
	_expect(_exit_settle_frames >= 0, "compact formal exit hides the shop")
	if _exit_settle_frames < 0:
		_finish()
		return
	await _capture("18_exit_to_route", "退出商店返回路线")

	var route_button := _find_route_button_by_kind(_game, "shop")
	_expect(route_button != null, "compact route exposes a current node-2 shop")
	if route_button == null:
		_finish()
		return
	await _click(route_button)
	var reentered_shop := await _wait_for_shop()
	if reentered_shop == null:
		var confirm := _game.find_child("ExitButton", true, false) as TextureButton
		if confirm != null:
			await _click(confirm)
			reentered_shop = await _wait_for_shop()
	_expect(reentered_shop != null, "compact formal route re-enters the shop")
	if reentered_shop != null:
		await _settle(24)
		await _move_mouse(NEUTRAL_MOUSE_POSITION)
		await _release_focus()
		await _capture("19_reenter_shop_after_exit", "退出后重新进入商店")
	_finish()


func _find_command_button(parent: Node, command_type: String, option_id := "") -> BaseButton:
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) != command_type:
			continue
		if option_id != "" and String(command.get("option_id", command.get("optionId", ""))) != option_id:
			continue
		return button
	return null


func _find_route_button_by_kind(parent: Node, route_kind: String) -> BaseButton:
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		var command := Dictionary(button.get_meta("command", {}))
		if String(command.get("type", "")) == "CHOOSE_ROUTE" \
				and String(button.get_meta("route_kind", "")) == route_kind:
			return button
	return null


func _enabled_command_buttons(parent: Node, command_type: String) -> Array[BaseButton]:
	var result: Array[BaseButton] = []
	for node in parent.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.disabled:
			continue
		if String(Dictionary(button.get_meta("command", {})).get("type", "")) == command_type:
			result.append(button)
	return result


func _command_offer_ids(parent: Node, command_type: String) -> PackedStringArray:
	var result := PackedStringArray()
	for button in _enabled_command_buttons(parent, command_type):
		var offer_id := String(Dictionary(button.get_meta("command", {})).get("offer_id", ""))
		if offer_id != "":
			result.append(offer_id)
	return result


func _offer_is_sold(snapshot: Dictionary, offer_id: String) -> bool:
	for value in Array(snapshot.get("shop_offers", [])):
		var offer := Dictionary(value)
		if String(offer.get("id", "")) == offer_id:
			return bool(offer.get("sold", false))
	return false


func _active_roster_count(snapshot: Dictionary) -> int:
	return Array(snapshot.get("roster", [])).filter(
		func(value: Variant) -> bool: return bool(Dictionary(value).get("active", false))
	).size()


func _inactive_roster_count(snapshot: Dictionary) -> int:
	return Array(snapshot.get("roster", [])).filter(
		func(value: Variant) -> bool: return not bool(Dictionary(value).get("active", false))
	).size()


func _wait_for_shop(max_frames := 240) -> Control:
	for _frame in range(max_frames):
		var view := _game.find_child("LegacyCodeShopView", true, false) as Control
		if view != null and view.visible:
			return view
		await process_frame
	return null


func _wait_for_shop_hidden(shop: Control, max_frames := 240) -> int:
	for frame_count in range(max_frames + 1):
		if shop == null or not is_instance_valid(shop) or not shop.visible:
			return frame_count
		await process_frame
	return -1


func _wait_for_control_hidden(control: Control, max_frames: int) -> int:
	for frame_count in range(max_frames + 1):
		if control == null or not is_instance_valid(control) or not control.visible:
			return frame_count
		await process_frame
	return -1


func _click(control: Control, settle_after := true) -> void:
	var position := control.get_global_rect().get_center()
	await _move_mouse(position)
	await _mouse_button(position, true)
	await process_frame
	await _mouse_button(position, false)
	if settle_after:
		await _settle(5)


func _move_mouse(position: Vector2) -> void:
	Input.warp_mouse(Vector2i(position))
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	await process_frame


func _mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func _settle(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _release_focus() -> void:
	var focused := root.gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	await process_frame


func _capture(name: String, operation: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _output_dir.path_join(name + ".png")
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "viewport image exists for %s" % name)
	if image != null and not image.is_empty():
		_expect(image.save_png(path) == OK, "capture writes %s" % path)
	var snapshot := Dictionary(_game.state.snapshot()) if _game != null and _game.get("state") != null else {}
	var mouse_position := root.get_mouse_position()
	_captures.append({
		"name": name,
		"operation": operation,
		"file": name + ".png",
		"phase": String(snapshot.get("phase", "")),
		"coins": int(snapshot.get("coins", 0)),
		"offer_count": Array(snapshot.get("shop_offers", [])).size(),
		"roster_count": Array(snapshot.get("roster", [])).size(),
		"state_version": int(snapshot.get("stateVersion", snapshot.get("state_version", -1))),
		"state_hash": String(snapshot.get("stateHash", snapshot.get("state_hash", ""))),
		"interaction": {
			"pointer_position": [roundi(mouse_position.x), roundi(mouse_position.y)],
			"hovered": _interaction_identity(root.gui_get_hovered_control()),
			"focused": _interaction_identity(root.gui_get_focus_owner()),
		},
	})


func _interaction_identity(control: Control) -> Dictionary:
	var target := control
	while target != null and not (target is BaseButton):
		target = target.get_parent() as Control
	if target == null:
		return {"action": "none", "offer_id": "", "control": ""}
	var command := Dictionary(target.get_meta("command", {}))
	var action := String(command.get("type", ""))
	var offer_id := String(command.get("offer_id", ""))
	if action == "":
		action = _action_from_control_name(target.name)
	if action == "BUY_OFFER" and offer_id == "":
		action = "none"
	return {"action": action, "offer_id": offer_id, "control": String(target.name)}


func _action_from_control_name(control_name: StringName) -> String:
	var value := String(control_name).to_lower()
	if "offer" in value:
		return "BUY_OFFER"
	if "refresh" in value or "roll" in value:
		return "ROLL_SHOP"
	if "bagpet" in value or "bagslot" in value or "bag_slot" in value:
		return "BAG_SLOT"
	if "bag" in value:
		return "TOGGLE_BAG"
	if "party" in value:
		return "PARTY_SLOT"
	if "exit" in value:
		return "EXIT_SHOP"
	return "CONTROL"


func _finish() -> void:
	if _output_dir != "":
		var manifest := {
			"schema": "ysbzs.formal-shop-operation-parity-capture.v1",
			"side": "formal_project",
			"project_root": _project_root,
			"expected_project_root": _expected_project_root,
			"git_root": _git_root,
			"project_file": _project_root.path_join("project.godot"),
			"scene_source": "res://art/scenes/app/game.tscn",
			"window_size": [WINDOW_SIZE.x, WINDOW_SIZE.y],
			"selected_option_id": OPTION_ID,
			"run_seed": RUN_SEED,
			"capture_script": "res://tests/visible/capture_formal_shop_operation_parity.gd",
			"refresh_settle_frames": _refresh_settle_frames,
			"paid_refresh_settle_frames": _paid_refresh_settle_frames,
			"exit_settle_frames": _exit_settle_frames,
			"captures": _captures,
			"passed": not _failed,
		}
		var file := FileAccess.open(_output_dir.path_join("capture_manifest.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(manifest, "  ") + "\n")
			file.close()
	print("FORMAL_SHOP_OPERATION_PARITY_CAPTURE_%s output=%s captures=%d" % ["FAIL" if _failed else "PASS", _output_dir, _captures.size()])
	quit(1 if _failed else 0)


func _argument_value(prefix: String) -> String:
	for value in OS.get_cmdline_user_args():
		var argument := String(value)
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _find_git_root(start_path: String) -> String:
	var candidate := start_path
	while candidate != "":
		if DirAccess.dir_exists_absolute(candidate.path_join(".git")) or FileAccess.file_exists(candidate.path_join(".git")):
			return candidate
		var parent := candidate.get_base_dir()
		if parent == candidate:
			break
		candidate = parent
	return ""


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FORMAL_SHOP_OPERATION_PARITY_CAPTURE_FAIL: %s" % message)
