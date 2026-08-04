extends Control

## The only script attached directly to ThreeChoiceScene. It binds authored
## nodes, projects snapshots into presentation, handles visual interaction and
## emits requests upward. Game owns the session and completes every request.

signal command_requested(command: Dictionary, request_id: int)
signal session_operation_requested(operation: StringName, arguments: Dictionary, request_id: int)
signal command_response_received(request_id: int)
signal session_operation_response_received(request_id: int)
signal presentation_settled

const GameLogScript := preload("res://core/logging/game_log.gd")
const StagePresenterScript := preload("res://core_ui/scripts/artist_flow/presenters/artist_flow_stage_presenter.gd")
const AssetRegistryScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_asset_registry.gd")
const RoutePresenterScript := preload("res://core_ui/scripts/route/presenters/route_presenter.gd")
const ShopPresenterScript := preload("res://core_ui/scripts/shop/presenters/shop_presenter.gd")
const InventoryPresenterScript := preload("res://core_ui/scripts/inventory/presenters/inventory_presenter.gd")
const PartyPresenterScript := preload("res://core_ui/scripts/party/presenters/party_presenter.gd")
const SettlementPresenterScript := preload("res://core_ui/scripts/settlement/presenters/settlement_presenter.gd")
const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")

const VIEW_THREE_OPTION := &"three_option"
const VIEW_SHOP := &"shop"
const VIEW_BAG := &"bag"
const VIEW_BATTLE := &"battle"

const DRAG_PREVIEW_SIZE := Vector2(110.0, 110.0)
const SLOT_DRAG_PREVIEW_SIZE := Vector2(96.0, 96.0)
const SHOP_SLOT_COUNT := 8
const BAG_SLOT_COUNT := 8
const PARTY_SLOT_COUNT := 4
const SHOP_SLOT_SIZE := Vector2(96.0, 96.0)
const BAG_SLOT_SIZE := Vector2(110.0, 110.0)
const BAG_SLOT_DISPLAY_SIZE := Vector2(110.0, 88.0)
const BAG_SLOT_DISPLAY_OFFSET := Vector2(0.0, 14.0)
const PARTY_SLOT_SIZE := Vector2(132.0, 132.0)
const PARTY_SLOT_DISPLAY_OFFSET := Vector2.ZERO
const BAG_FIRST_SLOT_HIGHLIGHT_EXTRA_OFFSET := Vector2(-1.0, 0.0)
const BAG_OTHER_SLOT_HIGHLIGHT_EXTRA_OFFSET := Vector2(-3.0, 0.0)
const SLOT_LAYOUT_SHOP := 0
const SLOT_LAYOUT_COLLECTION := 1
const SLOT_LAYOUT_PARTY := 2
const COLLECTION_SLOT_SHADER_SOURCE := """
shader_type canvas_item;

uniform vec2 control_size = vec2(110.0, 110.0);
uniform vec2 display_size = vec2(110.0, 73.3333);
uniform vec2 display_offset = vec2(0.0, 0.0);
uniform sampler2D source_texture : filter_nearest;
uniform vec2 source_size = vec2(1.0, 1.0);

void fragment() {
	vec4 tint = COLOR;
	vec2 pixel_position = UV * control_size;
	vec2 display_pixel_position = pixel_position - display_offset;
	bool outside = display_pixel_position.x < 0.0 || display_pixel_position.y < 0.0 || display_pixel_position.x >= display_size.x || display_pixel_position.y >= display_size.y;
	if (outside) {
		COLOR = vec4(0.0);
	} else {
		vec2 display_uv = display_pixel_position / display_size;
		float source_aspect = source_size.x / source_size.y;
		float target_aspect = display_size.x / display_size.y;
		vec2 source_uv = display_uv;
		if (source_aspect > target_aspect) {
			source_uv.x = 0.5 + (display_uv.x - 0.5) * target_aspect / source_aspect;
		} else {
			source_uv.y = 0.5 + (display_uv.y - 0.5) * source_aspect / target_aspect;
		}
		source_uv.x -= 0.000001;
		COLOR = texture(source_texture, source_uv) * tint;
	}
}
"""
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
const BAG_OPEN_TEXTURE := preload("res://art/images/route/three_choice_psd/bag_open_full.png")
const BAG_STORAGE_STATE_TEXTURES := [
	preload("res://art/images/route/three_choice_psd/bag_storage_state_0.png"),
	preload("res://art/images/route/three_choice_psd/bag_storage_state_1.png"),
	preload("res://art/images/route/three_choice_psd/bag_storage_state_2.png"),
	preload("res://art/images/route/three_choice_psd/bag_storage_state_3.png"),
	preload("res://art/images/route/three_choice_psd/bag_storage_state_4.png"),
	preload("res://art/images/route/three_choice_psd/bag_storage_state_5.png"),
	preload("res://art/images/route/three_choice_psd/bag_storage_state_6.png"),
	preload("res://art/images/route/three_choice_psd/bag_storage_state_7.png"),
	preload("res://art/images/route/three_choice_psd/bag_storage_state_8.png"),
]

