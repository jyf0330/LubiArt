extends SceneTree

const ThreeChoiceScene := preload("res://art/scenes/app/game.tscn")
const BattleScene := preload("res://art/scenes/battle/battle_art_scene.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var three_choice := ThreeChoiceScene.instantiate() as Control
	var battle := BattleScene.instantiate() as Control
	if three_choice == null or battle == null:
		push_error("The two formal art Scenes must both instantiate.")
		quit(1)
		return
	root.add_child(three_choice)
	root.add_child(battle)
	await process_frame
	var route_card_grid := three_choice.find_child("CardGrid", true, false)
	var board_grid := battle.get_node_or_null("Board/CellHost")
	if route_card_grid == null or route_card_grid.get_child_count() != 3:
		push_error("Three-choice CardGrid must own the three authored route cards.")
		quit(1)
		return
	if board_grid == null or board_grid.get_child_count() != 56:
		push_error("Battle Scene must expose the default 8x7 terrain leaf grid under CellHost.")
		quit(1)
		return
	print("SMOKE_ARTIST_STUDIO_SCENE_OK scenes=2")
	quit(0)
