extends Control

## Presentation boundary for the CellDetail secondary group. Pet and terrain
## detail prefabs remain independently reusable special children.


func mount_detail_panel(panel: Control) -> void:
	if panel != null:
		add_child(panel)


func get_detail_panel(node_name: StringName) -> Control:
	return get_node_or_null(NodePath(String(node_name))) as Control
