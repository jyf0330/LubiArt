extends SceneTree

const DEBUG_SCENE := preload("res://art/scenes/sprite_info_card_debug/sprite_info_card_debug_scene.tscn")


func _initialize() -> void:
	root.title = "SpriteInfoCard 独立调试面板"
	root.size = Vector2i(1920, 1080)
	root.min_size = Vector2i(1280, 720)
	call_deferred("_build_tool")


func _build_tool() -> void:
	root.add_child(DEBUG_SCENE.instantiate())
