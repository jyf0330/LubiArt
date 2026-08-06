extends Control

const GameLogScript := preload("res://core/logging/game_log.gd")
const DEBUG_BUTTON_PATH := "MainBG/DebugButton"

const REPLACEMENT_GROUPS: Array[Dictionary] = []


func _ready() -> void:
	var debug_button := get_node_or_null(DEBUG_BUTTON_PATH) as BaseButton
	if debug_button == null:
		GameLogScript.warning("调试界面/图片替换", "找不到调试按钮", {"节点路径": DEBUG_BUTTON_PATH})
		return

	debug_button.pressed.connect(_on_debug_button_pressed)


func _on_debug_button_pressed() -> void:
	for group in REPLACEMENT_GROUPS:
		var container_path := group["container_path"] as String
		var texture := group["texture"] as Texture2D
		var container := get_node_or_null(container_path)
		if container == null:
			GameLogScript.warning("调试界面/图片替换", "找不到待替换容器", {"节点路径": container_path})
			continue

		var replaced_count := _replace_texture_buttons(container, texture)
		if replaced_count == 0:
			GameLogScript.warning("调试界面/图片替换", "容器内没有可替换的图片按钮", {"节点路径": container_path})


func _replace_texture_buttons(node: Node, texture: Texture2D) -> int:
	var replaced_count := 0

	if node is TextureButton:
		node.texture_normal = texture
		replaced_count += 1

	for child in node.get_children():
		replaced_count += _replace_texture_buttons(child, texture)

	return replaced_count
