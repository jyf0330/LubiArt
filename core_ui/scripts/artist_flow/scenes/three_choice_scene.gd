extends Control

## The only script attached directly to ThreeChoiceScene. It binds authored
## nodes, projects snapshots into presentation, handles visual interaction and
## emits requests upward. Game owns the session and completes every request.

signal command_requested(command: Dictionary, request_id: int)
signal presentation_settled

const GameLogScript := preload("res://core/logging/game_log.gd")
const StagePresenterScript := preload("res://core_ui/scripts/artist_flow/presenters/artist_flow_stage_presenter.gd")
const AssetRegistryScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_asset_registry.gd")
const RoutePresenterScript := preload("res://core_ui/scripts/route/presenters/route_presenter.gd")
const InventoryPresenterScript := preload("res://core_ui/scripts/inventory/presenters/inventory_presenter.gd")
const PartyPresenterScript := preload("res://core_ui/scripts/party/presenters/party_presenter.gd")
const SettlementPresenterScript := preload("res://core_ui/scripts/settlement/presenters/settlement_presenter.gd")
const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")
const ShortcutCatalog := preload("res://core_ui/scripts/shared/shortcut_catalog.gd")
const RequestBrokerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_request_broker.gd")
const FocusCoordinatorScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_focus_coordinator.gd")
const DragControllerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")

const VIEW_THREE_OPTION := &"three_option"
const VIEW_BAG := &"bag"

const SLOT_DRAG_PREVIEW_SIZE := Vector2(96.0, 96.0)
const DRAG_SOURCE_NONE := DragControllerScript.SOURCE_NONE
const DRAG_SOURCE_PARTY := DragControllerScript.SOURCE_PARTY
const DRAG_SOURCE_BAG := DragControllerScript.SOURCE_BAG
const FIXED_TEST_PLAY_SEED := "ysbzs-test-play-20260715-v1"
const PARTY_SHELF_TEXTURE := preload("res://art/images/route/three_choice_psd/party_shelf.png")
const BAG_SLOT_HIGHLIGHT_TEXTURE := preload("res://art/images/route/three_choice_psd/bag_item_highlight.png")
const STANDALONE_PARTY_PREVIEW_TEXTURE := preload("res://art/images/shared/pets/sheets/slices/pet_style_001_gold_mascot.png")

@onready var middle_three_option: Control = $MainBG/Containers/Middle/Middle_Three_Option
@onready var route_shared_ui: Control = $RouteSharedUi
@onready var bag_overlay_mask: Control = $RouteSharedUi/BagOverlayMask
@onready var middle_bag: Control = $RouteSharedUi/Middle_Bag
@onready var party_container: Control = $RouteSharedUi/Party/Party_Container
@onready var top_sell_button: TextureButton = $RouteSharedUi/Top/Top_Sell
@onready var bags_panel: Control = $RouteSharedUi/Bags
@onready var bag_button: TextureButton = $RouteSharedUi/Bags/Bag_Button
@onready var bag_storage_state: TextureRect = $RouteSharedUi/Bags/BagStorageState
@onready var exit_button: TextureButton = $RouteSharedUi/ExitButton

var _stage_presenter := StagePresenterScript.new()
var _snapshot: Dictionary = {}
var _last_command_snapshot: Dictionary = {}
var _request_broker := RequestBrokerScript.new()
var _focus_coordinator := FocusCoordinatorScript.new()
var _drag_controller := DragControllerScript.new()
var _current_view := VIEW_THREE_OPTION
var _view_before_bag := VIEW_THREE_OPTION
var _is_transitioning := false
var _asset_registry := AssetRegistryScript.new()
var _three_buttons: Array[TextureButton] = []
var _three_slots: Array[Control] = []
var _party_buttons: Array[TextureButton] = []
var _party_slots: Array[Control] = []
var _bag_buttons: Array[TextureButton] = []
var _bag_slots: Array[Control] = []
var _is_toggling_bag := false
var _bag_page := 0
var _hovered_route_index := -1
var _selected_route_index := -1
var _selected_route_command := {}
var _hovered_storage_source := DRAG_SOURCE_NONE
var _hovered_storage_index := -1
var _pet_detail_panel: Control = null
var _route_presenter := RoutePresenterScript.new()
var _inventory_presenter := InventoryPresenterScript.new()
var _party_presenter := PartyPresenterScript.new()
var _settlement_presenter := SettlementPresenterScript.new()
var _standalone_art_preview := false

