extends Control

## Dedicated shop presentation Scene. Game owns the Session and routes every
## semantic command; this root only renders Snapshot data and interaction.

signal command_requested(command: Dictionary, request_id: int)
signal presentation_settled

const AssetRegistryScript := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_asset_registry.gd")
const ShopPresenterScript := preload("res://core_ui/scripts/shop/presenters/shop_presenter.gd")
const InventoryPresenterScript := preload("res://core_ui/scripts/inventory/presenters/inventory_presenter.gd")
const PartyPresenterScript := preload("res://core_ui/scripts/party/presenters/party_presenter.gd")
const DragControllerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")
const RequestBrokerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_request_broker.gd")
const ArtPreviewModelScript := preload("res://core_ui/scripts/shop/controllers/shop_art_preview_model.gd")
const MERCHANT_FALLBACK := preload("res://art/images/shop/screen_shop_godot_v1/merchant_default.png")
const MERCHANT_MAP_PATH := "res://art/manifests/shop/merchant_map.json"
const BAG_SLOT_HIGHLIGHT_TEXTURE := preload("res://art/images/route/three_choice_psd/bag_item_highlight.png")
const OFFER_COUNT := 5
const BAG_SLOT_COUNT := 8
const OFFER_PRICE_FONT_SIZE := 18
const OFFER_PRICE_TAG_WIDTH := 30.0
const OFFER_PRICE_COLOR := Color(0.99, 0.84, 0.36, 1.0)
const OFFER_PRICE_DISABLED_COLOR := Color(0.62, 0.62, 0.62, 1.0)

@onready var merchant: TextureRect = $Merchant
@onready var offers: Control = $Offers
@onready var refresh_curtain: TextureRect = $RefreshCurtain
@onready var refresh_button: TextureButton = $RefreshButton
@onready var shared_ui: Control = $RouteSharedUi
@onready var bag_button: TextureButton = $RouteSharedUi/Bags/Bag_Button
@onready var bag_storage_state: TextureRect = $RouteSharedUi/Bags/BagStorageState
@onready var party_container: Control = $RouteSharedUi/Party/Party_Container
@onready var exit_button: TextureButton = $RouteSharedUi/ExitButton

var _asset_registry := AssetRegistryScript.new()
var _shop_presenter := ShopPresenterScript.new()
var _inventory_presenter := InventoryPresenterScript.new()
var _party_presenter := PartyPresenterScript.new()
var _snapshot: Dictionary = {}
var _request_broker := RequestBrokerScript.new()
var _offer_buttons: Array[Button] = []
var _offer_prices := PackedStringArray()
var _bag_buttons: Array[TextureButton] = []
var _bag_open := false
var _refreshing := false
var _merchant_path_by_id: Dictionary = {}
var _party_buttons: Array[TextureButton] = []
var _drag_controller := DragControllerScript.new()
var _art_preview_model := ArtPreviewModelScript.new()
var _standalone_art_preview := false


func _ready() -> void:
	_asset_registry.reload()
	_configure_request_broker()
	_load_merchant_map()
	_collect_offer_buttons()
	offers.draw.connect(_draw_offer_prices)
	_collect_bag_buttons()
	_collect_party_buttons()
	_connect_buttons()
	_configure_drag_controller()
	_set_bag_open(false)
	refresh_curtain.visible = false
	if not _snapshot.is_empty():
		render_snapshot(_snapshot)
	else:
		call_deferred("_enable_standalone_art_preview_if_unowned")


func _exit_tree() -> void:
	_drag_controller.dispose()
	_request_broker.dispose()


func render_snapshot(snapshot: Dictionary) -> void:
	if not command_requested.get_connections().is_empty():
		_standalone_art_preview = false
	_snapshot = snapshot.duplicate(true)
	shared_ui.call("set_coin_amount", int(_snapshot.get("coins", 0)))
	_render_merchant()
	_render_offers()
	_render_roster()
	presentation_settled.emit()


func complete_command_request(request_id: int, response: Dictionary) -> void:
	_request_broker.complete_command(request_id, response)


func _configure_request_broker() -> void:
	var callback := Callable(self, "_on_broker_command_requested")
	if not _request_broker.command_requested.is_connected(callback):
		_request_broker.command_requested.connect(callback)


func _on_broker_command_requested(command: Dictionary, request_id: int) -> void:
	command_requested.emit(command.duplicate(true), request_id)


func get_feature_controller(feature_name: StringName) -> Variant:
	match feature_name:
		&"shop":
			return _shop_presenter
		&"inventory":
			return _inventory_presenter
		&"party":
			return _party_presenter
		_:
			return null


