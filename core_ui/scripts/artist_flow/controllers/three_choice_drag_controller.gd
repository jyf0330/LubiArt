extends RefCounted

## Owns the transient pointer transaction for ThreeChoiceScene. It classifies
## existing authored Controls and returns semantic release plans; it never
## submits commands, reads Snapshot, or decides gameplay legality.

const SOURCE_NONE := &"none"
const SOURCE_SHOP := &"shop"
const SOURCE_PARTY := &"party"
const SOURCE_BAG := &"bag"

const TARGET_AUTO := &"auto"
const TARGET_PARTY := &"party"
const TARGET_BAG := &"bag"
const TARGET_SELL := &"sell"

const PLAN_NONE := &"none"
const PLAN_INSPECT_SHOP := &"inspect_shop"
const PLAN_SUBMIT := &"submit"
const DEFAULT_PREVIEW_SIZE := Vector2(110.0, 110.0)

var _host: Control = null
var _shop_buttons: Array = []
var _shop_slots: Array = []
var _party_buttons: Array = []
var _party_slots: Array = []
var _bag_buttons: Array = []
var _bag_slots: Array = []
var _bag_button: Control = null
var _sell_button: Control = null
var _resolve_source_visual := Callable()
var _set_source_visible := Callable()
var _show_bag_highlight := Callable()
var _set_sell_visible := Callable()
var _clear_highlight := Callable()

var _candidate_source := SOURCE_NONE
var _candidate_index := -1
var _active_kind := SOURCE_NONE
var _preview: TextureRect = null
var _preview_locked_size := DEFAULT_PREVIEW_SIZE
var _hidden_button: BaseButton = null
var _hidden_visual: Control = null
var _hidden_texture: Texture2D = null
var _restore_hidden_source := false


func configure(
		host: Control,
		controls: Dictionary,
		resolve_source_visual: Callable,
		set_source_visible: Callable,
		show_bag_highlight: Callable,
		set_sell_visible: Callable,
		clear_highlight: Callable
) -> void:
	dispose()
	_host = host
	_shop_buttons = Array(controls.get("shop_buttons", []))
	_shop_slots = Array(controls.get("shop_slots", []))
	_party_buttons = Array(controls.get("party_buttons", []))
	_party_slots = Array(controls.get("party_slots", []))
	_bag_buttons = Array(controls.get("bag_buttons", []))
	_bag_slots = Array(controls.get("bag_slots", []))
	_bag_button = controls.get("bag_button") as Control
	_sell_button = controls.get("sell_button") as Control
	_resolve_source_visual = resolve_source_visual
	_set_source_visible = set_source_visible
	_show_bag_highlight = show_bag_highlight
	_set_sell_visible = set_sell_visible
	_clear_highlight = clear_highlight


func begin_shop(index: int) -> bool:
	if is_active() or index < 0 or index >= _shop_buttons.size():
		return false
	var button := _shop_buttons[index] as BaseButton
	if button == null or Dictionary(button.get_meta("command", {})).is_empty():
		return false
	_begin(SOURCE_SHOP, index)
	_active_kind = SOURCE_SHOP
	_start_preview()
	return true


func begin_storage(source: StringName, index: int, can_start: bool, can_sell: bool) -> bool:
	if is_active() or not can_start or (source != SOURCE_PARTY and source != SOURCE_BAG):
		return false
	var buttons := _buttons_for_source(source)
	if index < 0 or index >= buttons.size() or record_for_source(source, index).is_empty():
		return false
	_begin(source, index)
	_active_kind = source
	_call_if_valid(_set_sell_visible, [can_sell])
	_start_preview()
	return true


func handle_input(event: InputEvent) -> Dictionary:
	if _candidate_source == SOURCE_NONE or _candidate_index < 0:
		return {}
	if event is InputEventMouseMotion:
		var mouse_position := (event as InputEventMouseMotion).global_position
		update_preview(mouse_position)
		_update_bag_highlight(mouse_position)
		return {}
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			return plan_release(mouse_event.global_position)
	return {}


