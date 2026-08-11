extends TextureRect

const SOURCE_TEXTURE_SIZE := Vector2(1672.0, 941.0)
const SOURCE_VISIBLE_REGION := Rect2(18.0, 276.0, 1636.0, 460.0)
const ROUND_FONT := preload("res://art/images/shared/pets/info_card/fonts/fusion_pixel_zh_hans.ttf")

@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $Subtitle


func show_round(round_number: int, side: String, texture_resource: Texture2D, duration: float = 1.4) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture_resource != null:
		texture = _visible_texture(texture_resource)
	title_label.add_theme_font_override("font", ROUND_FONT)
	subtitle_label.add_theme_font_override("font", ROUND_FONT)
	title_label.text = "第%d回合" % round_number
	subtitle_label.text = "我方回合" if side == "player" else "敌方回合"
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2.ONE * 0.96
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(maxf(duration - 0.4, 0.1)).timeout
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(self, "modulate:a", 0.0, 0.22)
	fade.tween_property(self, "scale", Vector2.ONE * 1.02, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.finished.connect(queue_free)


func _visible_texture(source: Texture2D) -> Texture2D:
	if source.get_size() != SOURCE_TEXTURE_SIZE:
		return source
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = SOURCE_VISIBLE_REGION
	return cropped
