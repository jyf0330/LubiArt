extends Control
class_name ShopArtBackdrop

## Reusable, presentation-only composition for the formal shop screen.
## It knows about art layers, never about offers, coins, sessions, or commands.

signal refresh_reveal_finished

const BACKGROUND_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/background.png")
const FACADE_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/shop_facade.png")
const REFRESH_CURTAIN_TEXTURE := preload("res://art/images/shop/screen_shop_godot_v1/refresh_curtain.png")
const REFERENCE_SIZE := Vector2(1920.0, 1080.0)

var _refresh_curtain: TextureRect = null
var _refresh_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layers()


func _build_layers() -> void:
	var background := TextureRect.new()
	background.name = "ForestBackground"
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var facade := TextureRect.new()
	facade.name = "ShopFacade"
	facade.texture = FACADE_TEXTURE
	facade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	facade.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	facade.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	facade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_reference_rect(facade, Rect2(31.0, 86.0, 1766.0, 988.0))
	add_child(facade)

	var readability_veil := ColorRect.new()
	readability_veil.name = "ReadabilityVeil"
	readability_veil.color = Color(0.018, 0.025, 0.027, 0.0)
	readability_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readability_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(readability_veil)

	var top_band := ColorRect.new()
	top_band.name = "TopReadabilityBand"
	top_band.color = Color(0.025, 0.035, 0.034, 0.0)
	top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_band.anchor_right = 1.0
	top_band.offset_bottom = 110.0
	add_child(top_band)

	_refresh_curtain = TextureRect.new()
	_refresh_curtain.name = "RefreshCurtain"
	_refresh_curtain.texture = REFRESH_CURTAIN_TEXTURE
	_refresh_curtain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_refresh_curtain.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_refresh_curtain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refresh_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_curtain.z_index = 30
	_apply_reference_rect(_refresh_curtain, Rect2(492.0, 313.0, 836.0, 502.0))
	_refresh_curtain.pivot_offset = Vector2(418.0, 251.0)
	_refresh_curtain.visible = false
	add_child(_refresh_curtain)


func play_refresh_reveal() -> void:
	if _refresh_curtain == null:
		return
	if _refresh_tween != null and _refresh_tween.is_valid():
		_refresh_tween.kill()
	_refresh_curtain.visible = true
	_refresh_curtain.scale = Vector2.ONE
	_refresh_curtain.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_refresh_tween = create_tween()
	_refresh_tween.set_trans(Tween.TRANS_QUAD)
	_refresh_tween.set_ease(Tween.EASE_OUT)
	_refresh_tween.tween_property(_refresh_curtain, "modulate:a", 1.0, 0.10)
	_refresh_tween.tween_interval(0.12)
	_refresh_tween.set_ease(Tween.EASE_IN)
	_refresh_tween.tween_property(_refresh_curtain, "modulate:a", 0.0, 0.10)
	_refresh_tween.tween_callback(_hide_refresh_curtain)


func _hide_refresh_curtain() -> void:
	if _refresh_curtain != null:
		_refresh_curtain.visible = false
	refresh_reveal_finished.emit()


func _apply_reference_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x / REFERENCE_SIZE.x
	control.anchor_top = rect.position.y / REFERENCE_SIZE.y
	control.anchor_right = rect.end.x / REFERENCE_SIZE.x
	control.anchor_bottom = rect.end.y / REFERENCE_SIZE.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