@export_group("Item Slot Highlight")
@export var item_slot_highlight_offset := Vector2.ZERO

@onready var middle_three_option: Control = $MainBG/Containers/Middle/Middle_Three_Option
@onready var bag_overlay_mask: Control = $MainBG/Containers/Middle/BagOverlayMask
@onready var middle_shop: Control = $MainBG/Containers/Middle/Middle_Shop
@onready var middle_bag: Control = $MainBG/Containers/Middle/Middle_Bag
@onready var party_container: Control = $MainBG/Containers/Party/Party_Container
@onready var party_shadows: Array[TextureRect] = [
	$MainBG/Containers/Party/PartyShadow1,
	$MainBG/Containers/Party/PartyShadow2,
	$MainBG/Containers/Party/PartyShadow3,
	$MainBG/Containers/Party/PartyShadow4,
]
@onready var top_shop: Control = get_node_or_null("MainBG/Containers/Top/Top_Shop") as Control
@onready var top_sell_button: TextureButton = get_node_or_null("MainBG/Containers/Top/Top_Sell") as TextureButton
@onready var shop_back_button: TextureButton = get_node_or_null("MainBG/Containers/Top/Top_Shop/Shop_BackButton") as TextureButton
@onready var bags_panel: Control = $MainBG/Containers/Bags
@onready var bag_button: TextureButton = $MainBG/Containers/Bags/Bag_Button
@onready var bag_storage_state: TextureRect = $MainBG/Containers/Bags/BagStorageState
@onready var time_label: Label = get_node_or_null("MainBG/Containers/Top/Hud/TimeLabel") as Label
@onready var coin_label: Label = get_node_or_null("MainBG/Containers/Top/Hud/CoinLabel") as Label

var _stage_presenter := StagePresenterScript.new()
var _snapshot: Dictionary = {}
var _last_command_snapshot: Dictionary = {}
var _request_sequence := 0
var _command_responses: Dictionary = {}
var _session_operation_responses: Dictionary = {}
var _persistence_supported := false
var _persistence_slot_count := 0
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
var _drag_preview_locked_size := DRAG_PREVIEW_SIZE
var _drag_hidden_button: TextureButton = null
var _drag_hidden_texture: Texture2D = null
var _drag_hidden_restore := false
var _slot_draw_texture: ImageTexture = null
var _is_toggling_bag := false
var _bag_page := 0
var _hovered_route_index := -1
var _battle_view: Control = null
var _pet_detail_panel: Control = null
var _bazaar_info_panel: Control = null
var _run_tools: PanelContainer = null
var _run_status_label: Label = null
@onready var _item_slot_hover_highlight: TextureRect = $ItemSlotHoverHighlight
var _drag_preview: TextureRect = null
var _route_presenter := RoutePresenterScript.new()
var _shop_presenter := ShopPresenterScript.new()
var _inventory_presenter := InventoryPresenterScript.new()
var _party_presenter := PartyPresenterScript.new()
var _settlement_presenter := SettlementPresenterScript.new()
var _developer_tools := false


func _ready() -> void:
	RuntimeUiPolicy.install()
	_developer_tools = RuntimeUiPolicy.developer_tools_enabled()
	_asset_registry.reload()
	_build_runtime_slots()
	_collect_slots()
	_set_bag_storage_count(0)
	_ensure_pet_detail_panel()
	_ensure_bazaar_info_panel()
	_apply_runtime_ui_mode()
	if _developer_tools:
		_ensure_run_tools()
	_configure_stage_presenter()
	_connect_buttons()
	_configure_focus_navigation()
	_prepare_sell_button()
	_render_content_from_state(_current_snapshot())
	_set_initial_state()
	call_deferred("_show_initial_view")
	call_deferred("_grab_focus_for_current_view")


func _build_runtime_slots() -> void:
	var draw_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	draw_image.fill(Color.WHITE)
	_slot_draw_texture = ImageTexture.create_from_image(draw_image)
	var shop_slots := _slot_root(middle_shop) as GridContainer
	var bag_slots := _slot_root(middle_bag) as GridContainer
	_build_slot_buttons(shop_slots, "Shop_Slot", SHOP_SLOT_COUNT, SHOP_SLOT_SIZE, SLOT_LAYOUT_SHOP)
	_build_slot_buttons(bag_slots, "Bag_Slot", BAG_SLOT_COUNT, BAG_SLOT_SIZE, SLOT_LAYOUT_COLLECTION)
	_configure_authored_slot_buttons(party_container, "Party_Slot", PARTY_SLOT_COUNT, PARTY_SLOT_SIZE, SLOT_LAYOUT_PARTY)


func _build_slot_buttons(
	container: Node,
	base_name: String,
	count: int,
	slot_size: Vector2,
	slot_layout_mode: int
) -> void:
	if container == null:
		return
	for index in range(count):
		var button := TextureButton.new()
		button.name = base_name if index == 0 else "%s%d" % [base_name, index + 1]
		_configure_slot_button(button, slot_size, slot_layout_mode)
		container.add_child(button)


