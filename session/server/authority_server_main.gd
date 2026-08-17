extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const WebSocketAuthorityServerScript := preload("res://session/server/websocket_authority_server.gd")

var _server: RefCounted


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var secret := OS.get_environment("YSBZS_SESSION_SECRET")
	var session_id := OS.get_environment("YSBZS_SESSION_ID").strip_edges()
	var bind_address := OS.get_environment("YSBZS_BIND_ADDRESS").strip_edges()
	var port_text := OS.get_environment("YSBZS_PORT").strip_edges()
	if session_id == "":
		session_id = "production"
	if bind_address == "":
		bind_address = "127.0.0.1"
	var port := int(port_text) if port_text.is_valid_int() else 9080
	var authority := StateScript.new({"mode": "production"})
	if not bool(authority.call("is_initialized")):
		push_error("AUTHORITY_INIT_FAILED:%s" % JSON.stringify(authority.call("initialization_result")))
		quit(78)
		return
	_server = WebSocketAuthorityServerScript.new()
	var result := Dictionary(_server.call("start", authority, secret, session_id, port, bind_address))
	if not bool(result.get("ok", false)):
		push_error("AUTHORITY_SERVER_START_FAILED:%s" % JSON.stringify(result))
		quit(78)
		return
	print("AUTHORITY_SERVER_READY bind=%s port=%d session=%s" % [bind_address, port, session_id])
	while true:
		_server.call("poll")
		await process_frame


func _finalize() -> void:
	if _server != null:
		_server.call("stop")
