extends Control

## Presentation boundary for the TopInfoBar secondary group. The group is an
## authored placeholder until the official top-bar layers arrive; ordinary
## visual children should be managed here instead of receiving ad-hoc scripts.


func add_runtime_content(content: Control) -> void:
	if content != null:
		add_child(content)


func get_runtime_content(node_name: StringName) -> Control:
	return get_node_or_null(NodePath(String(node_name))) as Control