func _configure_authored_slot_buttons(
	container: Node,
	base_name: String,
	count: int,
	slot_size: Vector2,
	slot_layout_mode: int
) -> void:
	if container == null:
		return
	for index in range(count):
		var button_name := base_name if index == 0 else "%s%d" % [base_name, index + 1]
		var button := container.get_node_or_null(button_name) as TextureButton
		if button != null:
			_configure_slot_button(button, slot_size, slot_layout_mode)


func _configure_slot_button(button: TextureButton, slot_size: Vector2, slot_layout_mode: int) -> void:
	button.custom_minimum_size = slot_size
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED if slot_layout_mode == SLOT_LAYOUT_SHOP else TextureButton.STRETCH_SCALE
	if slot_layout_mode == SLOT_LAYOUT_COLLECTION or slot_layout_mode == SLOT_LAYOUT_PARTY:
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.material = _make_collection_slot_material(slot_size, slot_layout_mode)
	button.set_meta("slot_surface_self", true)
	button.set_meta("drag_preview_size", SLOT_DRAG_PREVIEW_SIZE)


func _make_collection_slot_material(slot_size: Vector2, slot_layout_mode: int = SLOT_LAYOUT_COLLECTION) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = COLLECTION_SLOT_SHADER_SOURCE
	var slot_material := ShaderMaterial.new()
	slot_material.shader = shader
	slot_material.set_shader_parameter("control_size", slot_size)
	var display_size := slot_size if slot_layout_mode == SLOT_LAYOUT_PARTY else BAG_SLOT_DISPLAY_SIZE
	var display_offset := PARTY_SLOT_DISPLAY_OFFSET if slot_layout_mode == SLOT_LAYOUT_PARTY else BAG_SLOT_DISPLAY_OFFSET
	slot_material.set_shader_parameter("display_size", display_size)
	slot_material.set_shader_parameter("display_offset", display_offset)
	return slot_material


func _set_slot_texture(button: TextureButton, texture_resource: Texture2D) -> void:
	button.set_meta("pet_texture", texture_resource)
	var slot_material := button.material as ShaderMaterial
	if slot_material == null:
		button.texture_normal = texture_resource
		return
	button.texture_normal = _slot_draw_texture if texture_resource != null else null
	slot_material.set_shader_parameter("source_texture", texture_resource)
	slot_material.set_shader_parameter("source_size", texture_resource.get_size() if texture_resource != null else Vector2.ONE)


func _game_cursor() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"game_cursor")


func _set_game_cursor_loading(source: StringName, active: bool) -> void:
	var cursor := _game_cursor()
	if cursor != null and cursor.has_method("set_loading_source"):
		cursor.call("set_loading_source", source, active)


func _exit_tree() -> void:
	_stage_presenter.dispose()


func render_snapshot(snapshot: Dictionary, animate_transition: bool = true) -> void:
	_snapshot = snapshot.duplicate(true)
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


func render_battle_command_response(command: Dictionary, response: Dictionary) -> void:
	var before_snapshot := _current_snapshot()
	var after_snapshot := Dictionary(response.get("snapshot", before_snapshot))
	_snapshot = after_snapshot.duplicate(true)
	if not bool(response.get("accepted", false)):
		var command_type := String(response.get("command", command.get("type", "")))
		var error := Dictionary(response.get("error", {}))
		var reason := String(error.get("message", error.get("code", "rejected")))
		GameLogScript.warning("界面/核心命令", "核心拒绝战斗界面命令", {
			"命令": command_type,
			"原因": reason,
		})
		return
	if String(command.get("type", "")) == "RUN_COMBAT_ROUND" \
			and String(after_snapshot.get("phase", "")) != "battle":
		_render_battle_view(after_snapshot)
		await _await_battle_trace_sequence()
	var target_view := _render_content_from_state(after_snapshot)
	await _transition_to_view(target_view)


func configure_session_capabilities(supports_persistence: bool, slot_count: int) -> void:
	_persistence_supported = supports_persistence
	_persistence_slot_count = maxi(0, slot_count)
	if is_node_ready() and _developer_tools:
		_ensure_run_tools()


func complete_command_request(request_id: int, response: Dictionary) -> void:
	_command_responses[request_id] = response.duplicate(true)
	command_response_received.emit(request_id)