func plan_release(mouse_position: Vector2) -> Dictionary:
	match _active_kind:
		SOURCE_SHOP:
			return _plan_shop_release(mouse_position)
		SOURCE_PARTY, SOURCE_BAG:
			return _plan_storage_release(mouse_position)
	return {"kind": PLAN_NONE}


func plan_sell(source := SOURCE_NONE, index := -1) -> Dictionary:
	var sell_source: StringName = _candidate_source if source == SOURCE_NONE else source
	var sell_index: int = _candidate_index if index < 0 else index
	if sell_source != SOURCE_PARTY and sell_source != SOURCE_BAG:
		return {"kind": PLAN_NONE}
	var record := record_for_source(sell_source, sell_index)
	var unit_id := _record_ref(record)
	if unit_id == "":
		return {"kind": PLAN_NONE}
	return {
		"kind": PLAN_SUBMIT,
		"source": sell_source,
		"target_kind": TARGET_SELL,
		"command": {
			"type": "DROP_ITEM_ON_TARGET",
			"unitId": unit_id,
			"target_type": String(TARGET_SELL),
			"target_index": -1,
		}
	}


func accept_release() -> void:
	_discard_source_restore()


func clear() -> void:
	_clear_preview()
	_restore_source()
	_candidate_source = SOURCE_NONE
	_candidate_index = -1
	_active_kind = SOURCE_NONE
	_call_if_valid(_set_sell_visible, [false])
	_call_if_valid(_clear_highlight)


func dispose() -> void:
	_clear_preview(true)
	_restore_source()
	_call_if_valid(_set_sell_visible, [false])
	_call_if_valid(_clear_highlight)
	_candidate_source = SOURCE_NONE
	_candidate_index = -1
	_active_kind = SOURCE_NONE
	_host = null
	_shop_buttons.clear()
	_shop_slots.clear()
	_party_buttons.clear()
	_party_slots.clear()
	_bag_buttons.clear()
	_bag_slots.clear()
	_bag_button = null
	_sell_button = null
	_resolve_source_visual = Callable()
	_set_source_visible = Callable()
	_show_bag_highlight = Callable()
	_set_sell_visible = Callable()
	_clear_highlight = Callable()


func is_active() -> bool:
	return _active_kind != SOURCE_NONE


func candidate_source() -> StringName:
	return _candidate_source


func candidate_index() -> int:
	return _candidate_index


func preview() -> TextureRect:
	return _preview


func preview_locked_size() -> Vector2:
	return _preview_locked_size


func candidate_button() -> BaseButton:
	var buttons := _buttons_for_source(_candidate_source)
	if _candidate_index < 0 or _candidate_index >= buttons.size():
		return null
	return buttons[_candidate_index] as BaseButton


func candidate_texture() -> Texture2D:
	if _hidden_texture != null:
		return _hidden_texture
	return _texture_for_candidate()


func preview_size_for_candidate() -> Vector2:
	var button := candidate_button()
	if button == null:
		return DEFAULT_PREVIEW_SIZE
	var authored_size := button.get_meta("drag_preview_size", Vector2.ZERO) as Vector2
	if authored_size.x > 0.0 and authored_size.y > 0.0:
		return authored_size
	var source_size := button.size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = button.custom_minimum_size
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return DEFAULT_PREVIEW_SIZE
	return source_size


func record_for_source(source: StringName, index: int) -> Dictionary:
	var buttons := _buttons_for_source(source)
	if index < 0 or index >= buttons.size():
		return {}
	var button := buttons[index] as BaseButton
	return Dictionary(button.get_meta("drag_record", {})).duplicate(true) if button != null else {}


func update_preview(mouse_position: Vector2) -> void:
	if _preview == null or not is_instance_valid(_preview):
		return
	_preview.custom_minimum_size = _preview_locked_size
	_preview.size = _preview_locked_size
	_preview.global_position = mouse_position - _preview.size * 0.5


