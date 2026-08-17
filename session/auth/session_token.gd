extends RefCounted

## Short-lived HMAC-SHA256 bearer tokens for authoritative sessions. Secrets
## are supplied by the environment/deployment layer and never enter saves,
## snapshots, logs, or repository files.

const SCHEMA := "ysbzs.session-token.v1"


static func issue(secret: String, actor_id: String, session_id: String, ttl_seconds: int = 300, scope: String = "player", now_unix: int = 0) -> String:
	if secret.length() < 32 or actor_id.is_empty() or session_id.is_empty():
		return ""
	var issued_at := now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var payload := {
		"schema": SCHEMA,
		"actorId": actor_id,
		"sessionId": session_id,
		"scope": "developer" if scope == "developer" else "player",
		"iat": issued_at,
		"exp": issued_at + clampi(ttl_seconds, 1, 86400),
	}
	var encoded := _base64url(JSON.stringify(payload).to_utf8_buffer())
	return "%s.%s" % [encoded, _signature(secret, encoded)]


static func verify(secret: String, token: String, now_unix: int = 0) -> Dictionary:
	if secret.length() < 32:
		return _error("AUTH_SECRET_INVALID")
	var parts := token.split(".", false)
	if parts.size() != 2 or not _constant_time_equal(String(parts[1]), _signature(secret, String(parts[0]))):
		return _error("AUTH_TOKEN_SIGNATURE_INVALID")
	var decoded := _base64url_decode(String(parts[0]))
	var parsed: Variant = JSON.parse_string(decoded.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _error("AUTH_TOKEN_PAYLOAD_INVALID")
	var claims := Dictionary(parsed)
	if String(claims.get("schema", "")) != SCHEMA or String(claims.get("actorId", "")).is_empty() or String(claims.get("sessionId", "")).is_empty():
		return _error("AUTH_TOKEN_CLAIMS_INVALID")
	if not ["player", "developer"].has(String(claims.get("scope", ""))):
		return _error("AUTH_TOKEN_SCOPE_INVALID")
	var current_time := now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var issued_at := int(claims.get("iat", current_time + 1))
	var expires_at := int(claims.get("exp", 0))
	if expires_at <= current_time:
		return _error("AUTH_TOKEN_EXPIRED")
	if issued_at > current_time + 30:
		return _error("AUTH_TOKEN_NOT_YET_VALID")
	if expires_at <= issued_at or expires_at - issued_at > 86400:
		return _error("AUTH_TOKEN_LIFETIME_INVALID")
	return {"ok": true, "claims": claims.duplicate(true)}


static func _signature(secret: String, encoded_payload: String) -> String:
	return Crypto.new().hmac_digest(
		HashingContext.HASH_SHA256,
		secret.to_utf8_buffer(),
		encoded_payload.to_utf8_buffer()
	).hex_encode()


static func _base64url(value: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(value).replace("+", "-").replace("/", "_").trim_suffix("=").trim_suffix("=")


static func _base64url_decode(value: String) -> PackedByteArray:
	var padded := value.replace("-", "+").replace("_", "/")
	while padded.length() % 4 != 0:
		padded += "="
	return Marshalls.base64_to_raw(padded)


static func _constant_time_equal(left: String, right: String) -> bool:
	if left.length() != right.length():
		return false
	var difference := 0
	for index in range(left.length()):
		difference |= left.unicode_at(index) ^ right.unicode_at(index)
	return difference == 0


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error": {"code": code}}