func _ready() -> void:
	RuntimeUiPolicy.install()
	_configure_request_broker()
	_asset_registry.reload()
	_prepare_shared_slots()
	_collect_slots()
	_set_bag_storage_count(0)
	_configure_drag_controller()
	_ensure_pet_detail_panel()
	_configure_stage_presenter()
	_connect_buttons()
	_configure_focus_navigation()
	_prepare_sell_button()
	_standalone_art_preview = _current_snapshot().is_empty() \
		and (get_parent() == null or not get_parent().has_method("get_game_session"))
	if _standalone_art_preview:
		_render_standalone_art_preview()
	else:
		_render_content_from_state(_current_snapshot())
	_set_initial_state()
	call_deferred("_show_initial_view")
	call_deferred("_grab_focus_for_current_view")

func _prepare_shared_slots() -> void:
	route_shared_ui.call("ensure_bag_buttons")
	for value in Array(route_shared_ui.call("party_buttons")):
		var button := value as TextureButton
		if button == null:
			continue
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.set_meta("slot_surface_self", true)
		button.set_meta("drag_preview_size", SLOT_DRAG_PREVIEW_SIZE)

func _set_slot_texture(button: TextureButton, texture_resource: Texture2D) -> void:
	if button in _party_buttons:
		route_shared_ui.call("set_party_texture", button, texture_resource)
	else:
		route_shared_ui.call("set_bag_texture", button, texture_resource)

func _game_cursor() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"game_cursor")

func _get(property: StringName) -> Variant:
	# Focused legacy smoke reads these diagnostics by name. Keep the probe shape
	# without mirroring transient state back into the page facade.
	match property:
		&"_drag_candidate_source":
			return _drag_controller.candidate_source()
		&"_drag_candidate_index":
			return _drag_controller.candidate_index()
		&"_drag_preview":
			return _drag_controller.preview()
		&"_drag_preview_locked_size":
			return _drag_controller.preview_locked_size()
	return null

func _configure_request_broker() -> void:
	var command_callback := Callable(self, "_on_broker_command_requested")
	if not _request_broker.command_requested.is_connected(command_callback):
		_request_broker.command_requested.connect(command_callback)

func _on_broker_command_requested(command: Dictionary, request_id: int) -> void:
	command_requested.emit(command.duplicate(true), request_id)

func _set_game_cursor_loading(source: StringName, active: bool) -> void:
	var cursor := _game_cursor()
	if cursor != null and cursor.has_method("set_loading_source"):
		cursor.call("set_loading_source", source, active)

func _exit_tree() -> void:
	_drag_controller.dispose()
	_stage_presenter.dispose()
	_request_broker.dispose()
	_focus_coordinator.dispose()

func render_snapshot(snapshot: Dictionary, animate_transition: bool = true) -> void:
	_snapshot = snapshot.duplicate(true)
	if not _snapshot.is_empty():
		_standalone_art_preview = false
	if not is_node_ready():
		return
	var target_view := _render_content_from_state(_snapshot)
	if animate_transition:
		await _transition_to_view(target_view)
	else:
		_show_view(target_view)

func render_current_snapshot() -> void:
	if is_node_ready():
		_render_from_state()

func is_presentation_busy() -> bool:
	return _is_transitioning

func complete_command_request(request_id: int, response: Dictionary) -> void:
	_request_broker.complete_command(request_id, response)

func get_feature_controller(feature_name: StringName) -> Variant:
	match feature_name:
		&"route":
			return _route_presenter
		&"inventory":
			return _inventory_presenter
		&"party":
			return _party_presenter
		&"settlement":
			return _settlement_presenter
		_:
			return null

func get_missing_image_report() -> Array:
	return _asset_registry.missing_image_report()

func _collect_slots() -> void:
	_three_slots = _get_direct_control_children(_slot_root(middle_three_option))
	_three_buttons = _get_texture_buttons(middle_three_option)
	_party_slots = _get_direct_control_children(party_container)
	_party_buttons.clear()
	for value in Array(route_shared_ui.call("party_buttons")):
		if value is TextureButton:
			_party_buttons.append(value as TextureButton)
	_bag_slots = _get_direct_control_children(_slot_root(middle_bag))
	_bag_buttons.clear()
	for value in Array(route_shared_ui.call("bag_buttons")):
		if value is TextureButton:
			_bag_buttons.append(value as TextureButton)

