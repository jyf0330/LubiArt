extends Control

## Reusable route-card presentation only. Static geometry and authored textures
## live in the prefab and in the three instance overrides of ThreeChoiceScene.


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
