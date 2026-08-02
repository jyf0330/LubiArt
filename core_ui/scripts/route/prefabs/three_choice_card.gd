extends Control

## Reusable route-card presentation only. Authored child geometry and default
## textures live in this prefab; ThreeChoiceScene keeps the three approved card
## instances, portrait resources, and per-card geometry visible in its Scene tree.


func set_portrait(texture: Texture2D) -> void:
	var portrait := get_node_or_null("Portrait") as TextureRect
	if portrait != null:
		portrait.texture = texture


func set_kind_icon(texture: Texture2D) -> void:
	var icon := get_node_or_null("KindIcon") as TextureRect
	if icon != null:
		icon.texture = texture


func set_route_highlight(texture: Texture2D) -> void:
	var highlight := get_node_or_null("RouteHighlight") as TextureRect
	if highlight != null:
		highlight.texture = texture


func set_hovered(is_hovered: bool) -> void:
	var smoke := get_node_or_null("HoverSmoke") as CanvasItem
	if smoke != null:
		smoke.visible = is_hovered
	var highlight := get_node_or_null("RouteHighlight") as CanvasItem
	if highlight != null:
		highlight.visible = is_hovered


func clear() -> void:
	set_portrait(null)
	set_route_highlight(null)
	set_hovered(false)