func _begin(source: StringName, index: int) -> void:
	_candidate_source = source
	_candidate_index = index
	_active_kind = SOURCE_NONE


func _plan_shop_release(mouse_position: Vector2) -> Dictionary:
	if _candidate_index < 0 or _candidate_index >= _shop_buttons.size():
		return {"kind": PLAN_NONE}
	var button := _shop_buttons[_candidate_index] as BaseButton
	var offer_command := Dictionary(button.get_meta("command", {})) if button != null else {}
	if offer_command.is_empty():
		return {"kind": PLAN_NONE}
	var target := _target_for_position(mouse_position)
	var target_kind := StringName(target.get("kind", TARGET_AUTO))
	if target_kind != TARGET_PARTY and target_kind != TARGET_BAG:
		if _candidate_index < _shop_slots.size() and _point_inside(_shop_slots[_candidate_index] as Control, mouse_position):
			return {"kind": PLAN_INSPECT_SHOP, "source_index": _candidate_index}
		return {"kind": PLAN_NONE}
	return {
		"kind": PLAN_SUBMIT,
		"source": SOURCE_SHOP,
		"target_kind": target_kind,
		"command": {
			"type": "DROP_ITEM_ON_TARGET",
			"source_type": String(SOURCE_SHOP),
			"source_index": _candidate_index,
			"offer_id": String(offer_command.get("offer_id", "")),
			"target_type": String(target_kind),
			"target_index": int(target.get("index", -1)),
		}
	}


func _plan_storage_release(mouse_position: Vector2) -> Dictionary:
	var record := record_for_source(_candidate_source, _candidate_index)
	if record.is_empty():
		return {"kind": PLAN_NONE}
	var target := _target_for_position(mouse_position)
	var target_kind := StringName(target.get("kind", TARGET_AUTO))
	var target_index := int(target.get("index", -1))
	if (target_kind == TARGET_PARTY and _candidate_source == SOURCE_PARTY and target_index == _candidate_index) \
			or (target_kind == TARGET_BAG and _candidate_source == SOURCE_BAG and target_index == _candidate_index):
		return {"kind": PLAN_NONE}
	var unit_id := _record_ref(record)
	if unit_id == "":
		return {"kind": PLAN_NONE}
	var allowed := target_kind == TARGET_SELL \
			or (_candidate_source == SOURCE_PARTY and target_kind == TARGET_PARTY) \
			or (_candidate_source == SOURCE_PARTY and target_kind == TARGET_BAG) \
			or (_candidate_source == SOURCE_BAG and target_kind == TARGET_BAG) \
			or (_candidate_source == SOURCE_BAG and target_kind == TARGET_PARTY)
	if not allowed:
		return {"kind": PLAN_NONE}
	return {
		"kind": PLAN_SUBMIT,
		"source": _candidate_source,
		"target_kind": target_kind,
		"command": {
			"type": "DROP_ITEM_ON_TARGET",
			"source_type": String(_candidate_source),
			"source_index": _candidate_index,
			"unitId": unit_id,
			"target_type": String(target_kind),
			"target_index": target_index,
		}
	}


func _target_for_position(mouse_position: Vector2) -> Dictionary:
	var bag_index := _slot_at_position(_bag_slots, mouse_position)
	if bag_index >= 0:
		return {"kind": TARGET_BAG, "index": bag_index}
	var party_index := _slot_at_position(_party_slots, mouse_position)
	if party_index >= 0:
		return {"kind": TARGET_PARTY, "index": party_index}
	if _point_inside(_bag_button, mouse_position):
		return {"kind": TARGET_BAG, "index": -1}
	if _point_inside(_sell_button, mouse_position):
		return {"kind": TARGET_SELL, "index": -1}
	return {"kind": TARGET_AUTO, "index": -1}


