extends SceneTree

const AssetRegistry := preload("res://core_ui/scripts/artist_flow/controllers/artist_flow_asset_registry.gd")
const ThreeChoiceScene := preload("res://art/scenes/three_choice/three_choice_scene.tscn")

var _failed := false

const PORTRAIT_CANVAS_SIZE := Vector2i(365, 500)
const PORTRAIT_CONTENT_HEIGHT := 220
const PORTRAIT_VISUAL_CENTER_X := 160.0
const PORTRAIT_BASELINE_Y := 370


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected_pool_sizes := [4, 4, 3]
	_expect(AssetRegistry.ROUTE_SLOT_IMAGE_POOLS.size() == 3, "three authored route portrait pools exist")
	for slot_index in range(AssetRegistry.ROUTE_SLOT_IMAGE_POOLS.size()):
		var pool := Array(AssetRegistry.ROUTE_SLOT_IMAGE_POOLS[slot_index])
		_expect(pool.size() == expected_pool_sizes[slot_index], "route portrait pool %d has the confirmed size" % slot_index)
		for path_value in pool:
			var portrait_path := String(path_value)
			_expect(ResourceLoader.exists(portrait_path), "route portrait exists: %s" % portrait_path)
			var image := Image.load_from_file(ProjectSettings.globalize_path(portrait_path))
			_expect(not image.is_empty(), "route portrait image loads: %s" % portrait_path)
			if image.is_empty():
				continue
			_expect(image.get_size() == PORTRAIT_CANVAS_SIZE, "route portrait keeps the authored 365x500 canvas: %s" % portrait_path)
			var used_rect := image.get_used_rect()
			_expect(used_rect.size.y == PORTRAIT_CONTENT_HEIGHT, "route portrait visible content uses the shared 220px height: %s" % portrait_path)
			_expect(used_rect.end.y == PORTRAIT_BASELINE_Y, "route portrait visible content uses the shared baseline: %s" % portrait_path)
			var visible_center_x := float(used_rect.position.x) + float(used_rect.size.x) * 0.5
			_expect(absf(visible_center_x - PORTRAIT_VISUAL_CENTER_X) <= 1.0, "route portrait visible content uses the shared parchment visual center: %s" % portrait_path)

	var registry := AssetRegistry.new()
	registry.reload()
	for slot_index in range(3):
		var option := {"id": "stable_option_%d" % slot_index}
		var first := registry.route_slot_texture(slot_index, option)
		var second := registry.route_slot_texture(slot_index, option)
		_expect(first != null and second != null, "route portrait pool %d loads a texture" % slot_index)
		_expect(first.resource_path == second.resource_path, "route portrait pool %d stays stable for the current option" % slot_index)

	var view := ThreeChoiceScene.instantiate() as Control
	root.add_child(view)
	for _frame in range(8):
		await process_frame
	var card_grid := view.get_node("MainBG/Containers/Middle/Middle_Three_Option/CardGrid") as Control
	for card in card_grid.get_children():
		var portrait := card.get_node("Portrait") as TextureRect
		var button := card.get_node("Three_Button") as TextureButton
		_expect(portrait.texture != null, "standalone ThreeChoice Scene keeps an authored portrait preview")
		_expect(not button.disabled, "standalone route preview accepts real hover input")
	var party_button := view.get_node("MainBG/Containers/Party/Party_Container/Party_Slot") as TextureButton
	_expect(party_button.get_meta("pet_texture", null) is Texture2D, "standalone ThreeChoice Scene shows an authored party sprite preview")
	var exit_button := view.get_node("MainBG/Containers/ExitButton") as TextureButton
	var temple := view.get_node("MainBG/Temple") as TextureRect
	var top := view.get_node("MainBG/Containers/Top") as Control
	_expect(exit_button.z_index > temple.z_index and exit_button.z_index < top.z_index, "exit door renders above the temple and below the coin HUD")
	var bag_slots := view.get_node("MainBG/Containers/Middle/Middle_Bag/Slots") as GridContainer
	_expect(bag_slots.get_theme_constant("h_separation") == 31, "bag hover columns match the measured painted-frame spacing")
	_expect(bag_slots.get_theme_constant("v_separation") == 32, "bag hover rows match the measured painted-frame spacing")
	view.queue_free()
	await process_frame

	print("SMOKE_THREE_CHOICE_ROUTE_PORTRAIT_POOL_%s" % ["FAIL" if _failed else "OK"])
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_THREE_CHOICE_ROUTE_PORTRAIT_POOL_FAIL: %s" % message)