func complete_session_operation_request(request_id: int, result: Dictionary) -> void:
	_session_operation_responses[request_id] = result.duplicate(true)
	session_operation_response_received.emit(request_id)


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
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not button.pressed.is_connected(_on_three_pressed):
			button.pressed.connect(_on_three_pressed.bind(index))
		if not button.mouse_entered.is_connected(_on_three_mouse_entered):
			button.mouse_entered.connect(_on_three_mouse_entered.bind(index))
		if not button.mouse_exited.is_connected(_on_three_mouse_exited):
			button.mouse_exited.connect(_on_three_mouse_exited.bind(index))

	for index in range(_shop_buttons.size()):
		var button := _shop_buttons[index]
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not button.button_down.is_connected(_on_shop_button_down):
			button.button_down.connect(_on_shop_button_down.bind(index))
		if not button.mouse_entered.is_connected(_on_shop_pet_mouse_entered):
			button.mouse_entered.connect(_on_shop_pet_mouse_entered.bind(index))
		if not button.mouse_exited.is_connected(_on_shop_pet_mouse_exited):
			button.mouse_exited.connect(_on_shop_pet_mouse_exited.bind(index))
		var keyboard_callback := Callable(self, "_on_shop_gui_input").bind(index)
		if not button.gui_input.is_connected(keyboard_callback):
			button.gui_input.connect(keyboard_callback)

	for index in range(_party_buttons.size()):
		var button := _party_buttons[index]
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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

	if shop_back_button != null and not shop_back_button.pressed.is_connected(_on_shop_back_pressed):
		shop_back_button.pressed.connect(_on_shop_back_pressed)
	if shop_back_button != null:
		shop_back_button.focus_mode = Control.FOCUS_ALL
	if top_shop != null:
		top_shop.mouse_filter = Control.MOUSE_FILTER_STOP
	if top_shop != null and not top_shop.gui_input.is_connected(_on_top_shop_gui_input):
		top_shop.gui_input.connect(_on_top_shop_gui_input)
	if not bag_button.pressed.is_connected(_on_bag_pressed):
		bag_button.pressed.connect(_on_bag_pressed)
	bag_button.focus_mode = Control.FOCUS_ALL
	bag_button.set_meta("slot_surface_self", true)
	bag_button.set_meta("focus_tint_disabled", true)
	bags_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not bags_panel.gui_input.is_connected(_on_bags_gui_input):
		bags_panel.gui_input.connect(_on_bags_gui_input)


func _configure_focus_navigation() -> void:
	for button in _all_focus_buttons():
		button.focus_mode = Control.FOCUS_ALL
		var entered := Callable(self, "_on_focus_entered").bind(button)
		var exited := Callable(self, "_on_focus_exited").bind(button)
		if not button.focus_entered.is_connected(entered):
			button.focus_entered.connect(entered)
		if not button.focus_exited.is_connected(exited):
			button.focus_exited.connect(exited)
	_configure_current_focus_ring()


func _configure_current_focus_ring() -> void:
	var controls := _focus_controls_for_view()
	if controls.is_empty():
		return
	for index in range(controls.size()):
		var control := controls[index]
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		var next := controls[(index + 1) % controls.size()]
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_right = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)


func _focus_controls_for_view() -> Array[Control]:
	var candidates: Array[Control] = []
	match _current_view:
		VIEW_SHOP:
			candidates.append_array(_shop_buttons)
		VIEW_BAG:
			candidates.append_array(_bag_buttons)
		_:
			candidates.append_array(_three_buttons)
	if _bazaar_info_panel != null and _bazaar_info_panel.has_method("focus_controls"):
		candidates.append_array(Array(_bazaar_info_panel.call("focus_controls")))
	if _current_view == VIEW_SHOP:
		candidates.append(shop_back_button)
	if _current_view != VIEW_BATTLE:
		candidates.append(bag_button)
	var controls: Array[Control] = []
	for control in candidates:
		if control == null or not control.visible:
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		controls.append(control)
	return controls


func _all_focus_buttons() -> Array[BaseButton]:
	var buttons: Array[BaseButton] = []
	for group in [_three_buttons, _shop_buttons, _party_buttons, _bag_buttons]:
		for value in group:
			buttons.append(value as BaseButton)
	for button in [shop_back_button, bag_button]:
		if button != null:
			buttons.append(button)
	if _bazaar_info_panel != null and _bazaar_info_panel.has_method("focus_controls"):
		for value in Array(_bazaar_info_panel.call("focus_controls")):
			if value is BaseButton:
				buttons.append(value as BaseButton)
	return buttons


func _grab_focus_for_current_view() -> void:
	_configure_current_focus_ring()
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return
	if focus_owner.is_visible_in_tree():
		return
	var controls := _focus_controls_for_view()
	if not controls.is_empty():
		controls[0].grab_focus()


func _on_focus_entered(button: BaseButton) -> void:
	if bool(button.get_meta("focus_tint_disabled", false)):
		return
	var surface := _button_surface(button)
	if surface != null:
		surface.modulate = Color(1.18, 1.08, 0.72, 1.0)


func _on_focus_exited(button: BaseButton) -> void:
	_restore_button_tint(button)


func _restore_button_tint(button: BaseButton) -> void:
	var surface := _button_surface(button)
	if surface == null:
		return
	surface.modulate = button.get_meta("base_tint", Color.WHITE) as Color


func _button_surface(button: BaseButton) -> CanvasItem:
	if bool(button.get_meta("slot_surface_self", false)):
		return button
	return button.get_parent() as CanvasItem


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
		button.set_meta("base_tint", Color.WHITE)
		_restore_button_tint(button)
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