func get_missing_image_report() -> Array:
	return _asset_registry.missing_image_report()


func is_standalone_art_preview() -> bool:
	return _standalone_art_preview


func preview_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func _enable_standalone_art_preview_if_unowned() -> void:
	if not _snapshot.is_empty() or not command_requested.get_connections().is_empty():
		return
	_standalone_art_preview = true
	_snapshot = Dictionary(_art_preview_model.reset())
	render_snapshot(_snapshot)


func _collect_offer_buttons() -> void:
	_offer_buttons.clear()
	for index in range(OFFER_COUNT):
		var button := offers.get_node("Offer%02d" % (index + 1)) as Button
		_offer_buttons.append(button)
	_offer_prices.resize(_offer_buttons.size())


func _collect_bag_buttons() -> void:
	_bag_buttons.clear()
	for value in Array(shared_ui.call("bag_buttons")):
		if value is TextureButton:
			_bag_buttons.append(value as TextureButton)


func _collect_party_buttons() -> void:
	_party_buttons.clear()
	for index in range(4):
		var button := party_container.get_node("Party_Slot" if index == 0 else "Party_Slot%d" % (index + 1)) as TextureButton
		_party_buttons.append(button)


func _configure_drag_controller() -> void:
	_drag_controller.configure(self, {
		"shop_buttons": _offer_buttons,
		"shop_slots": _offer_buttons,
		"party_buttons": _party_buttons,
		"party_slots": _party_buttons,
		"bag_buttons": _bag_buttons,
		"bag_slots": _bag_buttons,
		"bag_button": bag_button,
		"sell_button": null,
	}, Callable(), Callable(self, "_set_drag_source_visible"), Callable(self, "_show_drag_bag_highlight"), Callable(), Callable(self, "_hide_item_slot_highlight"))


func _connect_buttons() -> void:
	for index in range(_offer_buttons.size()):
		var offer_button := _offer_buttons[index]
		offer_button.button_down.connect(_on_offer_button_down.bind(index))
		offer_button.mouse_entered.connect(_on_offer_mouse_entered.bind(index))
		offer_button.mouse_exited.connect(_on_offer_mouse_exited.bind(index))
		offer_button.gui_input.connect(_on_offer_gui_input.bind(index))
	refresh_button.pressed.connect(_on_refresh_pressed)
	bag_button.pressed.connect(_on_bag_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	for button in _offer_buttons:
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for index in range(_party_buttons.size()):
		var party_button := _party_buttons[index]
		party_button.focus_mode = Control.FOCUS_ALL
		party_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		party_button.set_meta("party_mouse_hovered", false)
		party_button.button_down.connect(_on_party_button_down.bind(index))
		party_button.mouse_entered.connect(_on_party_mouse_entered.bind(index))
		party_button.mouse_exited.connect(_on_party_mouse_exited.bind(index))
	for index in range(_bag_buttons.size()):
		var bag_slot := _bag_buttons[index]
		bag_slot.button_down.connect(_on_bag_button_down.bind(index))
		bag_slot.mouse_entered.connect(_on_bag_mouse_entered.bind(index))
		bag_slot.mouse_exited.connect(_on_bag_mouse_exited.bind(index))
	refresh_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	exit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _render_merchant() -> void:
	var stall := Dictionary(_snapshot.get("active_stall", {}))
	var texture := _merchant_texture(stall)
	merchant.texture = texture if texture != null else MERCHANT_FALLBACK


func _load_merchant_map() -> void:
	_merchant_path_by_id.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MERCHANT_MAP_PATH))
	if parsed is Dictionary:
		_merchant_path_by_id = Dictionary(Dictionary(parsed).get("variants", {})).duplicate(true)


func _merchant_texture(stall: Dictionary) -> Texture2D:
	for key in ["nodeId", "node_id", "id", "shopPoolId", "shop_pool_id"]:
		var identity := String(stall.get(key, "")).strip_edges()
		if identity == "" or not _merchant_path_by_id.has(identity):
			continue
		var path := String(_merchant_path_by_id[identity])
		if ResourceLoader.exists(path, "Texture2D"):
			return load(path) as Texture2D
	return null


