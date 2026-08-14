extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const ROUND_FONT_PATH := "res://art/images/shared/pets/info_card/fonts/fusion_pixel_zh_hans.ttf"


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred("_run")


func _run() -> void:
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame

	for round_number in [1, 2, 3]:
		battle.call("render_snapshot", _snapshot(round_number))
		await process_frame
		await process_frame
		var vfx_host := battle.get_node("Board/VfxHost")
		var banners := vfx_host.get_children().filter(
			func(child: Node) -> bool: return child.name == &"RoundFeedback"
		)
		assert(banners.size() == 1)
		var banner := banners[0] as Control
		assert(int(banner.get_meta("round_number", -1)) == round_number)
		var title := banner.get_node("Title") as Label
		var subtitle := banner.get_node("Subtitle") as Label
		assert(title.text == "第%d回合" % round_number)
		assert(not subtitle.visible)
		assert(title.get_theme_font("font") == subtitle.get_theme_font("font"))
		assert(title.get_theme_font("font").resource_path == ROUND_FONT_PATH)

		battle.call("render_snapshot", _snapshot(round_number))
		await process_frame
		var repeated_banners := vfx_host.get_children().filter(
			func(child: Node) -> bool: return child.name == &"RoundFeedback"
		)
		assert(repeated_banners.size() == 1)

	print("SMOKE_BATTLE_ROUND_BANNER_PASS rounds=1,2,3 font=%s" % ROUND_FONT_PATH)
	quit(0)


func _snapshot(round_number: int) -> Dictionary:
	return {
		"phase": "battle",
		"battle_round": round_number,
		"battleRound": round_number,
		"board_width": 8,
		"board_height": 8,
		"board": {"cells": []},
		"units": [],
		"battleTrace": [],
		"battle_trace": [],
		"next_actions": [],
		"nextActions": [],
	}
