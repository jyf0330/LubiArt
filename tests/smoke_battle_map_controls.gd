extends SceneTree

const PREFAB := preload("res://art/prefabs/battle/hud/battle_map_controls.tscn")
const APPLICATION_TOOLTIP_THEME := preload("res://art/themes/shared/application_tooltip_theme.tres")
const EXPECTED_TOOLTIP_POSITION_OFFSET := Vector2(72.0, 64.0)
const EXPECTED_MAP_IDS := [
	"lowland_evening",
	"grassland_evening",
	"grassland_morning",
	"pond_evening",
	"pond_morning",
	"mountain_evening",
	"mountain_morning",
	"lowland_morning",
]
const EXPECTED_BUTTON_RECTS := {
	"AutoArrangeButton": Rect2(1841.0, 915.0, 66.0, 62.0),
	"ResetButton": Rect2(1704.0, 915.0, 66.0, 62.0),
	"SpeedButton": Rect2(90.0, 985.0, 65.0, 62.0),
	"SettingsButton": Rect2(20.0, 985.0, 65.0, 62.0),
	"AttackOrderButton": Rect2(1772.0, 915.0, 65.0, 62.0),
	"BagButton": Rect2(1635.0, 915.0, 66.0, 62.0),
	"AllOutButton": Rect2(1635.0, 983.0, 272.0, 64.0),
}
const EXPECTED_SHORTCUTS := {
	"A": "AutoArrangeButton",
	"R": "ResetButton",
	"D": "SpeedButton",
	"Escape": "SettingsButton",
	"Tab": "AttackOrderButton",
	"B": "BagButton",
	"Space": "AllOutButton",
}
const EXPECTED_TOOLTIPS := {
	"AutoArrangeButton": "自动布阵：快速安排我方精灵站位。（快捷键 A）",
	"ResetButton": "重置布阵：恢复我方精灵到本场战斗入场状态。（快捷键 R）",
	"SpeedButton": "切换战斗速度：在 1 倍与 2 倍播放速度之间切换。（快捷键 D）",
	"SettingsButton": "设置：打开或关闭设置菜单。（快捷键 ESC）",
	"AttackOrderButton": "攻击顺序：查看或收起本回合的攻击顺序。（快捷键 TAB）",
	"BagButton": "回撤：当前没有可回撤的上一回合。（快捷键 B）",
	"AllOutButton": "全军出击：确认当前布阵并开始本回合行动。（快捷键 空格）",
}