func _configure_drag_controller() -> void:
	_drag_controller.configure(self, {
		"shop_buttons": [],
		"shop_slots": [],
		"party_buttons": _party_buttons,
		"party_slots": _party_slots,
		"bag_buttons": _bag_buttons,
		"bag_slots": _bag_slots,
		"bag_button": bag_button,
		"sell_button": top_sell_button,
	}, Callable(), Callable(self, "_set_drag_source_visible"), Callable(self, "_show_drag_bag_highlight"), Callable(self, "_set_sell_button_visible"), Callable(self, "_hide_item_slot_highlight"))

func _set_drag_source_visible(
		button: TextureButton,
		source: StringName,
		_index: int,
		texture_resource: Texture2D,
		source_visible: bool
) -> void:
	button.set_meta("pet_texture", texture_resource)
	route_shared_ui.call("set_drag_source_visible", button, source, source_visible)

func _show_drag_bag_highlight(slot: Control, _index: int) -> void:
	route_shared_ui.call("show_bag_slot_highlight", slot, BAG_SLOT_HIGHLIGHT_TEXTURE)

func _connect_buttons() -> void:
	for index in range(_three_buttons.size()):
		var button := _three_buttons[index]
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not button.pressed.is_connected(_on_three_pressed):
			button.pressed.connect(_on_three_pressed.bind(index))
		if not button.mouse_entered.is_connected(_on_three_mouse_entered):
			button.mouse_entered.connect(_on_three_mouse_entered.bind(index))
		if not button.mouse_exited.is_connected(_on_three_mouse_exited):
			button.mouse_exited.connect(_on_three_mouse_exited.bind(index))

	for index in range(_party_buttons.size()):
		var button := _party_buttons[index]
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.set_meta("focus_tint_disabled", true)
		button.set_meta("party_mouse_hovered", false)
		if not button.button_down.is_connected(_on_party_button_down):
			button.button_down.connect(_on_party_button_down.bind(index))
		if not button.mouse_entered.is_connected(_on_party_pet_mouse_entered):
			button.mouse_entered.connect(_on_party_pet_mouse_entered.bind(index))
		if not button.mouse_exited.is_connected(_on_party_pet_mouse_exited):
			button.mouse_exited.connect(_on_party_pet_mouse_exited.bind(index))

	for index in range(_bag_buttons.size()):
		var button := _bag_buttons[index]
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not button.button_down.is_connected(_on_bag_slot_button_down):
			button.button_down.connect(_on_bag_slot_button_down.bind(index))
		if not button.mouse_entered.is_connected(_on_bag_pet_mouse_entered):
			button.mouse_entered.connect(_on_bag_pet_mouse_entered.bind(index))
		if not button.mouse_exited.is_connected(_on_bag_pet_mouse_exited):
			button.mouse_exited.connect(_on_bag_pet_mouse_exited.bind(index))

	if not bag_button.pressed.is_connected(_on_bag_pressed):
		bag_button.pressed.connect(_on_bag_pressed)
	bag_button.focus_mode = Control.FOCUS_ALL
	bag_button.set_meta("slot_surface_self", true)
	bag_button.set_meta("focus_tint_disabled", true)
	bags_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not bags_panel.gui_input.is_connected(_on_bags_gui_input):
		bags_panel.gui_input.connect(_on_bags_gui_input)
	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)
	exit_button.focus_mode = Control.FOCUS_ALL
	exit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	exit_button.set_meta("slot_surface_self", true)
	exit_button.set_meta("focus_tint_disabled", true)

func _configure_focus_navigation() -> void:
	_focus_coordinator.configure(
		self,
		_three_buttons,
		_party_buttons,
		_bag_buttons,
		bag_button,
		exit_button
	)
	_configure_current_focus_ring()

func _configure_current_focus_ring() -> void:
	_focus_coordinator.refresh(_current_view)

func _grab_focus_for_current_view() -> void:
	_focus_coordinator.grab_if_current_focus_hidden(_current_view)

func _restore_button_tint(button: BaseButton) -> void:
	_focus_coordinator.restore_button_tint(button)

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
			# Shop is rendered by the dedicated feature Scene mounted by Game.
			target_view = VIEW_THREE_OPTION
		"reward":
			_render_reward(snap)
		"battle":
			# Game owns the mounted BattleArtScene; this hidden route page does not render it.
			pass
		"battle_end", "day_end", "game_over":
			_render_terminal_choice(snap)
		_:
			_render_route(snap)
	return target_view