func _render_offers() -> void:
	var cards := Array(_shop_presenter.call("cards", _snapshot))
	for index in range(_offer_buttons.size()):
		var button := _offer_buttons[index]
		var card := Dictionary(cards[index]) if index < cards.size() else {}
		var offer := Dictionary(card.get("record", {}))
		var listed := not offer.is_empty() and bool(card.get("available", false))
		var purchasable := listed and bool(card.get("purchasable", false))
		var price := str(int(offer.get("price", 0))) if listed else ""
		button.disabled = not listed
		var pet_texture := _asset_registry.pet_texture(offer) if listed else null
		button.icon = pet_texture
		button.text = ""
		button.tooltip_text = String(offer.get("name", offer.get("id", "")))
		button.modulate = Color.WHITE if purchasable else Color(0.62, 0.62, 0.62, 1.0)
		button.set_meta("price", price)
		button.set_meta("command", Dictionary(card.get("command", {})))
		button.set_meta("offer", offer)
		button.set_meta("drag_record", offer)
		button.set_meta("pet_texture", pet_texture)
		button.set_meta("base_modulate", button.modulate)
		button.set_meta("drag_preview_size", Vector2(126.0, 124.0))
		_offer_prices[index] = price
	offers.queue_redraw()


func _draw_offer_prices() -> void:
	var font := ThemeDB.fallback_font
	var baseline_offset := (font.get_ascent(OFFER_PRICE_FONT_SIZE) - font.get_descent(OFFER_PRICE_FONT_SIZE)) * 0.5
	for index in range(_offer_buttons.size()):
		var price := _offer_prices[index]
		if price.is_empty():
			continue
		var button := _offer_buttons[index]
		var color := OFFER_PRICE_DISABLED_COLOR if button.disabled else OFFER_PRICE_COLOR
		var tag_center: Vector2 = button.get_meta(
			"price_tag_center",
			button.position + Vector2(button.size.x * 0.5, button.size.y - 10.0)
		)
		var tag_width := float(button.get_meta("price_tag_width", OFFER_PRICE_TAG_WIDTH))
		offers.draw_string(
			font,
			Vector2(tag_center.x - tag_width * 0.5, tag_center.y + baseline_offset),
			price,
			HORIZONTAL_ALIGNMENT_CENTER,
			tag_width,
			OFFER_PRICE_FONT_SIZE,
			color
		)


func _render_roster() -> void:
	var party_slots := Array(_party_presenter.call("slots", _snapshot, 4))
	for index in range(4):
		var button := _party_buttons[index]
		var pet := Dictionary(party_slots[index]) if index < party_slots.size() else {}
		button.set_meta("drag_record", pet)
		button.set_meta("drag_preview_size", Vector2(126.0, 124.0))
		_set_party_texture(button, _asset_registry.pet_texture(pet) if not pet.is_empty() else null)
	var bag_model := Dictionary(_inventory_presenter.call("page", _snapshot, 0, BAG_SLOT_COUNT))
	var items := Array(bag_model.get("items", []))
	bag_storage_state.tooltip_text = "%d / %d" % [int(bag_model.get("total_count", 0)), BAG_SLOT_COUNT]
	for index in range(_bag_buttons.size()):
		var pet := Dictionary(items[index]) if index < items.size() else {}
		var bag_slot := _bag_buttons[index]
		bag_slot.set_meta("drag_record", pet)
		bag_slot.set_meta("drag_preview_size", Vector2(121.0, 116.0))
		_set_bag_texture(bag_slot, _asset_registry.pet_texture(pet) if not pet.is_empty() else null)


func _set_party_texture(button: TextureButton, texture: Texture2D) -> void:
	shared_ui.call("set_party_texture", button, texture)


func _set_bag_texture(button: TextureButton, texture: Texture2D) -> void:
	shared_ui.call("set_bag_texture", button, texture)


func _set_drag_source_visible(button: BaseButton, source: StringName, _index: int, _texture: Texture2D, source_visible: bool) -> void:
	if source == DragControllerScript.SOURCE_SHOP and button is Button:
		var current_texture := button.get_meta("pet_texture") as Texture2D \
			if source_visible and button.has_meta("pet_texture") else null
		(button as Button).icon = current_texture
	else:
		shared_ui.call("set_drag_source_visible", button, source, source_visible)


func _show_drag_bag_highlight(slot: Control, _index: int) -> void:
	shared_ui.call("show_bag_slot_highlight", slot, BAG_SLOT_HIGHLIGHT_TEXTURE)


func _hide_item_slot_highlight() -> void:
	shared_ui.call("hide_bag_slot_highlight")


func _on_offer_button_down(index: int) -> void:
	if _refreshing:
		return
	_drag_controller.begin_shop(index)


func _on_offer_mouse_entered(index: int) -> void:
	if index < 0 or index >= _offer_buttons.size() or _drag_controller.is_active():
		return
	var button := _offer_buttons[index]
	var base_color := button.get_meta("base_modulate", button.modulate) as Color
	button.modulate = base_color.lightened(0.2)