var _attack_order_count := 0
var _bag_count := 0
var _reset_count := 0
var _blocked_shortcut_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var prefab := PREFAB.instantiate() as Control
	root.add_child(prefab)
	await process_frame
	assert(prefab.scene_file_path == "res://art/prefabs/battle/hud/battle_map_controls.tscn")
	assert(prefab.custom_minimum_size == Vector2(1920.0, 1080.0))
	assert(prefab.size == Vector2(1920.0, 1080.0))
	assert(Array(prefab.call("get_map_ids")) == EXPECTED_MAP_IDS)
	assert(prefab.call("get_keyboard_shortcuts") == EXPECTED_SHORTCUTS)
	assert(is_equal_approx(
		float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")),
		1.0
	))
	assert(
		Vector2(ProjectSettings.get_setting("display/mouse_cursor/tooltip_position_offset"))
		== EXPECTED_TOOLTIP_POSITION_OFFSET
	)
	assert(String(ProjectSettings.get_setting("gui/theme/custom")) == (
		"res://art/themes/shared/application_tooltip_theme.tres"
	))
	assert(APPLICATION_TOOLTIP_THEME.get_font_size("font_size", "TooltipLabel") == 24)
	assert(APPLICATION_TOOLTIP_THEME.get_constant("outline_size", "TooltipLabel") == 4)
	var tooltip_style := APPLICATION_TOOLTIP_THEME.get_stylebox("panel", "TooltipPanel") as StyleBoxFlat
	assert(tooltip_style != null)
	assert(tooltip_style.content_margin_left == 14.0)
	assert(tooltip_style.content_margin_top == 10.0)
	assert(tooltip_style.content_margin_right == 14.0)
	assert(tooltip_style.content_margin_bottom == 10.0)
	assert(prefab.get_node_or_null("MapBackground") == null)
	for index in range(EXPECTED_MAP_IDS.size()):
		assert(bool(prefab.call("set_map_by_index", index)))
		var map_texture := prefab.call("get_map_texture") as Texture2D
		assert(map_texture != null)
		assert(map_texture.get_size() == Vector2(1920.0, 1080.0))
		assert(String(prefab.call("get_map_id")) == EXPECTED_MAP_IDS[index])
	for node_name in EXPECTED_BUTTON_RECTS:
		var button := prefab.get_node(node_name) as TextureButton
		assert(button != null)
		assert(Rect2(button.position, button.size) == EXPECTED_BUTTON_RECTS[node_name])
		assert(button.texture_normal != null)
		assert(button.tooltip_text == EXPECTED_TOOLTIPS[node_name])
	var ordered_buttons := [
		prefab.get_node("ResetButton") as TextureButton,
		prefab.get_node("AttackOrderButton") as TextureButton,
		prefab.get_node("AutoArrangeButton") as TextureButton,
	]
	assert(not (prefab.get_node("BagButton") as TextureButton).visible)
	var all_out_rect := (prefab.get_node("AllOutButton") as TextureButton).get_rect()
	assert(ordered_buttons.back().position.x + ordered_buttons.back().size.x == all_out_rect.end.x)
	for index in range(1, ordered_buttons.size()):
		assert(ordered_buttons[index].position.y == ordered_buttons.front().position.y)
		assert(ordered_buttons[index].position.x > ordered_buttons[index - 1].get_rect().end.x)
	var reset_button := prefab.get_node("ResetButton") as TextureButton
	var reset_cooldown_label := reset_button.get_node("ResetCooldownLabel") as Label
	prefab.call("set_reset_charge_state", 1, 4)
	assert(not reset_cooldown_label.visible)
	assert(reset_cooldown_label.text == "")
	assert(reset_button.self_modulate == Color.WHITE)
	assert(not bool(reset_button.get_meta("cooling_down")))
	assert(not bool(reset_button.get_meta("waiting_for_charge")))
	prefab.call("set_reset_charge_state", 3, 2)
	assert(reset_cooldown_label.visible)
	assert(reset_cooldown_label.text == "×3")
	assert(reset_cooldown_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	assert(reset_cooldown_label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM)
	assert(int(reset_button.get_meta("charges")) == 3)
	for remaining in [5, 4, 3, 2, 1]:
		prefab.call("set_reset_charge_state", 0, remaining)
		assert(reset_cooldown_label.visible)
		assert(reset_cooldown_label.text == str(remaining))
		assert(reset_cooldown_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
		assert(reset_cooldown_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER)
		assert(bool(reset_button.get_meta("waiting_for_charge")))
		assert(not bool(reset_button.get_meta("cooling_down")))
	prefab.call("set_reset_charge_state", 1, 0)
	assert(not reset_cooldown_label.visible)
	assert(reset_cooldown_label.text == "")
	assert(reset_button.self_modulate == Color.WHITE)
	var all_out_button := prefab.get_node("AllOutButton") as TextureButton
	var all_out_highlight_material := all_out_button.material as ShaderMaterial
	assert(all_out_highlight_material != null)
	assert(is_equal_approx(
		float(all_out_highlight_material.get_shader_parameter("sweep_progress")),
		-1.0
	))
	prefab.call("_play_all_out_idle_prompt")
	var all_out_highlight_tween := prefab.get("_all_out_highlight_tween") as Tween
	assert(all_out_highlight_tween != null)
	all_out_highlight_tween.custom_step(0.41)
	var highlight_progress := float(
		all_out_highlight_material.get_shader_parameter("sweep_progress")
	)
	assert(highlight_progress > 0.0 and highlight_progress < 1.0)
	all_out_highlight_tween.custom_step(1.0)
	assert(prefab.get("_all_out_highlight_tween") == null)
	prefab.set("_next_all_out_prompt_msec", Time.get_ticks_msec() - 1)
	prefab.call("_process", 0.0)
	var repeated_highlight_tween := prefab.get("_all_out_highlight_tween") as Tween
	assert(repeated_highlight_tween != null)
	var activity_event := InputEventKey.new()
	activity_event.keycode = KEY_A
	activity_event.pressed = false
	prefab.call("_input", activity_event)
	assert(is_equal_approx(
		float(all_out_highlight_material.get_shader_parameter("sweep_progress")),
		-1.0
	))
	assert(not bool(prefab.get("_all_out_idle_prompt_played")))
	var hints := prefab.get_node("ShortcutHints") as TextureRect
	assert(hints != null)
	assert(Rect2(hints.position, hints.size) == Rect2(0.0, 948.0, 1920.0, 99.0))
	assert(hints.texture != null)
	assert(bool(prefab.call("are_shortcut_hints_visible")))
	assert(not bool(prefab.call("toggle_shortcut_hints")))
	assert(not hints.visible)
	prefab.call("set_shortcut_hints_visible", true)
	assert(hints.visible)
	for node_name in EXPECTED_BUTTON_RECTS:
		var button := prefab.get_node(node_name) as TextureButton
		prefab.call("_on_button_down", button)
		if node_name == "ResetButton":
			assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
		else:
			var press_tween := (prefab.get("_button_tweens") as Dictionary).get(button) as Tween
			press_tween.custom_step(0.1)
			assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
		prefab.call("_on_button_up", button)
		var release_tween := (prefab.get("_button_tweens") as Dictionary).get(button) as Tween
		if node_name == "ResetButton":
			release_tween.custom_step(0.05)
			assert(button.scale.is_equal_approx(Vector2(0.92, 0.92)))
			release_tween.custom_step(0.15)
		else:
			release_tween.custom_step(0.12)
		assert(button.scale.is_equal_approx(Vector2.ONE))
	prefab.attack_order_requested.connect(_on_attack_order_requested)
	prefab.bag_requested.connect(_on_bag_requested)
	prefab.reset_requested.connect(_on_reset_requested)
	(prefab.get_node("AttackOrderButton") as TextureButton).pressed.emit()
	(prefab.get_node("BagButton") as TextureButton).pressed.emit()
	assert(_attack_order_count == 1)
	assert(_bag_count == 1)
	var physical_r_down := InputEventKey.new()
	physical_r_down.keycode = KEY_NONE
	physical_r_down.physical_keycode = KEY_R
	physical_r_down.pressed = true
	prefab._unhandled_key_input(physical_r_down)
	assert((prefab.get_node("ResetButton") as TextureButton).scale.is_equal_approx(Vector2(0.92, 0.92)))
	var physical_r_up := InputEventKey.new()
	physical_r_up.keycode = KEY_NONE
	physical_r_up.physical_keycode = KEY_R
	physical_r_up.pressed = false
	prefab._unhandled_key_input(physical_r_up)
	var reset_release_tween := (prefab.get("_button_tweens") as Dictionary).get(prefab.get_node("ResetButton")) as Tween
	reset_release_tween.custom_step(0.20)
	assert((prefab.get_node("ResetButton") as TextureButton).scale.is_equal_approx(Vector2.ONE))
	assert(_reset_count == 1)
	prefab.shortcut_blocked.connect(_on_shortcut_blocked)
	reset_button.disabled = true
	var disabled_r_down := InputEventKey.new()
	disabled_r_down.keycode = KEY_R
	disabled_r_down.pressed = true
	prefab._unhandled_key_input(disabled_r_down)
	assert(reset_button.scale.is_equal_approx(Vector2(0.92, 0.92)))
	assert(_blocked_shortcut_count == 1)
	var disabled_r_up := InputEventKey.new()
	disabled_r_up.keycode = KEY_R
	disabled_r_up.pressed = false
	prefab._unhandled_key_input(disabled_r_up)
	var disabled_reset_release_tween := (
		(prefab.get("_button_tweens") as Dictionary).get(reset_button) as Tween
	)
	disabled_reset_release_tween.custom_step(0.20)
	assert(reset_button.scale.is_equal_approx(Vector2.ONE))
	assert(_reset_count == 1)
	reset_button.disabled = false
	for shortcut_name in EXPECTED_SHORTCUTS:
		var shortcut_keycode := OS.find_keycode_from_string(shortcut_name)
		var shortcut_button := prefab.get_node(EXPECTED_SHORTCUTS[shortcut_name]) as TextureButton
		var shortcut_down := InputEventKey.new()
		shortcut_down.keycode = shortcut_keycode
		shortcut_down.pressed = true
		prefab._unhandled_key_input(shortcut_down)
		assert(shortcut_button.scale.is_equal_approx(Vector2(0.92, 0.92)))
		var shortcut_up := InputEventKey.new()
		shortcut_up.keycode = shortcut_keycode
		shortcut_up.pressed = false
		prefab._unhandled_key_input(shortcut_up)
		var shortcut_release_tween := (
			(prefab.get("_button_tweens") as Dictionary).get(shortcut_button) as Tween
		)
		shortcut_release_tween.custom_step(0.05)
		assert(shortcut_button.scale.is_equal_approx(Vector2(0.92, 0.92)))
		shortcut_release_tween.custom_step(0.15)
		assert(shortcut_button.scale.is_equal_approx(Vector2.ONE))
	var speed_button := prefab.get_node("SpeedButton") as TextureButton
	prefab.call("set_speed_active", true)
	assert(speed_button.button_pressed)
	assert(bool(speed_button.get_meta("speed_active")))
	assert(speed_button.texture_normal.resource_path.get_file() == "speed_active.png")
	prefab.call("set_speed_active", false)
	assert(not speed_button.button_pressed)
	assert(speed_button.texture_normal.resource_path.get_file() == "speed_normal.png")
	assert(not bool(prefab.call("set_map_by_index", 8)))
	assert(not bool(prefab.call("set_map_by_id", "missing")))
	print("BATTLE_MAP_CONTROLS_SMOKE_PASS")
	quit(0)


func _on_attack_order_requested() -> void:
	_attack_order_count += 1


func _on_bag_requested() -> void:
	_bag_count += 1


func _on_reset_requested() -> void:
	_reset_count += 1


func _on_shortcut_blocked(_shortcut: String, _button_name: String) -> void:
	_blocked_shortcut_count += 1
