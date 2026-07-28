extends TextureRect

## Presentation boundary for the authored three-choice surface. Ordinary
## containers and buttons stay scriptless. Middle keeps its controller because
## it is the independently stateful route/shop/bag workflow component.

@onready var flow_controller: Node = $Containers/Middle


func get_flow_controller() -> Node:
	if is_instance_valid(flow_controller):
		return flow_controller
	return get_node_or_null("Containers/Middle")


func get_content_root() -> Control:
	return get_node_or_null("Containers") as Control
