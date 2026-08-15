extends RefCounted

const PetAssetResolverScript := preload("res://core_ui/scripts/shared/pet/pet_asset_resolver.gd")

const ROUTE_IMAGE_BY_KIND := {
	"shop": "res://art/images/route/three_choice_psd/route_portrait_shop.png",
	"event": "res://art/images/route/three_choice_psd/route_portrait_event.png",
	"reward": "res://art/images/route/three_choice_psd/route_portrait_reward.png",
	"battle": "res://art/images/route/three_choice_psd/route_portrait_event.png",
	"rest": "res://art/images/route/three_choice_psd/route_portrait_event.png",
}
const ROUTE_ICON_BY_KIND := {
	"shop": "res://art/images/route/three_choice_psd/route_icon_shop.png",
	"event": "res://art/images/route/three_choice_psd/route_icon_event.png",
	"reward": "res://art/images/route/three_choice_psd/route_icon_reward.png",
	"battle": "res://art/images/route/three_choice_psd/route_icon_event.png",
	"rest": "res://art/images/route/three_choice_psd/route_icon_event.png",
}
const ROUTE_SLOT_IMAGE_POOLS := [
	[
		"res://art/images/route/three_choice_psd/route_portrait_shop.png",
		"res://art/images/route/three_choice_psd/route_portrait_shop_bai_xiaochang.png",
		"res://art/images/route/three_choice_psd/route_portrait_shop_variant_3.png",
		"res://art/images/route/three_choice_psd/route_portrait_shop_variant_5.png",
	],
	[
		"res://art/images/route/three_choice_psd/route_portrait_event.png",
		"res://art/images/route/three_choice_psd/route_portrait_event_herb_merchant.png",
		"res://art/images/route/three_choice_psd/route_portrait_event_fish_merchant.png",
		"res://art/images/route/three_choice_psd/route_portrait_event_ox_merchant.png",
	],
	[
		"res://art/images/route/three_choice_psd/route_portrait_reward.png",
		"res://art/images/route/three_choice_psd/route_portrait_reward_short_samurai.png",
		"res://art/images/route/three_choice_psd/route_portrait_reward_variant_4.png",
	],
]
const ROUTE_SLOT_ICON_PATHS := [
	"res://art/images/route/three_choice_psd/route_icon_shop.png",
	"res://art/images/route/three_choice_psd/route_icon_event.png",
	"res://art/images/route/three_choice_psd/route_icon_reward.png",
]
const ROUTE_SLOT_HIGHLIGHT_PATHS := [
	"res://art/images/route/three_choice_psd/route_highlight_shop.png",
	"res://art/images/route/three_choice_psd/route_highlight_event.png",
	"res://art/images/route/three_choice_psd/route_highlight_reward.png",
]
const PET_IMAGE_MAP_PATH := "res://art/manifests/shared/pets/sheets/pet_id_map.json"
const PET_SHEET_SLICE_DIR := "res://art/images/shared/pets/sheets/slices"
const PET_EXPLICIT_IMAGE_DIR := "res://art/images/shared/pets/sheets/slices"
const PET_FALLBACK_IMAGE_PATH := "res://art/images/shared/pets/sheets/slices/pet_style_008_volcanic_dijiang.png"
const SHOP_CHARACTER_MAP_PATH := "res://art/manifests/route/shop/characters/shop_character_map.json"
const REWARD_NODE_MAP_PATH := "res://art/manifests/route/rewards/reward_node_map.json"

var _missing_images := {}
var _pet_asset_resolver: RefCounted = null
var _shop_character_by_id := {}
var _reward_node_by_id := {}
var _route_portrait_path_by_key := {}
var _route_rng := RandomNumberGenerator.new()


func reload() -> void:
	_route_rng.randomize()
	_route_portrait_path_by_key.clear()
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
	var path := String(ROUTE_IMAGE_BY_KIND.get(kind, ROUTE_IMAGE_BY_KIND["event"]))
	return load(path) as Texture2D


func route_slot_texture(index: int, option: Dictionary = {}) -> Texture2D:
	var safe_index := clampi(index, 0, ROUTE_SLOT_IMAGE_POOLS.size() - 1)
	var pool := Array(ROUTE_SLOT_IMAGE_POOLS[safe_index])
	if pool.is_empty():
		return null
	var cache_key := "%d:%s" % [safe_index, _route_option_identity(option)]
	if not _route_portrait_path_by_key.has(cache_key):
		_route_portrait_path_by_key[cache_key] = String(pool[_route_rng.randi_range(0, pool.size() - 1)])
	return load(String(_route_portrait_path_by_key[cache_key])) as Texture2D


func _route_option_identity(option: Dictionary) -> String:
	for key in ["route_id", "routeId", "node_id", "nodeId", "option_id", "optionId", "id", "kind", "type"]:
		var value := String(option.get(key, "")).strip_edges()
		if value != "":
			return value
	return "default"


func route_icon_texture(kind: String) -> Texture2D:
	var path := String(ROUTE_ICON_BY_KIND.get(kind, ROUTE_ICON_BY_KIND["event"]))
	return load(path) as Texture2D


func route_slot_icon_texture(index: int) -> Texture2D:
	var safe_index := clampi(index, 0, ROUTE_SLOT_ICON_PATHS.size() - 1)
	return load(String(ROUTE_SLOT_ICON_PATHS[safe_index])) as Texture2D


func route_slot_highlight_texture(index: int) -> Texture2D:
	var safe_index := clampi(index, 0, ROUTE_SLOT_HIGHLIGHT_PATHS.size() - 1)
	return load(String(ROUTE_SLOT_HIGHLIGHT_PATHS[safe_index])) as Texture2D


func pet_texture(record: Dictionary) -> Texture2D:
	if _pet_asset_resolver == null:
		return null
	return _pet_asset_resolver.call("texture_for", record) as Texture2D


func fallback_pet_texture() -> Texture2D:
	return _load_texture_if_exists(PET_FALLBACK_IMAGE_PATH)


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
