extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const OUTPUT_PATH := "res://output/damage_preview_embedded_1920x1080.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	battle.call("render_snapshot", _snapshot())
	for _frame in range(4):
		await process_frame

	var ally := _unit_by_id(battle, "preview_ally")
	var enemy := _unit_by_id(battle, "preview_enemy")
	var lethal_enemy := _unit_by_id(battle, "preview_lethal_enemy")
	if ally == null or enemy == null or lethal_enemy == null:
		_fail("preview units are unavailable")
		return
	ally.call("start_damage_preview", 20, 12, -1, 8, 0, 0, 20)
	enemy.call("start_damage_preview", 20, 12, -1, 8, 0, 0, 20)
	lethal_enemy.call("start_damage_preview", 10, 0, -1, 10, 0, 0, 20)
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	var viewport_image := root.get_texture().get_image()

	if not _verify_preview(ally, false, true):
		_fail("ally embedded damage preview is invalid")
		return
	if not _verify_preview(enemy, false, false):
		_fail("enemy embedded damage preview is invalid")
		return
	if not _verify_preview(lethal_enemy, true, false):
		_fail("lethal enemy embedded damage preview is invalid")
		return
	if not _verify_fill_pixel_alignment(viewport_image, ally):
		_fail("ally green and red fill pixels are not vertically aligned")
		return
	if not _verify_fill_pixel_alignment(viewport_image, enemy):
		_fail("enemy orange and red fill pixels are not vertically aligned")
		return
	var error := viewport_image.save_png(
		ProjectSettings.globalize_path(OUTPUT_PATH)
	)
	if error != OK:
		_fail("could not save embedded damage preview capture")
		return
	print("VISIBLE_EMBEDDED_DAMAGE_PREVIEW_PASS capture=%s" % OUTPUT_PATH)
	quit(0)


func _verify_preview(unit: Control, lethal: bool, ally: bool) -> bool:
	var preview := Dictionary(unit.call("get_damage_preview_snapshot"))
	var stats := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats") as Control
	var health := stats.get_node("Health") as ProgressBar
	var overlay := health.get_node("IncomingDamagePreview") as Control
	var separator := overlay.get_node("Background") as ColorRect
	var red_fill := overlay.get_node("Value") as Label
	var base_fill := health.get_theme_stylebox("fill") as StyleBoxFlat
	if not stats.visible or not health.visible or not overlay.visible:
		return false
	if not bool(preview.get("embedded_in_health_bar", false)) \
			or bool(preview.get("lethal", false)) != lethal:
		return false
	if separator.size.x * overlay.scale.x < 1.9:
		return false
	if overlay.get_parent() != health:
		return false
	if not is_zero_approx(overlay.position.y):
		return false
	if not is_equal_approx(overlay.size.y, health.size.y):
		return false
	if overlay.scale != Vector2.ONE:
		return false
	if not overlay.clip_contents:
		return false
	if red_fill.text != "" or red_fill.size.x <= 0.0:
		return false
	if lethal != bool(preview.get("lethal_flash_active", false)):
		return false
	if lethal and red_fill.modulate.a >= 0.95:
		return false
	if not lethal and not is_equal_approx(red_fill.modulate.a, 1.0):
		return false
	if base_fill == null:
		return false
	var current_hp := int(preview.get("current_hp", 0))
	var max_hp := maxi(1, int(preview.get("max_hp", current_hp)))
	var current_fill_right := health.size.x \
		* clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	var preview_right := overlay.position.x + overlay.size.x * overlay.scale.x
	if not is_equal_approx(preview_right, current_fill_right):
		return false
	var full_bar_right := health.size.x
	if current_hp < max_hp and preview_right >= full_bar_right - 0.01:
		return false
	if ally:
		return base_fill.bg_color.g > base_fill.bg_color.r
	return base_fill.bg_color.r > base_fill.bg_color.g and base_fill.bg_color.g > 0.45


