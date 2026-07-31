extends NinePatchRect

signal feature_view_requested(feature_id: StringName)
signal feature_view_release_requested(feature_id: StringName)

const GameLogScript := preload("res://core/logging/game_log.gd")
const SessionBridgeScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd")
const StagePresenterScript := preload("res://core_ui/scripts/artist_flow/presenters/artist_flow_stage_presenter.gd")
const AssetRegistryScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_asset_registry.gd")
const PET_DETAIL_PANEL_SCENE := preload("res://art/prefabs/pet/pet_detail.tscn")
const RoutePresenterScript := preload("res://core_ui/scripts/route/presenters/route_presenter.gd")
const ShopPresenterScript := preload("res://core_ui/scripts/shop/presenters/shop_presenter.gd")
const InventoryPresenterScript := preload("res://core_ui/scripts/inventory/presenters/inventory_presenter.gd")
const PartyPresenterScript := preload("res://core_ui/scripts/party/presenters/party_presenter.gd")
const SettlementPresenterScript := preload("res://core_ui/scripts/settlement/presenters/settlement_presenter.gd")

const VIEW_THREE_OPTION := &"three_option"
const VIEW_SHOP := &"shop"
const VIEW_BAG := &"bag"
const VIEW_BATTLE := &"battle"

const DRAG_PREVIEW_SIZE := Vector2(110.0, 110.0)
const DRAG_SOURCE_NONE := &"none"
const DRAG_SOURCE_SHOP := &"shop"
const DRAG_SOURCE_PARTY := &"party"
const DRAG_SOURCE_BAG := &"bag"
const TARGET_AUTO := &"auto"
const TARGET_PARTY := &"party"
const TARGET_BAG := &"bag"
const TARGET_SELL := &"sell"
const RUN_TOOL_SIZE := Vector2(92.0, 48.0)
const FIXED_TEST_PLAY_SEED := "ysbzs-test-play-20260715-v1"
const BAG_CLOSED_TEXTURE := preload("res://art/images/route/three_choice_psd/bag_closed.png")
const BAG_OPEN_TEXTURE := preload("res://art/images/route/three_choice_psd/bag_open.png")
const ITEM_SELECTED_HIGHLIGHT_TEXTURE := preload("res://art/images/route/three_choice_psd/item_selected_highlight.png")

@export_group("Item Slot Highlight")
@export var item_slot_highlight_offset := Vector2.ZERO
@export var item_slot_highlight_size := Vector2(110.0, 110.0)

@onready var animation_player: AnimationPlayer = $"../../../AnimationPlayer"
@onready var middle_three_option: Control = $Middle_Three_Option
@onready var bag_overlay_mask: Control = $BagOverlayMask
@onready var middle_shop: Control = $Middle_Shop
@onready var middle_bag: Control = $Middle_Bag
@onready var party_container: GridContainer = $"../Party/Party_Container"
@onready var top_shop: Control = get_node_or_null("../Top/Top_Shop") as Control
@onready var top_sell_button: Button = get_node_or_null("../Top/Top_Sell") as Button
@onready var shop_back_button: TextureButton = get_node_or_null("../Top/Top_Shop/Shop_BackButton") as TextureButton
@onready var bags_panel: Control = $"../Bags"
@onready var bag_button: TextureButton = $"../Bags/Bag_Button"
@onready var time_label: Label = get_node_or_null("../Top/Hud/TimeLabel") as Label
@onready var coin_label: Label = get_node_or_null("../Top/Hud/CoinLabel") as Label

var _session_bridge := SessionBridgeScript.new()
var _stage_presenter := StagePresenterScript.new()
var state: RefCounted:
	get:
		return _session_bridge.authority()
	set(value):
		set_state_authority(value)
var game_session: Variant:
	get:
		return _session_bridge.session()
	set(value):
		set_game_session(value)
var _current_view := VIEW_THREE_OPTION
var _view_before_bag := VIEW_THREE_OPTION
var _is_transitioning := false
var _asset_registry := AssetRegistryScript.new()
var _three_buttons: Array[TextureButton] = []
var _three_slots: Array[Control] = []
var _shop_buttons: Array[TextureButton] = []
var _shop_slots: Array[Control] = []
var _party_buttons: Array[TextureButton] = []
var _party_slots: Array[Control] = []
var _bag_buttons: Array[TextureButton] = []
var _bag_slots: Array[Control] = []
var _drag_candidate_source := DRAG_SOURCE_NONE
var _drag_candidate_index := -1
var _is_dragging_shop_item := false
var _is_dragging_storage_item := false
var _drag_preview: TextureRect = null
var _drag_hidden_button: TextureButton = null
var _drag_hidden_visual: Control = null
var _drag_hidden_texture: Texture2D = null
var _drag_hidden_restore := false
var _is_toggling_bag := false
var _bag_page := 0
var _hovered_route_index := -1
var _battle_view: Control = null
var _pet_detail_panel: Control = null
var _bazaar_info_panel: Control = null
var _run_tools: PanelContainer = null
var _run_status_label: Label = null
var _item_slot_hover_highlight: TextureRect = null
var _visible_auto_battle_running := false
var _route_presenter := RoutePresenterScript.new()
var _shop_presenter := ShopPresenterScript.new()
var _inventory_presenter := InventoryPresenterScript.new()
var _party_presenter := PartyPresenterScript.new()
var _settlement_presenter := SettlementPresenterScript.new()


func _ready() -> void:
	if not _session_bridge.asynchronous_snapshot_received.is_connected(_on_session_bridge_snapshot_received):
		_session_bridge.asynchronous_snapshot_received.connect(_on_session_bridge_snapshot_received)
	_ensure_game_session()
	_asset_registry.reload()
	_collect_slots()
	_ensure_pet_detail_panel()
	_ensure_bazaar_info_panel()
	_ensure_run_tools()
	_configure_stage_presenter()
	_connect_buttons()
	_prepare_sell_button()
	_render_content_from_state(_current_snapshot())
	_set_initial_state()
	call_deferred("_show_initial_view")
	call_deferred("_refresh_slot_button_layouts")


func _exit_tree() -> void:
	_session_bridge.dispose()
	_stage_presenter.dispose()


func set_state_authority(authority: RefCounted) -> void:
	if authority == null or state == authority:
		return
	_session_bridge.bind_authority(authority)
	if is_node_ready():
		_render_from_state()


func render_current_snapshot() -> void:
	if is_node_ready():
		_render_from_state()


func get_feature_controller(feature_name: StringName) -> Variant:
	match feature_name:
		&"route":
			return _route_presenter
		&"shop":
			return _shop_presenter
		&"inventory":
			return _inventory_presenter
		&"party":
			return _party_presenter
		&"settlement":
			return _settlement_presenter
		&"battle":
			return _battle_view
		_:
			return null


func get_missing_image_report() -> Array:
	return _asset_registry.missing_image_report()


func get_battle_missing_mapping_report() -> Array:
	_ensure_battle_view()
	if _battle_view != null and _battle_view.has_method("get_missing_mapping_report"):
		return Array(_battle_view.call("get_missing_mapping_report"))
	return []


func _collect_slots() -> void:
	_three_slots = _get_direct_control_children(_slot_root(middle_three_option))
	_three_buttons = _get_texture_buttons(middle_three_option)
	_shop_slots = _get_direct_control_children(_slot_root(middle_shop))
	_shop_buttons = _get_texture_buttons(middle_shop)
	_party_slots = _get_direct_control_children(party_container)
	_party_buttons = _get_texture_buttons(party_container)
	_bag_slots = _get_direct_control_children(_slot_root(middle_bag))
	_bag_buttons = _get_texture_buttons(middle_bag)


