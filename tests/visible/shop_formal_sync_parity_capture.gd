extends SceneTree

const MAIN_SCENE := preload("res://art/scenes/app/game.tscn")
const WINDOW_SIZE := Vector2i(1920, 1080)
const OPTION_ID := "node_shop_basic"
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
var _captures: Array = []
var _game: Control = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = _argument_value("--output-dir=")
	_expected_project_root = _argument_value("--expected-project-root=").trim_suffix("/").simplify_path()
	_project_root = ProjectSettings.globalize_path("res://").trim_suffix("/").simplify_path()
	_git_root = _find_git_root(_project_root)
	_expect(_output_dir != "", "output directory is required")
	_expect(_expected_project_root != "", "expected project root is required")
	_expect(_project_root == _expected_project_root, "res root matches the expected art project")
	_expect(_git_root == _project_root, "Git root and res root are identical")
	if _failed:
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(_output_dir)
	DisplayServer.window_set_size(WINDOW_SIZE)
	root.size = WINDOW_SIZE

	_game = MAIN_SCENE.instantiate() as Control
	root.add_child(_game)
	await _settle(36)
	var route_button := _find_command_button(_game, "CHOOSE_ROUTE", OPTION_ID)
	_expect(route_button != null, "route exposes node_shop_basic")
	if route_button == null:
		_finish()
		return
	await _click(route_button)
	var route_confirm := _game.get_node("ThreeChoiceScene/RouteSharedUi/ExitButton") as TextureButton
	await _click(route_confirm)
	var shop := await _wait_for_shop(_game)
	_expect(shop != null, "real route pointer flow mounts the authored ShopScene")
	if shop == null:
		_finish()
		return
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _release_focus()
	var offers := shop.get_node("Offers") as Control
	_expect(_visible_offer_count(offers) == 3, "three synchronized formal offers are visible")
	_expect(_empty_offer_count(offers) == 2, "two authored shelf slots remain intentionally empty")
	await _capture("01_shop_entry", "进入基础商店", shop)
	await _move_mouse(ENTRY_SECOND_EMPTY_PARTY_SLOT_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "art entry second empty party aperture exposes no occupied party identity")
	await _capture("01b_entry_second_empty_party_slot_hover", "悬停入口第二个空队伍槽", shop)
	var entry_empty_party_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(ENTRY_SECOND_EMPTY_PARTY_SLOT_POSITION, true)
	await process_frame
	await _mouse_button(ENTRY_SECOND_EMPTY_PARTY_SLOT_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == entry_empty_party_snapshot_before_click, "clicking the authored entry second empty party aperture leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "art entry second empty party aperture click leaves no occupied party identity")
	await _capture("01b2_entry_second_empty_party_slot_click", "点击入口第二个空队伍槽", shop)
	await _move_mouse(ENTRY_FOURTH_EMPTY_PARTY_SLOT_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "art entry fourth empty party aperture exposes no occupied party identity")
	await _capture("01c_entry_fourth_empty_party_slot_hover", "悬停入口第四个空队伍槽", shop)
	var entry_fourth_empty_party_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(ENTRY_FOURTH_EMPTY_PARTY_SLOT_POSITION, true)
	await process_frame
	await _mouse_button(ENTRY_FOURTH_EMPTY_PARTY_SLOT_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == entry_fourth_empty_party_snapshot_before_click, "clicking the authored entry fourth empty party aperture leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "art entry fourth empty party aperture click leaves no occupied party identity")
	await _capture("01c2_entry_fourth_empty_party_slot_click", "点击入口第四个空队伍槽", shop)
	await _move_mouse(ENTRY_THIRD_EMPTY_PARTY_SLOT_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "art entry third empty party aperture exposes no occupied party identity")
	await _capture("01d_entry_third_empty_party_slot_hover", "悬停入口第三个空队伍槽", shop)
	var entry_third_empty_party_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(ENTRY_THIRD_EMPTY_PARTY_SLOT_POSITION, true)
	await process_frame
	await _mouse_button(ENTRY_THIRD_EMPTY_PARTY_SLOT_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == entry_third_empty_party_snapshot_before_click, "clicking the authored entry third empty party aperture leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "art entry third empty party aperture click leaves no occupied party identity")
	await _capture("01d2_entry_third_empty_party_slot_click", "点击入口第三个空队伍槽", shop)
	var coin_panel := shop.get_node("RouteSharedUi/Top/Hud/CoinIcon") as Control
	var entry_exit_button := shop.get_node("RouteSharedUi/ExitButton") as BaseButton
	_expect(coin_panel.get_global_rect().has_point(COIN_PANEL_SAFE_POSITION), "authored coin panel contains the safe parity pointer")
	_expect(not entry_exit_button.get_global_rect().has_point(COIN_PANEL_SAFE_POSITION), "authored coin safe parity pointer stays outside the exit rectangle")
	await _move_mouse(COIN_PANEL_SAFE_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored coin safe area exposes no semantic action")
	await _capture("01e_entry_coin_panel_hover", "悬停金币牌安全区", shop)
	var entry_coin_panel_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(COIN_PANEL_SAFE_POSITION, true)
	await process_frame
	await _mouse_button(COIN_PANEL_SAFE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == entry_coin_panel_snapshot_before_click, "clicking the authored coin safe area leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored coin safe area click leaves no semantic identity")
	await _capture("01e2_entry_coin_panel_click", "点击金币牌安全区", shop)
	_expect(coin_panel.get_global_rect().has_point(COIN_EXIT_OVERLAP_POSITION), "authored coin panel contains the shared overlap pointer")
	_expect(entry_exit_button.get_global_rect().has_point(COIN_EXIT_OVERLAP_POSITION), "authored exit rectangle contains the shared overlap pointer")
	await _move_mouse(COIN_EXIT_OVERLAP_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored coin panel blocks the covered exit edge from exposing an exit action")
	await _capture("01f_entry_coin_exit_overlap_hover", "悬停金币牌与退出牌交叠边缘", shop)
	var entry_coin_exit_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(COIN_EXIT_OVERLAP_POSITION, true)
	await process_frame
	await _mouse_button(COIN_EXIT_OVERLAP_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == entry_coin_exit_snapshot_before_click, "clicking the authored coin-covered exit edge leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored coin-covered exit edge click leaves no exit identity")
	await _capture("01f2_entry_coin_exit_overlap_click", "点击金币牌与退出牌交叠边缘", shop)
	_expect(entry_exit_button.get_global_rect().has_point(EXIT_TRANSPARENT_GAP_POSITION), "authored exit rectangle contains the shared transparent-gap pointer")
	_expect(not coin_panel.get_global_rect().has_point(EXIT_TRANSPARENT_GAP_POSITION), "authored exit transparent-gap pointer stays outside the coin panel")
	await _move_mouse(EXIT_TRANSPARENT_GAP_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored exit PNG transparent gap exposes no exit action")
	await _capture("01g_entry_exit_transparent_gap_hover", "悬停退出牌透明空隙", shop)
	var entry_exit_transparent_gap_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(EXIT_TRANSPARENT_GAP_POSITION, true)
	await process_frame
	await _mouse_button(EXIT_TRANSPARENT_GAP_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == entry_exit_transparent_gap_snapshot_before_click, "clicking the authored exit PNG transparent gap leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored exit PNG transparent-gap click leaves no exit identity")
	await _capture("01g2_entry_exit_transparent_gap_click", "点击退出牌透明空隙", shop)

	var first_offer := offers.get_node("Offer01") as Button
	await _move_mouse(first_offer.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("02_offer_hover", "悬停第一件商品", shop)
	var first_offer_snapshot_before_press := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(FIRST_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(shop.call("preview_snapshot")) == first_offer_snapshot_before_press, "authored first-offer mouse-down does not execute BUY_OFFER before release")
	_expect(first_offer.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored first-offer button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "authored first offer remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_001", "authored first offer keeps the synchronized offer identity while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "authored first offer receives action focus while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_001", "authored first offer receives synchronized offer focus while held")
	await _capture("02a_entry_first_offer_pressed", "按下第一件商品但尚未松开", shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == first_offer_snapshot_before_press, "authored first-offer press cancelled outside the button leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored first-offer cancelled press leaves no purchase identity")
	var second_offer := offers.get_node("Offer02") as Button
	await _move_mouse(second_offer.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("02_entry_second_offer_hover", "悬停入口第二件商品", shop)
	var second_offer_snapshot_before_press := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(SECOND_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(shop.call("preview_snapshot")) == second_offer_snapshot_before_press, "authored second-offer mouse-down does not execute BUY_OFFER before release")
	_expect(second_offer.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored second-offer button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "authored second offer remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "authored second offer keeps the synchronized offer identity while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "authored second offer receives action focus while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "authored second offer receives synchronized offer focus while held")
	await _capture("02a2_entry_second_offer_pressed", "按下第二件商品但尚未松开", shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == second_offer_snapshot_before_press, "authored second-offer press cancelled outside the button leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored second-offer cancelled press leaves no purchase identity")
	var third_offer := offers.get_node("Offer03") as Button
	_expect(third_offer.get_global_rect().has_point(THIRD_OFFER_HOVER_POSITION), "entry third offer contains the shared parity pointer")
	await _move_mouse(THIRD_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("02_entry_third_offer_hover", "悬停入口第三件商品", shop)
	var third_offer_snapshot_before_press := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(THIRD_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(shop.call("preview_snapshot")) == third_offer_snapshot_before_press, "authored third-offer mouse-down does not execute BUY_OFFER before release")
	_expect(third_offer.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored third-offer button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "authored third offer remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_003", "authored third offer keeps the synchronized offer identity while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "authored third offer receives action focus while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_003", "authored third offer receives synchronized offer focus while held")
	await _capture("02a3_entry_third_offer_pressed", "按下第三件商品但尚未松开", shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == third_offer_snapshot_before_press, "authored third-offer press cancelled outside the button leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored third-offer cancelled press leaves no purchase identity")

	await _move_mouse(FOURTH_EMPTY_SLOT_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "the authored fourth empty aperture exposes no stale purchase action")
	await _capture("02c_entry_fourth_empty_slot_hover", "指针移入入口第四个空货孔", shop)
	var fourth_empty_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(FOURTH_EMPTY_SLOT_POSITION, true)
	await process_frame
	await _mouse_button(FOURTH_EMPTY_SLOT_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == fourth_empty_snapshot_before_click, "clicking the authored fourth empty aperture leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "the authored fourth empty aperture click leaves no purchase identity")
	await _capture("02c2_entry_fourth_empty_slot_click", "点击入口第四个空货孔", shop)
	await _move_mouse(FIFTH_EMPTY_SLOT_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "the authored fifth empty aperture exposes no stale purchase action")
	await _capture("02d_entry_fifth_empty_slot_hover", "指针移入入口第五个空货孔", shop)
	var fifth_empty_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(FIFTH_EMPTY_SLOT_POSITION, true)
	await process_frame
	await _mouse_button(FIFTH_EMPTY_SLOT_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == fifth_empty_snapshot_before_click, "clicking the authored fifth empty aperture leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "the authored fifth empty aperture click leaves no purchase identity")
	await _capture("02d2_entry_fifth_empty_slot_click", "点击入口第五个空货孔", shop)

	var refresh := shop.get_node("RefreshButton") as TextureButton
	var refresh_position := refresh.get_global_rect().get_center()
	await _move_mouse(refresh_position)
	await _settle(8)
	await _release_focus()
	await _capture("02b_refresh_hover", "悬停刷新铃但不点击", shop)
	var refresh_snapshot_before_press := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(refresh_position, true)
	await _settle(2)
	_expect(JSON.stringify(shop.call("preview_snapshot")) == refresh_snapshot_before_press, "authored refresh mouse-down does not execute ROLL_SHOP before release")
	_expect(refresh.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored refresh button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "ROLL_SHOP", "authored refresh remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "ROLL_SHOP", "authored refresh receives focus while held")
	await _capture("02b2_refresh_pressed", "按下刷新铃但尚未松开", shop)
	await _mouse_button(refresh_position, false)
	await create_timer(0.18).timeout
	var curtain := shop.get_node("RefreshCurtain") as TextureRect
	_expect(curtain.visible, "refresh curtain is visible during the operation")
	await _release_focus()
	await _capture("03_refresh_curtain", "点击刷新后的红帘过程", shop)
	await create_timer(0.55).timeout
	_expect(not curtain.visible and not refresh.disabled, "refresh completes and unlocks input")
	_expect(_visible_offer_count(offers) == 3, "refresh keeps the formal three-offer shape")
	await _release_focus()
	await _capture("04_refresh_complete", "刷新动画完成", shop)

	first_offer = offers.get_node("Offer01") as Button
	_expect(first_offer.get_global_rect().has_point(FIRST_OFFER_HOVER_POSITION), "refreshed first offer contains the shared parity pointer")
	await _move_mouse(FIRST_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("04a_refresh_first_offer_hover", "悬停首次刷新后的第一件商品", shop)
	second_offer = offers.get_node("Offer02") as Button
	_expect(second_offer.get_global_rect().has_point(SECOND_OFFER_HOVER_POSITION), "refreshed second offer contains the shared parity pointer")
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("04b_refresh_second_offer_hover", "悬停首次刷新后的第二件商品", shop)
	third_offer = offers.get_node("Offer03") as Button
	_expect(third_offer.get_global_rect().has_point(THIRD_OFFER_HOVER_POSITION), "refreshed third offer contains the shared parity pointer")
	await _move_mouse(THIRD_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("04c_refresh_third_offer_hover", "悬停首次刷新后的第三件商品", shop)

	var purchase_id := String(Dictionary(first_offer.get_meta("offer", {})).get("id", ""))
	var coins_before_purchase := int(Dictionary(shop.call("preview_snapshot")).get("coins", 0))
	await _click(first_offer)
	await _settle(24)
	var purchased_snapshot := Dictionary(shop.call("preview_snapshot"))
	_expect(purchase_id != "" and _offer_is_sold(purchased_snapshot, purchase_id), "real click marks the captured first offer sold")
	_expect(int(purchased_snapshot.get("coins", 0)) < coins_before_purchase, "real purchase deducts formal coins")
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _release_focus()
	await _capture("05_purchase_complete", "购买第一件商品完成", shop)

	var party_slot := shop.get_node("RouteSharedUi/Party/Party_Container/Party_Slot") as TextureButton
	await _move_mouse(party_slot.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("06_party_hover", "悬停第一名队伍宠物", shop)
	var first_party_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _click(party_slot)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == first_party_snapshot_before_click, "clicking the first authored party slot leaves the captured formal snapshot unchanged")
	await _capture("06a_party_first_click", "点击第一名队伍宠物", shop)
	var second_party_slot := shop.get_node("RouteSharedUi/Party/Party_Container/Party_Slot2") as TextureButton
	await _move_mouse(second_party_slot.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("06b_party_second_hover", "悬停第二名队伍宠物", shop)
	var second_party_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _click(second_party_slot)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == second_party_snapshot_before_click, "clicking the authored party slot leaves the captured formal snapshot unchanged")
	await _capture("06c_party_second_click", "点击第二名队伍宠物", shop)

	var bag_button := shop.get_node("RouteSharedUi/Bags/Bag_Button") as TextureButton
	_expect(bag_button.get_global_rect().has_point(BAG_BUTTON_POSITION), "the authored closed bag contains the shared parity pointer")
	await _move_mouse(BAG_BUTTON_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("06d_bag_closed_hover", "悬停关闭态宝箱", shop)
	var bag_snapshot_before_press := JSON.stringify(shop.call("preview_snapshot"))
	var middle_bag := shop.get_node("RouteSharedUi/Middle_Bag") as Control
	_expect(middle_bag != null and not middle_bag.visible, "the authored bag starts closed before the held-close probe")
	await _mouse_button(BAG_BUTTON_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(shop.call("preview_snapshot")) == bag_snapshot_before_press, "authored closed-bag mouse-down leaves the captured formal snapshot unchanged")
	_expect(middle_bag != null and not middle_bag.visible, "authored closed-bag mouse-down does not open the bag before release")
	_expect(bag_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "the authored closed bag exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "TOGGLE_BAG", "the authored closed bag remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "TOGGLE_BAG", "the authored closed bag receives focus while held")
	await _capture("06d2_bag_closed_pressed", "按下关闭态宝箱但尚未松开", shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(4)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == bag_snapshot_before_press, "authored closed-bag cancel gesture leaves the captured formal snapshot unchanged")
	_expect(middle_bag != null and not middle_bag.visible, "authored closed-bag cancel gesture keeps the bag closed")
	await _click(bag_button)
	await _release_focus()
	await _capture("07_bag_open", "点击宝箱打开背包", shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("07a_bag_open_hover_cleared", "鼠标移出打开态宝箱", shop)
	await _move_mouse(BAG_BUTTON_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("07a2_bag_open_hover", "重新悬停打开态宝箱", shop)
	var open_bag_snapshot_before_press := JSON.stringify(shop.call("preview_snapshot"))
	_expect(middle_bag != null and middle_bag.visible, "the authored bag remains open before the held-open probe")
	await _mouse_button(BAG_BUTTON_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(shop.call("preview_snapshot")) == open_bag_snapshot_before_press, "authored open-bag mouse-down leaves the captured formal snapshot unchanged")
	_expect(middle_bag != null and middle_bag.visible, "authored open-bag mouse-down does not close the bag before release")
	_expect(bag_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "the authored open bag exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "TOGGLE_BAG", "the authored open bag remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "TOGGLE_BAG", "the authored open bag receives focus while held")
	await _capture("07a3_bag_open_pressed", "按下打开态宝箱但尚未松开", shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(4)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == open_bag_snapshot_before_press, "authored open-bag cancel gesture leaves the captured formal snapshot unchanged")
	_expect(middle_bag != null and middle_bag.visible, "authored open-bag cancel gesture keeps the bag open")
	await _move_mouse(Vector2(628.0, 496.0))
	await _settle(8)
	await _release_focus()
	await _capture("07b_empty_bag_slot_hover", "悬停空背包第一槽", shop)
	var empty_bag_slot := shop.get_node("RouteSharedUi/Middle_Bag/Slots/Bag_Slot") as BaseButton
	_expect(empty_bag_slot != null and Dictionary(empty_bag_slot.get_meta("drag_record", {})).is_empty(), "the authored first bag slot is empty before the no-op click probe")
	var empty_bag_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _click(empty_bag_slot)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == empty_bag_snapshot_before_click, "clicking the empty authored bag slot leaves the captured formal snapshot unchanged")
	await _capture("07c_empty_bag_slot_click", "点击空背包第一槽", shop)
	var eighth_empty_bag_slot := shop.get_node("RouteSharedUi/Middle_Bag/Slots/Bag_Slot8") as BaseButton
	_expect(eighth_empty_bag_slot != null and eighth_empty_bag_slot.get_global_rect() == Rect2(1106.0, 601.0, 154.0, 146.0), "the authored eighth bag slot keeps the far shared rectangle")
	await _move_mouse(Vector2(1183.0, 674.0))
	await _settle(8)
	await _release_focus()
	await _capture("07d_empty_bag_eighth_slot_hover", "悬停空背包第八槽", shop)
	await _click(bag_button)
	await _release_focus()
	await _capture("08_bag_closed", "再次点击宝箱关闭背包", shop)

	second_offer = offers.get_node("Offer02") as Button
	await _click(second_offer)
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _release_focus()
	var second_purchased_snapshot := Dictionary(shop.call("preview_snapshot"))
	_expect(Array(second_purchased_snapshot.get("roster", [])).size() == 3, "second captured formal purchase adds the third roster record")
	await _capture("09_second_purchase", "购买第二件商品完成", shop)

	third_offer = offers.get_node("Offer03") as Button
	await _click(third_offer)
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _release_focus()
	var party_full_snapshot := Dictionary(shop.call("preview_snapshot"))
	_expect(_active_roster_count(party_full_snapshot) == 4, "third captured formal purchase fills the four-member party")
	await _capture("10_party_full_purchase", "购买第三件商品填满队伍", shop)
	var third_party_slot := shop.get_node("RouteSharedUi/Party/Party_Container/Party_Slot3") as TextureButton
	await _move_mouse(third_party_slot.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("10b_party_third_hover", "悬停第三名队伍宠物", shop)
	var third_party_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _click(third_party_slot)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == third_party_snapshot_before_click, "clicking the third authored party slot leaves the captured formal snapshot unchanged")
	await _capture("10b2_party_third_click", "点击第三名队伍宠物", shop)
	var fourth_party_slot := shop.get_node("RouteSharedUi/Party/Party_Container/Party_Slot4") as TextureButton
	await _move_mouse(fourth_party_slot.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("10c_party_fourth_hover", "悬停第四名队伍宠物", shop)
	var fourth_party_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _click(fourth_party_slot)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == fourth_party_snapshot_before_click, "clicking the fourth authored party slot leaves the captured formal snapshot unchanged")
	await _capture("10c2_party_fourth_click", "点击第四名队伍宠物", shop)

	await _move_mouse(refresh_position)
	await _settle(8)
	await _release_focus()
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "ROLL_SHOP", "authored paid refresh hover exposes the refresh action")
	await _capture("10d_paid_refresh_hover", "悬停付费刷新铃但不点击", shop)
	var paid_refresh_snapshot_before_press := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(refresh_position, true)
	await _settle(2)
	_expect(JSON.stringify(shop.call("preview_snapshot")) == paid_refresh_snapshot_before_press, "authored paid refresh mouse-down does not execute ROLL_SHOP before release")
	_expect(refresh.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored paid refresh button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "ROLL_SHOP", "authored paid refresh remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "ROLL_SHOP", "authored paid refresh receives focus while held")
	await _capture("10d2_paid_refresh_pressed", "按下付费刷新铃但尚未松开", shop)
	await _mouse_button(refresh_position, false)
	await create_timer(0.18).timeout
	_expect(curtain.visible, "captured paid refresh curtain is visible during the operation")
	await _release_focus()
	await _capture("11_paid_refresh_curtain", "点击付费刷新后的红帘过程", shop)
	await create_timer(0.55).timeout
	_expect(not curtain.visible and not refresh.disabled, "captured paid refresh completes and unlocks input")
	await _release_focus()
	await _capture("12_paid_refresh_complete", "付费刷新动画完成", shop)

	first_offer = offers.get_node("Offer01") as Button
	_expect(first_offer.get_global_rect().has_point(FIRST_OFFER_HOVER_POSITION), "paid first offer contains the shared parity pointer")
	await _move_mouse(FIRST_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("12a_paid_refresh_first_offer_hover", "悬停付费刷新后的第一件商品", shop)
	second_offer = offers.get_node("Offer02") as Button
	_expect(second_offer.get_global_rect().has_point(SECOND_OFFER_HOVER_POSITION), "paid second offer contains the shared parity pointer")
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("12b_paid_refresh_second_offer_hover", "悬停付费刷新后的第二件商品", shop)
	third_offer = offers.get_node("Offer03") as Button
	_expect(third_offer.get_global_rect().has_point(THIRD_OFFER_HOVER_POSITION), "paid third offer contains the shared parity pointer")
	await _move_mouse(THIRD_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	await _capture("12c_paid_refresh_third_offer_hover", "悬停付费刷新后的第三件商品", shop)

	await _click(first_offer)
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _release_focus()
	var bag_purchased_snapshot := Dictionary(shop.call("preview_snapshot"))
	_expect(_active_roster_count(bag_purchased_snapshot) == 4 and _inactive_roster_count(bag_purchased_snapshot) == 1, "fifth captured formal purchase enters the bag")
	await _capture("13_bag_pet_purchase", "购买第五只宠物进入背包", shop)

	await _click(bag_button)
	await _release_focus()
	await _capture("14_bag_with_pet_open", "打开已有宠物的背包", shop)
	var first_bag_slot := shop.get_node("RouteSharedUi/Middle_Bag/Slots/Bag_Slot") as TextureButton
	_expect(first_bag_slot.get_meta("pet_texture", null) != null, "first authored bag slot renders the captured inactive pet")
	await _move_mouse(first_bag_slot.get_global_rect().get_center())
	await _settle(8)
	await _release_focus()
	await _capture("15_bag_pet_hover", "悬停背包第一只宠物", shop)
	var mixed_bag_eighth_slot := shop.get_node("RouteSharedUi/Middle_Bag/Slots/Bag_Slot8") as TextureButton
	_expect(Dictionary(mixed_bag_eighth_slot.get_meta("drag_record", {})).is_empty(), "the authored mixed bag keeps the eighth slot empty")
	await _move_mouse(Vector2(1183.0, 674.0))
	await _settle(8)
	await _release_focus()
	await _capture("15b_bag_pet_eighth_empty_slot_hover", "已有宠物时悬停背包第八空槽", shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(8)
	await _release_focus()
	var mixed_bag_highlight := shop.get_node("RouteSharedUi/ItemSlotHoverHighlight") as CanvasItem
	_expect(mixed_bag_highlight != null and not mixed_bag_highlight.visible, "the authored bag highlight clears after the pointer exits every slot")
	await _capture("15c_bag_hover_cleared", "移出背包清除槽高亮", shop)
	var occupied_bag_snapshot_before_click := JSON.stringify(shop.call("preview_snapshot"))
	await _click(first_bag_slot)
	await _release_focus()
	_expect(JSON.stringify(shop.call("preview_snapshot")) == occupied_bag_snapshot_before_click, "clicking the occupied authored bag slot leaves the captured formal snapshot unchanged")
	_expect(mixed_bag_highlight != null and mixed_bag_highlight.visible, "the occupied authored bag slot remains highlighted after click")
	await _capture("15d_bag_pet_click", "点击背包第一只宠物", shop)
	await _click(bag_button)
	await _release_focus()
	await _capture("16_bag_with_pet_closed", "关闭已有宠物的背包", shop)

	var exit_button := shop.get_node("RouteSharedUi/ExitButton") as TextureButton
	var exit_position := exit_button.get_global_rect().get_center()
	await _move_mouse(exit_position)
	await _settle(8)
	await _release_focus()
	await _capture("17_exit_hover", "悬停商店退出牌", shop)
	var exit_snapshot_before_press := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(exit_position, true)
	await _settle(2)
	_expect(JSON.stringify(shop.call("preview_snapshot")) == exit_snapshot_before_press, "authored exit mouse-down does not execute EXIT_SHOP before release")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored exit button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "EXIT_SHOP", "authored exit remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "authored exit receives focus while held")
	await _capture("17b_exit_pressed", "按下退出牌但尚未松开", shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(8)
	_expect(String(_game.call("get_active_feature_id")) == "shop", "authored exit remains in the shop while the held pointer is outside")
	_expect(JSON.stringify(shop.call("preview_snapshot")) == exit_snapshot_before_press, "moving the held authored exit pointer outside leaves the captured formal snapshot unchanged")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_NORMAL, "authored exit returns to its normal draw mode while held outside")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored exit held outside clears the hovered action")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "authored exit keeps focus while held outside")
	await _capture("17b2_exit_pressed_pointer_outside", "按住退出牌并移出", shop)
	await _move_mouse(exit_position)
	await _settle(8)
	_expect(String(_game.call("get_active_feature_id")) == "shop", "authored exit remains in the shop when the held pointer re-enters")
	_expect(JSON.stringify(shop.call("preview_snapshot")) == exit_snapshot_before_press, "re-entering the held authored exit leaves the captured formal snapshot unchanged")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored exit restores its pressed draw mode when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "EXIT_SHOP", "authored exit restores the hovered action when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "authored exit keeps focus when the held pointer re-enters")
	await _capture("17b3_exit_pressed_pointer_reentered", "按住退出牌移出后重新移入", shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(8)
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_NORMAL, "authored exit returns to normal before the re-entered press is cancelled outside")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored exit clears hover again before the re-entered press is cancelled outside")
	_expect(String(_game.call("get_active_feature_id")) == "shop", "authored exit remains in the shop when the re-entered held pointer moves outside again")
	_expect(JSON.stringify(shop.call("preview_snapshot")) == exit_snapshot_before_press, "moving the re-entered held authored exit pointer outside again leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "authored exit keeps focus when the re-entered held pointer moves outside again")
	await _capture("17b4_exit_pressed_pointer_outside_again", "按住退出牌重新移出但尚未松开", shop)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(8)
	await _release_focus()
	_expect(String(_game.call("get_active_feature_id")) == "shop", "authored exit remains in the shop after a held pointer moves away before release")
	_expect(JSON.stringify(shop.call("preview_snapshot")) == exit_snapshot_before_press, "cancelling the authored exit press leaves the captured formal snapshot unchanged")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_NORMAL, "authored exit returns to its normal draw mode after a cancelled press")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored exit cancel clears the hovered action")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "authored exit cancel clears focus before capture")
	await _capture("17c_exit_press_cancelled", "移出退出牌并松开取消", shop)
	await _move_mouse(exit_position)
	await _settle(8)
	var exit_snapshot_before_repress := JSON.stringify(shop.call("preview_snapshot"))
	await _mouse_button(exit_position, true)
	await _settle(2)
	_expect(String(_game.call("get_active_feature_id")) == "shop", "authored exit remains in the shop while pressed again after cancellation")
	_expect(JSON.stringify(shop.call("preview_snapshot")) == exit_snapshot_before_repress, "authored exit repress does not execute EXIT_SHOP before release")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored exit restores its pressed draw mode on a new press after cancellation")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "EXIT_SHOP", "authored exit is hovered on a new press after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "authored exit receives focus on a new press after cancellation")
	await _capture("17d_exit_repressed_after_cancel", "取消后再次按住退出牌", shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(8)
	_expect(String(_game.call("get_active_feature_id")) == "shop", "authored exit remains in the shop when the new press moves outside after cancellation")
	_expect(JSON.stringify(shop.call("preview_snapshot")) == exit_snapshot_before_repress, "moving the new authored exit press outside after cancellation leaves the captured formal snapshot unchanged")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_NORMAL, "authored exit returns to normal when the new press moves outside after cancellation")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored exit clears hover when the new press moves outside after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "authored exit keeps focus when the new press moves outside after cancellation")
	await _capture("17e_exit_repressed_pointer_outside", "取消后再次按住退出牌并移出", shop)
	await _move_mouse(exit_position)
	await _settle(8)
	_expect(String(_game.call("get_active_feature_id")) == "shop", "authored exit remains in the shop when the new press re-enters after cancellation")
	_expect(JSON.stringify(shop.call("preview_snapshot")) == exit_snapshot_before_repress, "re-entering the new authored exit press after cancellation leaves the captured formal snapshot unchanged")
	_expect(exit_button.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored exit restores pressed mode when the new press re-enters after cancellation")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "EXIT_SHOP", "authored exit restores hover when the new press re-enters after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "EXIT_SHOP", "authored exit keeps focus when the new press re-enters after cancellation")
	await _capture("17f_exit_repressed_pointer_reentered", "取消后再次按住移出后重新移入", shop)
	await _mouse_button(exit_position, false)
	await _settle(30)
	_expect(String(_game.call("get_active_feature_id")) == "", "real exit returns to route")
	await _capture("18_exit_to_route", "退出商店返回路线", null)
	var reentry_route_button := _find_command_button(_game, "CHOOSE_ROUTE", OPTION_ID)
	_expect(reentry_route_button != null, "authored route still exposes node_shop_basic after leaving the shop")
	if reentry_route_button == null:
		_finish()
		return
	await _click(reentry_route_button)
	var reentered_shop := await _wait_for_shop(_game)
	if reentered_shop == null:
		var reentry_confirm := _game.find_child("ExitButton", true, false) as TextureButton
		_expect(reentry_confirm != null, "authored route provides confirmation when shop re-entry is not immediate")
		if reentry_confirm != null:
			await _click(reentry_confirm)
			reentered_shop = await _wait_for_shop(_game)
	_expect(reentered_shop != null, "real authored route pointer flow re-enters the shop after exit")
	if reentered_shop == null:
		_finish()
		return
	await _settle(24)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _release_focus()
	_expect(String(_game.call("get_active_feature_id")) == "shop", "authored re-entry returns the public snapshot to shop")
	await _capture("19_reenter_shop_after_exit", "退出后重新进入商店", reentered_shop)
	var reentered_offers := reentered_shop.get_node("Offers") as Control
	var reentered_second_offer := reentered_offers.get_node("Offer02") as Button
	_expect(reentered_second_offer.get_global_rect().has_point(SECOND_OFFER_HOVER_POSITION), "authored re-entered second offer contains the shared parity pointer")
	var reentered_snapshot_before_hover := JSON.stringify(reentered_shop.call("preview_snapshot"))
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(8)
	await _release_focus()
	_expect(JSON.stringify(reentered_shop.call("preview_snapshot")) == reentered_snapshot_before_hover, "hovering the authored re-entered second offer leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "authored re-entered second offer exposes BUY_OFFER on hover")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "authored re-entered second offer keeps the synchronized offer identity")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "authored re-entered second-offer hover leaves keyboard focus clear")
	await _capture("19a_reentered_second_offer_hover", "重进商店后悬停第二件商品", reentered_shop)
	var reentered_snapshot_before_press := JSON.stringify(reentered_shop.call("preview_snapshot"))
	await _mouse_button(SECOND_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(reentered_shop.call("preview_snapshot")) == reentered_snapshot_before_press, "authored re-entered second-offer mouse-down leaves the captured formal snapshot unchanged")
	_expect(reentered_second_offer.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored re-entered second-offer button exposes its pressed draw mode while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "authored re-entered second offer remains the hovered action while held")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "authored re-entered second offer keeps the synchronized hover identity while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "authored re-entered second offer receives action focus while held")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "authored re-entered second offer receives synchronized offer focus while held")
	await _capture("19b_reentered_second_offer_pressed", "重进商店后按下第二件商品但尚未松开", reentered_shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(reentered_shop.call("preview_snapshot")) == reentered_snapshot_before_press, "authored re-entered second-offer press cancelled outside leaves the captured formal snapshot unchanged")
	_expect(reentered_second_offer.get_draw_mode() == BaseButton.DRAW_NORMAL, "authored re-entered second-offer cancelled press restores its normal draw mode")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored re-entered second-offer cancelled press leaves no purchase hover identity")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "authored re-entered second-offer cancelled press leaves keyboard focus clear")
	await _capture("19c_reentered_second_offer_press_cancelled", "重进商店后移出并松开取消第二件商品", reentered_shop)
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(60)
	await _release_focus()
	_expect(JSON.stringify(reentered_shop.call("preview_snapshot")) == reentered_snapshot_before_press, "rehovering the authored re-entered second offer after cancellation leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "authored re-entered second offer restores BUY_OFFER on a real rehover after cancellation")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "authored re-entered second offer restores the synchronized offer identity after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "authored re-entered second-offer rehover after cancellation leaves keyboard focus clear")
	await _capture("19d_reentered_second_offer_rehover_after_cancel", "取消后重新悬停重进商店第二件商品", reentered_shop)
	await _mouse_button(SECOND_OFFER_HOVER_POSITION, true)
	await _settle(2)
	_expect(JSON.stringify(reentered_shop.call("preview_snapshot")) == reentered_snapshot_before_press, "authored re-entered second-offer repress after cancellation leaves the captured formal snapshot unchanged")
	_expect(reentered_second_offer.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored re-entered second-offer repress exposes its pressed draw mode")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "authored re-entered second offer remains the hovered action when repressed after cancellation")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "authored re-entered second offer keeps the synchronized hover identity when repressed after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "authored re-entered second offer regains action focus when repressed after cancellation")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "authored re-entered second offer regains synchronized offer focus when repressed after cancellation")
	await _capture("19e_reentered_second_offer_repressed_after_cancel", "取消后重新悬停并再次按住重进商店第二件商品", reentered_shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	_expect(JSON.stringify(reentered_shop.call("preview_snapshot")) == reentered_snapshot_before_press, "authored re-entered second-offer repress remains non-committing while held outside")
	_expect(reentered_second_offer.get_draw_mode() == BaseButton.DRAW_NORMAL, "authored re-entered second-offer repress restores normal draw mode while held outside")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored re-entered second-offer repress clears purchase hover identity while held outside")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "authored re-entered second-offer repress keeps action focus while held outside")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "authored re-entered second-offer repress keeps synchronized offer focus while held outside")
	await _capture("19f_reentered_second_offer_repressed_pointer_outside", "取消后再次按住重进商店第二件商品并移出", reentered_shop)
	await _move_mouse(SECOND_OFFER_HOVER_POSITION)
	await _settle(2)
	_expect(JSON.stringify(reentered_shop.call("preview_snapshot")) == reentered_snapshot_before_press, "authored re-entered second-offer repress remains non-committing when the held pointer re-enters")
	_expect(reentered_second_offer.get_draw_mode() == BaseButton.DRAW_PRESSED, "authored re-entered second-offer repress restores pressed mode when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "BUY_OFFER", "authored re-entered second-offer repress restores purchase hover identity when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("offer_id", "")) == "shop_002", "authored re-entered second-offer repress restores synchronized hover identity when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "authored re-entered second-offer repress keeps action focus when the held pointer re-enters")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "authored re-entered second-offer repress keeps synchronized offer focus when the held pointer re-enters")
	await _capture("19g_reentered_second_offer_repressed_pointer_reentered", "取消后再次按住移出并重新移入重进商店第二件商品", reentered_shop)
	await _move_mouse(NEUTRAL_MOUSE_POSITION)
	await _settle(2)
	_expect(JSON.stringify(reentered_shop.call("preview_snapshot")) == reentered_snapshot_before_press, "authored re-entered second-offer repress remains non-committing when the re-entered held pointer exits again")
	_expect(reentered_second_offer.get_draw_mode() == BaseButton.DRAW_NORMAL, "authored re-entered second-offer repress restores normal mode when the re-entered held pointer exits again")
	_expect(String(_interaction_identity(root.gui_get_hovered_control()).get("action", "")) == "none", "authored re-entered second-offer repress clears purchase hover identity when the re-entered held pointer exits again")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "BUY_OFFER", "authored re-entered second-offer repress keeps action focus when the re-entered held pointer exits again")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("offer_id", "")) == "shop_002", "authored re-entered second-offer repress keeps synchronized offer focus when the re-entered held pointer exits again")
	await _capture("19h_reentered_second_offer_repressed_pointer_outside_again", "取消后再次按住移出重新移入后再次移出重进商店第二件商品", reentered_shop)
	await _mouse_button(NEUTRAL_MOUSE_POSITION, false)
	await _settle(5)
	await _release_focus()
	_expect(JSON.stringify(reentered_shop.call("preview_snapshot")) == reentered_snapshot_before_press, "authored re-entered second-offer repress cancellation leaves the captured formal snapshot unchanged")
	_expect(String(_interaction_identity(root.gui_get_focus_owner()).get("action", "")) == "none", "authored re-entered second-offer repress cancellation clears keyboard focus")
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


func _wait_for_shop(game: Control) -> Control:
	for _frame in range(240):
		var active := game.call("get_active_feature_view") as Control
		if String(game.call("get_active_feature_id")) == "shop" and active != null:
			return active
		await process_frame
	return null


func _visible_offer_ids(offers: Control) -> PackedStringArray:
	var result := PackedStringArray()
	for child in offers.get_children():
		var button := child as Button
		if button == null:
			continue
		var offer_id := String(Dictionary(button.get_meta("offer", {})).get("id", ""))
		if offer_id != "":
			result.append(offer_id)
	return result


func _visible_offer_count(offers: Control) -> int:
	return _visible_offer_ids(offers).size()


func _empty_offer_count(offers: Control) -> int:
	return 5 - _visible_offer_count(offers)


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


func _capture(name: String, operation: String, shop: Control) -> void:
	await RenderingServer.frame_post_draw
	var path := _output_dir.path_join(name + ".png")
	var image := root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "viewport image exists for %s" % name)
	if image != null and not image.is_empty():
		_expect(image.save_png(path) == OK, "capture writes %s" % path)
	var snapshot := _current_snapshot(shop)
	var mouse_position := root.get_mouse_position()
	_captures.append({
		"name": name,
		"operation": operation,
		"file": name + ".png",
		"phase": String(snapshot.get("phase", "route")),
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
	var offer := Dictionary(target.get_meta("offer", {}))
	var action := String(command.get("type", ""))
	var offer_id := String(command.get("offer_id", offer.get("id", "")))
	if action == "":
		action = _action_from_control_name(target.name)
	if action == "BUY_OFFER" and offer_id == "":
		action = "none"
	if action == "PARTY_SLOT" and Dictionary(target.get_meta("drag_record", {})).is_empty():
		action = "none"
	return {"action": action, "offer_id": offer_id, "control": String(target.name)}


func _action_from_control_name(control_name: StringName) -> String:
	var value := String(control_name).to_lower()
	if "offer" in value:
		return "BUY_OFFER"
	if "refresh" in value or "roll" in value:
		return "ROLL_SHOP"
	if "bag_slot" in value or "bagslot" in value:
		return "BAG_SLOT"
	if "bag" in value:
		return "TOGGLE_BAG"
	if "party" in value:
		return "PARTY_SLOT"
	if "exit" in value:
		return "EXIT_SHOP"
	return "CONTROL"


func _current_snapshot(shop: Control) -> Dictionary:
	if shop != null and is_instance_valid(shop):
		return Dictionary(shop.call("preview_snapshot"))
	if _game != null and is_instance_valid(_game):
		var session := _game.call("get_game_session") as RefCounted
		if session != null:
			return Dictionary(session.call("current_snapshot"))
	return {}


func _finish() -> void:
	if _output_dir != "":
		var manifest := {
			"schema": "lubiart.shop-formal-sync-parity-capture.v1",
			"side": "art_package",
			"project_root": _project_root,
			"expected_project_root": _expected_project_root,
			"git_root": _git_root,
			"project_file": _project_root.path_join("project.godot"),
			"scene_source": "res://art/scenes/app/game.tscn",
			"window_size": [WINDOW_SIZE.x, WINDOW_SIZE.y],
			"selected_option_id": OPTION_ID,
			"capture_script": "res://tests/visible/shop_formal_sync_parity_capture.gd",
			"captures": _captures,
			"passed": not _failed,
		}
		var file := FileAccess.open(_output_dir.path_join("capture_manifest.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(manifest, "  ") + "\n")
			file.close()
	print("SHOP_FORMAL_SYNC_PARITY_CAPTURE_%s output=%s captures=%d" % ["FAIL" if _failed else "PASS", _output_dir, _captures.size()])
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
	push_error("SHOP_FORMAL_SYNC_PARITY_CAPTURE_FAIL: %s" % message)
