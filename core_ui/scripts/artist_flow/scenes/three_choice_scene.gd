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
const ShortcutCatalog := preload("res://core_ui/scripts/shared/shortcut_catalog.gd")
const RequestBrokerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_request_broker.gd")
const FocusCoordinatorScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_focus_coordinator.gd")
const DeveloperToolbarScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_developer_toolbar.gd")
const DragControllerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")

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
const DRAG_SOURCE_NONE := DragControllerScript.SOURCE_NONE
const DRAG_SOURCE_SHOP := DragControllerScript.SOURCE_SHOP
const DRAG_SOURCE_PARTY := DragControllerScript.SOURCE_PARTY
const DRAG_SOURCE_BAG := DragControllerScript.SOURCE_BAG
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
var _request_broker := RequestBrokerScript.new()
var _focus_coordinator := FocusCoordinatorScript.new()
var _developer_toolbar := DeveloperToolbarScript.new()
var _drag_controller := DragControllerScript.new()
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
var _slot_draw_texture: ImageTexture = null
var _is_toggling_bag := false
var _bag_page := 0
var _hovered_route_index := -1
var _hovered_storage_source := DRAG_SOURCE_NONE
var _hovered_storage_index := -1
var _battle_view: Control = null
var _pet_detail_panel: Control = null
var _bazaar_info_panel: Control = null
@onready var _item_slot_hover_highlight: TextureRect = $ItemSlotHoverHighlight
var _route_presenter := RoutePresenterScript.new()
var _shop_presenter := ShopPresenterScript.new()
var _inventory_presenter := InventoryPresenterScript.new()
var _party_presenter := PartyPresenterScript.new()
var _settlement_presenter := SettlementPresenterScript.new()
var _developer_tools := false

func _ready() -> void:
	RuntimeUiPolicy.install()
	_developer_tools = RuntimeUiPolicy.developer_tools_enabled()
	_configure_request_broker()
	_asset_registry.reload()
	_build_runtime_slots()
	_collect_slots()
	_set_bag_storage_count(0)
	_configure_drag_controller()
	_ensure_pet_detail_panel()
	_ensure_bazaar_info_panel()
	_developer_toolbar.configure(
		self,
		Callable(self, "_request_session_operation"),
		Callable(self, "_on_developer_operation_completed")
	)
	_developer_toolbar.set_enabled(_developer_tools)
	_apply_runtime_ui_mode()
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
	var operation_callback := Callable(self, "_on_broker_session_operation_requested")
	if not _request_broker.session_operation_requested.is_connected(operation_callback):
		_request_broker.session_operation_requested.connect(operation_callback)

func _on_broker_command_requested(command: Dictionary, request_id: int) -> void:
	command_requested.emit(command.duplicate(true), request_id)

func _on_broker_session_operation_requested(operation: StringName, arguments: Dictionary, request_id: int) -> void:
	session_operation_requested.emit(operation, arguments.duplicate(true), request_id)

func _set_game_cursor_loading(source: StringName, active: bool) -> void:
	var cursor := _game_cursor()
	if cursor != null and cursor.has_method("set_loading_source"):
		cursor.call("set_loading_source", source, active)

func _exit_tree() -> void:
	_drag_controller.dispose()
	_stage_presenter.dispose()
	_request_broker.dispose()
	_focus_coordinator.dispose()
	_developer_toolbar.dispose()

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

func is_presentation_busy() -> bool:
	return _is_transitioning

func render_battle_command_response(command: Dictionary, response: Dictionary) -> void:
	var before_snapshot := _current_snapshot()
	var after_snapshot := Dictionary(response.get("snapshot", before_snapshot))
	_snapshot = after_snapshot.duplicate(true)
	if _battle_view != null and _battle_view.has_method("render_command_response"):
		_battle_view.call("render_command_response", command, response)
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
	# Commands that remain in battle only need the active battle presentation.
	# Re-rendering the hidden route HUD, roster and bazaar content here adds work
	# directly to pointer-down/up without changing anything the player can see.
	if String(after_snapshot.get("phase", "")) == "battle" and _battle_view != null:
		_render_battle_view(after_snapshot)
		await _transition_to_view(VIEW_BATTLE)
		return
	var target_view := _render_content_from_state(after_snapshot)
	await _transition_to_view(target_view)

func configure_session_capabilities(supports_persistence: bool, slot_count: int) -> void:
	_developer_toolbar.configure_session_capabilities(supports_persistence, slot_count)

func complete_command_request(request_id: int, response: Dictionary) -> void:
	_request_broker.complete_command(request_id, response)
	command_response_received.emit(request_id)

func complete_session_operation_request(request_id: int, result: Dictionary) -> void:
	_request_broker.complete_session_operation(request_id, result)
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