func _render_route(snap: Dictionary) -> void:
	_hovered_route_index = -1
	_selected_route_index = -1
	_selected_route_command = {}
	var cards := Array(_route_presenter.call("cards", snap))
	for index in range(_three_buttons.size()):
		var card := Dictionary(cards[index]) if index < cards.size() else {}
		var option := Dictionary(card.get("record", {}))
		var button := _three_buttons[index]
		var slot := _three_slots[index] if index < _three_slots.size() else button.get_parent()
		var has_option := not card.is_empty()
		button.disabled = not has_option
		if has_option:
			_render_route_card(slot, button, _route_slot_texture(index, option), _route_slot_icon_texture(index), index)
			button.set_meta("command", Dictionary(card.get("command", {})))
			button.set_meta("route_kind", String(card.get("kind", "")))
			button.set_meta("detail_record", {})
			_clear_runtime_overlays(slot)
		else:
			_clear_route_card(slot, button)
			button.set_meta("command", {})
			button.set_meta("route_kind", "")
			button.set_meta("detail_record", {})
			_clear_runtime_overlays(slot)
		button.set_meta("base_tint", Color.WHITE)
		_restore_button_tint(button)
	_update_exit_button_state()
	call_deferred("_configure_current_focus_ring")


func _render_standalone_art_preview() -> void:
	_hovered_route_index = -1
	_selected_route_index = -1
	_selected_route_command = {}
	for index in range(_three_buttons.size()):
		var button := _three_buttons[index]
		var slot := _three_slots[index] if index < _three_slots.size() else button.get_parent()
		button.disabled = false
		_render_route_card(
			slot,
			button,
			_route_slot_texture(index, {"id": "standalone_art_preview_%d" % index}),
			_route_slot_icon_texture(index),
			index
		)
		button.set_meta("command", {})
		button.set_meta("route_kind", "")
		button.set_meta("detail_record", {})
		button.set_meta("base_tint", Color.WHITE)
		_restore_button_tint(button)

	var preview_texture := STANDALONE_PARTY_PREVIEW_TEXTURE
	for index in range(_party_buttons.size()):
		var party_button := _party_buttons[index]
		if index == 0 and preview_texture != null:
			_render_shared_pet(_party_slots[index], party_button, {}, preview_texture)
			party_button.set_meta("drag_record", {"id": "standalone_art_preview_party_0"})
		else:
			_clear_shared_pet(_party_slots[index], party_button)
			party_button.set_meta("drag_record", {})
	_update_exit_button_state()
	call_deferred("_configure_current_focus_ring")

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
		button.set_meta("base_tint", Color.WHITE)
		_restore_button_tint(button)
	call_deferred("_configure_current_focus_ring")

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
		button.set_meta("base_tint", Color.WHITE)
		_restore_button_tint(button)
	call_deferred("_configure_current_focus_ring")

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
	_set_bag_storage_count(int(bag_model.get("total_count", 0)))
	for index in range(_bag_buttons.size()):
		var button := _bag_buttons[index]
		var slot := _bag_slots[index] if index < _bag_slots.size() else button.get_parent()
		var pet := Dictionary(bag_display[index]) if index < bag_display.size() else {}
		if not pet.is_empty():
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
	if _standalone_art_preview:
		_selected_route_index = index
		_set_selected_route_card(index)
		return
	var command := Dictionary(_three_buttons[index].get_meta("command", {}))
	if command.is_empty():
		return
	var snap := _current_snapshot()
	if String(snap.get("phase", "route")) == "route":
		_selected_route_index = index
		_selected_route_command = command.duplicate(true)
		_set_selected_route_card(index)
		_update_exit_button_state()
		return
	if String(snap.get("phase", "")) == "reward":
		_close_pet_context_detail()
	if not await _submit_core_command(command):
		return
	var target_view := _render_content_from_state(_take_core_command_snapshot())
	await _transition_to_view(target_view)

func _on_three_mouse_entered(index: int) -> void:
	if _is_transitioning or _has_active_drag() or _current_view != VIEW_THREE_OPTION:
		return
	if index < 0 or index >= _three_buttons.size() or index >= _three_slots.size():
		return
	if _three_buttons[index].disabled:
		return
	_set_hovered_route_card(index)
	if String(_current_snapshot().get("phase", "")) != "reward":
		return
	var reward := Dictionary(_three_buttons[index].get_meta("detail_record", {}))
	if reward.is_empty():
		return
	_ensure_pet_detail_panel()
	if _pet_detail_panel == null or not _pet_detail_panel.has_method("show_context_detail"):
		return
	var detail_record := Dictionary(reward.get("source", reward))
	if detail_record.is_empty():
		detail_record = reward
	detail_record = _detail_record_with_display_skill(detail_record)
	detail_record["attack_shape"] = _attack_shape_for_record(detail_record, _current_snapshot())
	_pet_detail_panel.call("show_context_detail", detail_record, _pet_texture(detail_record))