func _render_battle_view(snap: Dictionary) -> void:
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
	_battle_view.visible = false
	_battle_view.z_index = 50
	_battle_view.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		button.set_meta("base_tint", Color.WHITE)
		_restore_button_tint(button)
	call_deferred("_configure_current_focus_ring")


func _render_shop(snap: Dictionary) -> void:
	var cards := Array(_shop_presenter.call("cards", snap))
	for index in range(_shop_buttons.size()):
		var card := Dictionary(cards[index]) if index < cards.size() else {}
		var offer := Dictionary(card.get("record", {}))
		var button := _shop_buttons[index]
		var slot := _shop_slots[index] if index < _shop_slots.size() else button.get_parent()
		var has_offer := not offer.is_empty() and bool(card.get("available", false))
		var purchasable := bool(card.get("purchasable", false))
		button.disabled = not has_offer
		button.set_meta("purchasable", purchasable)
		button.set_meta("availability", Dictionary(card.get("availability", {})))
		button.set_meta("base_tint", Color.WHITE if purchasable else Color(0.56, 0.56, 0.56, 1.0))
		if has_offer:
			var texture := _pet_texture(offer)
			_set_slot_texture(button, texture)
			button.set_meta("command", Dictionary(card.get("command", {})))
			button.set_meta("drag_record", offer)
			_clear_runtime_overlays(slot)
			if texture == null:
				_record_missing_image("shop_offer", offer)
		else:
			_set_slot_texture(button, null)
			button.set_meta("command", {})
			button.set_meta("drag_record", {})
			_clear_runtime_overlays(slot)
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
			_set_party_shadow_visible(index, true)
			button.set_meta("drag_record", pet)
			_clear_runtime_overlays(slot)
			if texture == null:
				_record_missing_image("party_active", pet)
		else:
			_clear_shared_pet(slot, button)
			_set_party_shadow_visible(index, false)
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
	var command := Dictionary(_three_buttons[index].get_meta("command", {}))
	if command.is_empty():
		return
	var snap := _current_snapshot()
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


func _on_shop_button_down(index: int) -> void:
	if _is_transitioning or _has_active_drag() or _current_view != VIEW_SHOP or index < 0 or index >= _shop_buttons.size():
		return
	var command := Dictionary(_shop_buttons[index].get_meta("command", {}))
	if command.is_empty():
		return
	if not bool(_shop_buttons[index].get_meta("purchasable", false)):
		_show_shop_unavailable_feedback(index)
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


func _on_shop_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton or not event.is_action_pressed("ui_accept"):
		return
	accept_event()
	_clear_drag_state()
	await _purchase_shop_offer_with_focus(index)


func _purchase_shop_offer_with_focus(index: int) -> void:
	if _is_transitioning or _current_view != VIEW_SHOP or index < 0 or index >= _shop_buttons.size():
		return
	var button := _shop_buttons[index]
	var command := Dictionary(button.get_meta("command", {}))
	if command.is_empty():
		return
	if not bool(button.get_meta("purchasable", false)):
		_show_shop_unavailable_feedback(index)
		return
	_close_pet_context_detail()
	if await _submit_core_command(command):
		_render_content_from_state(_take_core_command_snapshot())
		call_deferred("_grab_focus_for_current_view")


func _show_shop_unavailable_feedback(index: int) -> void:
	if index < 0 or index >= _shop_buttons.size():
		return
	var offer := Dictionary(_shop_buttons[index].get_meta("drag_record", {}))
	var availability := Dictionary(_shop_buttons[index].get_meta("availability", {}))
	var message := RuntimeUiPolicy.text("UI_RESULT_NO_COINS", [
		int(availability.get("coins", _current_snapshot().get("coins", 0))),
		int(availability.get("price", offer.get("price", 0))),
	])
	_show_bazaar_feedback(message, false)


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
	_show_item_slot_highlight(
		_bag_slots[index] if index >= 0 and index < _bag_slots.size() else null,
		_bag_slot_highlight_extra_offset(index)
	)
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
		var mouse_position := (event as InputEventMouseMotion).global_position
		if _has_active_drag():
			_update_drag_preview(mouse_position)
			_update_bag_drag_highlight(mouse_position)
	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event.button_index != MOUSE_BUTTON_LEFT or mouse_button_event.pressed:
			return
		var mouse_position := mouse_button_event.global_position
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
	var authored_size := button.get_meta("drag_preview_size", Vector2.ZERO) as Vector2
	if authored_size.x > 0.0 and authored_size.y > 0.0:
		return authored_size
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
	_drag_preview.z_index = 100
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.82)
	add_child(_drag_preview)
	_drag_preview_locked_size = preview_size
	_drag_preview.texture = texture
	_drag_preview.custom_minimum_size = preview_size
	_drag_preview.size = preview_size
	_drag_preview.visible = true
	_drag_preview.move_to_front()