func _verify_fill_pixel_alignment(image: Image, unit: Control) -> bool:
	var health := unit.get_node("CompleteBattleCreaturePrefab/01_UnitVisual/Stats/Health") as ProgressBar
	var overlay := health.get_node("IncomingDamagePreview") as Control
	var red_fill := overlay.get_node("Value") as Label
	var separator := overlay.get_node("Background") as ColorRect
	var base_style := health.get_theme_stylebox("fill") as StyleBoxFlat
	var red_style := red_fill.get_theme_stylebox("normal") as StyleBoxFlat
	if base_style == null or red_style == null:
		return false
	var scan_rect := health.get_global_rect().grow(2.0)
	var base_bounds := _color_y_bounds(image, scan_rect, base_style.bg_color)
	var red_bounds := _color_y_bounds(image, scan_rect, red_style.bg_color)
	var separator_bounds := _color_y_bounds(image, scan_rect, separator.color)
	var separator_covers_fill := separator_bounds.x >= 0 \
		and separator_bounds.x <= base_bounds.x \
		and separator_bounds.y >= base_bounds.y
	if base_bounds != red_bounds or not separator_covers_fill:
		print("DAMAGE_PREVIEW_PIXEL_BOUNDS unit=%s base=%s separator=%s red=%s" % [
			String(unit.call("get_unit_id")),
			base_bounds,
			separator_bounds,
			red_bounds,
		])
		print("DAMAGE_PREVIEW_PIXEL_GEOMETRY overlay_visible=%s overlay_pos=%s overlay_size=%s overlay_scale=%s overlay_modulate=%s red_visible=%s red_pos=%s red_size=%s red_modulate=%s red_color=%s" % [
			overlay.visible,
			overlay.position,
			overlay.size,
			overlay.scale,
			overlay.modulate,
			red_fill.visible,
			red_fill.position,
			red_fill.size,
			red_fill.modulate,
			red_style.bg_color,
		])
	return base_bounds.x >= 0 and red_bounds.x >= 0 \
		and base_bounds == red_bounds \
		and separator_covers_fill


func _color_y_bounds(image: Image, rect: Rect2, target: Color) -> Vector2i:
	var left := clampi(floori(rect.position.x), 0, image.get_width() - 1)
	var top := clampi(floori(rect.position.y), 0, image.get_height() - 1)
	var right := clampi(ceili(rect.end.x), left, image.get_width() - 1)
	var bottom := clampi(ceili(rect.end.y), top, image.get_height() - 1)
	var min_y := image.get_height()
	var max_y := -1
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - target.r) <= 0.004 \
					and absf(pixel.g - target.g) <= 0.004 \
					and absf(pixel.b - target.b) <= 0.004 \
					and pixel.a > 0.99:
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	return Vector2i(min_y, max_y) if max_y >= 0 else Vector2i(-1, -1)


func _unit_by_id(battle: Control, unit_id: String) -> Control:
	var cell_host := battle.get_node("Board/CellHost") as Control
	for cell in cell_host.get_children():
		if not cell.has_method("get_unit_node"):
			continue
		var unit := cell.call("get_unit_node") as Control
		if unit != null and String(unit.call("get_unit_id")) == unit_id:
			return unit
	return null


func _snapshot() -> Dictionary:
	var cells := [
		_unit_cell(Vector2i(2, 5), "preview_ally", "player", "pal_002", 20),
		_unit_cell(Vector2i(5, 2), "preview_enemy", "enemy", "pal_001", 20),
		_unit_cell(Vector2i(6, 4), "preview_lethal_enemy", "enemy", "pal_006", 10, 20),
	]
	return {
		"phase": "battle",
		"stateVersion": 1,
		"stateHash": "embedded-damage-preview",
		"board": {"width": 8, "height": 7, "cells": cells},
		"units": cells.duplicate(true),
		"battleTrace": [],
	}


func _unit_cell(
	grid: Vector2i,
	unit_id: String,
	side: String,
	pet_id: String,
	hp: int,
	max_hp: int = -1
) -> Dictionary:
	return {
		"x": grid.x,
		"y": grid.y,
		"unitId": unit_id,
		"id": unit_id,
		"pet_id": pet_id,
		"name": unit_id,
		"side": side,
		"hp": hp,
		"max_hp": hp if max_hp < 0 else max_hp,
		"atk": 3,
		"shield": 0,
		"elements": {},
	}


func _fail(message: String) -> void:
	push_error("VISIBLE_EMBEDDED_DAMAGE_PREVIEW_FAIL: %s" % message)
	quit(1)