func _on_three_mouse_exited(_index: int) -> void:
	_set_hovered_route_card(-1)
	_close_pet_context_detail()

func _on_party_button_down(index: int) -> void:
	_start_storage_drag_candidate(DRAG_SOURCE_PARTY, index)

func _on_party_pet_mouse_entered(index: int) -> void:
	if _is_transitioning or _has_active_drag():
		return
	_set_hovered_storage_target(DRAG_SOURCE_PARTY, index)
	if index >= 0 and index < _party_buttons.size():
		route_shared_ui.call("set_party_hovered", _party_buttons[index], true)
	_show_storage_pet_context(DRAG_SOURCE_PARTY, index)

func _on_party_pet_mouse_exited(index: int) -> void:
	if index >= 0 and index < _party_buttons.size():
		route_shared_ui.call("set_party_hovered", _party_buttons[index], false)
	if _has_active_drag():
		return
	_clear_hovered_storage_target(DRAG_SOURCE_PARTY, index)
	_close_pet_context_detail()

func _on_bag_slot_button_down(index: int) -> void:
	_start_storage_drag_candidate(DRAG_SOURCE_BAG, index)

func _on_bag_pet_mouse_entered(index: int) -> void:
	if _is_transitioning or _has_active_drag() or _current_view != VIEW_BAG:
		return
	_set_hovered_storage_target(DRAG_SOURCE_BAG, index)
	_show_item_slot_highlight(
		_bag_slots[index] if index >= 0 and index < _bag_slots.size() else null,
		null,
		BAG_SLOT_HIGHLIGHT_TEXTURE
	)
	_show_storage_pet_context(DRAG_SOURCE_BAG, index)

func _on_bag_pet_mouse_exited(index: int) -> void:
	if _has_active_drag() or _current_view != VIEW_BAG:
		return
	_clear_hovered_storage_target(DRAG_SOURCE_BAG, index)
	_hide_item_slot_highlight()
	_close_pet_context_detail()

func _start_storage_drag_candidate(source: StringName, index: int) -> void:
	if _is_transitioning or _has_active_drag() or not _can_start_storage_drag(source):
		return
	if _drag_controller.begin_storage(source, index, true, _can_sell_storage_items()):
		_close_pet_context_detail()

func _input(event: InputEvent) -> void:
	if _is_sell_shortcut_pressed(event):
		get_viewport().set_input_as_handled()
		await _sell_shortcut_target()
		return
	var release_plan := _drag_controller.handle_input(event)
	if release_plan.is_empty():
		return
	if _standalone_art_preview:
		_apply_standalone_drag_release_plan(release_plan)
		_clear_drag_state()
		return
	await _execute_drag_release_plan(release_plan)
	_clear_drag_state()