func _update_drag_preview(mouse_position: Vector2) -> void:
	if _drag_preview == null or not is_instance_valid(_drag_preview) or not _drag_preview.visible:
		return
	_drag_preview.custom_minimum_size = _drag_preview_locked_size
	_drag_preview.size = _drag_preview_locked_size
	_drag_preview.global_position = mouse_position - _drag_preview.size * 0.5


func _update_bag_drag_highlight(mouse_position: Vector2) -> void:
	var bag_index := _find_slot_at_position(_bag_slots, mouse_position)
	if bag_index < 0:
		_hide_item_slot_highlight()
		return
	_show_item_slot_highlight(_bag_slots[bag_index], _bag_slot_highlight_extra_offset(bag_index))


func _clear_drag_preview() -> void:
	if _drag_preview != null and is_instance_valid(_drag_preview):
		if _drag_preview.get_parent() != null:
			_drag_preview.get_parent().remove_child(_drag_preview)
		_drag_preview.queue_free()
	_drag_preview = null
	_drag_preview_locked_size = DRAG_PREVIEW_SIZE


func _hide_drag_source_texture(texture: Texture2D) -> void:
	var button := _drag_button_for_candidate()
	if button == null:
		return
	_drag_hidden_button = button
	_drag_hidden_texture = texture
	_drag_hidden_restore = true
	if _drag_candidate_source == DRAG_SOURCE_PARTY:
		_set_party_shadow_visible(_drag_candidate_index, false)
	_set_slot_texture(button, null)


func _restore_drag_source_texture() -> void:
	if _drag_hidden_restore and _drag_hidden_button != null:
		_set_slot_texture(_drag_hidden_button, _drag_hidden_texture)
		if _drag_candidate_source == DRAG_SOURCE_PARTY:
			_set_party_shadow_visible(_drag_candidate_index, true)
	_discard_drag_source_restore()


func _discard_drag_source_restore() -> void:
	_drag_hidden_button = null
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
	_current_view = view
	_stage_presenter.show_immediate(view)
	_set_persistent_hud_visible(view != VIEW_BATTLE)
	_set_bag_button_open(view == VIEW_BAG)
	_set_run_tools_visible(true)
	presentation_settled.emit()
	call_deferred("_grab_focus_for_current_view")


func _set_initial_state() -> void:
	_ensure_persistent_hud_visible()
	_set_run_tools_visible(true)
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
	_set_run_tools_visible(true)
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
	_set_run_tools_visible(true)
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
	_set_game_cursor_loading(&"view_transition", false)
	_is_transitioning = false
	call_deferred("_grab_focus_for_current_view")


