extends Resource
class_name SpriteInfoData

@export var sprite_id := ""
@export var display_name := ""
@export var sprite_texture: Texture2D
@export var portrait_texture: Texture2D
@export var element_name := "风属性"
@export var element_icon: Texture2D
@export var element_color := Color(0.16, 0.65, 0.48, 1.0)
@export_range(1, 21, 1) var attack_cell_count := 21
@export_range(0, 20, 1) var origin_cell_index := 10
@export var hit_cell_indices: Array[int] = [9, 11, 17]
@export_range(0, 20, 1) var current_rank_index := 0
@export var ranks: Array[SpriteRankStats] = []


func get_current_rank() -> SpriteRankStats:
	if ranks.is_empty():
		var default_rank := SpriteRankStats.new()
		default_rank.quality_name = "青铜"
		return default_rank

	return ranks[clamp(current_rank_index, 0, ranks.size() - 1)]


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name

	if not sprite_id.is_empty():
		return sprite_id

	if sprite_texture != null:
		var base_name := sprite_texture.resource_path.get_file().get_basename().replace("Sprite_", "")
		return base_name

	return "未命名精灵"
