extends RefCounted
class_name MockAssetProvider

const PLAYER_FRAME := preload("res://art/images/battle/runtime/prefabs/select_frames/selection-blue-64.png")
const ENEMY_FRAME := preload("res://art/images/battle/runtime/prefabs/select_frames/selection-red-64.png")
const PET_TEXTURES := {
	"pal_001": preload("res://art/images/shared/pets/sheets/slices/shop_creature_001_water_tidewhisker.png"),
	"pal_013": preload("res://art/images/shared/pets/sheets/slices/shop_creature_013_water_tidedrake.png"),
	"pal_028": preload("res://art/images/shared/pets/sheets/slices/shop_creature_028_earth_thornstone.png"),
	"pal_029": preload("res://art/images/shared/pets/sheets/slices/shop_creature_029_earth_mossshell.png"),
	"enemy_001": preload("res://art/images/shared/pets/sheets/slices/shop_creature_001_water_tidewhisker.png"),
	"enemy_002": preload("res://art/images/shared/pets/sheets/slices/shop_creature_042_wind_twister.png"),
	"enemy_003": preload("res://art/images/shared/pets/sheets/slices/shop_creature_006_water_pondhopper.png"),
	"enemy_004": preload("res://art/images/shared/pets/sheets/slices/shop_creature_003_water_frostwaddle.png"),
}


func frame_texture(side: String) -> Texture2D:
	return PLAYER_FRAME if side in ["player", "hero_leader"] else ENEMY_FRAME


func texture_for_unit(data: Dictionary, _side: String) -> Dictionary:
	var pet_id := String(data.get("pet_id", data.get("petId", "")))
	return {
		"texture": PET_TEXTURES.get(pet_id, null),
		"missing": {} if PET_TEXTURES.has(pet_id) else {"pet_id": pet_id},
	}


func texture_for_pet_id(pet_id: String) -> Texture2D:
	return PET_TEXTURES.get(pet_id, null) as Texture2D