func _on_offer_mouse_exited(index: int) -> void:
	if index < 0 or index >= _offer_buttons.size() or _drag_controller.is_active():
		return
	var button := _offer_buttons[index]
	button.modulate = button.get_meta("base_modulate", button.modulate) as Color


func _on_offer_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton or not event.is_action_pressed("ui_accept"):
		return
	accept_event()
	await _on_offer_pressed(index)


func _on_party_button_down(index: int) -> void:
	_drag_controller.begin_storage(DragControllerScript.SOURCE_PARTY, index, true, false)


func _on_party_mouse_entered(index: int) -> void:
	if index < 0 or index >= _party_buttons.size() or _drag_controller.is_active():
		return
	shared_ui.call("set_party_hovered", _party_buttons[index], true)


func _on_party_mouse_exited(index: int) -> void:
	if index < 0 or index >= _party_buttons.size():
		return
	shared_ui.call("set_party_hovered", _party_buttons[index], false)


func _on_bag_button_down(index: int) -> void:
	if not _bag_open:
		return
	_drag_controller.begin_storage(DragControllerScript.SOURCE_BAG, index, true, false)


func _on_bag_mouse_entered(index: int) -> void:
	if not _bag_open or _drag_controller.is_active() or index < 0 or index >= _bag_buttons.size():
		return
	shared_ui.call("show_bag_slot_highlight", _bag_buttons[index], BAG_SLOT_HIGHLIGHT_TEXTURE)


func _on_bag_mouse_exited(_index: int) -> void:
	if not _drag_controller.is_active():
		_hide_item_slot_highlight()


func _input(event: InputEvent) -> void:
	var plan := _drag_controller.handle_input(event)
	if plan.is_empty():
		return
	match StringName(plan.get("kind", DragControllerScript.PLAN_NONE)):
		DragControllerScript.PLAN_INSPECT_SHOP:
			await _on_offer_pressed(int(plan.get("source_index", -1)))
		DragControllerScript.PLAN_SUBMIT:
			var command := Dictionary(plan.get("command", {})).duplicate(true)
			var response := await _submit_command(command)
			var snapshot := Dictionary(response.get("snapshot", {}))
			if not snapshot.is_empty():
				_drag_controller.accept_release()
				render_snapshot(snapshot)
	_drag_controller.clear()


func _on_offer_pressed(index: int) -> void:
	if _refreshing or index < 0 or index >= _offer_buttons.size():
		return
	var command := Dictionary(_offer_buttons[index].get_meta("command", {}))
	if command.is_empty():
		return
	var response := await _submit_command(command)
	var snapshot := Dictionary(response.get("snapshot", {}))
	if not snapshot.is_empty():
		render_snapshot(snapshot)


func _on_refresh_pressed() -> void:
	if _refreshing:
		return
	_refreshing = true
	refresh_button.disabled = true
	refresh_curtain.visible = true
	refresh_curtain.modulate.a = 0.0
	var tween_in := create_tween()
	tween_in.tween_property(refresh_curtain, "modulate:a", 1.0, 0.14)
	await tween_in.finished
	var response := await _submit_command({"type": "ROLL_SHOP"})
	var snapshot := Dictionary(response.get("snapshot", {}))
	if not snapshot.is_empty():
		render_snapshot(snapshot)
	await get_tree().create_timer(0.12).timeout
	var tween_out := create_tween()
	tween_out.tween_property(refresh_curtain, "modulate:a", 0.0, 0.14)
	await tween_out.finished
	refresh_curtain.visible = false
	refresh_button.disabled = false
	_refreshing = false


func _on_bag_pressed() -> void:
	_set_bag_open(not _bag_open)


func _set_bag_open(open: bool) -> void:
	_bag_open = open
	shared_ui.call("set_bag_open", open)


func _on_exit_pressed() -> void:
	if _refreshing:
		return
	await _submit_command({"type": "EXIT_SHOP"})


func _submit_command(command: Dictionary) -> Dictionary:
	if _standalone_art_preview or command_requested.get_connections().is_empty():
		if not _standalone_art_preview:
			_enable_standalone_art_preview_if_unowned()
		return _apply_standalone_preview_command(command)
	return Dictionary(await _request_broker.request_command(command))


func _apply_standalone_preview_command(command: Dictionary) -> Dictionary:
	var response := Dictionary(_art_preview_model.apply_command(command))
	var preview_snapshot := Dictionary(response.get("snapshot", {}))
	if not preview_snapshot.is_empty():
		_snapshot = preview_snapshot.duplicate(true)
	return response