func _is_sell_shortcut_pressed(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed \
				and not key_event.echo \
				and ShortcutCatalog.event_matches_action(
					key_event, ShortcutCatalog.ACTION_SELL_ITEM
				)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed \
				and ShortcutCatalog.event_matches_action(
					mouse_event, ShortcutCatalog.ACTION_SELL_ITEM
				)
	return false


func _sell_shortcut_target() -> void:
	if _is_transitioning or not _can_sell_storage_items():
		return
	var plan := _drag_controller.plan_sell()
	if StringName(plan.get("kind", DragControllerScript.PLAN_NONE)) != DragControllerScript.PLAN_SUBMIT:
		plan = _drag_controller.plan_sell(_hovered_storage_source, _hovered_storage_index)
	if StringName(plan.get("kind", DragControllerScript.PLAN_NONE)) != DragControllerScript.PLAN_SUBMIT:
		return
	_clear_hovered_storage_target()
	await _execute_drag_release_plan(plan)
	_clear_drag_state()


func _set_hovered_storage_target(source: StringName, index: int) -> void:
	_hovered_storage_source = source
	_hovered_storage_index = index


func _clear_hovered_storage_target(source := DRAG_SOURCE_NONE, index := -1) -> void:
	if source != DRAG_SOURCE_NONE \
			and (_hovered_storage_source != source or _hovered_storage_index != index):
		return
	_hovered_storage_source = DRAG_SOURCE_NONE
	_hovered_storage_index = -1

func _has_active_drag() -> bool:
	return _drag_controller.is_active()

func _can_sell_storage_items() -> bool:
	return party_container != null and party_container.is_visible_in_tree()

func _can_start_storage_drag(source: StringName) -> bool:
	if source == DRAG_SOURCE_PARTY:
		return party_container != null and party_container.is_visible_in_tree()
	if source == DRAG_SOURCE_BAG:
		return _current_view == VIEW_BAG and middle_bag != null and middle_bag.is_visible_in_tree()
	return false

func _execute_drag_release_plan(plan: Dictionary) -> void:
	match StringName(plan.get("kind", DragControllerScript.PLAN_NONE)):
		DragControllerScript.PLAN_SUBMIT:
			var command := Dictionary(plan.get("command", {})).duplicate(true)
			if command.is_empty() or not await _submit_core_command(command):
				return
			_drag_controller.accept_release()
			var target_view := _render_content_from_state(_take_core_command_snapshot())
			var target_kind := StringName(plan.get("target_kind", DragControllerScript.TARGET_AUTO))
			if _current_view == VIEW_BAG and target_kind != DragControllerScript.TARGET_SELL:
				_show_view(VIEW_BAG)
				return
			await _transition_to_view(target_view)


func _apply_standalone_drag_release_plan(plan: Dictionary) -> bool:
	if StringName(plan.get("kind", DragControllerScript.PLAN_NONE)) != DragControllerScript.PLAN_SUBMIT:
		return false
	var source := StringName(plan.get("source", DragControllerScript.SOURCE_NONE))
	var source_index := _drag_controller.candidate_index()
	var target := StringName(plan.get("target_kind", DragControllerScript.TARGET_AUTO))
	var target_index := int(Dictionary(plan.get("command", {})).get("target_index", -1))
	if target != DragControllerScript.TARGET_PARTY and target != DragControllerScript.TARGET_BAG:
		return false
	if target_index < 0:
		target_index = _first_empty_standalone_slot(target)
	var source_button := _storage_button(source, source_index)
	var target_button := _storage_button(target, target_index)
	if source_button == null or target_button == null or source_button == target_button:
		return false
	var source_record := _drag_controller.record_for_source(source, source_index)
	var source_texture := _drag_controller.candidate_texture()
	if source_record.is_empty() or source_texture == null:
		return false
	var target_record := Dictionary(target_button.get_meta("drag_record", {})).duplicate(true)
	var target_texture := target_button.get_meta("pet_texture") as Texture2D if target_button.has_meta("pet_texture") else null
	_drag_controller.accept_release()
	target_button.set_meta("drag_record", source_record)
	_set_slot_texture(target_button, source_texture)
	source_button.set_meta("drag_record", target_record)
	_set_slot_texture(source_button, target_texture)
	_clear_hovered_storage_target()
	_close_pet_context_detail()
	return true


func _first_empty_standalone_slot(target: StringName) -> int:
	var buttons := _party_buttons if target == DragControllerScript.TARGET_PARTY else _bag_buttons
	for index in range(buttons.size()):
		if Dictionary((buttons[index] as TextureButton).get_meta("drag_record", {})).is_empty():
			return index
	return -1


func _storage_button(source: StringName, index: int) -> TextureButton:
	var buttons := _party_buttons if source == DragControllerScript.SOURCE_PARTY else _bag_buttons if source == DragControllerScript.SOURCE_BAG else []
	if index < 0 or index >= buttons.size():
		return null
	return buttons[index] as TextureButton

func _drag_record_for_source(source: StringName, index: int) -> Dictionary:
	return _drag_controller.record_for_source(source, index)

func _update_drag_preview(mouse_position: Vector2) -> void:
	_drag_controller.update_preview(mouse_position)

func _clear_drag_state() -> void:
	_drag_controller.clear()

func _prepare_sell_button() -> void:
	if top_sell_button == null:
		return
	top_sell_button.mouse_filter = Control.MOUSE_FILTER_STOP
	top_sell_button.focus_mode = Control.FOCUS_NONE
	_set_sell_button_visible(false)

func _set_sell_button_visible(is_visible: bool) -> void:
	if top_sell_button == null:
		return
	top_sell_button.visible = is_visible
	top_sell_button.disabled = not is_visible

func _on_exit_pressed() -> void:
	if _is_transitioning or _has_active_drag() or _current_view == VIEW_BAG:
		return
	if _standalone_art_preview:
		return
	var phase := String(_current_snapshot().get("phase", "route"))
	if phase != "route" or _selected_route_command.is_empty():
		return
	var command := _selected_route_command.duplicate(true)
	if not await _submit_core_command(command):
		return
	_selected_route_index = -1
	_selected_route_command = {}
	var target_view := _render_content_from_state(_take_core_command_snapshot())
	await _transition_to_view(target_view)

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
	_current_view = view
	_stage_presenter.show_immediate(view)
	_set_persistent_hud_visible(true)
	_set_bag_button_open(view == VIEW_BAG)
	_update_exit_button_state()
	presentation_settled.emit()
	call_deferred("_grab_focus_for_current_view")

func _set_initial_state() -> void:
	_ensure_persistent_hud_visible()
	_stage_presenter.set_initial()
	call_deferred("_grab_focus_for_current_view")

func _show_initial_view() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_set_game_cursor_loading(&"view_transition", true)
	var target_view := _target_view_from_state()
	await _stage_presenter.show_initial(target_view)
	_current_view = target_view
	_ensure_persistent_hud_visible()
	_set_bag_button_open(target_view == VIEW_BAG)
	_update_exit_button_state()
	_set_game_cursor_loading(&"view_transition", false)
	_is_transitioning = false
	presentation_settled.emit()
	call_deferred("_grab_focus_for_current_view")

func _transition_to_view(target_view: StringName) -> void:
	if target_view == _current_view:
		_show_view(target_view)
		return
	_is_transitioning = true
	_set_game_cursor_loading(&"view_transition", true)
	await _stage_presenter.switch_view(_current_view, target_view)
	_current_view = target_view
	_ensure_persistent_hud_visible()
	_set_bag_button_open(target_view == VIEW_BAG)
	_update_exit_button_state()
	_set_game_cursor_loading(&"view_transition", false)
	_is_transitioning = false
	presentation_settled.emit()
	call_deferred("_grab_focus_for_current_view")

func _open_bag() -> void:
	_is_transitioning = true
	_set_game_cursor_loading(&"view_transition", true)
	_view_before_bag = _current_view
	_set_bag_overlay_visible(true)
	_set_bag_view_visible(true)
	middle_three_option.visible = true
	_set_canvas_alpha(middle_three_option, 1.0)
	_current_view = VIEW_BAG
	_ensure_persistent_hud_visible()
	_set_bag_button_open(true)
	_update_exit_button_state()
	_set_game_cursor_loading(&"view_transition", false)
	_is_transitioning = false
	call_deferred("_grab_focus_for_current_view")

func _close_bag() -> void:
	_is_transitioning = true
	_set_game_cursor_loading(&"view_transition", true)
	_set_bag_overlay_visible(false)
	_set_bag_view_visible(false)
	middle_three_option.visible = true
	_set_canvas_alpha(middle_three_option, 1.0)
	_current_view = _view_before_bag
	_ensure_persistent_hud_visible()
	_set_bag_button_open(false)
	_update_exit_button_state()
	_set_game_cursor_loading(&"view_transition", false)
	_is_transitioning = false
	call_deferred("_grab_focus_for_current_view")

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
	return VIEW_THREE_OPTION

func _before_stage_clear() -> void:
	_close_pet_context_detail()
	_hide_item_slot_highlight()
	_ensure_persistent_hud_visible()

func _configure_stage_presenter() -> void:
	_stage_presenter.configure(self, null, {
		&"three_option": middle_three_option,
		&"bag_overlay": bag_overlay_mask,
		&"bag": middle_bag
	}, Callable(self, "_before_stage_clear"))

func _ensure_persistent_hud_visible() -> void:
	_set_persistent_hud_visible(true)

func _set_persistent_hud_visible(is_visible: bool) -> void:
	if bags_panel != null:
		bags_panel.visible = is_visible
	var party_panel := party_container.get_parent() as Control if party_container != null else null
	if party_panel != null:
		party_panel.visible = is_visible

func _ensure_pet_detail_panel() -> void:
	if _pet_detail_panel != null:
		return
	_pet_detail_panel = route_shared_ui.get_node_or_null("ArtistPetDetailPanel") as Control
	if _pet_detail_panel != null and _pet_detail_panel.has_signal("confirm_requested"):
		var callback := Callable(self, "_on_pet_detail_confirm_requested")
		if not _pet_detail_panel.is_connected("confirm_requested", callback):
			_pet_detail_panel.connect("confirm_requested", callback)

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

func _show_item_slot_highlight(
		slot: Control,
		_highlight_offset: Variant = null,
		texture_resource: Texture2D = null
) -> void:
	route_shared_ui.call("show_bag_slot_highlight", slot, texture_resource)

func _hide_item_slot_highlight() -> void:
	route_shared_ui.call("hide_bag_slot_highlight")

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

func _submit_core_command(command: Dictionary) -> bool:
	var before_snapshot := _current_snapshot()
	_set_game_cursor_loading(&"session_command", true)
	var response := Dictionary(await _request_broker.request_command(command))
	_set_game_cursor_loading(&"session_command", false)
	var after_snapshot := Dictionary(response.get("snapshot", before_snapshot))
	_snapshot = after_snapshot.duplicate(true)
	if bool(response.get("accepted", false)):
		_last_command_snapshot = after_snapshot.duplicate(true)
		return true
	var command_type := String(response.get("command", command.get("type", "")))
	var error := Dictionary(response.get("error", {}))
	var reason := String(error.get("message", error.get("code", "rejected")))
	GameLogScript.warning("界面/核心命令", "核心拒绝界面命令", {"命令": command_type, "原因": reason, "当前视图": _current_view})
	return false

func _take_core_command_snapshot() -> Dictionary:
	var snapshot := _last_command_snapshot
	_last_command_snapshot = {}
	return snapshot if not snapshot.is_empty() else _current_snapshot()

func _current_snapshot() -> Dictionary:
	return _snapshot

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
		if card.has_method("set_selected"):
			card.call("set_selected", false)
		card.call("set_hovered", false)
		return
	button.texture_normal = texture_resource

func _clear_route_card(slot: Control, button: TextureButton) -> void:
	button.texture_normal = null
	if slot != null and slot.has_method("clear"):
		slot.call("clear")

func _render_hud(snap: Dictionary) -> void:
	route_shared_ui.call("set_coin_amount", int(snap.get("coins", 0)))

func _set_bag_button_open(is_open: bool) -> void:
	route_shared_ui.call("set_bag_open", is_open)

func _set_hovered_route_card(index: int) -> void:
	_hovered_route_index = index
	for slot_index in range(_three_slots.size()):
		var slot := _three_slots[slot_index]
		if slot != null and slot.has_method("set_hovered"):
			slot.call("set_hovered", slot_index == _hovered_route_index)


func _set_selected_route_card(index: int) -> void:
	for slot_index in range(_three_slots.size()):
		var slot := _three_slots[slot_index]
		if slot != null and slot.has_method("set_selected"):
			slot.call("set_selected", slot_index == index)


func _update_exit_button_state() -> void:
	if exit_button == null:
		return
	var phase := String(_current_snapshot().get("phase", "route"))
	var supported_phase := phase == "route"
	exit_button.visible = supported_phase
	exit_button.disabled = not supported_phase \
		or _current_view == VIEW_BAG

func _render_shared_pet(_slot: Control, button: TextureButton, _record: Dictionary, texture_resource: Texture2D) -> void:
	_set_slot_texture(button, texture_resource)

func _clear_shared_pet(_slot: Control, button: TextureButton) -> void:
	_set_slot_texture(button, null)

func _set_bag_storage_count(_count: int) -> void:
	if bag_storage_state == null:
		return
	bag_storage_state.texture = PARTY_SHELF_TEXTURE

func _route_texture(option: Dictionary, kind: String) -> Texture2D:
	return _asset_registry.route_texture(option, kind)

func _route_slot_texture(index: int, option: Dictionary = {}) -> Texture2D:
	return _asset_registry.route_slot_texture(index, option)

func _route_icon_texture(kind: String) -> Texture2D:
	return _asset_registry.route_icon_texture(kind)

func _route_slot_icon_texture(index: int) -> Texture2D:
	return _asset_registry.route_slot_icon_texture(index)

func _route_slot_highlight_texture(index: int) -> Texture2D:
	return _asset_registry.route_slot_highlight_texture(index)

func _pet_texture(record: Dictionary) -> Texture2D:
	return _asset_registry.pet_texture(record)

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
