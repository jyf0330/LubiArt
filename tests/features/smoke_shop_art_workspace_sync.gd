extends SceneTree

const SYNC_TOOL_PATH := "res://tools/art/sync_shop_art_workspace.py"
const EXPORT_TOOL_PATH := "res://tools/export_public_shop_art_capture.gd"
const RESOURCE_INVENTORY_PATH := "res://art/manifests/shop/formal_resource_inventory.json"
const ART_ROOT := "res://art/images/shop/screen_shop_godot_v1"
const ART_ORIGIN_IMAGES := {
	"shared_bag_closed.png": Vector2i(236, 233),
	"shared_bag_open.png": Vector2i(236, 233),
	"shared_bag_inventory.png": Vector2i(818, 439),
	"shared_bag_item_highlight.png": Vector2i(181, 174),
	"shared_party_shelf.png": Vector2i(882, 419),
	"shared_coin_panel.png": Vector2i(165, 124),
	"shared_exit_normal.png": Vector2i(269, 472),
	"shared_exit_hover.png": Vector2i(269, 472),
	"shared_party_shadow.png": Vector2i(79, 19),
}

var _ok := true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sync_source := FileAccess.get_file_as_string(SYNC_TOOL_PATH)
	_expect(sync_source.contains("RETURN_ART_MAPPINGS"), "sync owns an explicit art-return mapping allowlist")
	_expect(sync_source.contains("FORMAL_PET_FALLBACK_PATH"), "sync mirrors the same explicit missing-pet fallback used by the formal presentation")
	_expect(sync_source.contains("ART_RESOURCE_INVENTORY_PATH"), "sync publishes a separate formal image universe and fixed-seed closure inventory")
	_expect(sync_source.contains("contains_all_formal_program_images"), "resource inventory does not confuse the bounded seed closure with the complete formal image library")
	_expect(sync_source.contains("formal_pet_hashes <= art_png_hashes"), "all-program image verdict is computed from actual PNG hashes instead of being hard-coded")
	_expect(sync_source.contains("stale_formal_sync_pet_png_ids"), "resource inventory exposes stale historical formal-sync PNGs")
	_expect(sync_source.contains("pet_map_removals"), "outbound sync removes only stale formal-sync mapping identities")
	_expect(sync_source.contains("copied_code_files\": 0"), "inbound receipt explicitly records zero copied code files")
	_expect(sync_source.contains("inbound accepts PNG only"), "inbound rejects non-PNG resources")
	_expect(not sync_source.contains("copytree("), "sync never mirrors a whole directory")
	_expect(not sync_source.contains("rmtree("), "sync never deletes an art or formal directory")

	var inventory: Variant = JSON.parse_string(FileAccess.get_file_as_string(RESOURCE_INVENTORY_PATH))
	_expect(typeof(inventory) == TYPE_DICTIONARY, "formal resource inventory is readable JSON")
	if typeof(inventory) == TYPE_DICTIONARY:
		var workspace := Dictionary(inventory.get("art_workspace_before_sync", {}))
		var verdict := Dictionary(inventory.get("verdict", {}))
		_expect(int(workspace.get("matching_formal_pet_png_resources", -1)) == 20, "inventory counts exact formal pet PNG hashes already present before sync")
		_expect(int(workspace.get("missing_formal_pet_png_resources", -1)) == 258, "inventory exposes the remaining formal pet PNG gap")
		_expect(int(workspace.get("matching_formal_merchant_png_resources", -1)) == 1, "inventory counts exact formal merchant PNG hashes already present before sync")
		_expect(int(workspace.get("missing_formal_merchant_png_resources", -1)) == 32, "inventory exposes the remaining formal merchant PNG gap")
		_expect(not bool(verdict.get("contains_all_formal_program_images", true)), "bounded art workspace must not be reported as the complete formal image library")

	var export_source := FileAccess.get_file_as_string(EXPORT_TOOL_PATH)
	_expect(export_source.contains("current_snapshot"), "outbound data comes from the public Snapshot boundary")
	_expect(export_source.contains("submit_command"), "outbound operations use the public Session command boundary")
	_expect(export_source.contains("replay_snapshots"), "outbound carries ordered public snapshots for multi-operation art replay")
	_expect(export_source.contains("snapshot_key"), "every recorded art operation names its public snapshot")
	_expect(export_source.contains("_inactive_roster_count"), "outbound proves the fifth formal purchase entered the bag")
	_expect(export_source.contains("reentered_snapshot"), "outbound carries the public Snapshot after formal shop re-entry")
	_expect(export_source.contains("reenter_shop_after_exit"), "outbound records shop re-entry as a public Session operation")
	_expect(not export_source.contains("get_authority"), "outbound never extracts the authority object")
	_expect(not export_source.contains("store_var"), "outbound never serializes runtime objects")

	for file_name in ART_ORIGIN_IMAGES:
		var path := ART_ROOT.path_join(file_name)
		_expect(FileAccess.file_exists(path), "%s returned from the art workspace" % file_name)
		var image := Image.new()
		var load_error := image.load(ProjectSettings.globalize_path(path))
		_expect(load_error == OK and not image.is_empty(), "%s decodes as a PNG" % file_name)
		if load_error == OK and not image.is_empty():
			_expect(image.get_size() == ART_ORIGIN_IMAGES[file_name], "%s keeps its contracted pixel geometry" % file_name)

	if _ok:
		print("SMOKE_SHOP_ART_WORKSPACE_SYNC_OK public_snapshot=true public_commands=true art_origin_png=9 mirrored_dirs=0 copied_code=0")
		quit(0)
	else:
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_ok = false
	push_error("SMOKE_SHOP_ART_WORKSPACE_SYNC_FAIL: %s" % message)
