extends TextureButton

## Attack-order card. The root owns input while Background, Pet and Frame keep
## their independently editable authored geometry.

const VISUAL_METRICS_PATH := "res://art/manifests/shared/pets/sheets/pet_battle_visual_metrics.json"

const PET_TEXTURES := {
	"pal_002": preload("res://art/images/shared/pets/sheets/slices/pet_style_001_gold_mascot.png"),
	"pal_011": preload("res://art/images/shared/pets/sheets/slices/pet_style_002_gold_shell.png"),
	"pal_030": preload("res://art/images/shared/pets/sheets/slices/pet_style_999_crystal_shell.png"),
	"pal_028": preload("res://art/images/shared/pets/sheets/slices/pet_style_003_blue_electric_shell.png"),
}

const ELEMENT_BACKGROUNDS := {
	"无": preload("res://art/images/battle/hud/attack_timeline/pet_frame/backgrounds/creature_card_background_nature_inset_v2.png"),
	"火": preload("res://art/images/battle/hud/attack_timeline/pet_frame/backgrounds/creature_card_background_fire_inset_v2.png"),
	"水": preload("res://art/images/battle/hud/attack_timeline/pet_frame/backgrounds/creature_card_background_water_inset_v2.png"),
	"草": preload("res://art/images/battle/hud/attack_timeline/pet_frame/backgrounds/creature_card_background_nature_inset_v2.png"),
	"雷": preload("res://art/images/battle/hud/attack_timeline/pet_frame/backgrounds/creature_card_background_light_inset_v2.png"),
	"冰": preload("res://art/images/battle/hud/attack_timeline/pet_frame/backgrounds/creature_card_background_ice_inset_v2.png"),
	"地": preload("res://art/images/battle/hud/attack_timeline/pet_frame/backgrounds/creature_card_background_earth_inset_v2.png"),
	"暗": preload("res://art/images/battle/hud/attack_timeline/pet_frame/backgrounds/creature_card_background_shadow_inset_v2.png"),
	"龙": preload("res://art/images/battle/hud/attack_timeline/pet_frame/backgrounds/creature_card_background_wind_inset_v2.png"),
}

const QUALITY_FRAMES := {
	"青铜": preload("res://art/images/battle/hud/attack_timeline/pet_frame/top_frames/creature_card_top_frame_bronze_001.png"),
	"bronze": preload("res://art/images/battle/hud/attack_timeline/pet_frame/top_frames/creature_card_top_frame_bronze_001.png"),
	"白银": preload("res://art/images/battle/hud/attack_timeline/pet_frame/top_frames/creature_card_top_frame_silver_001.png"),
	"silver": preload("res://art/images/battle/hud/attack_timeline/pet_frame/top_frames/creature_card_top_frame_silver_001.png"),
	"黄金": preload("res://art/images/battle/hud/attack_timeline/pet_frame/top_frames/creature_card_top_frame_gold_001.png"),
	"gold": preload("res://art/images/battle/hud/attack_timeline/pet_frame/top_frames/creature_card_top_frame_gold_001.png"),
	"钻石": preload("res://art/images/battle/hud/attack_timeline/pet_frame/top_frames/creature_card_top_frame_diamond_001.png"),
	"diamond": preload("res://art/images/battle/hud/attack_timeline/pet_frame/top_frames/creature_card_top_frame_diamond_001.png"),
}

@onready var background: TextureRect = $Background
@onready var pet: TextureRect = $Pet
@onready var frame: TextureRect = $Frame

static var _visual_metrics: Dictionary = {}


func _ready() -> void:
	pivot_offset = size * 0.5


func configure(record: Dictionary) -> void:
	var element := String(record.get("element", "无"))
	var quality := String(record.get("quality", "青铜"))
	var pet_id := String(record.get("pet_id", record.get("source_pet_id", record.get("id", ""))))
	var pet_texture := PET_TEXTURES.get(pet_id) as Texture2D
	background.texture = ELEMENT_BACKGROUNDS.get(element, ELEMENT_BACKGROUNDS["无"]) as Texture2D
	frame.texture = QUALITY_FRAMES.get(quality, QUALITY_FRAMES["青铜"]) as Texture2D
	pet.texture = _normalized_pet_texture(pet_texture)
	pet.visible = pet.texture != null
	tooltip_text = String(record.get("name", "精灵"))
	set_meta("unit_id", String(record.get("id", pet_id)))
	set_meta("pet_id", pet_id)


func set_drag_visual(active: bool) -> void:
	z_index = 20 if active else 0
	modulate = Color("fff5c9") if active else Color.WHITE
	scale = Vector2(1.06, 1.06) if active else Vector2.ONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _normalized_pet_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var path := source.resource_path
	var metric := Dictionary(_metrics().get(path, {}))
	var used_rect := Array(metric.get("used_rect", []))
	if used_rect.size() != 4:
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(
		float(used_rect[0]),
		float(used_rect[1]),
		float(used_rect[2]),
		float(used_rect[3])
	)
	return atlas


static func _metrics() -> Dictionary:
	if not _visual_metrics.is_empty():
		return _visual_metrics
	if not FileAccess.file_exists(VISUAL_METRICS_PATH):
		return _visual_metrics
	var file := FileAccess.open(VISUAL_METRICS_PATH, FileAccess.READ)
	if file == null:
		return _visual_metrics
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_visual_metrics = Dictionary(Dictionary(parsed).get("by_texture_path", {}))
	return _visual_metrics
