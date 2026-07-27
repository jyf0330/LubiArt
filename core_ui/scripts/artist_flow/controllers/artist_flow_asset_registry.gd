extends RefCounted

const PetAssetResolverScript := preload("res://core_ui/scripts/shared/pet/pet_asset_resolver.gd")

const ROUTE_IMAGE_BY_KIND := {
	"shop": "res://art/images/debug/artist_ui/three_shang.png",
	"reward": "res://art/images/debug/artist_ui/three_qi.png",
	"battle": "res://art/images/debug/artist_ui/three_fight_logo.png",
}
const PET_IMAGE_MAP_PATH := "res://art/manifests/shared/pets/sheets/pet_id_map.json"
const PET_SHEET_SLICE_DIR := "res://art/images/shared/pets/sheets/slices"
const PET_EXPLICIT_IMAGE_DIR := "res://art/images/shared/pets/portraits"
const SHOP_CHARACTER_MAP_PATH := "res://art/manifests/route/shop/characters/shop_character_map.json"
const REWARD_NODE_MAP_PATH := "res://art/manifests/route/rewards/reward_node_map.json"

var _missing_images := {}
var _pet_asset_resolver: RefCounted = null
var _shop_character_by_id := {}
var _reward_node_by_id := {}


func reload() -> void:
	_pet_asset_resolver = PetAssetResolverScript.new()
	_pet_asset_resolver.call("configure", PET_SHEET_SLICE_DIR, PET_EXPLICIT_IMAGE_DIR)
	_pet_asset_resolver.call("load_map", PET_IMAGE_MAP_PATH)
	_shop_character_by_id = _load_string_map(SHOP_CHARACTER_MAP_PATH)
	_reward_node_by_id = _load_string_map(REWARD_NODE_MAP_PATH)


func clear_missing_report() -> void:
	_missing_images.clear()


func missing_image_report() -> Array:
	var values := _missing_images.values()
	values.sort_custom(func(a, b):
		var left := Dictionary(a)
		var right := Dictionary(b)
		return String(left.get("key", "")) < String(right.get("key", ""))
	)
	return values


func route_texture(option: Dictionary, kind: String) -> Texture2D:
	if kind == "shop":
		var shop_character := _shop_character_texture(option)
		if shop_character != null:
			return shop_character
	if kind == "reward":
		var reward_node := _reward_node_texture(option)
		if reward_node != null:
			return reward_node
	var path := String(ROUTE_IMAGE_BY_KIND.get(kind, "res://art/images/debug/artist_ui/three_qi_logo.png"))
	return load(path) as Texture2D


func pet_texture(record: Dictionary) -> Texture2D:
	if _pet_asset_resolver == null:
		return null
	return _pet_asset_resolver.call("texture_for", record) as Texture2D


func record_missing_image(context: String, record: Dictionary) -> void:
	var pet_id := String(record.get("pet_id", record.get("id", "")))
	var name := String(record.get("name", record.get("displayName", "")))
	var key := "%s:%s:%s" % [context, pet_id, name]
	_missing_images[key] = {
		"key": key,
		"context": context,
		"id": String(record.get("id", "")),
		"pet_id": pet_id,
		"name": name,
		"reason": "宠物整图已导入，但缺少明确的 pet_id/name 到切片图片的映射"
	}


func _reward_node_texture(record: Dictionary) -> Texture2D:
	var reward_id := _reward_node_id(record)
	if reward_id == "" or not _reward_node_by_id.has(reward_id):
		return null
	return _load_texture_if_exists(String(_reward_node_by_id[reward_id]))


func _reward_node_id(record: Dictionary) -> String:
	for key in [
		"nodeId",
		"node_id",
		"id",
		"optionId",
		"option_id",
		"name",
		"title",
		"reward_node_id",
		"rewardNodeId",
		"reward_pool_id",
		"rewardPoolId",
		"pool_id"
	]:
		var value := String(record.get(key, "")).strip_edges()
		if value != "" and _reward_node_by_id.has(value):
			return _normalize_reward_node_id(value)
	var source_node := Dictionary(record.get("sourceNode", {}))
	if not source_node.is_empty():
		return _reward_node_id(source_node)
	for key in ["reward_node_id", "rewardNodeId", "reward_pool_id", "rewardPoolId", "pool_id"]:
		var value := String(record.get(key, "")).strip_edges()
		if value != "":
			return _normalize_reward_node_id(value)
	return ""


func _normalize_reward_node_id(value: String) -> String:
	return "reward_node_%03d" % int(value) if value.is_valid_int() else value


func _shop_character_texture(record: Dictionary) -> Texture2D:
	var character_id := _shop_character_id(record)
	if character_id == "" or not _shop_character_by_id.has(character_id):
		return null
	return _load_texture_if_exists(String(_shop_character_by_id[character_id]))


func _shop_character_id(record: Dictionary) -> String:
	for key in [
		"nodeId",
		"node_id",
		"id",
		"optionId",
		"option_id",
		"name",
		"title",
		"shop_character_id",
		"shopCharacterId",
		"merchant_id",
		"merchantId",
		"portrait_id",
		"portraitId",
		"character_id",
		"characterId",
		"shop_store_id",
		"shopStoreId",
		"shopPoolId",
		"pool_id"
	]:
		var value := String(record.get(key, "")).strip_edges()
		if value != "" and _shop_character_by_id.has(value):
			return _normalize_shop_character_id(value)
	var source_node := Dictionary(record.get("sourceNode", {}))
	if not source_node.is_empty():
		return _shop_character_id(source_node)
	for key in [
		"shop_character_id",
		"shopCharacterId",
		"merchant_id",
		"merchantId",
		"portrait_id",
		"portraitId",
		"character_id",
		"characterId",
		"shop_store_id",
		"shopStoreId",
		"shopPoolId",
		"pool_id"
	]:
		var value := String(record.get(key, "")).strip_edges()
		if value != "":
			return _normalize_shop_character_id(value)
	return ""


func _normalize_shop_character_id(value: String) -> String:
	return "shop_character_%03d" % int(value) if value.is_valid_int() else value


func _load_string_map(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for key in Dictionary(parsed).keys():
		var texture_path := String(Dictionary(parsed)[key]).strip_edges()
		if texture_path != "":
			out[String(key)] = texture_path
	return out


func _load_texture_if_exists(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
