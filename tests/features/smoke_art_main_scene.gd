extends SceneTree

const GAME_SCENE_PATH := "res://art/scenes/app/game.tscn"
const THREE_CHOICE_SCENE_PATH := "res://art/scenes/three_choice/three_choice_scene.tscn"
const VIEW_SCRIPT_PATH := "res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd"

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		String(ProjectSettings.get_setting("application/run/main_scene", "")) == GAME_SCENE_PATH,
		"project starts from the persistent Game composition"
	)
	var art_packed := load(GAME_SCENE_PATH) as PackedScene
	_expect(art_packed != null, "Game Scene loads")
	if art_packed == null:
		_finish()
		return

	var art := art_packed.instantiate() as Control
	root.add_child(art)
	await process_frame
	await process_frame
	_expect(art.name == "Game", "formal root is named Game")
	var route_scene := art.get_node_or_null("ThreeChoiceScene") as Control
	_expect(route_scene != null and route_scene.scene_file_path == THREE_CHOICE_SCENE_PATH, "Game owns the authored three-choice page")
	var main_bg := route_scene.get_node_or_null("MainBG") as Control if route_scene != null else null
	_expect(
		route_scene != null
			and route_scene.get_script() != null
			and String(route_scene.get_script().resource_path) == VIEW_SCRIPT_PATH,
		"ThreeChoiceScene root owns its presentation script"
	)
	_expect(main_bg != null and main_bg.get_script() == null, "ordinary MainBG stays scriptless")
	_expect(art.get_node_or_null("FeatureHost") != null, "Game owns the battle feature host")
	_expect(art.get_node_or_null("ViewHost") == null, "three-choice Scene has no redundant self-wrapper view host")
	_expect(art.has_method("get_game_session") and art.call("get_game_session") != null, "Game owns the GameSession boundary")
	_expect(route_scene != null and not route_scene.has_method("get_game_session"), "three-choice page has no Session ownership API")
	_expect(
		route_scene != null and route_scene.find_child("CardGrid", true, false).get_child_count() == 3,
		"three-choice Scene directly contains its three authored option slots"
	)
	for ordinary_child_path in [
		"MainBG/Containers",
		"MainBG/Containers/Bags",
		"MainBG/Containers/Party",
	]:
		var ordinary_child := route_scene.get_node_or_null(ordinary_child_path) if route_scene != null else null
		_expect(
			ordinary_child != null and ordinary_child.get_script() == null,
			"ordinary three-choice child stays scriptless: %s" % ordinary_child_path
		)
	var middle := route_scene.get_node_or_null("MainBG/Containers/Middle") if route_scene != null else null
	_expect(
		middle != null and middle.get_script() == null,
		"ordinary route/shop/bag layout group stays scriptless"
	)
	art.queue_free()
	await process_frame
	await process_frame

	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_ART_MAIN_SCENE_FAIL: %s" % message)


func _finish() -> void:
	print("SMOKE_ART_MAIN_SCENE_%s main=%s" % ["FAIL" if _failed else "OK", GAME_SCENE_PATH])
	quit(1 if _failed else 0)
