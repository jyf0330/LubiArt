extends Control

## Public adapter around the authored combined ArtistFlow scene. The game shell
## talks only to this surface and never reaches into authored child nodes.

@onready var flow_controller: Node = $MainBG/Containers/Middle

var _configured_session: RefCounted = null


func configure(session: RefCounted) -> void:
	_configured_session = session
	var controller := _flow_controller()
	if session != null and controller != null and controller.has_method("set_game_session"):
		controller.call("set_game_session", session)
	if is_node_ready():
		call_deferred("render_current_snapshot")


func _ready() -> void:
	configure(_configured_session)


func get_game_session() -> RefCounted:
	var controller := _flow_controller()
	if controller != null and controller.has_method("get_game_session"):
		return controller.call("get_game_session")
	return null


func get_feature_controller(feature_name: StringName) -> Variant:
	var controller := _flow_controller()
	if controller != null and controller.has_method("get_feature_controller"):
		return controller.call("get_feature_controller", feature_name)
	return null


func render_current_snapshot() -> void:
	var controller := _flow_controller()
	if controller != null and controller.has_method("render_current_snapshot"):
		controller.call("render_current_snapshot")


func _flow_controller() -> Node:
	if is_instance_valid(flow_controller):
		return flow_controller
	return get_node_or_null("MainBG/Containers/Middle")