func _slot_at_position(slots: Array, mouse_position: Vector2) -> int:
	for index in range(slots.size()):
		if _point_inside(slots[index] as Control, mouse_position):
			return index
	return -1


func _point_inside(control: Control, point: Vector2) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var local_point := control.get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(Vector2.ZERO, control.size).has_point(local_point)


func _start_preview() -> void:
	var texture := _texture_for_candidate()
	if texture == null or _host == null or not is_instance_valid(_host) or not _host.is_inside_tree():
		return
	_hide_source(texture)
	_clear_preview()
	_preview_locked_size = preview_size_for_candidate()
	_preview = TextureRect.new()
	_preview.name = "DragPreview"
	_preview.texture = texture
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.custom_minimum_size = _preview_locked_size
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.modulate = Color(1.0, 1.0, 1.0, 0.82)
	_preview.z_index = 100
	_host.add_child(_preview)
	_preview.size = _preview_locked_size
	_preview.visible = true
	_preview.move_to_front()
	update_preview(_host.get_global_mouse_position())


func _texture_for_candidate() -> Texture2D:
	var button := candidate_button()
	if button == null:
		return null
	var shared_texture := button.get_meta("pet_texture") as Texture2D if button.has_meta("pet_texture") else null
	if shared_texture != null:
		return shared_texture
	if button is TextureButton:
		return (button as TextureButton).texture_normal
	if button is Button:
		return (button as Button).icon
	return null


func _hide_source(texture: Texture2D) -> void:
	var button := candidate_button()
	if button == null:
		return
	_hidden_button = button
	_hidden_visual = _resolve_source_visual.call(button.get_parent() as Control) as Control if _resolve_source_visual.is_valid() else null
	_hidden_texture = texture
	_restore_hidden_source = true
	if _set_source_visible.is_valid():
		_set_source_visible.call(button, _candidate_source, _candidate_index, texture, false)
	elif _hidden_visual != null:
		_hidden_visual.visible = false
	else:
		button.texture_normal = null


func _restore_source() -> void:
	if _restore_hidden_source:
		if _set_source_visible.is_valid() and _hidden_button != null and is_instance_valid(_hidden_button):
			_set_source_visible.call(_hidden_button, _candidate_source, _candidate_index, _hidden_texture, true)
		elif _hidden_visual != null and is_instance_valid(_hidden_visual):
			_hidden_visual.visible = _hidden_texture != null
		elif _hidden_button != null and is_instance_valid(_hidden_button):
			_hidden_button.texture_normal = _hidden_texture
	_discard_source_restore()


func _discard_source_restore() -> void:
	_hidden_button = null
	_hidden_visual = null
	_hidden_texture = null
	_restore_hidden_source = false


func _clear_preview(immediate: bool = false) -> void:
	if _preview != null and is_instance_valid(_preview):
		if immediate:
			_preview.free()
		else:
			_preview.queue_free()
	_preview = null
	_preview_locked_size = DEFAULT_PREVIEW_SIZE


func _update_bag_highlight(mouse_position: Vector2) -> void:
	var bag_index := _slot_at_position(_bag_slots, mouse_position)
	if bag_index < 0:
		_call_if_valid(_clear_highlight)
		return
	if _show_bag_highlight.is_valid():
		_show_bag_highlight.call(_bag_slots[bag_index] as Control, bag_index)


func _buttons_for_source(source: StringName) -> Array:
	match source:
		SOURCE_SHOP:
			return _shop_buttons
		SOURCE_PARTY:
			return _party_buttons
		SOURCE_BAG:
			return _bag_buttons
	return []


func _record_ref(record: Dictionary) -> String:
	for key in ["id", "unitId", "unit_id", "pet_id", "petId", "instance_id", "instanceId"]:
		var value := String(record.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func _call_if_valid(callback: Callable, arguments: Array = []) -> void:
	if callback.is_valid():
		callback.callv(arguments)
