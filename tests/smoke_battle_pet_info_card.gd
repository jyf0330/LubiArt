extends SceneTree

const CARD_SCENE := preload("res://art/prefabs/pet/battle_pet_info_card.tscn")
const DETAIL_SCENE := preload("res://art/prefabs/pet/pet_detail.tscn")
const BATTLE_DETAIL_CONTROLLER := preload("res://core_ui/scripts/battle/controllers/battle_detail_controller.gd")
const FRAME_OUTER_HALF_WIDTH_FOR_TEST := 9.0


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var card := CARD_SCENE.instantiate() as Control
	root.add_child(card)
	await process_frame
	var bridged_record: Dictionary = BATTLE_DETAIL_CONTROLLER.new().pet_record({
		"quality": "diamond",
		"traits": [{"id": "S02"}],
		"quality_progression": {"upgrade_selection": "legacy_first"},
	}, "", {})
	assert(Array(bridged_record["traits"]) == [{"id": "S02"}])
	assert(Dictionary(bridged_record["quality_progression"])["upgrade_selection"] == "legacy_first")

	var required_paths := [
		"Frame",
		"QualityHeader/QualityStars",
		"QualityHeader/QualityName",
		"PortraitPanel/PortraitBackdrop",
		"PortraitPanel/Portrait",
		"PortraitPanel/PetName",
		"PortraitPanel/ElementIcon",
		"PortraitPanel/ElementName",
		"HealthBar/HealthValue",
		"ShieldBar/ShieldValue",
		"AttackRangePanel/AttackRangeTitle",
		"AttackRangePanel/AttackGrid",
		"TraitSlots/TraitSlotSilver",
		"TraitSlots/TraitSlotGold",
		"TraitSlots/TraitSlotDiamond",
		"StatsPanel/StatsGrid/HpStat/Icon",
		"StatsPanel/StatsGrid/HpStat/Value",
		"StatsPanel/StatsGrid/AttackStat/Icon",
		"StatsPanel/StatsGrid/ApStat/Icon",
		"StatsPanel/StatsGrid/DefenseStat/Icon",
		"StatsPanel/StatsGrid/ShieldStat/Icon",
		"StatsPanel/StatsGrid/RegenStat/Icon",
	]
	for path in required_paths:
		assert(card.get_node_or_null(path) != null, "Missing confirmed prefab node: %s" % path)

	var quality_cases := [
		{"key": "bronze", "stars": 1, "trait_slots": 0, "traits": ["", "", ""], "prices": [2, 4, 6]},
		{"key": "silver", "stars": 2, "trait_slots": 1, "traits": ["S01", "", ""], "prices": [4, 8, 12]},
		{"key": "gold", "stars": 3, "trait_slots": 2, "traits": ["S01", "G01", ""], "prices": [8, 16, 24]},
		{"key": "diamond", "stars": 4, "trait_slots": 3, "traits": ["S01", "G01", "D01"], "prices": [16, 32, 48]},
	]
	assert(int(card.call("get_trait_catalog_count")) == 68)
	for quality_case in quality_cases:
		for attack_cell_count in range(1, 4):
			var price_record := _sample_record(String(quality_case["key"]))
			price_record["attack_shape"] = _attack_shape(attack_cell_count)
			card.call("set_info", price_record, null)
			await process_frame
			assert(String(card.call("get_quality_key")) == String(quality_case["key"]))
			assert(int(card.call("get_quality_star_count")) == int(quality_case["stars"]))
			assert((card.get_node("QualityHeader/QualityStars") as Label).text.length() == int(quality_case["stars"]))
			assert(int(card.call("get_trait_slot_count")) == 3)
			assert(int(card.call("get_unlocked_trait_slot_count")) == int(quality_case["trait_slots"]))
			assert(Array(card.call("get_displayed_trait_ids")) == Array(quality_case["traits"]))
			for trait_slot_index in range(3):
				var trait_slot := card.get_node("TraitSlots").get_child(trait_slot_index) as Panel
				assert(trait_slot.mouse_filter == Control.MOUSE_FILTER_STOP)
				assert(bool(card.call("is_trait_slot_awakened", trait_slot_index)) == (
					trait_slot_index < int(quality_case["trait_slots"])
				))
				if trait_slot_index >= int(quality_case["trait_slots"]):
					var empty_slot_style := trait_slot.get_theme_stylebox("panel") as StyleBoxFlat
					assert(empty_slot_style != null)
					assert(empty_slot_style.bg_color.is_equal_approx(Color("#090f0d")))
					assert(empty_slot_style.border_color.is_equal_approx(Color("#1b2723")))
					assert(trait_slot.tooltip_text.contains("特性槽 · 空"))
					assert(trait_slot.tooltip_text.contains("品质后解锁"))
				else:
					var trait_slot_style := trait_slot.get_theme_stylebox("panel") as StyleBoxTexture
					assert(trait_slot_style != null)
					assert(trait_slot_style.texture != null)
					assert(trait_slot_style.texture.get_size() == Vector2(476.0, 476.0))
					assert(trait_slot.tooltip_text.strip_edges() != "")
			assert(int(card.call("get_attack_cell_tier")) == attack_cell_count)
			assert(int(card.call("get_display_price")) == int(quality_case["prices"][attack_cell_count - 1]))
			assert((card.get_node("PortraitPanel/ElementName") as Label).text == str(quality_case["prices"][attack_cell_count - 1]))

	var explicit_traits_record := _sample_record("diamond")
	explicit_traits_record["traits"] = [{"id": "S02"}, {"name": "终点重击"}, {"trait_id": "D21"}]
	card.call("set_info", explicit_traits_record, null)
	await process_frame
	assert(Array(card.call("get_displayed_trait_ids")) == ["S02", "G10", "D21"])
	assert(String(card.call("get_trait_display_name", "G10")) == "终点重击")

	card.call("set_info", _sample_record("diamond"), null)
	await process_frame
	assert(card.size == Vector2(380.0, 820.0))
	assert(card.call("get_source_canvas_size") == Vector2(380.0, 820.0))
	var frame_style := (card.get_node("Frame") as Panel).get_theme_stylebox("panel") as StyleBoxEmpty
	assert(frame_style != null)
	var quality_header := card.get_node("QualityHeader") as Panel
	var quality_header_style := quality_header.get_theme_stylebox("panel") as StyleBoxEmpty
	assert(quality_header.position == Vector2.ZERO)
	assert(quality_header.size == Vector2(380.0, 60.0))
	assert((card.get_node("Frame") as Panel).position.y == 46.0)
	assert(quality_header.position.y + quality_header.size.y > (card.get_node("Frame") as Panel).position.y)
	assert(quality_header_style != null)
	var draw_spec: Dictionary = card.call("get_frame_draw_spec")
	var outline_points: PackedVector2Array = draw_spec["points"]
	assert(outline_points == PackedVector2Array([
		Vector2(380.0, 811.0),
		Vector2(9.0, 811.0),
		Vector2(9.0, 46.0),
		Vector2(110.0, 46.0),
		Vector2(126.0, 18.0),
		Vector2(254.0, 18.0),
		Vector2(270.0, 46.0),
		Vector2(380.0, 46.0),
	]))
	assert(draw_spec["widths"] == PackedFloat32Array([18.0, 14.0, 8.0, 5.0, 2.0]))
	assert(draw_spec["fill_color"] == Color("#131e1a"))
	assert(not bool(draw_spec["right_border"]))
	assert(not (card.get_node("QualityHeader/QualityName") as Label).visible)
	var quality_stars := card.get_node("QualityHeader/QualityStars") as Label
	assert(quality_stars.position == Vector2(126.0, 24.0))
	assert(quality_stars.size == Vector2(128.0, 24.0))
	assert(quality_stars.get_theme_font_size("font_size") == 16)
	assert(quality_stars.get_theme_constant("outline_size") == 3)
	assert(quality_stars.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
	assert(quality_stars.vertical_alignment == VERTICAL_ALIGNMENT_CENTER)
	assert(is_equal_approx(
		quality_header.position.x + quality_header.size.x * 0.5,
		190.0
	))
	for centered_path in [
		"PortraitPanel",
		"HealthBar",
		"ShieldBar",
		"StatsPanel",
	]:
		var centered_section := card.get_node(centered_path) as Control
		assert(centered_section != null)
		assert(is_equal_approx(
			centered_section.position.x + centered_section.size.x * 0.5,
			199.0
		))
	var portrait_panel := card.get_node("PortraitPanel") as Control
	assert(portrait_panel.position == Vector2(27.0, 60.0))
	assert(portrait_panel.size == Vector2(344.0, 262.0))
	assert(is_equal_approx(portrait_panel.position.x - 18.0, 9.0))
	assert(is_equal_approx(
		380.0 - (portrait_panel.position.x + portrait_panel.size.x),
		9.0
	))
	assert(String(card.call("get_element_key")) == "fire")
	var name_bar := card.get_node("PortraitPanel/PetName") as Label
	var element_icon := card.get_node("PortraitPanel/ElementIcon") as TextureRect
	var price_label := card.get_node("PortraitPanel/ElementName") as Label
	assert(name_bar.position == Vector2(8.0, 210.0))
	assert(name_bar.size == Vector2(328.0, 44.0))
	assert(name_bar.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT)
	assert(element_icon.position == Vector2(16.0, 164.0))
	assert(element_icon.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(element_icon.tooltip_text.contains("火属性"))
	assert(element_icon.position.y + element_icon.size.y <= name_bar.position.y)
	assert(price_label.position == Vector2(246.0, 210.0))
	assert(price_label.size == Vector2(80.0, 44.0))
	assert(price_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	assert(int(card.call("get_attack_cell_tier")) == 3)
	assert(int(card.call("get_display_price")) == 48)
	assert(price_label.text == "48")
	assert((name_bar.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Color("#bc6b2f"))
	assert(int(card.call("get_attack_shape_cell_count")) == 21)
	assert(card.call("get_attack_grid_size") == Vector2i(7, 3))
	assert(int(card.call("get_attack_origin_index")) == 9)
	assert(card.call("get_attack_icon_cell_size") == Vector2(10.0, 10.0))
	var attack_range_panel := card.get_node("AttackRangePanel") as Control
	var attack_range_title := card.get_node("AttackRangePanel/AttackRangeTitle") as Label
	var attack_grid := card.get_node("AttackRangePanel/AttackGrid") as GridContainer
	assert(attack_range_panel.position == Vector2(39.0, 441.0))
	assert(attack_range_panel.size == Vector2(96.0, 96.0))
	assert(attack_range_panel.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(attack_range_panel.tooltip_text.contains("攻击范围"))
	var attack_range_style := (attack_range_panel as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	assert(attack_range_style != null)
	assert(attack_range_style.bg_color.is_equal_approx(Color("#131e1a")))
	assert(attack_range_style.border_color.is_equal_approx(Color("#2f4f4e")))
	assert(attack_range_style.border_width_left == 3)
	assert(attack_range_style.border_width_top == 3)
	assert(attack_range_style.border_width_right == 3)
	assert(attack_range_style.border_width_bottom == 3)
	assert(attack_range_style.shadow_size == 0)
	assert(not attack_range_style.anti_aliasing)
	assert(attack_range_title.visible)
	assert(attack_range_title.text == "")
	assert(attack_range_title.position == Vector2(0.0, -21.0))
	assert(attack_range_title.size == Vector2(320.0, 138.0))
	var attack_divider_style := attack_range_title.get_theme_stylebox("normal") as StyleBoxFlat
	assert(attack_divider_style != null)
	assert(attack_divider_style.bg_color.a == 0.0)
	assert(attack_divider_style.border_color.is_equal_approx(Color("#2f4f4e")))
	assert(attack_divider_style.border_width_left == 0)
	assert(attack_divider_style.border_width_top == 3)
	assert(attack_divider_style.border_width_right == 0)
	assert(attack_divider_style.border_width_bottom == 3)
	assert(not attack_divider_style.anti_aliasing)
	var attack_divider_top := attack_range_panel.position.y + attack_range_title.position.y
	var attack_divider_bottom := attack_divider_top + attack_range_title.size.y
	assert(attack_divider_top + 3.0 + 18.0 == attack_range_panel.position.y)
	assert(attack_range_panel.position.y + attack_range_panel.size.y + 18.0 == attack_divider_bottom - 3.0)
	assert(attack_grid.position == Vector2(7.0, 31.0))
	assert(attack_grid.size == Vector2(82.0, 34.0))
	assert(attack_grid.columns == 7)
	assert(attack_grid.get_theme_constant("h_separation") == 2)
	assert(attack_grid.get_theme_constant("v_separation") == 2)
	assert(attack_grid.get_child_count() == 21)
	assert((attack_grid.get_child(9) as ColorRect).color == Color("#72d7e7"))
	assert((attack_grid.get_child(0) as ColorRect).color.a == 0.0)
	assert(Array(card.call("get_target_cell_indices")).size() == 3)
	var health_bar := card.get_node("HealthBar") as TextureProgressBar
	var health_value := card.get_node("HealthBar/HealthValue") as Label
	assert(is_equal_approx(health_bar.value, 73.0))
	assert(health_bar.position == Vector2(39.0, 330.0))
	assert(health_bar.size == Vector2(320.0, 36.0))
	assert(health_bar.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(health_bar.tooltip_text.contains("73 / 100"))
	var shield_bar := card.get_node("ShieldBar") as TextureProgressBar
	var shield_value := card.get_node("ShieldBar/ShieldValue") as Label
	assert(shield_bar.position == Vector2(39.0, 366.0))
	assert(shield_bar.size == health_bar.size)
	assert(shield_bar.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(shield_bar.tooltip_text.contains("4 / 4"))
	assert(shield_bar.position.y + shield_bar.size.y + 18.0 == attack_divider_top)
	assert(attack_range_panel.position.x + attack_range_title.position.x == health_bar.position.x)
	assert(attack_range_title.size.x == health_bar.size.x)
	assert(shield_bar.texture_under is GradientTexture2D)
	assert(shield_bar.texture_progress is GradientTexture2D)
	assert((shield_bar.texture_under as GradientTexture2D).width == 320)
	assert((shield_bar.texture_under as GradientTexture2D).height == 36)
	assert((shield_bar.texture_progress as GradientTexture2D).width == 320)
	assert((shield_bar.texture_progress as GradientTexture2D).height == 36)
	assert(is_equal_approx(shield_bar.max_value, 4.0))
	assert(is_equal_approx(shield_bar.value, 4.0))
	assert(shield_value.text == "4 / 4")
	assert(health_value.get_theme_font_size("font_size") == 18)
	assert(shield_value.get_theme_font_size("font_size") == 18)
	assert(health_value.get_theme_constant("outline_size") == 5)
	assert(shield_value.get_theme_constant("outline_size") == 5)
	assert(health_value.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT)
	assert(shield_value.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT)
	assert(health_value.position.x == 16.0)
	assert(shield_value.position.x == 16.0)
	assert((card.get_node("AttackRangePanel") as Control).position.y == 441.0)
	var trait_slots := card.get_node("TraitSlots") as HBoxContainer
	assert(trait_slots.position == Vector2(39.0, 576.0))
	assert(trait_slots.size == Vector2(320.0, 96.0))
	assert(attack_divider_bottom + 18.0 == trait_slots.position.y)
	assert(trait_slots.get_theme_constant("separation") == 16)
	assert(trait_slots.get_child_count() == 3)
	for index in range(3):
		var trait_slot := trait_slots.get_child(index) as Panel
		assert(trait_slot != null)
		assert(trait_slot.size == Vector2(96.0, 96.0))
		assert(trait_slot.get_child_count() == 0)
		assert(bool(card.call("is_trait_slot_awakened", index)))
	var awakened_trait_style := (trait_slots.get_child(0) as Panel).get_theme_stylebox("panel") as StyleBoxTexture
	assert(awakened_trait_style != null)
	assert(awakened_trait_style.texture.resource_path.ends_with("/s01_guard.png"))
	var gold_trait_style := (trait_slots.get_child(1) as Panel).get_theme_stylebox("panel") as StyleBoxTexture
	var diamond_trait_style := (trait_slots.get_child(2) as Panel).get_theme_stylebox("panel") as StyleBoxTexture
	assert(gold_trait_style.texture.resource_path.ends_with("/g01_stance_switch.png"))
	assert(diamond_trait_style.texture.resource_path.ends_with("/d01_endpoint_extension.png"))
	var stats_panel := card.get_node("StatsPanel") as Control
	var stats_grid := card.get_node("StatsPanel/StatsGrid") as GridContainer
	assert(stats_panel.position == Vector2(39.0, 690.0))
	assert(stats_panel.size == Vector2(320.0, 104.0))
	assert(trait_slots.position.y + trait_slots.size.y + 18.0 == stats_panel.position.y)
	assert(stats_panel.position.x == trait_slots.position.x)
	assert(stats_panel.size.x == trait_slots.size.x)
	var stats_style := (stats_panel as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	assert(stats_style != null)
	assert(stats_style.bg_color.is_equal_approx(Color("#131e1a")))
	assert(stats_style.border_width_top == 3)
	assert(stats_style.border_width_left == 0)
	assert(stats_style.border_width_right == 0)
	assert(stats_style.border_width_bottom == 0)
	assert(stats_style.border_color.is_equal_approx(Color("#2f4f4e")))
	assert(stats_grid.position == Vector2(0.0, 20.0))
	assert(stats_grid.size == Vector2(320.0, 84.0))
	assert(stats_grid.get_theme_constant("h_separation") == 10)
	assert(float(outline_points[0].y) - FRAME_OUTER_HALF_WIDTH_FOR_TEST - (stats_panel.position.y + stats_panel.size.y) >= 8.0)
	assert(not (card.get_node("StatsPanel/StatsGrid/HpStat") as Control).visible)
	assert((card.get_node("StatsPanel/StatsGrid/AttackStat") as Control).visible)
	assert(not (card.get_node("StatsPanel/StatsGrid/ApStat") as Control).visible)
	assert((card.get_node("StatsPanel/StatsGrid/DefenseStat") as Control).visible)
	assert(not (card.get_node("StatsPanel/StatsGrid/ShieldStat") as Control).visible)
	assert((card.get_node("StatsPanel/StatsGrid/RegenStat") as Control).visible)
	assert((card.get_node("StatsPanel/StatsGrid/AttackStat") as Control).tooltip_text.contains("攻击力：18"))
	assert((card.get_node("StatsPanel/StatsGrid/DefenseStat") as Control).tooltip_text.contains("防御力：7"))
	assert((card.get_node("StatsPanel/StatsGrid/RegenStat") as Control).tooltip_text.contains("生命回复：2"))
	assert((card.get_node("StatsPanel/StatsGrid/AttackStat/Icon") as TextureRect).custom_minimum_size == Vector2(100.0, 32.0))
	assert((card.get_node("StatsPanel/StatsGrid/DefenseStat/Icon") as TextureRect).custom_minimum_size == Vector2(100.0, 36.0))
	assert((card.get_node("StatsPanel/StatsGrid/RegenStat/Icon") as TextureRect).custom_minimum_size == Vector2(100.0, 36.0))
	for value_path in [
		"StatsPanel/StatsGrid/AttackStat/Value",
		"StatsPanel/StatsGrid/DefenseStat/Value",
		"StatsPanel/StatsGrid/RegenStat/Value",
	]:
		var stat_value := card.get_node(value_path) as Label
		assert(stat_value.custom_minimum_size == Vector2(100.0, 44.0))
		assert(stat_value.get_theme_font_size("font_size") == 36)
		assert(stat_value.get_theme_constant("outline_size") == 5)
	var zero_shield_record := _sample_record("diamond")
	zero_shield_record["shield"] = 0
	zero_shield_record["max_shield"] = 0
	card.call("set_info", zero_shield_record, null)
	await process_frame
	assert(is_equal_approx(shield_bar.value, 0.0))
	assert((card.get_node("ShieldBar/ShieldValue") as Label).text == "0 / 0")

	card.queue_free()
	var detail := DETAIL_SCENE.instantiate() as Control
	root.add_child(detail)
	await process_frame
	detail.call("show_context_detail", _sample_record("gold"), null)
	await process_frame
	var panel := detail.get_node("Panel") as Control
	assert(panel.position == Vector2(1540.0, 80.0))
	assert(panel.size == Vector2(380.0, 820.0))
	assert(detail.call("get_component_source") == "res://art/prefabs/pet/battle_pet_info_card.tscn")
	assert(detail.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var context_card := detail.call("get_info_card") as Control
	for tooltip_path in [
		"PortraitPanel/ElementIcon",
		"HealthBar",
		"ShieldBar",
		"AttackRangePanel",
		"TraitSlots/TraitSlotSilver",
		"TraitSlots/TraitSlotGold",
		"TraitSlots/TraitSlotDiamond",
		"StatsPanel/StatsGrid/AttackStat",
		"StatsPanel/StatsGrid/DefenseStat",
		"StatsPanel/StatsGrid/RegenStat",
	]:
		var tooltip_control := context_card.get_node(tooltip_path) as Control
		assert(tooltip_control.mouse_filter == Control.MOUSE_FILTER_STOP)
		assert(tooltip_control.tooltip_text.strip_edges() != "")

	print("BATTLE_PET_INFO_CARD_SMOKE_PASS")
	quit(0)


func _sample_record(quality: String) -> Dictionary:
	return {
		"name": "焰尾兽",
		"quality": quality,
		"element": "fire",
		"hp": 73,
		"max_hp": 100,
		"attack": 18,
		"ap": 3,
		"max_ap": 5,
		"defense": 7,
		"shield": 4,
		"max_shield": 4,
		"regen": 2,
		"quality_progression": {"upgrade_selection": "legacy_first"},
		"attack_shape": [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)],
	}


func _attack_shape(cell_count: int) -> Dictionary:
	var offsets: Array[Dictionary] = []
	for index in range(cell_count):
		offsets.append({"dr": index - 1, "dc": 1})
	return {
		"cell_count": cell_count,
		"offsets": offsets,
	}
