extends SceneTree

const SessionTokenScript := preload("res://session/auth/session_token.gd")
const WebSocketTransportScript := preload("res://session/transport/websocket_session_transport.gd")
const WebSocketServerScript := preload("res://session/server/websocket_authority_server.gd")


func _initialize() -> void:
	var secret := "commercial-session-secret-at-least-32-bytes"
	var token := SessionTokenScript.issue(secret, "player-1", "match-1", 60, "player", 1000)
	var verified := SessionTokenScript.verify(secret, token, 1010)
	var ok := bool(verified.get("ok", false))
	ok = _expect(WebSocketTransportScript.new() != null and WebSocketServerScript.new() != null, "production WebSocket adapters compile") and ok
	var claims := Dictionary(verified.get("claims", {}))
	ok = _expect(ok and String(claims.get("actorId", "")) == "player-1", "valid token preserves actor") and ok
	ok = _expect(not bool(SessionTokenScript.verify(secret, token + "x", 1010).get("ok", false)), "tampered token is rejected") and ok
	ok = _expect(String(Dictionary(SessionTokenScript.verify(secret, token, 2000).get("error", {})).get("code", "")) == "AUTH_TOKEN_EXPIRED", "expired token is rejected") and ok
	ok = _expect(SessionTokenScript.issue("short", "player", "match").is_empty(), "short deployment secret cannot issue tokens") and ok
	print("SMOKE_SESSION_TOKEN_%s" % ("OK" if ok else "FAIL"))
	quit(0 if ok else 1)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("SESSION_TOKEN_FAIL: %s" % message)
	return false
