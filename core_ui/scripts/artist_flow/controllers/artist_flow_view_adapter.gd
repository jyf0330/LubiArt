extends Control

## Public adapter around the authored combined ArtistFlow scene. The game shell
## talks only to this surface and never reaches into authored child nodes.

signal feature_view_requested(feature_id: StringName)
signal feature_view_release_requested(feature_id: StringName)

@onready var ui_surface: Control = $MainBG
@onready var flow_controller: Node = ui_surface.call("get_flow_controller") as Node

var _configured_session: RefCounted = null


func configure(session: RefCounted) -> void:
	_configured_session = session
	var controller := _flow_controller()
	if session != null and controller != null and controller.has_method("set_game_session"):
		controller.call("set_game_session", session)
	if is_node_ready():
		call_deferred("render_current_snapshot")


func _ready() -> void:
	_bind_flow_controller_signals()
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


func attach_feature_view(feature_id: StringName, view: Node) -> void:
	var controller := _flow_controller()
	if controller != null and controller.has_method("attach_feature_view"):
		controller.call("attach_feature_view", feature_id, view)


func detach_feature_view(feature_id: StringName, view: Node = null) -> void:
	var controller := _flow_controller()
	if controller != null and controller.has_method("detach_feature_view"):
		controller.call("detach_feature_view", feature_id, view)


func _bind_flow_controller_signals() -> void:
	var controller := _flow_controller()
	if controller == null:
		return
	var request_callback := Callable(self, "_on_feature_view_requested")
	var release_callback := Callable(self, "_on_feature_view_release_requested")
	if controller.has_signal("feature_view_requested") \
			and not controller.is_connected("feature_view_requested", request_callback):
		controller.connect("feature_view_requested", request_callback)
	if controller.has_signal("feature_view_release_requested") \
			and not controller.is_connected("feature_view_release_requested", release_callback):
		controller.connect("feature_view_release_requested", release_callback)


func _on_feature_view_requested(feature_id: StringName) -> void:
	feature_view_requested.emit(feature_id)


func _on_feature_view_release_requested(feature_id: StringName) -> void:
	feature_view_release_requested.emit(feature_id)


func _flow_controller() -> Node:
	if is_instance_valid(flow_controller):
		return flow_controller
	if is_instance_valid(ui_surface) and ui_surface.has_method("get_flow_controller"):
		return ui_surface.call("get_flow_controller") as Node
	return get_node_or_null("MainBG/Containers/Middle")
