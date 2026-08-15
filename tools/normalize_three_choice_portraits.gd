extends SceneTree

## Normalizes every route portrait into the same authored 365x500 card canvas.
## This deliberately edits the PNG assets rather than changing runtime Control
## geometry, so editor preview and the running scene share one static result.

const PORTRAIT_DIR := "res://art/images/route/three_choice_psd"
const CARD_SIZE := Vector2i(365, 500)
const TARGET_CONTENT_HEIGHT := 220
const MAX_CONTENT_WIDTH := 260
const TARGET_VISUAL_CENTER_X := 160
const TARGET_BASELINE_Y := 370

const PORTRAIT_FILES := [
	"route_portrait_shop.png",
	"route_portrait_shop_bai_xiaochang.png",
	"route_portrait_shop_variant_3.png",
	"route_portrait_shop_variant_5.png",
	"route_portrait_event.png",
	"route_portrait_event_herb_merchant.png",
	"route_portrait_event_fish_merchant.png",
	"route_portrait_event_ox_merchant.png",
	"route_portrait_reward.png",
	"route_portrait_reward_short_samurai.png",
	"route_portrait_reward_variant_4.png",
]

const CLEAN_SOURCE_OVERRIDES := {
	"route_portrait_shop.png": "res://outputs/three_choice_godot_psd_v1/exports/route_portrait_shop.png",
	"route_portrait_event.png": "res://outputs/three_choice_godot_psd_v1/exports/route_portrait_event.png",
	"route_portrait_reward.png": "res://outputs/three_choice_godot_psd_v1/exports/route_portrait_reward.png",
}


func _initialize() -> void:
	var failed := false
	for file_name in PORTRAIT_FILES:
		var output_path := "%s/%s" % [PORTRAIT_DIR, file_name]
		var source_path := String(CLEAN_SOURCE_OVERRIDES.get(file_name, output_path))
		if not FileAccess.file_exists(source_path):
			source_path = output_path
		var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		if source == null or source.is_empty():
			push_error("Unable to load route portrait source: %s" % source_path)
			failed = true
			continue
		source.convert(Image.FORMAT_RGBA8)
		var used_rect := source.get_used_rect()
		if used_rect.size.x <= 0 or used_rect.size.y <= 0:
			push_error("Route portrait has no visible content: %s" % source_path)
			failed = true
			continue

		var content := source.get_region(used_rect)
		var uniform_scale := minf(
			float(TARGET_CONTENT_HEIGHT) / float(used_rect.size.y),
			float(MAX_CONTENT_WIDTH) / float(used_rect.size.x)
		)
		var normalized_size := Vector2i(
			maxi(1, roundi(float(used_rect.size.x) * uniform_scale)),
			maxi(1, roundi(float(used_rect.size.y) * uniform_scale))
		)
		content.resize(normalized_size.x, normalized_size.y, Image.INTERPOLATE_NEAREST)

		var canvas := Image.create(CARD_SIZE.x, CARD_SIZE.y, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
		var destination := Vector2i(
			roundi(float(TARGET_VISUAL_CENTER_X) - float(normalized_size.x) * 0.5),
			TARGET_BASELINE_Y - normalized_size.y
		)
		canvas.blit_rect(content, Rect2i(Vector2i.ZERO, normalized_size), destination)
		var save_error := canvas.save_png(ProjectSettings.globalize_path(output_path))
		if save_error != OK:
			push_error("Unable to save normalized route portrait: %s" % output_path)
			failed = true
			continue
		print("NORMALIZED_ROUTE_PORTRAIT %s content=%dx%d baseline=%d" % [
			file_name,
			normalized_size.x,
			normalized_size.y,
			TARGET_BASELINE_Y,
		])

	print("NORMALIZE_THREE_CHOICE_PORTRAITS_%s" % ["FAIL" if failed else "OK"])
	quit(1 if failed else 0)
