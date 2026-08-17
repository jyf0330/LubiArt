extends SceneTree

const MAIN_SCENE := preload("res://art/scenes/app/game.tscn")
const GameSessionScript := preload("res://session/game_session.gd")

var _failed := false


func _initialize() -> void:
	var art := MAIN_SCENE.instantiate()
	var injected_session = GameSessionScript.new()
	art.call("set_game_session", injected_session)
	root.add_child(art)
	await process_frame
	await process_frame

	_expect(art.call("get_game_session") == injected_session, "Game preserves a session injected before mounting the view")
	var view: Node = art.call("get_three_choice_view")
	_expect(view != null, "Game owns the authored three-choice presentation")
	if view != null:
		_expect(not view.has_method("get_game_session"), "presentation view has no GameSession ownership API")

	var game_source := FileAccess.get_file_as_string("res://core_ui/scripts/app/game_controller.gd")
	var view_source := FileAccess.get_file_as_string("res://core_ui/scripts/artist_flow/scenes/three_choice_scene.gd")
	_expect(game_source.contains("SessionFactoryScript.create_local_result"), "Game creates and validates the default Session before configuring views")
	_expect(not game_source.contains("get_authority_state"), "Game never asks a view to provide authority")
	_expect(not game_source.contains("YsbzsState"), "Game does not construct the authoritative core type directly")
	_expect(not view_source.contains("SessionFactoryScript") and not view_source.contains("GameSession"), "presentation view neither creates nor owns a Session")

	root.remove_child(art)
	art.free()
	await process_frame

	if _failed:
		quit(1)
		return
	print("SMOKE_SESSION_FIRST_BOOTSTRAP_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_SESSION_FIRST_BOOTSTRAP_FAIL: %s" % message)