func _connect_buttons() -> void:
	for index in range(_three_buttons.size()):
		var button := _three_buttons[index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_prepare_slot_image_button(button)
		if not button.pressed.is_connected(_on_three_pressed):
			button.pressed.connect(_on_three_pressed.bind(index))
		if not button.mouse_entered.is_connected(_on_three_mouse_entered):
			button.mouse_entered.connect(_on_three_mouse_entered.bind(index))

	for index in range(_shop_buttons.size()):
		var button := _shop_buttons[index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_prepare_slot_image_button(button)
		if not button.button_down.is_connected(_on_shop_button_down):
			button.button_down.connect(_on_shop_button_down.bind(index))
		if not button.mouse_entered.is_connected(_on_shop_pet_mouse_entered):
			button.mouse_entered.connect(_on_shop_pet_mouse_entered.bind(index))
		if not button.mouse_exited.is_connected(_on_shop_pet_mouse_exited):
			button.mouse_exited.connect(_on_shop_pet_mouse_exited.bind(index))

	for index in range(_party_buttons.size()):
		var button := _party_buttons[index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_prepare_slot_image_button(button)
		if not button.button_down.is_connected(_on_party_button_down):
			button.button_down.connect(_on_party_button_down.bind(index))
		if not button.mouse_entered.is_connected(_on_party_pet_mouse_entered):
			button.mouse_entered.connect(_on_party_pet_mouse_entered.bind(index))
		if not button.mouse_exited.is_connected(_on_party_pet_mouse_exited):
			button.mouse_exited.connect(_on_party_pet_mouse_exited.bind(index))

	for index in range(_bag_buttons.size()):
		var button := _bag_buttons[index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_prepare_slot_image_button(button)
		if not button.button_down.is_connected(_on_bag_slot_button_down):
			button.button_down.connect(_on_bag_slot_button_down.bind(index))
		if not button.mouse_entered.is_connected(_on_bag_pet_mouse_entered):
			button.mouse_entered.connect(_on_bag_pet_mouse_entered.bind(index))
		if not button.mouse_exited.is_connected(_on_bag_pet_mouse_exited):
			button.mouse_exited.connect(_on_bag_pet_mouse_exited.bind(index))

	if shop_back_button != null and not shop_back_button.pressed.is_connected(_on_shop_back_pressed):
		shop_back_button.pressed.connect(_on_shop_back_pressed)
	if top_shop != null:
		top_shop.mouse_filter = Control.MOUSE_FILTER_STOP
	if top_shop != null and not top_shop.gui_input.is_connected(_on_top_shop_gui_input):
		top_shop.gui_input.connect(_on_top_shop_gui_input)
	if not bag_button.pressed.is_connected(_on_bag_pressed):
		bag_button.pressed.connect(_on_bag_pressed)
	bags_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not bags_panel.gui_input.is_connected(_on_bags_gui_input):
		bags_panel.gui_input.connect(_on_bags_gui_input)


func _render_from_state() -> void:
	var snap := _current_snapshot()
	var target_view := _render_content_from_state(snap)
	_show_view(target_view)


func _render_content_from_state(snap: Dictionary) -> StringName:
	_asset_registry.clear_missing_report()
	_render_hud(snap)
	_render_roster(snap)
	var target_view := VIEW_THREE_OPTION
	match String(snap.get("phase", "route")):
		"shop":
			_render_shop(snap)
			target_view = VIEW_SHOP
		"reward":
			_render_reward(snap)
		"battle":
			_render_battle_view(snap)
			target_view = VIEW_BATTLE
		"battle_end", "day_end", "game_over":
			_render_terminal_choice(snap)
		_:
			_render_route(snap)
	_render_bazaar_information(snap, target_view)
	return target_view


func _render_route(snap: Dictionary) -> void:
	_hovered_route_index = -1
	var cards := Array(_route_presenter.call("cards", snap))
	for index in range(_three_buttons.size()):
		var card := Dictionary(cards[index]) if index < cards.size() else {}
		var option := Dictionary(card.get("record", {}))
		var button := _three_buttons[index]
		var slot := _three_slots[index] if index < _three_slots.size() else button.get_parent()
		var has_option := not card.is_empty()
		button.disabled = not has_option
		if has_option:
			_render_route_card(slot, button, _route_slot_texture(index), _route_slot_icon_texture(index), index)
			button.set_meta("command", Dictionary(card.get("command", {})))
			button.set_meta("detail_record", {})
			_clear_runtime_overlays(slot)
		else:
			_clear_route_card(slot, button)
			button.set_meta("command", {})
			button.set_meta("detail_record", {})
			_clear_runtime_overlays(slot)


func _render_reward(snap: Dictionary) -> void:
	var cards := Array(_settlement_presenter.call("reward_cards", snap))
	for index in range(_three_buttons.size()):
		var card := Dictionary(cards[index]) if index < cards.size() else {}
		var reward := Dictionary(card.get("record", {}))
		var button := _three_buttons[index]
		var slot := _three_slots[index] if index < _three_slots.size() else button.get_parent()
		var has_reward := not card.is_empty()
		button.disabled = not has_reward
		if has_reward:
			var texture := _pet_texture(reward)
			_render_route_card(slot, button, texture, _route_icon_texture("reward"), index)
			button.set_meta("command", Dictionary(card.get("command", {})))
			button.set_meta("detail_record", reward)
			_clear_runtime_overlays(slot)
			if texture == null:
				_record_missing_image("reward", reward)
		else:
			_clear_route_card(slot, button)
			button.set_meta("command", {})
			button.set_meta("detail_record", {})
			_clear_runtime_overlays(slot)


func _render_battle_view(snap: Dictionary) -> void:
	_ensure_battle_view()
	if _battle_view != null and _battle_view.has_method("render_snapshot"):
		_battle_view.call("render_snapshot", snap)


func attach_feature_view(feature_id: StringName, view: Node) -> void:
	if feature_id != VIEW_BATTLE or not (view is Control):
		return
	var battle_view := _runtime_feature_view(view)
	if battle_view == null:
		return
	if _battle_view == battle_view:
		return
	_detach_battle_view()
	_battle_view = battle_view
	_battle_view.name = "BattleFlow"
	_battle_view.visible = false
	_battle_view.z_index = 50
	_battle_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	var command_callback := Callable(self, "_on_battle_command_requested")
	if _battle_view.has_signal("command_requested") \
			and not _battle_view.is_connected("command_requested", command_callback):
		_battle_view.connect("command_requested", command_callback)
	_configure_stage_presenter()


func detach_feature_view(feature_id: StringName, view: Node = null) -> void:
	if feature_id != VIEW_BATTLE:
		return
	if view != null and _battle_view != _runtime_feature_view(view):
		return
	_detach_battle_view()


func _runtime_feature_view(view: Node) -> Control:
	if view == null:
		return null
	if view.has_method("get_runtime_view"):
		return view.call("get_runtime_view") as Control
	return view as Control


func _detach_battle_view() -> void:
	if is_instance_valid(_battle_view):
		var command_callback := Callable(self, "_on_battle_command_requested")
		if _battle_view.has_signal("command_requested") \
				and _battle_view.is_connected("command_requested", command_callback):
			_battle_view.disconnect("command_requested", command_callback)
	_battle_view = null
	_configure_stage_presenter()


func _render_terminal_choice(snap: Dictionary) -> void:
	var card := Dictionary(_settlement_presenter.call("terminal_card", snap, FIXED_TEST_PLAY_SEED))
	var title := String(card.get("title", "继续"))
	var command := Dictionary(card.get("command", {}))
	for index in range(_three_buttons.size()):
		var button := _three_buttons[index]
		var slot := _three_slots[index] if index < _three_slots.size() else button.get_parent()
		button.disabled = index != 0
		if index == 0:
			button.tooltip_text = title
			_render_route_card(slot, button, _route_texture({}, "reward"), _route_icon_texture("reward"), index)
			button.set_meta("command", command)
			button.set_meta("detail_record", {})
			_clear_runtime_overlays(slot)
		else:
			button.tooltip_text = ""
			_clear_route_card(slot, button)
			button.set_meta("command", {})
			button.set_meta("detail_record", {})
			_clear_runtime_overlays(slot)


func _render_shop(snap: Dictionary) -> void:
	var cards := Array(_shop_presenter.call("cards", snap))
	for index in range(_shop_buttons.size()):
		var card := Dictionary(cards[index]) if index < cards.size() else {}
		var offer := Dictionary(card.get("record", {}))
		var button := _shop_buttons[index]
		var slot := _shop_slots[index] if index < _shop_slots.size() else button.get_parent()
		var has_offer := bool(card.get("available", false))
		button.disabled = not has_offer
		if has_offer:
			var texture := _pet_texture(offer)
			button.texture_normal = texture
			button.set_meta("pet_texture", null)
			button.set_meta("command", Dictionary(card.get("command", {})))
			button.set_meta("drag_record", offer)
			_clear_runtime_overlays(slot)
			if texture == null:
				_record_missing_image("shop_offer", offer)
		else:
			button.texture_normal = null
			button.set_meta("pet_texture", null)
			button.set_meta("command", {})
			button.set_meta("drag_record", {})
			_clear_runtime_overlays(slot)


func _render_roster(snap: Dictionary) -> void:
	var party_slots := Array(_party_presenter.call("slots", snap, _party_buttons.size()))

	for index in range(_party_buttons.size()):
		var button := _party_buttons[index]
		var slot := _party_slots[index] if index < _party_slots.size() else button.get_parent()
		var pet := Dictionary(party_slots[index]) if index < party_slots.size() else {}
		if not pet.is_empty():
			var texture := _pet_texture(pet)
			_render_shared_pet(slot, button, pet, texture)
			button.set_meta("drag_record", pet)
			_clear_runtime_overlays(slot)
			if texture == null:
				_record_missing_image("party_active", pet)
		else:
			_clear_shared_pet(slot, button)
			button.set_meta("drag_record", {})
			_clear_runtime_overlays(slot)

	var bag_model := Dictionary(_inventory_presenter.call("page", snap, _bag_page, _bag_buttons.size()))
	var bag_display := Array(bag_model.get("items", []))
	_bag_page = int(bag_model.get("page", 0))
	for index in range(_bag_buttons.size()):
		var button := _bag_buttons[index]
		var slot := _bag_slots[index] if index < _bag_slots.size() else button.get_parent()
		if index < bag_display.size():
			var pet := Dictionary(bag_display[index])
			var texture := _pet_texture(pet)
			_render_shared_pet(slot, button, pet, texture)
			button.set_meta("drag_record", pet)
			_clear_runtime_overlays(slot)
			if texture == null:
				_record_missing_image("bag_pet", pet)
		else:
			_clear_shared_pet(slot, button)
			button.set_meta("drag_record", {})
			_clear_runtime_overlays(slot)


func _on_three_pressed(index: int) -> void:
	if _is_transitioning or _has_active_drag() or index < 0 or index >= _three_buttons.size():
		return
	var command := Dictionary(_three_buttons[index].get_meta("command", {}))
	if command.is_empty():
		return
	var snap := _current_snapshot()
	if String(snap.get("phase", "")) == "reward":
		var reward := Dictionary(_three_buttons[index].get_meta("detail_record", {}))
		if not reward.is_empty():
			_show_pet_detail(reward, command)
		return
	if not await _submit_core_command(command):
		return
	var target_view := _render_content_from_state(_take_core_command_snapshot())
	await _transition_to_view(target_view)


func _on_shop_button_down(index: int) -> void:
	if _is_transitioning or _has_active_drag() or _current_view != VIEW_SHOP or index < 0 or index >= _shop_buttons.size():
		return
	var command := Dictionary(_shop_buttons[index].get_meta("command", {}))
	if command.is_empty():
		return
	var offer := Dictionary(_shop_buttons[index].get_meta("drag_record", {}))
	var item_type := String(offer.get("item_type", "宠物" if String(offer.get("pet_id", "")) != "" else ""))
	if item_type != "宠物":
		_close_pet_context_detail()
		if await _submit_core_command(command):
			_render_content_from_state(_take_core_command_snapshot())
		return
	_close_pet_context_detail()
	_start_drag_candidate(DRAG_SOURCE_SHOP, index)
	_start_shop_item_drag()


func _on_shop_pet_mouse_entered(index: int) -> void:
	if _is_transitioning or _has_active_drag() or _current_view != VIEW_SHOP:
		return
	_show_item_slot_highlight(_shop_slots[index] if index >= 0 and index < _shop_slots.size() else null)
	_show_shop_pet_context(index)


func _on_shop_pet_mouse_exited(_index: int) -> void:
	if _has_active_drag() or _current_view != VIEW_SHOP:
		return
	_hide_item_slot_highlight()
	_close_pet_context_detail()


func _on_three_mouse_entered(index: int) -> void:
	if _is_transitioning or _has_active_drag() or _current_view != VIEW_THREE_OPTION:
		return
	if index < 0 or index >= _three_slots.size():
		return
	if _three_buttons[index].disabled:
		return
	_set_hovered_route_card(index)


func _on_party_button_down(index: int) -> void:
	_start_storage_drag_candidate(DRAG_SOURCE_PARTY, index)


func _on_party_pet_mouse_entered(index: int) -> void:
	if _is_transitioning or _has_active_drag() or _current_view == VIEW_BATTLE:
		return
	_show_storage_pet_context(DRAG_SOURCE_PARTY, index)


func _on_party_pet_mouse_exited(_index: int) -> void:
	if _has_active_drag():
		return
	_close_pet_context_detail()


func _on_bag_slot_button_down(index: int) -> void:
	_start_storage_drag_candidate(DRAG_SOURCE_BAG, index)


func _on_bag_pet_mouse_entered(index: int) -> void:
	if _is_transitioning or _has_active_drag() or _current_view != VIEW_BAG:
		return
	_show_item_slot_highlight(_bag_slots[index] if index >= 0 and index < _bag_slots.size() else null)
	_show_storage_pet_context(DRAG_SOURCE_BAG, index)


func _on_bag_pet_mouse_exited(_index: int) -> void:
	if _has_active_drag() or _current_view != VIEW_BAG:
		return
	_hide_item_slot_highlight()
	_close_pet_context_detail()


func _start_storage_drag_candidate(source: StringName, index: int) -> void:
	if _is_transitioning or _has_active_drag() or not _can_start_storage_drag(source):
		return
	if source == DRAG_SOURCE_PARTY and (index < 0 or index >= _party_buttons.size()):
		return
	if source == DRAG_SOURCE_BAG and (index < 0 or index >= _bag_buttons.size()):
		return
	if _drag_record_for_source(source, index).is_empty():
		return
	_start_drag_candidate(source, index)
	_start_storage_item_drag()


func _start_drag_candidate(source: StringName, index: int) -> void:
	_drag_candidate_source = source
	_drag_candidate_index = index
	_is_dragging_shop_item = false
	_is_dragging_storage_item = false


func _input(event: InputEvent) -> void:
	if _drag_candidate_source == DRAG_SOURCE_NONE or _drag_candidate_index < 0:
		return
	if event is InputEventMouseMotion:
		var mouse_position := get_global_mouse_position()
		if _has_active_drag():
			_update_drag_preview(mouse_position)
	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event.button_index != MOUSE_BUTTON_LEFT or mouse_button_event.pressed:
			return
		var mouse_position := get_global_mouse_position()
		if _is_dragging_shop_item:
			await _drop_dragged_shop_item(mouse_position)
		elif _is_dragging_storage_item:
			await _drop_dragged_storage_item(mouse_position)
		_clear_drag_state()


func _start_shop_item_drag() -> void:
	if _drag_candidate_index < 0 or _drag_candidate_index >= _shop_buttons.size():
		_clear_drag_state()
		return
	if Dictionary(_shop_buttons[_drag_candidate_index].get_meta("command", {})).is_empty():
		_clear_drag_state()
		return
	_is_dragging_shop_item = true
	_start_drag_preview()


func _start_storage_item_drag() -> void:
	if _drag_record_for_source(_drag_candidate_source, _drag_candidate_index).is_empty():
		_clear_drag_state()
		return
	_is_dragging_storage_item = true
	_set_sell_button_visible(_can_sell_storage_items())
	_start_drag_preview()


func _has_active_drag() -> bool:
	return _is_dragging_shop_item or _is_dragging_storage_item


func _can_sell_storage_items() -> bool:
	return _current_view != VIEW_BATTLE and party_container != null and party_container.is_visible_in_tree()


func _can_start_storage_drag(source: StringName) -> bool:
	if source == DRAG_SOURCE_PARTY:
		return _current_view != VIEW_BATTLE and party_container != null and party_container.is_visible_in_tree()
	if source == DRAG_SOURCE_BAG:
		return _current_view == VIEW_BAG and middle_bag != null and middle_bag.is_visible_in_tree()
	return false


func _drop_dragged_shop_item(mouse_position: Vector2) -> void:
	if _drag_candidate_index < 0 or _drag_candidate_index >= _shop_buttons.size():
		return
	var offer_command := Dictionary(_shop_buttons[_drag_candidate_index].get_meta("command", {}))
	if offer_command.is_empty():
		return
	var target := _drop_target_for_position(mouse_position)
	var target_kind := String(target.get("kind", TARGET_AUTO))
	if target_kind != TARGET_PARTY and target_kind != TARGET_BAG:
		if _drag_candidate_index < _shop_slots.size() and _is_point_inside_control(_shop_slots[_drag_candidate_index], mouse_position):
			_show_shop_pet_context(_drag_candidate_index)
		return
	var command := {
		"type": "DROP_ITEM_ON_TARGET",
		"source_type": DRAG_SOURCE_SHOP,
		"source_index": _drag_candidate_index,
		"offer_id": String(offer_command.get("offer_id", "")),
		"target_type": target_kind,
		"target_index": int(target.get("index", -1))
	}
	if not await _submit_core_command(command):
		return
	_discard_drag_source_restore()
	var target_view := _render_content_from_state(_take_core_command_snapshot())
	await _transition_to_view(target_view)


func _drop_dragged_storage_item(mouse_position: Vector2) -> void:
	var record := _drag_record_for_source(_drag_candidate_source, _drag_candidate_index)
	if record.is_empty():
		return
	var target := _drop_target_for_position(mouse_position)
	var kind := String(target.get("kind", ""))
	if (kind == TARGET_PARTY and _drag_candidate_source == DRAG_SOURCE_PARTY and int(target.get("index", -1)) == _drag_candidate_index) \
		or (kind == TARGET_BAG and _drag_candidate_source == DRAG_SOURCE_BAG and int(target.get("index", -1)) == _drag_candidate_index):
		return
	var unit_id := _record_ref(record)
	if unit_id == "":
		return
	var command := {
		"type": "DROP_ITEM_ON_TARGET",
		"source_type": _drag_candidate_source,
		"source_index": _drag_candidate_index,
		"unitId": unit_id,
		"target_type": kind,
		"target_index": int(target.get("index", -1))
	}
	var allowed := kind == TARGET_SELL \
		or (_drag_candidate_source == DRAG_SOURCE_PARTY and kind == TARGET_PARTY) \
		or (_drag_candidate_source == DRAG_SOURCE_PARTY and kind == TARGET_BAG) \
		or (_drag_candidate_source == DRAG_SOURCE_BAG and kind == TARGET_BAG) \
		or (_drag_candidate_source == DRAG_SOURCE_BAG and kind == TARGET_PARTY)
	if not allowed:
		return
	if not await _submit_core_command(command):
		return
	_discard_drag_source_restore()
	var target_view := _render_content_from_state(_take_core_command_snapshot())
	if _current_view == VIEW_BAG and kind != TARGET_SELL:
		_show_view(VIEW_BAG)
		return
	await _transition_to_view(target_view)


func _drop_target_for_position(mouse_position: Vector2) -> Dictionary:
	var bag_index := _find_slot_at_position(_bag_slots, mouse_position)
	if bag_index >= 0:
		return {"kind": TARGET_BAG, "index": bag_index}
	var party_index := _find_slot_at_position(_party_slots, mouse_position)
	if party_index >= 0:
		return {"kind": TARGET_PARTY, "index": party_index}
	if _is_point_inside_control(bag_button, mouse_position):
		return {"kind": TARGET_BAG, "index": -1}
	if _is_point_inside_control(top_sell_button, mouse_position):
		return {"kind": TARGET_SELL, "index": -1}
	return {"kind": TARGET_AUTO, "index": -1}


func _drag_record_for_source(source: StringName, index: int) -> Dictionary:
	match source:
		DRAG_SOURCE_SHOP:
			if index >= 0 and index < _shop_buttons.size():
				return Dictionary(_shop_buttons[index].get_meta("drag_record", {}))
		DRAG_SOURCE_PARTY:
			if index >= 0 and index < _party_buttons.size():
				return Dictionary(_party_buttons[index].get_meta("drag_record", {}))
		DRAG_SOURCE_BAG:
			if index >= 0 and index < _bag_buttons.size():
				return Dictionary(_bag_buttons[index].get_meta("drag_record", {}))
	return {}


func _record_ref(record: Dictionary) -> String:
	for key in ["id", "unitId", "unit_id", "pet_id", "petId", "instance_id", "instanceId"]:
		var value := String(record.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func _find_slot_at_position(slots: Array[Control], mouse_position: Vector2) -> int:
	for index in range(slots.size()):
		if _is_point_inside_control(slots[index], mouse_position):
			return index
	return -1


func _is_point_inside_control(control: Control, point: Vector2) -> bool:
	return control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point)


func _start_drag_preview() -> void:
	var texture := _drag_texture_for_candidate()
	if texture == null:
		return
	_hide_drag_source_texture(texture)
	_create_drag_preview(texture, _drag_preview_size_for_candidate())
	_update_drag_preview(get_global_mouse_position())


func _drag_button_for_candidate() -> TextureButton:
	match _drag_candidate_source:
		DRAG_SOURCE_SHOP:
			if _drag_candidate_index >= 0 and _drag_candidate_index < _shop_buttons.size():
				return _shop_buttons[_drag_candidate_index]
		DRAG_SOURCE_PARTY:
			if _drag_candidate_index >= 0 and _drag_candidate_index < _party_buttons.size():
				return _party_buttons[_drag_candidate_index]
		DRAG_SOURCE_BAG:
			if _drag_candidate_index >= 0 and _drag_candidate_index < _bag_buttons.size():
				return _bag_buttons[_drag_candidate_index]
	return null


func _drag_texture_for_candidate() -> Texture2D:
	var button := _drag_button_for_candidate()
	if button == null:
		return null
	var shared_texture := button.get_meta("pet_texture") as Texture2D if button.has_meta("pet_texture") else null
	return shared_texture if shared_texture != null else button.texture_normal


func _drag_preview_size_for_candidate() -> Vector2:
	var button := _drag_button_for_candidate()
	if button == null:
		return DRAG_PREVIEW_SIZE
	var size := button.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = button.custom_minimum_size
	if size.x <= 0.0 or size.y <= 0.0:
		return DRAG_PREVIEW_SIZE
	return size


func _create_drag_preview(texture: Texture2D, preview_size: Vector2) -> void:
	_clear_drag_preview()
	_drag_preview = TextureRect.new()
	_drag_preview.name = "DragPreview"
	_drag_preview.texture = texture
	_drag_preview.custom_minimum_size = preview_size
	_drag_preview.size = preview_size
	_drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.82)
	_drag_preview.z_index = 100
	get_tree().root.add_child(_drag_preview)


func _update_drag_preview(mouse_position: Vector2) -> void:
	if _drag_preview == null:
		return
	_drag_preview.global_position = mouse_position - _drag_preview.size * 0.5


func _clear_drag_preview() -> void:
	if _drag_preview == null:
		return
	_drag_preview.queue_free()
	_drag_preview = null


func _hide_drag_source_texture(texture: Texture2D) -> void:
	var button := _drag_button_for_candidate()
	if button == null:
		return
	_drag_hidden_button = button
	_drag_hidden_visual = _shared_pet_visual(button.get_parent() as Control)
	_drag_hidden_texture = texture
	_drag_hidden_restore = true
	if _drag_hidden_visual != null:
		_drag_hidden_visual.visible = false
	else:
		button.texture_normal = null


func _restore_drag_source_texture() -> void:
	if _drag_hidden_restore:
		if _drag_hidden_visual != null:
			_drag_hidden_visual.visible = _drag_hidden_texture != null
		elif _drag_hidden_button != null:
			_drag_hidden_button.texture_normal = _drag_hidden_texture
	_discard_drag_source_restore()


func _discard_drag_source_restore() -> void:
	_drag_hidden_button = null
	_drag_hidden_visual = null
	_drag_hidden_texture = null
	_drag_hidden_restore = false


func _clear_drag_state() -> void:
	_clear_drag_preview()
	_restore_drag_source_texture()
	_drag_candidate_source = DRAG_SOURCE_NONE
	_drag_candidate_index = -1
	_is_dragging_shop_item = false
	_is_dragging_storage_item = false
	_set_sell_button_visible(false)
	_hide_item_slot_highlight()


func _prepare_sell_button() -> void:
	if top_sell_button == null:
		return
	top_sell_button.text = "出售"
	top_sell_button.mouse_filter = Control.MOUSE_FILTER_STOP
	top_sell_button.focus_mode = Control.FOCUS_NONE
	_set_sell_button_visible(false)


func _set_sell_button_visible(is_visible: bool) -> void:
	if top_sell_button == null:
		return
	top_sell_button.visible = is_visible
	top_sell_button.disabled = not is_visible


func _on_shop_back_pressed() -> void:
	if _is_transitioning or _has_active_drag():
		return
	if not await _submit_core_command({"type": "EXIT_SHOP"}):
		return
	var target_view := _render_content_from_state(_take_core_command_snapshot())
	await _transition_to_view(target_view)


func _on_top_shop_gui_input(event: InputEvent) -> void:
	if _current_view != VIEW_SHOP or _has_active_drag():
		return
	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT and not mouse_button_event.pressed:
			accept_event()
			await _on_shop_back_pressed()


func _on_bag_pressed() -> void:
	if _is_transitioning or _is_toggling_bag or _has_active_drag():
		return
	_is_toggling_bag = true
	if _current_view == VIEW_BAG:
		await _close_bag()
	else:
		await _open_bag()
	_is_toggling_bag = false


func _on_bags_gui_input(event: InputEvent) -> void:
	if _has_active_drag():
		accept_event()
		return
	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT and not mouse_button_event.pressed:
			accept_event()
			await _on_bag_pressed()


func _show_view(view: StringName) -> void:
	_close_pet_detail()
	var previous_view := _current_view
	_current_view = view
	_stage_presenter.show_immediate(view)
	_set_persistent_hud_visible(view != VIEW_BATTLE)
	_set_bag_button_open(view == VIEW_BAG)
	_set_run_tools_visible(true)
	_release_battle_view_after_transition(previous_view, view)


func _set_initial_state() -> void:
	_ensure_persistent_hud_visible()
	_set_run_tools_visible(true)
	_stage_presenter.set_initial()


func _show_initial_view() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	var target_view := _target_view_from_state()
	await _stage_presenter.show_initial(target_view)
	_current_view = target_view
	_ensure_persistent_hud_visible()
	_set_bag_button_open(target_view == VIEW_BAG)
	_set_run_tools_visible(true)
	_is_transitioning = false


func _transition_to_view(target_view: StringName) -> void:
	if target_view == _current_view:
		_show_view(target_view)
		return
	var previous_view := _current_view
	_is_transitioning = true
	await _stage_presenter.switch_view(_current_view, target_view)
	_current_view = target_view
	_ensure_persistent_hud_visible()
	_set_bag_button_open(target_view == VIEW_BAG)
	_set_run_tools_visible(true)
	_is_transitioning = false
	_release_battle_view_after_transition(previous_view, target_view)


func _open_bag() -> void:
	_is_transitioning = true
	_view_before_bag = _current_view
	_set_bag_overlay_visible(true)
	_set_bag_view_visible(true)
	if _view_before_bag == VIEW_SHOP:
		middle_shop.visible = false
		if top_shop != null:
			top_shop.visible = false
	middle_three_option.visible = true
	_set_canvas_alpha(middle_three_option, 1.0)
	_current_view = VIEW_BAG
	_ensure_persistent_hud_visible()
	_set_bag_button_open(true)
	_set_run_tools_visible(true)
	_render_bazaar_information(_current_snapshot(), VIEW_BAG)
	_is_transitioning = false


func _close_bag() -> void:
	_is_transitioning = true
	_set_bag_overlay_visible(false)
	_set_bag_view_visible(false)
	if _view_before_bag == VIEW_SHOP:
		middle_three_option.visible = false
		middle_shop.visible = true
		if top_shop != null:
			top_shop.visible = true
	else:
		middle_three_option.visible = true
	_set_canvas_alpha(middle_three_option, 1.0)
	_current_view = _view_before_bag
	_ensure_persistent_hud_visible()
	_set_bag_button_open(false)
	_set_run_tools_visible(true)
	_render_bazaar_information(_current_snapshot(), _current_view)
	_is_transitioning = false


func _set_bag_overlay_visible(is_visible: bool) -> void:
	if bag_overlay_mask == null:
		return
	bag_overlay_mask.visible = is_visible
	_set_canvas_alpha(bag_overlay_mask, 1.0)


func _set_bag_view_visible(is_visible: bool) -> void:
	if middle_bag == null:
		return
	middle_bag.visible = is_visible
	_set_canvas_alpha(middle_bag, 1.0)


func _set_canvas_alpha(node: CanvasItem, alpha: float) -> void:
	if node == null:
		return
	var color := node.modulate
	color.a = alpha
	node.modulate = color


func _target_view_from_state() -> StringName:
	match String(_current_snapshot().get("phase", "route")):
		"shop":
			return VIEW_SHOP
		"battle":
			return VIEW_BATTLE
		_:
			return VIEW_THREE_OPTION


func _before_stage_clear() -> void:
	_close_pet_context_detail()
	_hide_item_slot_highlight()
	_ensure_persistent_hud_visible()


func _configure_stage_presenter() -> void:
	_stage_presenter.configure(self, animation_player, {
		&"three_option": middle_three_option,
		&"bag_overlay": bag_overlay_mask,
		&"shop": middle_shop,
		&"bag": middle_bag,
		&"shop_top": top_shop,
		&"battle": _battle_view
	}, Callable(self, "_before_stage_clear"))


func _ensure_persistent_hud_visible() -> void:
	_set_persistent_hud_visible(_current_view != VIEW_BATTLE)


func _set_persistent_hud_visible(is_visible: bool) -> void:
	if bags_panel != null:
		bags_panel.visible = is_visible
	var party_panel := party_container.get_parent() as Control if party_container != null else null
	if party_panel != null:
		party_panel.visible = is_visible


func _ensure_battle_view() -> void:
	if is_instance_valid(_battle_view):
		return
	_battle_view = null
	feature_view_requested.emit(VIEW_BATTLE)


func _release_battle_view_after_transition(previous_view: StringName, target_view: StringName) -> void:
	if previous_view == VIEW_BATTLE and target_view != VIEW_BATTLE and is_instance_valid(_battle_view):
		feature_view_release_requested.emit(VIEW_BATTLE)


func _ensure_pet_detail_panel() -> void:
	if _pet_detail_panel != null:
		return
	var scene_root := owner as Control
	if scene_root == null:
		return
	_pet_detail_panel = scene_root.get_node_or_null("ArtistPetDetailPanel") as Control
	if _pet_detail_panel == null:
		_pet_detail_panel = PET_DETAIL_PANEL_SCENE.instantiate() as Control
		_pet_detail_panel.name = "ArtistPetDetailPanel"
		_pet_detail_panel.z_index = 200
		scene_root.add_child.call_deferred(_pet_detail_panel)
	if _pet_detail_panel.has_signal("confirm_requested"):
		_pet_detail_panel.connect("confirm_requested", Callable(self, "_on_pet_detail_confirm_requested"))


func _ensure_bazaar_info_panel() -> void:
	if _bazaar_info_panel != null:
		return
	var scene_root := owner as Control
	if scene_root == null:
		return
	_bazaar_info_panel = scene_root.get_node_or_null("BazaarInfoPanel") as Control
	if _bazaar_info_panel == null:
		return
	if _bazaar_info_panel.has_signal("command_requested"):
		_bazaar_info_panel.connect("command_requested", Callable(self, "_on_bazaar_info_command_requested"))


func _render_bazaar_information(snap: Dictionary, target_view: StringName) -> void:
	_ensure_bazaar_info_panel()
	if _bazaar_info_panel != null and _bazaar_info_panel.has_method("render_snapshot"):
		var panel_snapshot := snap.duplicate(true)
		panel_snapshot["ui_bag_page"] = _bag_page
		_bazaar_info_panel.call("render_snapshot", panel_snapshot, target_view)


func _on_bazaar_info_command_requested(command: Dictionary) -> void:
	if _is_transitioning or command.is_empty():
		return
	if String(command.get("type", "")) == "UI_SET_BAG_PAGE":
		_bag_page = max(0, int(command.get("page", 0)))
		var snap := _current_snapshot()
		_render_roster(snap)
		_render_bazaar_information(snap, VIEW_BAG)
		return
	if not await _submit_core_command(command):
		return
	var target_view := _render_content_from_state(_take_core_command_snapshot())
	await _transition_to_view(target_view)


func _show_pet_detail(record: Dictionary, confirm_command: Dictionary = {}) -> void:
	_ensure_pet_detail_panel()
	if _pet_detail_panel == null or not _pet_detail_panel.has_method("show_detail"):
		return
	var detail_record := Dictionary(record.get("source", record))
	if detail_record.is_empty():
		detail_record = record
	detail_record = _detail_record_with_display_skill(detail_record)
	detail_record["attack_shape"] = _attack_shape_for_record(detail_record, _current_snapshot())
	_pet_detail_panel.call("show_detail", detail_record, _pet_texture(detail_record), confirm_command)


func _show_shop_pet_context(index: int) -> void:
	if index < 0 or index >= _shop_buttons.size():
		return
	var record := _drag_record_for_source(DRAG_SOURCE_SHOP, index)
	if record.is_empty():
		_close_pet_context_detail()
		return
	_ensure_pet_detail_panel()
	if _pet_detail_panel == null or not _pet_detail_panel.has_method("show_context_detail"):
		return
	var detail_record := _detail_record_with_display_skill(record)
	detail_record["attack_shape"] = _attack_shape_for_record(detail_record, _current_snapshot())
	_pet_detail_panel.call("show_context_detail", detail_record, _pet_texture(detail_record))


func _show_storage_pet_context(source: StringName, index: int) -> void:
	var record := _drag_record_for_source(source, index)
	if record.is_empty():
		_close_pet_context_detail()
		return
	_ensure_pet_detail_panel()
	if _pet_detail_panel == null or not _pet_detail_panel.has_method("show_context_detail"):
		return
	var detail_record := _detail_record_with_display_skill(record)
	detail_record["attack_shape"] = _attack_shape_for_record(detail_record, _current_snapshot())
	_pet_detail_panel.call("show_context_detail", detail_record, _pet_texture(detail_record))


func _close_pet_context_detail() -> void:
	if _pet_detail_panel != null and _pet_detail_panel.has_method("close_context_detail"):
		_pet_detail_panel.call("close_context_detail")


func _show_item_slot_highlight(slot: Control) -> void:
	if slot == null:
		return
	_ensure_item_slot_hover_highlight()
	if _item_slot_hover_highlight == null:
		return
	var rect := slot.get_global_rect()
	_item_slot_hover_highlight.size = item_slot_highlight_size
	_item_slot_hover_highlight.global_position = rect.position + item_slot_highlight_offset
	_item_slot_hover_highlight.visible = true
	_item_slot_hover_highlight.move_to_front()


func _hide_item_slot_highlight() -> void:
	if _item_slot_hover_highlight != null:
		_item_slot_hover_highlight.visible = false


func _ensure_item_slot_hover_highlight() -> void:
	if is_instance_valid(_item_slot_hover_highlight):
		return
	_item_slot_hover_highlight = TextureRect.new()
	_item_slot_hover_highlight.name = "ItemSlotHoverHighlight"
	_item_slot_hover_highlight.texture = ITEM_SELECTED_HIGHLIGHT_TEXTURE
	_item_slot_hover_highlight.custom_minimum_size = item_slot_highlight_size
	_item_slot_hover_highlight.size = item_slot_highlight_size
	_item_slot_hover_highlight.stretch_mode = TextureRect.STRETCH_SCALE
	_item_slot_hover_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_slot_hover_highlight.visible = false
	_item_slot_hover_highlight.z_index = 80
	add_child(_item_slot_hover_highlight)


func _detail_record_with_display_skill(record: Dictionary) -> Dictionary:
	var detail_record := record.duplicate(true)
	var skill_id := String(detail_record.get("skill", ""))
	if skill_id == "":
		return detail_record
	var skill := Dictionary(Dictionary(_current_snapshot().get("skill_catalog", {})).get(skill_id, {}))
	var skill_name := String(skill.get("name", skill_id))
	var skill_description := String(skill.get("description", ""))
	detail_record["skill_description"] = skill_name if skill_description == "" else "%s\n%s" % [skill_name, skill_description]
	return detail_record


func _attack_shape_for_record(record: Dictionary, snap: Dictionary) -> Dictionary:
	var shape_id := String(record.get("shape_id", record.get("shapeId", ""))).strip_edges()
	var shape_text := String(record.get("shape", record.get("shape_name", ""))).strip_edges()
	for value in Array(Dictionary(snap.get("battle", {})).get("shape_catalog", [])):
		var shape := Dictionary(value)
		var candidate_id := String(shape.get("shape_id", shape.get("shapeId", ""))).strip_edges()
		var candidate_label := String(shape.get("label", "")).strip_edges()
		if candidate_id != "" and (candidate_id == shape_id or shape_text == candidate_id or shape_text == candidate_label or shape_text.contains(candidate_id)):
			return shape.duplicate(true)
	return {}


func _close_pet_detail() -> void:
	if _pet_detail_panel != null and _pet_detail_panel.has_method("close"):
		_pet_detail_panel.call("close")


func _on_pet_detail_confirm_requested(command: Dictionary) -> void:
	if _is_transitioning or command.is_empty() or not await _submit_core_command(command):
		return
	var target_view := _render_content_from_state(_take_core_command_snapshot())
	await _transition_to_view(target_view)


func _on_battle_command_requested(command: Dictionary) -> void:
	if _is_transitioning or command.is_empty():
		return
	if String(command.get("type", "")) == "RUN_BATTLE":
		await _run_visible_auto_battle()
		return
	if not await _submit_core_command(command):
		return
	var command_snapshot := _take_core_command_snapshot()
	if String(command.get("type", "")) == "RUN_COMBAT_ROUND" \
			and String(command_snapshot.get("phase", "")) != "battle":
		_render_battle_view(command_snapshot)
		await _await_battle_trace_sequence()
	var target_view := _render_content_from_state(command_snapshot)
	await _transition_to_view(target_view)


func _await_battle_trace_sequence() -> void:
	if _battle_view != null \
			and _battle_view.has_method("is_battle_input_locked") \
			and bool(_battle_view.call("is_battle_input_locked")) \
			and _battle_view.has_signal("trace_sequence_finished"):
		await _battle_view.trace_sequence_finished


func _run_visible_auto_battle() -> void:
	if _visible_auto_battle_running or String(_current_snapshot().get("phase", "")) != "battle":
		return
	_visible_auto_battle_running = true
	var guard := 0
	while String(_current_snapshot().get("phase", "")) == "battle" and guard < 40:
		guard += 1
		var pre_round_snapshot := _current_snapshot()
		if bool(Dictionary(Dictionary(pre_round_snapshot.get("pet_reset", {})).get("player", {})).get("eligible", false)):
			if not await _submit_core_command({"type": "RESET_PETS"}):
				break
			_render_battle_view(_take_core_command_snapshot())
		if not await _submit_core_command({"type": "AUTO_POSITION_HEROES"}):
			break
		_render_battle_view(_take_core_command_snapshot())
		if not await _submit_core_command({"type": "RUN_COMBAT_ROUND"}):
			break
		var round_snapshot := _take_core_command_snapshot()
		_render_battle_view(round_snapshot)
		await _await_battle_trace_sequence()
		if String(round_snapshot.get("phase", "")) != "battle":
			var target_view := _render_content_from_state(round_snapshot)
			await _transition_to_view(target_view)
			break
	_visible_auto_battle_running = false


func _ensure_run_tools() -> void:
	if _run_tools != null:
		return
	var scene_root := owner as Control
	if scene_root == null:
		return
	_run_tools = PanelContainer.new()
	_run_tools.name = "RunTools"
	_run_tools.z_index = 90
	_run_tools.mouse_filter = Control.MOUSE_FILTER_STOP
	_run_tools.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_run_tools.position = Vector2(28.0, 22.0)
	_run_tools.custom_minimum_size = Vector2(1180.0, 62.0)
	_run_tools.add_theme_stylebox_override("panel", _make_run_tools_style())

	var row := HBoxContainer.new()
	row.name = "RunToolsRow"
	row.add_theme_constant_override("separation", 10)
	_run_tools.add_child(row)

	var slot_count := int(game_session.persistence_slot_count()) if game_session != null and game_session.has_method("persistence_slot_count") else 0
	for slot in range(1, slot_count + 1):
		var save_button_name := "SaveButton" if slot == 1 else "SaveSlot%dButton" % slot
		var load_button_name := "LoadButton" if slot == 1 else "LoadSlot%dButton" % slot
		_add_run_tool_button(row, "保存%d" % slot, save_button_name, _on_save_slot_pressed.bind(slot))
		_add_run_tool_button(row, "读档%d" % slot, load_button_name, _on_load_slot_pressed.bind(slot))
	_add_run_tool_button(row, "导出回放", "ExportReplayButton", _on_export_replay_pressed)
	_add_run_tool_button(row, "导出战报", "ExportBattleTraceButton", _on_export_battle_trace_pressed)

	_run_status_label = Label.new()
	_run_status_label.name = "RunToolsStatus"
	_run_status_label.custom_minimum_size = Vector2(220.0, RUN_TOOL_SIZE.y)
	_run_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_run_status_label.add_theme_font_size_override("font_size", 18)
	_run_status_label.add_theme_color_override("font_color", Color("#f4edd8"))
	_run_status_label.text = "本地存档"
	row.add_child(_run_status_label)
	scene_root.add_child.call_deferred(_run_tools)


func _add_run_tool_button(row: HBoxContainer, label_text: String, button_name: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = label_text
	button.custom_minimum_size = RUN_TOOL_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	row.add_child(button)


func _make_run_tools_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.78)
	style.border_color = Color(0.84, 0.68, 0.38, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style


func _on_save_slot_pressed(slot: int) -> void:
	_ensure_game_session()
	if not _session_supports_persistence():
		_set_run_tools_status("当前会话不支持本地存档")
		return
	var ok: bool = _session_bridge.save_to_slot(slot)
	_set_run_tools_status("已保存槽%d" % slot if ok else "槽%d保存失败" % slot)
	_render_content_from_state(_current_snapshot())


func _on_load_slot_pressed(slot: int) -> void:
	_ensure_game_session()
	if not _session_supports_persistence():
		_set_run_tools_status("当前会话不支持本地读档")
		return
	var ok: bool = _session_bridge.load_from_slot(slot)
	_set_run_tools_status("已读档槽%d" % slot if ok else "槽%d读档失败" % slot)
	var target_view := _render_content_from_state(_current_snapshot())
	await _transition_to_view(target_view)


func _on_export_replay_pressed() -> void:
	_ensure_game_session()
	if not _session_supports_persistence():
		_set_run_tools_status("当前会话不支持本地导出")
		return
	var ok: bool = _session_bridge.export_replay()
	_set_run_tools_status("已导出回放" if ok else "导出失败")
	_render_content_from_state(_current_snapshot())


func _on_export_battle_trace_pressed() -> void:
	_ensure_game_session()
	if not _session_supports_persistence():
		_set_run_tools_status("当前会话不支持本地导出")
		return
	var ok: bool = _session_bridge.export_battle_trace()
	_set_run_tools_status("已导出战报" if ok else "导出失败")
	_render_content_from_state(_current_snapshot())


func _set_run_tools_status(text: String) -> void:
	if _run_status_label != null:
		_run_status_label.text = text


func _session_supports_persistence() -> bool:
	return _session_bridge.supports_persistence()


func _set_run_tools_visible(is_visible: bool) -> void:
	if _run_tools != null:
		_run_tools.position.y = 14.0 if _current_view == VIEW_BATTLE else 22.0
		_run_tools.visible = is_visible and _current_view == VIEW_BATTLE


func _submit_core_command(command: Dictionary) -> bool:
	_ensure_game_session()
	var response := Dictionary(await _session_bridge.submit_command(command))
	if bool(response.get("accepted", false)):
		return true
	var command_type := String(response.get("command", command.get("type", "")))
	var error := Dictionary(response.get("error", {}))
	var reason := String(error.get("message", error.get("code", "rejected")))
	_set_run_tools_status("操作未生效")
	GameLogScript.warning("界面/核心命令", "核心拒绝界面命令", {"命令": command_type, "原因": reason, "当前视图": _current_view})
	return false


func _take_core_command_snapshot() -> Dictionary:
	return _session_bridge.take_command_snapshot()


func set_game_session(session: RefCounted) -> void:
	_session_bridge.bind_session(session)


func get_game_session() -> RefCounted:
	_ensure_game_session()
	return _session_bridge.session()


func _ensure_game_session() -> void:
	_session_bridge.ensure_default(FIXED_TEST_PLAY_SEED)


func _on_session_bridge_snapshot_received(snap: Dictionary) -> void:
	call_deferred("_apply_async_game_session_snapshot", snap)


func _apply_async_game_session_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	var target_view := _render_content_from_state(snap)
	await _transition_to_view(target_view)


func _current_snapshot() -> Dictionary:
	_ensure_game_session()
	return _session_bridge.current_snapshot()


func _prepare_slot_image_button(button: TextureButton) -> void:
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var parent := button.get_parent() as Control
	if parent == null:
		return
	if parent.has_method("set_portrait"):
		button.texture_normal = null
		button.custom_minimum_size = parent.custom_minimum_size
		button.position = Vector2.ZERO
		button.size = parent.custom_minimum_size
		return
	var image_size := parent.size - Vector2(24, 24)
	if image_size.x <= 0 or image_size.y <= 0:
		image_size = parent.custom_minimum_size - Vector2(24, 24)
	image_size.x = maxf(image_size.x, 96.0)
	image_size.y = maxf(image_size.y, 96.0)
	button.custom_minimum_size = image_size
	button.position = Vector2(12, 12)
	button.size = image_size


func _refresh_slot_button_layouts() -> void:
	for button in _three_buttons:
		_prepare_slot_image_button(button)
	for button in _shop_buttons:
		_prepare_slot_image_button(button)
	for button in _party_buttons:
		_prepare_slot_image_button(button)
	for button in _bag_buttons:
		_prepare_slot_image_button(button)


func _slot_root(root: Node) -> Node:
	if root == null:
		return null
	for name in ["Slots", "CardGrid"]:
		var child := root.get_node_or_null(name)
		if child != null:
			return child
	return root


func _clear_runtime_overlays(slot: Control) -> void:
	if slot == null:
		return
	var label := slot.get_node_or_null("RuntimeLabel") as Label
	if label != null:
		label.queue_free()
	var icon := slot.get_node_or_null("RuntimeIcon") as TextureRect
	if icon != null:
		icon.queue_free()


func _render_route_card(
	slot: Control,
	button: TextureButton,
	texture_resource: Texture2D,
	icon_resource: Texture2D,
	_slot_index: int = -1
) -> void:
	button.texture_normal = null
	var card := slot
	if card != null and card.has_method("set_portrait"):
		card.call("set_portrait", texture_resource)
		card.call("set_kind_icon", icon_resource)
		if card.has_method("set_route_highlight"):
			card.call("set_route_highlight", _route_slot_highlight_texture(_slot_index))
		card.call("set_hovered", false)
		return
	button.texture_normal = texture_resource


func _clear_route_card(slot: Control, button: TextureButton) -> void:
	button.texture_normal = null
	if slot != null and slot.has_method("clear"):
		slot.call("clear")


func _render_hud(snap: Dictionary) -> void:
	if time_label != null:
		var day := int(snap.get("day", 1))
		var node_index := int(snap.get("node_index", snap.get("nodeIndex", 1)))
		time_label.text = "第%d天 第%d节点" % [day, node_index]
	if coin_label != null:
		coin_label.text = str(int(snap.get("coins", 0)))


func _set_bag_button_open(is_open: bool) -> void:
	if bag_button == null:
		return
	bag_button.texture_normal = BAG_OPEN_TEXTURE if is_open else BAG_CLOSED_TEXTURE
	if is_open:
		bag_button.position = Vector2(56.0, 0.0)
		bag_button.size = Vector2(158.0, 182.0)
	else:
		bag_button.position = Vector2(55.0, 51.0)
		bag_button.size = Vector2(161.0, 123.0)


func _set_hovered_route_card(index: int) -> void:
	_hovered_route_index = index
	for slot_index in range(_three_slots.size()):
		var slot := _three_slots[slot_index]
		if slot != null and slot.has_method("set_hovered"):
			slot.call("set_hovered", slot_index == _hovered_route_index)


func _render_shared_pet(slot: Control, button: TextureButton, record: Dictionary, texture_resource: Texture2D) -> void:
	button.texture_normal = null
	button.set_meta("pet_texture", texture_resource)
	var visual := _shared_pet_visual(slot)
	if visual == null:
		return
	visual.visible = texture_resource != null
	if visual.has_method("set_collection_data"):
		if visual.is_node_ready():
			visual.call("set_collection_data", record, texture_resource)
		else:
			visual.call_deferred("set_collection_data", record, texture_resource)


func _clear_shared_pet(slot: Control, button: TextureButton) -> void:
	button.texture_normal = null
	button.set_meta("pet_texture", null)
	var visual := _shared_pet_visual(slot)
	if visual == null:
		return
	if visual.has_method("clear_collection_data"):
		if visual.is_node_ready():
			visual.call("clear_collection_data")
		else:
			visual.call_deferred("clear_collection_data")
	visual.visible = false


func _shared_pet_visual(slot: Control) -> Control:
	if slot == null:
		return null
	return slot.find_child("PetVisual", true, false) as Control


func _route_texture(option: Dictionary, kind: String) -> Texture2D:
	return _asset_registry.route_texture(option, kind)


func _route_slot_texture(index: int) -> Texture2D:
	return _asset_registry.route_slot_texture(index)


func _route_icon_texture(kind: String) -> Texture2D:
	return _asset_registry.route_icon_texture(kind)


func _route_slot_icon_texture(index: int) -> Texture2D:
	return _asset_registry.route_slot_icon_texture(index)


func _route_slot_highlight_texture(index: int) -> Texture2D:
	return _asset_registry.route_slot_highlight_texture(index)


func _pet_texture(record: Dictionary) -> Texture2D:
	return _asset_registry.pet_texture(record)


func _load_pet_image_map() -> void:
	_asset_registry.reload()


func _record_missing_image(context: String, record: Dictionary) -> void:
	_asset_registry.record_missing_image(context, record)


func _get_texture_buttons(root: Node) -> Array[TextureButton]:
	var buttons: Array[TextureButton] = []
	_collect_texture_buttons(root, buttons)
	return buttons


func _get_direct_control_children(root: Node) -> Array[Control]:
	var controls: Array[Control] = []
	for child in root.get_children():
		if child is Control:
			controls.append(child)
	return controls


func _collect_texture_buttons(node: Node, buttons: Array[TextureButton]) -> void:
	if node is TextureButton:
		buttons.append(node)
	for child in node.get_children():
		_collect_texture_buttons(child, buttons)
