extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const MockSession := preload("res://session/mock_game_session.gd")
const OUTPUT_PATH := "res://output/attack_timeline_integrated_1920x1080.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame
	battle.call("render_snapshot", Dictionary(MockSession.new({"start_phase": "battle"}).call("current_snapshot")))
	await process_frame
	await process_frame
	var attack_order_button := battle.get_node("MapControls/AttackOrderButton") as TextureButton
	attack_order_button.pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("ATTACK_TIMELINE_CAPTURE_FAIL: %d" % error)
		quit(1)
		return
	print("ATTACK_TIMELINE_CAPTURE_PASS: %s" % OUTPUT_PATH)
	battle.queue_free()
	quit(0)