func _close_bag() -> void:
	_is_transitioning = true
	_set_game_cursor_loading(&"view_transition", true)
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
	_stage_presenter.configure(self, null, {
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


func _ensure_pet_detail_panel() -> void:
	if _pet_detail_panel != null:
		return
	var scene_root := self
	_pet_detail_panel = scene_root.get_node_or_null("ArtistPetDetailPanel") as Control
	if _pet_detail_panel != null and _pet_detail_panel.has_signal("confirm_requested"):
		var callback := Callable(self, "_on_pet_detail_confirm_requested")
		if not _pet_detail_panel.is_connected("confirm_requested", callback):
			_pet_detail_panel.connect("confirm_requested", callback)


func _ensure_bazaar_info_panel() -> void:
	if _bazaar_info_panel != null:
		return
	var scene_root := self
	_bazaar_info_panel = scene_root.get_node_or_null("BazaarInfoPanel") as Control
	if _bazaar_info_panel == null:
		return
	if _bazaar_info_panel.has_signal("command_requested"):
		_bazaar_info_panel.connect("command_requested", Callable(self, "_on_bazaar_info_command_requested"))


func _apply_runtime_ui_mode() -> void:
	var scene_root := self
	var debug_button := scene_root.get_node_or_null("MainBG/DebugButton") as Control
	if debug_button != null:
		debug_button.visible = _developer_tools
		debug_button.mouse_filter = Control.MOUSE_FILTER_STOP if _developer_tools else Control.MOUSE_FILTER_IGNORE
		debug_button.focus_mode = Control.FOCUS_ALL if _developer_tools else Control.FOCUS_NONE


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


func _show_item_slot_highlight(slot: Control, extra_offset := Vector2.ZERO) -> void:
	if slot == null:
		return
	var rect := slot.get_global_rect()
	_item_slot_hover_highlight.global_position = rect.position + item_slot_highlight_offset + extra_offset
	_item_slot_hover_highlight.visible = true
	_item_slot_hover_highlight.move_to_front()


func _hide_item_slot_highlight() -> void:
	_item_slot_hover_highlight.visible = false


func _bag_slot_highlight_extra_offset(index: int) -> Vector2:
	return BAG_FIRST_SLOT_HIGHLIGHT_EXTRA_OFFSET if index == 0 else BAG_OTHER_SLOT_HIGHLIGHT_EXTRA_OFFSET


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


func _await_battle_trace_sequence() -> void:
	if _battle_view != null \
			and _battle_view.has_method("is_battle_input_locked") \
			and bool(_battle_view.call("is_battle_input_locked")) \
			and _battle_view.has_signal("trace_sequence_finished"):
		await _battle_view.trace_sequence_finished

func _ensure_run_tools() -> void:
	if not _developer_tools:
		return
	if _run_tools != null:
		return
	var scene_root := self
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

	var slot_count := _persistence_slot_count
	for slot in range(1, slot_count + 1):
		var save_button_name := "SaveButton" if slot == 1 else "SaveSlot%dButton" % slot
		var load_button_name := "LoadButton" if slot == 1 else "LoadSlot%dButton" % slot
		_add_run_tool_button(row, RuntimeUiPolicy.text("UI_SAVE_SLOT", [slot]), save_button_name, _on_save_slot_pressed.bind(slot))
		_add_run_tool_button(row, RuntimeUiPolicy.text("UI_LOAD_SLOT", [slot]), load_button_name, _on_load_slot_pressed.bind(slot))
	_add_run_tool_button(row, RuntimeUiPolicy.text("UI_EXPORT_REPLAY"), "ExportReplayButton", _on_export_replay_pressed)
	_add_run_tool_button(row, RuntimeUiPolicy.text("UI_EXPORT_TRACE"), "ExportBattleTraceButton", _on_export_battle_trace_pressed)

	_run_status_label = Label.new()
	_run_status_label.name = "RunToolsStatus"
	_run_status_label.custom_minimum_size = Vector2(220.0, RUN_TOOL_SIZE.y)
	_run_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_run_status_label.add_theme_font_size_override("font_size", 18)
	_run_status_label.add_theme_color_override("font_color", Color("#f4edd8"))
	_run_status_label.text = RuntimeUiPolicy.text("UI_LOCAL_SAVE")
	row.add_child(_run_status_label)
	scene_root.add_child.call_deferred(_run_tools)


func _add_run_tool_button(row: HBoxContainer, label_text: String, button_name: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = button_name
	button.text = label_text
	button.custom_minimum_size = RUN_TOOL_SIZE
	button.focus_mode = Control.FOCUS_ALL
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
	if not _session_supports_persistence():
		_set_run_tools_status("当前会话不支持本地存档")
		return
	var result := await _request_session_operation(&"save", {"slot": slot})
	var ok := bool(result.get("ok", false))
	_set_run_tools_status("已保存槽%d" % slot if ok else "槽%d保存失败" % slot)
	_render_content_from_state(_current_snapshot())


func _on_load_slot_pressed(slot: int) -> void:
	if not _session_supports_persistence():
		_set_run_tools_status("当前会话不支持本地读档")
		return
	var result := await _request_session_operation(&"load", {"slot": slot})
	var ok := bool(result.get("ok", false))
	if result.get("snapshot") is Dictionary:
		_snapshot = Dictionary(result.get("snapshot", {})).duplicate(true)
	_set_run_tools_status("已读档槽%d" % slot if ok else "槽%d读档失败" % slot)
	var target_view := _render_content_from_state(_current_snapshot())
	await _transition_to_view(target_view)


func _on_export_replay_pressed() -> void:
	if not _session_supports_persistence():
		_set_run_tools_status("当前会话不支持本地导出")
		return
	var result := await _request_session_operation(&"export_replay", {})
	var ok := bool(result.get("ok", false))
	_set_run_tools_status("已导出回放" if ok else "导出失败")
	_render_content_from_state(_current_snapshot())


func _on_export_battle_trace_pressed() -> void:
	if not _session_supports_persistence():
		_set_run_tools_status("当前会话不支持本地导出")
		return
	var result := await _request_session_operation(&"export_battle_trace", {})
	var ok := bool(result.get("ok", false))
	_set_run_tools_status("已导出战报" if ok else "导出失败")
	_render_content_from_state(_current_snapshot())


func _set_run_tools_status(text: String) -> void:
	if _run_status_label != null:
		_run_status_label.text = text


func _session_supports_persistence() -> bool:
	return _persistence_supported


func _set_run_tools_visible(is_visible: bool) -> void:
	if _run_tools != null:
		_run_tools.position.y = 14.0 if _current_view == VIEW_BATTLE else 22.0
		_run_tools.visible = _developer_tools and is_visible and _current_view == VIEW_BATTLE


func _submit_core_command(command: Dictionary) -> bool:
	var before_snapshot := _current_snapshot()
	_set_game_cursor_loading(&"session_command", true)
	var request_id := _next_request_id()
	command_requested.emit(command.duplicate(true), request_id)
	while not _command_responses.has(request_id):
		await command_response_received
	var response := Dictionary(_command_responses.get(request_id, {}))
	_command_responses.erase(request_id)
	_set_game_cursor_loading(&"session_command", false)
	var after_snapshot := Dictionary(response.get("snapshot", before_snapshot))
	_snapshot = after_snapshot.duplicate(true)
	if bool(response.get("accepted", false)):
		_last_command_snapshot = after_snapshot.duplicate(true)
		_publish_command_feedback(command, response, before_snapshot, after_snapshot, true)
		return true
	var command_type := String(response.get("command", command.get("type", "")))
	var error := Dictionary(response.get("error", {}))
	var reason := String(error.get("message", error.get("code", "rejected")))
	_publish_command_feedback(command, response, before_snapshot, after_snapshot, false)
	_set_run_tools_status(RuntimeUiPolicy.text("UI_RESULT_COMMAND_REJECTED", [reason]))
	GameLogScript.warning("界面/核心命令", "核心拒绝界面命令", {"命令": command_type, "原因": reason, "当前视图": _current_view})
	return false


func _publish_command_feedback(command: Dictionary, response: Dictionary, before: Dictionary, after: Dictionary, success: bool) -> void:
	if _current_view == VIEW_BATTLE:
		return
	var command_type := String(command.get("type", response.get("command", "")))
	var message := ""
	if command_type == "BUY_OFFER":
		var offer := _offer_for_command(before, command)
		var name := String(offer.get("name", offer.get("id", command.get("offer_id", "商品"))))
		var price := int(offer.get("price", 0))
		if success:
			message = RuntimeUiPolicy.text("UI_RESULT_PURCHASED", [name, int(after.get("coins", 0))])
		elif int(before.get("coins", 0)) < price:
			message = RuntimeUiPolicy.text("UI_RESULT_NO_COINS", [int(before.get("coins", 0)), price])
	if message == "" and success and command_type == "ROLL_SHOP":
		message = RuntimeUiPolicy.text("UI_RESULT_REFRESHED", [int(after.get("coins", 0))])
	if message == "":
		message = _latest_log_line(after)
	if message == "":
		message = RuntimeUiPolicy.text("UI_RESULT_COMMAND_ACCEPTED" if success else "UI_RESULT_COMMAND_REJECTED", [command_type])
	_show_bazaar_feedback(message, success)


func _offer_for_command(snap: Dictionary, command: Dictionary) -> Dictionary:
	var offer_id := String(command.get("offer_id", command.get("offerId", command.get("id", ""))))
	for value in Array(snap.get("shop_offers", [])):
		var offer := Dictionary(value)
		if String(offer.get("id", offer.get("offer_id", ""))) == offer_id:
			return offer
	return {}


func _latest_log_line(snap: Dictionary) -> String:
	var lines := Array(snap.get("log_lines", snap.get("logLines", [])))
	return String(lines.back()).strip_edges() if not lines.is_empty() else ""


func _show_bazaar_feedback(message: String, success: bool) -> void:
	_ensure_bazaar_info_panel()
	if _bazaar_info_panel != null and _bazaar_info_panel.has_method("show_command_feedback"):
		_bazaar_info_panel.call("show_command_feedback", message, success)


func _take_core_command_snapshot() -> Dictionary:
	var snapshot := _last_command_snapshot
	_last_command_snapshot = {}
	return snapshot if not snapshot.is_empty() else _current_snapshot()


func set_developer_tools_enabled(enabled: bool) -> void:
	_developer_tools = enabled
	_apply_runtime_ui_mode()
	if enabled:
		_ensure_run_tools()
	_set_run_tools_visible(true)


func _apply_async_game_session_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	_snapshot = snap.duplicate(true)
	var target_view := _render_content_from_state(snap)
	await _transition_to_view(target_view)


func _current_snapshot() -> Dictionary:
	return _snapshot


func _next_request_id() -> int:
	_request_sequence += 1
	return _request_sequence


func _request_session_operation(operation: StringName, arguments: Dictionary) -> Dictionary:
	var request_id := _next_request_id()
	session_operation_requested.emit(operation, arguments.duplicate(true), request_id)
	while not _session_operation_responses.has(request_id):
		await session_operation_response_received
	var result := Dictionary(_session_operation_responses.get(request_id, {}))
	_session_operation_responses.erase(request_id)
	return result


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


func _set_hovered_route_card(index: int) -> void:
	_hovered_route_index = index
	for slot_index in range(_three_slots.size()):
		var slot := _three_slots[slot_index]
		if slot != null and slot.has_method("set_hovered"):
			slot.call("set_hovered", slot_index == _hovered_route_index)


func _render_shared_pet(_slot: Control, button: TextureButton, _record: Dictionary, texture_resource: Texture2D) -> void:
	_set_slot_texture(button, texture_resource)


func _clear_shared_pet(_slot: Control, button: TextureButton) -> void:
	_set_slot_texture(button, null)


func _set_party_shadow_visible(index: int, is_visible: bool) -> void:
	if index < 0 or index >= party_shadows.size():
		return
	var shadow := party_shadows[index]
	if shadow != null:
		shadow.visible = is_visible


func _set_bag_storage_count(count: int) -> void:
	if bag_storage_state == null:
		return
	var state_index := clampi(count, 0, BAG_STORAGE_STATE_TEXTURES.size() - 1)
	bag_storage_state.texture = BAG_STORAGE_STATE_TEXTURES[state_index]


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
