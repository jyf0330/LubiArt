extends RefCounted
class_name MockAssetProvider

const FRAME := preload("res://assets/artist_ui/images/party_slot_frame.png")
const PET_TEXTURES := {
	"pal_001": preload("res://assets/artist_ui/pet_sheet/slices/pet_sheet_001.png"),
	"pal_013": preload("res://assets/artist_ui/pet_sheet/slices/pet_sheet_013.png"),
	"pal_028": preload("res://assets/artist_ui/pet_sheet/slices/pet_sheet_028.png"),
	"pal_029": preload("res://assets/artist_ui/pet_sheet/slices/pet_sheet_029.png"),
	"enemy_001": preload("res://assets/artist_ui/pet_sheet/slices/pet_sheet_002.png"),
	"enemy_002": preload("res://assets/artist_ui/pet_sheet/slices/pet_sheet_003.png"),
	"enemy_003": preload("res://assets/artist_ui/pet_sheet/slices/pet_sheet_004.png"),
	"enemy_004": preload("res://assets/artist_ui/pet_sheet/slices/pet_sheet_014.png"),
}


func frame_texture(_side: String) -> Texture2D:
	return FRAME


func texture_for_unit(data: Dictionary, _side: String) -> Dictionary:
	var pet_id := String(data.get("pet_id", data.get("petId", "")))
	return {
		"texture": PET_TEXTURES.get(pet_id, null),
		"missing": {} if PET_TEXTURES.has(pet_id) else {"pet_id": pet_id},
	}


func texture_for_pet_id(pet_id: String) -> Texture2D:
	return PET_TEXTURES.get(pet_id, null) as Texture2D
