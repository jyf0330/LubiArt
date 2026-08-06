extends SceneTree

const DragControllerScript := preload("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")

var _failed := false
var _sell_visible := false
var _highlight_clear_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.name = "Host"
	host.size = Vector2(900.0, 600.0)
	root.add_child(host)

	var shop := _slot_with_button(host, "Shop", Vector2(20.0, 40.0))
	var party := _slot_with_button(host, "Party", Vector2(260.0, 40.0))
	var bag := _slot_with_button(host, "Bag", Vector2(500.0, 40.0))
	var bag_button := _target(host, "BagButton", Vector2(500.0, 240.0))
	var sell_button := _target(host, "SellButton", Vector2(700.0, 240.0))
	await process_frame

	var texture := _test_texture()
	var shop_button := shop.get_node("Button") as TextureButton
	shop_button.texture_normal = texture
	shop_button.set_meta("command", {"type": "BUY_OFFER", "offer_id": "offer_1"})
	shop_button.set_meta("drag_record", {"pet_id": "pet_shop"})
	var party_button := party.get_node("Button") as TextureButton
	party_button.texture_normal = texture
	party_button.set_meta("drag_record", {"id": "unit_party"})
	var bag_button_item := bag.get_node("Button") as TextureButton
	bag_button_item.texture_normal = texture
	bag_button_item.set_meta("drag_record", {"unitId": "unit_bag"})

	var controller := DragControllerScript.new()
	controller.configure(host, {
		"shop_buttons": [shop_button],
		"shop_slots": [shop],
		"party_buttons": [party_button],
		"party_slots": [party],
		"bag_buttons": [bag_button_item],
		"bag_slots": [bag],
		"bag_button": bag_button,
		"sell_button": sell_button,
	}, Callable(self, "_resolve_visual"), Callable(), Callable(), Callable(self, "_set_sell_visible"), Callable(self, "_clear_highlight"))

	_expect(controller.begin_shop(0), "shop drag begins from a valid semantic offer")
	_expect(controller.candidate_source() == DragControllerScript.SOURCE_SHOP and controller.candidate_index() == 0, "controller owns the candidate identity")
	_expect(controller.is_active() and controller.preview() != null, "controller owns one active preview")
	_expect(shop_button.texture_normal == null, "begin hides the source image")
	_expect(controller.preview().size == Vector2(110.0, 110.0), "preview captures the authored source size")
	var pointer := Vector2(420.0, 300.0)
	controller.update_preview(pointer)
	_expect(controller.preview().global_position == pointer - controller.preview().size * 0.5, "preview follows the pointer with locked size")

	var party_plan := controller.plan_release(_center(party))
	_expect(StringName(party_plan.get("kind")) == DragControllerScript.PLAN_SUBMIT, "party target returns a submit plan")
	var party_command := Dictionary(party_plan.get("command", {}))
	_expect(party_command == {
		"type": "DROP_ITEM_ON_TARGET",
		"offer_id": "offer_1",
		"target_type": "party",
		"target_index": 0,
	}, "shop plan contains only the semantic drop intent")
	party_command["offer_id"] = "mutated"
	_expect(String(Dictionary(shop_button.get_meta("command", {})).get("offer_id", "")) == "offer_1", "release plans do not mutate button command metadata")
	controller.clear()
	_expect(shop_button.texture_normal == texture and not controller.is_active(), "cancel/rejection cleanup restores the source")
	_expect(_highlight_clear_count == 1 and not _sell_visible, "cleanup closes transient presentation affordances")

	_expect(controller.begin_shop(0), "accepted shop transaction can begin again")
	controller.accept_release()
	controller.clear()
	_expect(shop_button.texture_normal == null, "accepted transaction does not resurrect an authority-removed source")
	shop_button.texture_normal = texture

	_expect(controller.begin_storage(DragControllerScript.SOURCE_PARTY, 0, true, true), "storage drag begins when page policy allows it")
	_expect(_sell_visible, "storage drag exposes the existing sell target through the narrow callback")
	var bag_plan := controller.plan_release(_center(bag))
	var bag_command := Dictionary(bag_plan.get("command", {}))
	_expect(StringName(bag_plan.get("source")) == DragControllerScript.SOURCE_PARTY, "storage plan preserves presentation source kind")
	_expect(String(bag_command.get("unitId", "")) == "unit_party" and String(bag_command.get("target_type", "")) == "bag", "storage plan uses stable unit identity and authored bag target")
	var self_plan := controller.plan_release(_center(party))
	_expect(StringName(self_plan.get("kind")) == DragControllerScript.PLAN_NONE, "same-slot storage release is a no-op")
	controller.clear()
	_expect(party_button.texture_normal == texture and not _sell_visible, "storage cleanup restores source and hides sell target")

	_expect(controller.begin_shop(0), "shop inspection transaction begins")
	var inspect_plan := controller.plan_release(_center(shop))
	_expect(StringName(inspect_plan.get("kind")) == DragControllerScript.PLAN_INSPECT_SHOP and int(inspect_plan.get("source_index", -1)) == 0, "release on the source asks the page facade to inspect the offer")
	controller.dispose()
	_expect(controller.preview() == null and shop_button.texture_normal == texture, "dispose frees preview and restores hidden source")

	_test_source_boundary()
	host.queue_free()
	await process_frame
	print("SMOKE_THREE_CHOICE_DRAG_CONTROLLER_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _slot_with_button(parent: Control, slot_name: String, position: Vector2) -> Control:
	var slot := Control.new()
	slot.name = slot_name
	slot.position = position
	slot.size = Vector2(110.0, 110.0)
	parent.add_child(slot)
	var button := TextureButton.new()
	button.name = "Button"
	button.size = slot.size
	button.custom_minimum_size = slot.size
	slot.add_child(button)
	return slot


func _target(parent: Control, target_name: String, position: Vector2) -> Control:
	var target := Control.new()
	target.name = target_name
	target.position = position
	target.size = Vector2(110.0, 110.0)
	parent.add_child(target)
	return target


func _test_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.7, 0.9, 1.0))
	return ImageTexture.create_from_image(image)


func _resolve_visual(_slot: Control) -> Control:
	return null


func _set_sell_visible(visible: bool) -> void:
	_sell_visible = visible


func _clear_highlight() -> void:
	_highlight_clear_count += 1


func _center(control: Control) -> Vector2:
	var rect := control.get_global_rect()
	return rect.position + rect.size * 0.5


func _test_source_boundary() -> void:
	var source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/controllers/three_choice_drag_controller.gd")
	for forbidden in ["GameSession", "YsbzsState", "snapshot.get", "preload(\"res://session", "preload(\"res://persistence", "preload(\"res://core/state"]:
		_expect(not source.contains(forbidden), "drag controller has no gameplay/session/persistence authority dependency: %s" % forbidden)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_THREE_CHOICE_DRAG_CONTROLLER_FAIL: %s" % message)