func _configure_drag_controller() -> void:
	_drag_controller.configure(self, {
		"shop_buttons": _shop_buttons,
		"shop_slots": _shop_slots,
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
		index: int,
		texture_resource: Texture2D,
		is_visible: bool
) -> void:
	_set_slot_texture(button, texture_resource if is_visible else null)
	if source == DRAG_SOURCE_PARTY:
		_set_party_shadow_visible(index, is_visible and texture_resource != null)

func _show_drag_bag_highlight(slot: Control, index: int) -> void:
	_show_item_slot_highlight(slot, _bag_slot_highlight_extra_offset(index))

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
	_focus_coordinator.configure(
		self,
		_three_buttons,
		_shop_buttons,
		_party_buttons,
		_bag_buttons,
		shop_back_button,
		bag_button,
		_bazaar_info_panel
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
	_drag_controller.begin_shop(index)

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
	_set_hovered_storage_target(DRAG_SOURCE_PARTY, index)
	_show_storage_pet_context(DRAG_SOURCE_PARTY, index)

func _on_party_pet_mouse_exited(index: int) -> void:
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
		_bag_slot_highlight_extra_offset(index)
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
	_drag_controller.begin_storage(source, index, true, _can_sell_storage_items())

func _input(event: InputEvent) -> void:
	if _is_sell_shortcut_pressed(event):
		get_viewport().set_input_as_handled()
		await _sell_shortcut_target()
		return
	var release_plan := _drag_controller.handle_input(event)
	if release_plan.is_empty():
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
	return _current_view != VIEW_BATTLE and party_container != null and party_container.is_visible_in_tree()

func _can_start_storage_drag(source: StringName) -> bool:
	if source == DRAG_SOURCE_PARTY:
		return _current_view != VIEW_BATTLE and party_container != null and party_container.is_visible_in_tree()
	if source == DRAG_SOURCE_BAG:
		return _current_view == VIEW_BAG and middle_bag != null and middle_bag.is_visible_in_tree()
	return false

func _drop_dragged_shop_item(mouse_position: Vector2) -> void:
	await _execute_drag_release_plan(_drag_controller.plan_release(mouse_position))

func _drop_dragged_storage_item(mouse_position: Vector2) -> void:
	await _execute_drag_release_plan(_drag_controller.plan_release(mouse_position))

func _execute_drag_release_plan(plan: Dictionary) -> void:
	match StringName(plan.get("kind", DragControllerScript.PLAN_NONE)):
		DragControllerScript.PLAN_INSPECT_SHOP:
			_show_shop_pet_context(int(plan.get("source_index", -1)))
		DragControllerScript.PLAN_SUBMIT:
			var command := Dictionary(plan.get("command", {})).duplicate(true)
			if command.is_empty() or not await _submit_core_command(command):
				return
			_drag_controller.accept_release()
			var target_view := _render_content_from_state(_take_core_command_snapshot())
			var source := StringName(plan.get("source", DragControllerScript.SOURCE_NONE))
			var target_kind := StringName(plan.get("target_kind", DragControllerScript.TARGET_AUTO))
			if source != DRAG_SOURCE_SHOP and _current_view == VIEW_BAG and target_kind != DragControllerScript.TARGET_SELL:
				_show_view(VIEW_BAG)
				return
			await _transition_to_view(target_view)

func _drag_record_for_source(source: StringName, index: int) -> Dictionary:
	return _drag_controller.record_for_source(source, index)

func _drag_button_for_candidate() -> TextureButton:
	return _drag_controller.candidate_button()

func _drag_preview_size_for_candidate() -> Vector2:
	return _drag_controller.preview_size_for_candidate()

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

func _set_run_tools_status(text: String) -> void:
	_developer_toolbar.set_status(text)

func _set_run_tools_visible(is_visible: bool) -> void:
	_developer_toolbar.set_visible_for_view(_current_view, is_visible)

func _on_developer_operation_completed(operation: StringName, result: Dictionary) -> void:
	if operation == &"load" and result.get("snapshot") is Dictionary:
		_snapshot = Dictionary(result.get("snapshot", {})).duplicate(true)
	var target_view := _render_content_from_state(_current_snapshot())
	if operation == &"load":
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
	_developer_toolbar.set_enabled(enabled)
	_apply_runtime_ui_mode()
	_set_run_tools_visible(true)

func _apply_async_game_session_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	_snapshot = snap.duplicate(true)
	var target_view := _render_content_from_state(snap)
	await _transition_to_view(target_view)

func _current_snapshot() -> Dictionary:
	return _snapshot

func _request_session_operation(operation: StringName, arguments: Dictionary) -> Dictionary:
	return Dictionary(await _request_broker.request_session_operation(operation, arguments))

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
