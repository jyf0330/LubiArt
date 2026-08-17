extends SceneTree

const BATTLE_SCENE_PATH := "res://art/scenes/battle/battle_art_scene.tscn"
const TERRAIN_PREFAB_PATH := "res://art/prefabs/terrain/terrain.tscn"
const PET_PREFAB_PATH := "res://art/prefabs/pet/pet.tscn"
const PET_DETAIL_PREFAB_PATH := "res://art/prefabs/pet/pet_detail.tscn"
const TERRAIN_DETAIL_PREFAB_PATH := "res://art/prefabs/terrain/terrain_detail.tscn"
const BOARD_SCRIPT_PATH := "res://core_ui/scripts/battle/scenes/battle_board.gd"
const HUD_SCRIPT_PATH := "res://core_ui/scripts/battle/prefabs/hud/battle_hud.gd"
const OVERLAY_SCRIPT_PATH := "res://core_ui/scripts/battle/scenes/battle_overlay.gd"
const VFX_SCRIPT_PATH := "res://core_ui/scripts/battle/controllers/battle_vfx_controller.gd"
const BattleSceneProbe := preload("res://tests/helpers/battle_scene_probe.gd")
const PREFAB_PATHS := [
	"res://art/prefabs/pet/pet.tscn",
	PET_DETAIL_PREFAB_PATH,
	TERRAIN_PREFAB_PATH,
	TERRAIN_DETAIL_PREFAB_PATH,
]

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(BATTLE_SCENE_PATH) as PackedScene
	_expect(packed != null, "formal battle Scene loads")
	if packed == null:
		_finish(null)
		return

	var battle := packed.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame

	_expect(battle.name == "BattleArtScene", "formal battle Scene keeps its authored root name")
	_expect(battle.scene_file_path == BATTLE_SCENE_PATH, "formal battle Scene is the runtime source")
	_expect(battle.has_method("get_runtime_view") and battle.call("get_runtime_view") == battle, "battle Scene is its own runtime view")
	_expect(battle.get_node_or_null("Runtime") == null, "battle Scene has no catalog wrapper runtime branch")
	_expect(battle.get_node_or_null("PrefabCatalog") == null, "battle Scene has no non-runtime prefab catalog branch")
	var direct_children := battle.get_children().map(func(child: Node) -> String: return child.name)
	_expect(
		direct_children == ["Board", "MapControls", "Hud", "OverlayHost"],
		"battle Scene keeps the four authored responsibility roots: Board, MapControls, Hud, OverlayHost"
	)

	var board_group := battle.get_node_or_null("Board") as Control
	var board_background := battle.get_node_or_null("Board/Background") as TextureRect
	var board_grid := battle.get_node_or_null("Board/CellHost") as Control
	var unit_host := battle.get_node_or_null("Board/UnitHost") as Control
	var vfx_host := battle.get_node_or_null("Board/VfxHost") as Control
	var map_controls := battle.get_node_or_null("MapControls") as Control
	var hud := battle.get_node_or_null("Hud") as Control
	var overlay := battle.get_node_or_null("OverlayHost") as Control
	var log_dashboard := battle.get_node_or_null("OverlayHost/BattleLogDashboard") as Control
	_expect(board_group != null and board_grid != null and unit_host != null, "Board owns background, cell and unit presentation hosts")
	_expect(
		board_group != null
			and board_group.get_script() != null
			and String(board_group.get_script().resource_path) == BOARD_SCRIPT_PATH,
		"Board secondary group owns its presentation script"
	)
	_expect(
		hud != null
			and hud.get_script() != null
			and String(hud.get_script().resource_path) == HUD_SCRIPT_PATH,
		"Hud responsibility root owns its presentation script"
	)
	_expect(
		overlay != null
			and overlay.get_script() != null
			and String(overlay.get_script().resource_path) == OVERLAY_SCRIPT_PATH,
		"OverlayHost responsibility root owns its presentation script"
	)
	_expect(
		vfx_host != null
			and vfx_host.get_script() != null
			and String(vfx_host.get_script().resource_path) == VFX_SCRIPT_PATH,
		"Board/VfxHost owns Trace presentation behavior"
	)
	_expect(board_group.get_children().map(func(child: Node) -> String: return child.name) == ["Background", "CellHost", "UnitHost", "VfxHost"], "Board has exactly four presentation hosts")
	_expect(board_grid != null and board_grid.get_child_count() == 56, "Board builds the default 8x7 terrain leaf pool")
	if board_grid != null:
		for terrain in board_grid.get_children():
			_expect(
				terrain.scene_file_path == TERRAIN_PREFAB_PATH,
				"every authored board cell reuses the one terrain prefab"
			)
	_expect(board_background != null, "battle background belongs to Board")
	_expect(
		map_controls != null and map_controls.get_script() != null,
		"MapControls owns its authored button presentation and shortcut input"
	)
	_expect(battle.get_node_or_null("Hud/BattleActionPanel") != null, "battle action panel belongs to Hud")
	_expect(battle.get_node_or_null("Hud/BattlePrimaryActions") != null, "authored primary-action group belongs to Hud")
	_expect(battle.get_node_or_null("Hud/BattlePrimaryActions/AutoArrangeButton") != null, "auto-arrange button belongs to Hud primary actions")
	_expect(
		battle.get_node_or_null("Hud/BattleActionPanel/Margin/Content/PositionDifficultyButton") != null,
		"difficulty button belongs to the authored Hud action panel"
	)
	_expect(battle.get_node_or_null("Hud/BattlePrimaryActions/BeginTurnButton") != null, "begin-turn button belongs to Hud primary actions")
	_expect(battle.get_node_or_null("Hud/AttackTimelineLayer/AttackTimeline") != null, "attack timeline belongs to Hud")
	for ordinary_child_path in [
		"Board/Background",
		"Board/CellHost",
		"Board/UnitHost",
		"Hud/BattleActionPanel/Margin/Content/PositionDifficultyButton",
		"Hud/BattlePrimaryActions/AutoArrangeButton",
		"Hud/BattlePrimaryActions/BeginTurnButton",
	]:
		var ordinary_child := battle.get_node_or_null(ordinary_child_path)
		_expect(
			ordinary_child != null and ordinary_child.get_script() == null,
			"ordinary presentation child stays scriptless: %s" % ordinary_child_path
		)
	for special_child_path in [
		"Board/VfxHost",
		"MapControls",
		"Hud/BattleActionPanel",
		"Hud/AttackTimelineLayer/AttackTimeline",
	]:
		var special_child := battle.get_node_or_null(special_child_path)
		_expect(
			special_child != null and special_child.get_script() != null,
			"special child keeps its independent behavior script: %s" % special_child_path
		)
	var pet := battle.get_node_or_null("OverlayHost/BattlePetDetailPanel") as Control
	var terrain_detail := battle.get_node_or_null("OverlayHost/BattleElementDetailPanel") as PanelContainer
	_expect(
		pet != null
			and pet.scene_file_path == PET_DETAIL_PREFAB_PATH,
		"OverlayHost mounts the authored pet-detail prefab"
	)
	_expect(
		terrain_detail != null and terrain_detail.scene_file_path == TERRAIN_DETAIL_PREFAB_PATH,
		"OverlayHost mounts the formal terrain-detail prefab"
	)
	_expect(
		overlay != null
			and overlay.has_method("request_detail")
			and overlay.has_method("render_snapshot")
			and overlay.has_method("clear")
			and overlay.has_method("has_visible_detail"),
		"OverlayHost exposes one narrow detail lifecycle API"
	)
	_expect(
		log_dashboard != null
			and not log_dashboard.visible
			and not log_dashboard.z_as_relative
			and log_dashboard.z_index == 1100,
		"battle log dashboard starts closed above battle-world presentation"
	)
	if log_dashboard != null:
		log_dashboard.call("render_snapshot", {"log_lines": ["第二条", "第一条"]})
		var log_text := log_dashboard.get_node_or_null("Panel/Content/LogText") as RichTextLabel
		_expect(
			log_text != null
				and log_text.get_parsed_text() == "【系统】  第二条\n【系统】  第一条"
				and log_text.get_theme_font_size("normal_font_size") == 26
				and log_text.get_theme_constant("line_separation") == 10,
			"battle log dashboard renders categorized readable Snapshot log lines"
		)
		log_dashboard.call("render_snapshot", {
			"phase": "battle",
			"battle_round": 1,
			"board": {"width": 2, "height": 2, "cells": []},
			"log_lines": [],
		})
		log_dashboard.call("render_snapshot", {
			"phase": "battle",
			"battle_round": 2,
			"board": {
				"width": 2,
				"height": 2,
				"cells": [
					{"x": 0, "y": 0, "elements": {"火": 2}},
					{"x": 1, "y": 0, "elements": {}},
					{"x": 0, "y": 1, "elements": {"水": 1}, "traces": [{"id": "trace"}]},
					{"x": 1, "y": 1, "elements": {}},
				],
			},
			"log_lines": ["进入第 2 回合。"],
		})
		var terrain_log := log_text.get_parsed_text()
		_expect(
				terrain_log.contains("【地形】  第1回合结束 · 2个格子带有元素")
					and terrain_log.contains("【地形】  第1回合的元素格子：第1行第1列（火2层）  |  第2行第1列（水1层）")
				and not terrain_log.contains("C2 无")
				and not terrain_log.contains("痕迹"),
			"battle log dashboard summarizes only cells with active element terrain"
		)
		var speed_button := log_dashboard.get_node_or_null("Panel/Content/Header/SpeedButton") as Button
		_expect(speed_button != null and speed_button.toggle_mode, "battle log dashboard preserves the 2x trace control")
		(battle.get_node("MapControls/SpeedButton") as TextureButton).pressed.emit()
		_expect(log_dashboard.visible, "left-bottom second button opens the battle log dashboard")
		var close_button := log_dashboard.get_node_or_null("Panel/Content/Header/CloseButton") as Button
		if close_button != null:
			close_button.pressed.emit()
		_expect(not log_dashboard.visible, "battle log dashboard close button closes the generated overlay")
	_expect(battle.get_node_or_null("OverlayHost/BattleActionPanel") == null, "OverlayHost does not absorb action controls")

	for prefab_path in PREFAB_PATHS:
		var prefab := load(prefab_path) as PackedScene
		_expect(prefab != null, "allowed reusable prefab loads: %s" % prefab_path)
		if prefab != null:
			var instance := prefab.instantiate()
			_expect(instance.scene_file_path == prefab_path, "allowed prefab has one formal source: %s" % prefab_path)
			instance.free()

	var probe := BattleSceneProbe.new(battle)
	_expect(probe.is_ready(), "test probe locates all battle responsibility roots")
	var reuse_summary := Dictionary(probe.spawn_prefab_samples())
	for result_key in ["banner_ok", "trap_ok"]:
		_expect(bool(reuse_summary.get(result_key, false)), "Scene-owned runtime feedback works: %s" % result_key)
	for result_key in ["projectile_ok", "damage_ok", "bite_ok"]:
		_expect(not bool(reuse_summary.get(result_key, false)), "blank board leaves pet-owned feedback dormant: %s" % result_key)
	var round_feedback := battle.find_child("RoundFeedback", true, false) as TextureRect
	_expect(
		round_feedback != null
			and round_feedback.scene_file_path.is_empty()
			and round_feedback.get_script() != null
			and round_feedback.get_node_or_null("Title") is Label
			and round_feedback.get_node_or_null("Subtitle") is Label,
		"RoundFeedback is a runtime Scene node, not a fifth prefab"
	)

	_finish(battle)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_BATTLE_ART_SCENE_FAIL: %s" % message)


func _finish(battle: Node) -> void:
	if battle != null:
		battle.queue_free()
		await process_frame
	print(
		"SMOKE_BATTLE_ART_SCENE_%s scenes=1 prefabs=%d"
		% ["FAIL" if _failed else "OK", PREFAB_PATHS.size()]
	)
	quit(1 if _failed else 0)
