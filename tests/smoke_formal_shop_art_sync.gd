extends SceneTree

const MockGameSessionScript := preload("res://session/mock_game_session.gd")
const SharedUiScene := preload("res://art/prefabs/route/route_shared_ui.tscn")

const SYNC_MANIFEST_PATH := "res://art/manifests/shop/formal_sync_manifest.json"
const PREVIEW_PATH := "res://data/formal_shop_art_preview.json"
const BATTLE_CAPTURE_PATH := "res://data/mock_battle_snapshot.json"
const PET_MAP_PATH := "res://art/manifests/shared/pets/sheets/pet_id_map.json"
const MERCHANT_MAP_PATH := "res://art/manifests/shop/merchant_map.json"

var _ok := true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _read_json(SYNC_MANIFEST_PATH)
	var pet_reference_count := Dictionary(manifest.get("pet_map_updates", {})).size()
	_expect(String(manifest.get("schema", "")) == "ysbzs.shop-art-workspace-sync.v1", "sync manifest schema is current")
	_expect(bool(manifest.get("display_only", false)), "formal data is marked display-only")
	_expect(pet_reference_count >= 10, "sync carries the complete multi-purchase pet image closure")
	_expect(Array(manifest.get("outbound_files", [])).size() == pet_reference_count + 1, "sync carries only the bounded pet closure plus one merchant image")
	_expect(Array(manifest.get("return_files", [])).size() == 15, "only fifteen allowlisted art-owned shop and shared PNGs may return")
	_expect(Array(manifest.get("forbidden_inbound_types", [])).has("gd"), "GDScript is explicitly forbidden inbound")
	_expect(Array(manifest.get("forbidden_inbound_types", [])).has("tscn"), "Scene files are explicitly forbidden inbound")

	var preview := _read_json(PREVIEW_PATH)
	_expect(String(preview.get("schema", "")) == "ysbzs.public-shop-art-capture.v1", "public shop capture schema is current")
	_expect(String(Dictionary(preview.get("source", {})).get("selected_option_id", "")) == "node_shop_basic", "capture selects the formal basic shop")
	_expect(Array(Dictionary(preview.get("shop_snapshot", {})).get("shop_offers", [])).size() == 3, "formal basic shop exposes three real offers")
	_expect(FileAccess.get_sha256(PREVIEW_PATH) == String(manifest.get("capture_sha256", "")), "preview hash matches sync manifest")
	var mapped_pet_ids := Dictionary(manifest.get("pet_map_updates", {})).keys()
	for snapshot_key in [
		"shop_snapshot",
		"refreshed_snapshot",
		"purchased_snapshot",
		"second_purchased_snapshot",
		"party_full_snapshot",
		"paid_refreshed_snapshot",
		"bag_purchased_snapshot",
	]:
		for value in Array(Dictionary(preview.get(snapshot_key, {})).get("roster", [])):
			var visible_roster_pet_id := String(Dictionary(value).get("pet_id", Dictionary(value).get("id", "")))
			_expect(mapped_pet_ids.has(visible_roster_pet_id), "%s visible roster pet %s is inside the synchronized image closure" % [snapshot_key, visible_roster_pet_id])
		for value in Array(Dictionary(preview.get(snapshot_key, {})).get("shop_offers", [])):
			var visible_pet_id := String(Dictionary(value).get("pet_id", ""))
			_expect(mapped_pet_ids.has(visible_pet_id), "%s visible pet %s is inside the synchronized image closure" % [snapshot_key, visible_pet_id])
	for value in Array(manifest.get("return_files", [])):
		var returned := Dictionary(value)
		_expect(String(returned.get("source", "")).get_extension() == "png", "art return source stays PNG-only")
		_expect(String(returned.get("target", "")).get_extension() == "png", "formal return target stays PNG-only")

	var battle_capture := _read_json(BATTLE_CAPTURE_PATH)
	var runtime_capture := Dictionary(battle_capture.get("shop_art_capture", {}))
	var projection_keys := Array(runtime_capture.get("runtime_projection_keys", []))
	_expect(not projection_keys.is_empty(), "runtime capture declares its bounded presentation fields")
	for snapshot_key in [
		"route_snapshot",
		"shop_snapshot",
		"refreshed_snapshot",
		"purchased_snapshot",
		"second_purchased_snapshot",
		"party_full_snapshot",
		"paid_refreshed_snapshot",
		"bag_purchased_snapshot",
		"exit_snapshot",
	]:
		var runtime_snapshot := Dictionary(runtime_capture.get(snapshot_key, {}))
		var public_snapshot := Dictionary(preview.get(snapshot_key, {}))
		_expect(runtime_snapshot.keys().all(func(key: Variant) -> bool: return projection_keys.has(key)), "%s contains presentation fields only" % snapshot_key)
		for key_value in runtime_snapshot.keys():
			var key := String(key_value)
			_expect(runtime_snapshot.get(key) == public_snapshot.get(key), "%s.%s matches the audited public Snapshot" % [snapshot_key, key])
	_expect(not Dictionary(runtime_capture.get("route_snapshot", {})).has("battle"), "runtime capture excludes battle authority data")
	_expect(not Dictionary(runtime_capture.get("route_snapshot", {})).has("run_plan"), "runtime capture excludes run-plan authority data")
	var replay_snapshots := Dictionary(runtime_capture.get("replay_snapshots", {}))
	_expect(replay_snapshots.size() == 8, "runtime capture carries all eight ordered formal shop snapshots")
	for operation_value in Array(runtime_capture.get("operations", [])):
		var snapshot_key := String(Dictionary(operation_value).get("snapshot_key", ""))
		_expect(replay_snapshots.has(snapshot_key), "each formal operation resolves to an exported replay Snapshot")
	_expect(not Array(battle_capture.get("steps", [])).is_empty(), "existing battle replay steps remain present")

	var pet_map := Dictionary(_read_json(PET_MAP_PATH).get("by_pet_id", {}))
	for pet_id_value in Dictionary(manifest.get("pet_map_updates", {})).keys():
		var pet_id := String(pet_id_value)
		var path := String(pet_map.get(pet_id, ""))
		_expect(path.begins_with("res://art/images/formal_sync/shop/pets/"), "%s uses the synchronized formal image" % pet_id)
		_expect(ResourceLoader.exists(path, "Texture2D"), "%s synchronized image imports as Texture2D" % pet_id)
	var merchant_map := _read_json(MERCHANT_MAP_PATH)
	var variants := Dictionary(merchant_map.get("variants", {}))
	var merchant_path := String(variants.get("node_shop_basic", ""))
	_expect(merchant_path.begins_with("res://art/images/formal_sync/shop/merchants/"), "basic shop uses synchronized formal merchant")
	_expect(ResourceLoader.exists(merchant_path, "Texture2D"), "synchronized merchant imports as Texture2D")

	var shared_ui := SharedUiScene.instantiate()
	root.add_child(shared_ui)
	var party_buttons := Array(shared_ui.call("party_buttons"))
	var wide_texture := ResourceLoader.load(String(pet_map.get("pal_002", "")), "Texture2D") as Texture2D
	var square_texture := ResourceLoader.load(String(pet_map.get("pal_009", "")), "Texture2D") as Texture2D
	shared_ui.call("set_party_texture", party_buttons[0], wide_texture)
	shared_ui.call("set_party_texture", party_buttons[1], square_texture)
	await process_frame
	var wide_portrait := (party_buttons[0] as TextureButton).get_node_or_null("PartyPortrait") as TextureRect
	var square_portrait := (party_buttons[1] as TextureButton).get_node_or_null("PartyPortrait") as TextureRect
	_expect(wide_portrait != null and wide_portrait.texture == wide_texture, "wide synchronized party art uses a direct texture child")
	_expect(square_portrait != null and square_portrait.texture == square_texture, "square synchronized party art uses a direct texture child")
	_expect(wide_portrait != null and wide_portrait.position == Vector2(5.0, 12.0) and wide_portrait.size == Vector2(154.0, 124.0), "wide party art preserves its authored aspect projection")
	_expect(square_portrait != null and square_portrait.position == Vector2(19.0, 11.0) and square_portrait.size == Vector2(126.0, 126.0), "square party art preserves its authored aspect projection")
	var wide_material := (party_buttons[0] as TextureButton).material as ShaderMaterial
	_expect(wide_material != null and not bool(wide_material.get_shader_parameter("source_enabled")), "party shader remains shadow-only after direct texture projection")

	var session := MockGameSessionScript.new({"start_phase": "route"})
	var route := Dictionary(session.current_snapshot())
	_expect(String(route.get("phase", "")) == "route", "Mock starts from synchronized formal route")
	var entry := Dictionary(session.submit_command({"type": "CHOOSE_ROUTE", "option_id": "node_shop_basic"}))
	_expect(bool(entry.get("accepted", false)), "Mock accepts synchronized formal shop entry")
	var shop := Dictionary(session.current_snapshot())
	_expect(String(shop.get("phase", "")) == "shop", "Mock reaches shop")
	_expect(Array(shop.get("shop_offers", [])).size() == 3, "Mock renders three formal offers and leaves two authored slots empty")
	_expect(String(Dictionary(shop.get("active_stall", {})).get("id", "")) == "merchant_aila", "Mock renders the formal active stall")

	var refresh := Dictionary(session.submit_command({"type": "ROLL_SHOP"}))
	_expect(bool(refresh.get("accepted", false)), "Mock accepts synchronized formal refresh")
	var refreshed := Dictionary(session.current_snapshot())
	_expect(_matches_public_projection(refreshed, Dictionary(preview.get("refreshed_snapshot", {})), projection_keys), "refresh replays the exact formal public presentation projection")
	var refreshed_offers := Array(refreshed.get("shop_offers", []))
	var purchase_id := String(Dictionary(refreshed_offers[0]).get("id", ""))
	var purchase := Dictionary(session.submit_command({"type": "BUY_OFFER", "offer_id": purchase_id}))
	_expect(bool(purchase.get("accepted", false)), "Mock accepts synchronized formal purchase")
	_expect(_matches_public_projection(Dictionary(session.current_snapshot()), Dictionary(preview.get("purchased_snapshot", {})), projection_keys), "purchase replays the exact formal public presentation projection")
	var second_id := String(Dictionary(refreshed_offers[1]).get("id", ""))
	var second_purchase := Dictionary(session.submit_command({"type": "BUY_OFFER", "offer_id": second_id}))
	_expect(bool(second_purchase.get("accepted", false)), "Mock accepts the second captured formal purchase")
	_expect(_matches_public_projection(Dictionary(session.current_snapshot()), Dictionary(preview.get("second_purchased_snapshot", {})), projection_keys), "second purchase replays the exact formal public projection")
	var third_id := String(Dictionary(refreshed_offers[2]).get("id", ""))
	var third_purchase := Dictionary(session.submit_command({"type": "BUY_OFFER", "offer_id": third_id}))
	_expect(bool(third_purchase.get("accepted", false)), "Mock accepts the third captured formal purchase")
	_expect(_matches_public_projection(Dictionary(session.current_snapshot()), Dictionary(preview.get("party_full_snapshot", {})), projection_keys), "third purchase replays the full-party formal projection")
	var paid_refresh := Dictionary(session.submit_command({"type": "ROLL_SHOP"}))
	_expect(bool(paid_refresh.get("accepted", false)), "Mock accepts the captured paid refresh")
	_expect(_matches_public_projection(Dictionary(session.current_snapshot()), Dictionary(preview.get("paid_refreshed_snapshot", {})), projection_keys), "paid refresh replays the exact formal projection")
	var paid_offers := Array(Dictionary(session.current_snapshot()).get("shop_offers", []))
	var bag_purchase_id := String(Dictionary(paid_offers[0]).get("id", ""))
	var bag_purchase := Dictionary(session.submit_command({"type": "BUY_OFFER", "offer_id": bag_purchase_id}))
	_expect(bool(bag_purchase.get("accepted", false)), "Mock accepts the captured fifth purchase")
	var bag_snapshot := Dictionary(session.current_snapshot())
	_expect(_matches_public_projection(bag_snapshot, Dictionary(preview.get("bag_purchased_snapshot", {})), projection_keys), "fifth purchase replays the exact non-empty-bag formal projection")
	_expect(Array(bag_snapshot.get("roster", [])).size() == 5, "captured replay contains five formal roster records")
	_expect(Array(bag_snapshot.get("roster", [])).filter(func(value: Variant) -> bool: return not bool(Dictionary(value).get("active", false))).size() == 1, "captured replay contains exactly one inactive bag pet")
	var bag_buttons := Array(shared_ui.call("bag_buttons"))
	var bag_texture := ResourceLoader.load(String(pet_map.get("pal_017", "")), "Texture2D") as Texture2D
	shared_ui.call("set_bag_texture", bag_buttons[0], bag_texture)
	var bag_portrait := (bag_buttons[0] as TextureButton).get_node_or_null("BagPortrait") as TextureRect
	_expect(bag_portrait != null and bag_portrait.texture == bag_texture, "synchronized bag art uses a direct texture child")
	_expect(bag_portrait != null and bag_portrait.position == Vector2(19.0, 15.0) and bag_portrait.size == Vector2(116.0, 116.0), "square bag art preserves aspect and centers in the first authored slot")
	shared_ui.call("set_drag_source_visible", bag_buttons[0], &"bag", false)
	_expect(not bag_portrait.visible and (bag_buttons[0] as TextureButton).get_meta("pet_texture") == bag_texture, "hiding a dragged bag portrait preserves its synchronized texture metadata")
	shared_ui.call("set_drag_source_visible", bag_buttons[0], &"bag", true)
	_expect(bag_portrait.visible and bag_portrait.texture == bag_texture, "restoring a dragged bag portrait reuses the preserved synchronized texture")
	var bag_material := (bag_buttons[0] as TextureButton).material as ShaderMaterial
	_expect(bag_material != null and not bool(bag_material.get_shader_parameter("source_enabled")), "bag shader no longer resamples the synchronized pet source")
	var exit := Dictionary(session.submit_command({"type": "EXIT_SHOP"}))
	_expect(bool(exit.get("accepted", false)), "Mock accepts synchronized formal exit")
	_expect(_matches_public_projection(Dictionary(session.current_snapshot()), Dictionary(preview.get("exit_snapshot", {})), projection_keys), "exit replays the exact formal public presentation projection")

	if _ok:
		print("SMOKE_FORMAL_SHOP_ART_SYNC_OK offers=3 empty_slots=2 visible_image_closure=true pets=%d merchant=1 non_empty_bag=true direct_party_texture=true code_inbound=0" % pet_reference_count)
		quit(0)
	else:
		quit(1)


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return Dictionary(parsed)
	_expect(false, "JSON parses: %s" % path)
	return {}


func _matches_public_projection(runtime_snapshot: Dictionary, public_snapshot: Dictionary, keys: Array) -> bool:
	for key_value in runtime_snapshot.keys():
		if not keys.has(key_value):
			return false
		if runtime_snapshot.get(key_value) != public_snapshot.get(key_value):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_ok = false
	push_error("SMOKE_FORMAL_SHOP_ART_SYNC_FAIL: %s" % message)
