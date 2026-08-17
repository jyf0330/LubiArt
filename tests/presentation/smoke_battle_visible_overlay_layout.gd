extends SceneTree

const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")
const ThreeChoiceCardScene := preload("res://art/prefabs/route/three_choice_card.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var battle := BattleScene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame

	var vfx_host := battle.get_node("Board/VfxHost") as Control
	assert(vfx_host.size.is_equal_approx(Vector2(1920, 1080)))
	var banner := vfx_host.call("play_round_banner", 6, "player") as Control
	await process_frame
	assert(banner != null)
	assert(banner.position.x > 400.0 and banner.position.y > 300.0)
	assert(banner.position.x + banner.size.x < 1600.0)
	assert(banner.position.y + banner.size.y < 900.0)

	var hud := battle.get_node("Hud") as Control
	var timeline_layer := battle.get_node("Hud/AttackTimelineLayer") as CanvasLayer
	assert(not hud.visible)
	hud.call("toggle_attack_timeline")
	assert(bool(hud.call("debug_is_attack_timeline_open")))
	assert(timeline_layer.visible)
	hud.call("close_attack_timeline")

	var route_card := ThreeChoiceCardScene.instantiate() as Control
	root.add_child(route_card)
	await process_frame
	var portrait := route_card.get_node("Portrait") as TextureRect
	assert(portrait.expand_mode == TextureRect.EXPAND_IGNORE_SIZE)
	var authored_portrait_size := portrait.size
	var oversized_image := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	oversized_image.fill(Color.WHITE)
	var oversized_texture := ImageTexture.create_from_image(oversized_image)
	route_card.call("set_portrait", oversized_texture)
	await process_frame
	assert(portrait.size.is_equal_approx(authored_portrait_size))
	assert(portrait.size.is_equal_approx(Vector2(207.0, 247.0)))

	print("SMOKE_BATTLE_VISIBLE_OVERLAY_LAYOUT_PASS")
	quit(0)
