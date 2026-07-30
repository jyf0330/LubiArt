extends RefCounted
class_name MockAssetProvider

const PLAYER_FRAME := preload("res://art/images/battle/runtime/prefabs/select_frames/selection-blue-64.png")
const ENEMY_FRAME := preload("res://art/images/battle/runtime/prefabs/select_frames/selection-red-64.png")
const PET_TEXTURES := {
	"pal_001": preload("res://art/images/shared/pets/sheets/slices/pet_style_005_earth_slime.png"),
	"pal_002": preload("res://art/images/shared/pets/sheets/slices/pet_style_001_gold_mascot.png"),
	"pal_003": preload("res://art/images/shared/pets/sheets/slices/pet_style_007_rock_claw.png"),
	"pal_006": preload("res://art/images/shared/pets/sheets/slices/pet_style_006_shadow_rock_wolf.png"),
	"pal_011": preload("res://art/images/shared/pets/sheets/slices/pet_style_002_gold_shell.png"),
	"pal_028": preload("res://art/images/shared/pets/sheets/slices/pet_style_003_blue_electric_shell.png"),
	"pal_030": preload("res://art/images/shared/pets/sheets/slices/pet_style_004_pink_electric_wave.png"),
	"pal_042": preload("res://art/images/shared/pets/sheets/slices/pet_style_008_volcanic_dijiang.png"),
	"enemy_001": preload("res://art/images/shared/pets/sheets/slices/pet_style_005_earth_slime.png"),
	"enemy_002": preload("res://art/images/shared/pets/sheets/slices/pet_style_008_volcanic_dijiang.png"),
	"enemy_003": preload("res://art/images/shared/pets/sheets/slices/pet_style_006_shadow_rock_wolf.png"),
	"enemy_004": preload("res://art/images/shared/pets/sheets/slices/pet_style_007_rock_claw.png"),
}


func frame_texture(side: String) -> Texture2D:
	return PLAYER_FRAME if side in ["player", "hero_leader"] else ENEMY_FRAME


func texture_for_unit(data: Dictionary, _side: String) -> Dictionary:
	var pet_id := String(data.get(
		"pet_id",
		data.get("petId", data.get("source_pet_id", data.get("sourcePetId", "")))
	))
	return {
		"texture": PET_TEXTURES.get(pet_id, null),
		"missing": {} if PET_TEXTURES.has(pet_id) else {"pet_id": pet_id},
	}


func texture_for_pet_id(pet_id: String) -> Texture2D:
	return PET_TEXTURES.get(pet_id, null) as Texture2D
