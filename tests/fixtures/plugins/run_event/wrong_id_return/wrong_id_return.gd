extends RefCounted

func plugin_id() -> int:
	return 7

func _validate_params(_params: Dictionary) -> Array[String]:
	return []

func execute(_port: RefCounted, _event: Dictionary, _context: Dictionary, _params: Dictionary) -> Dictionary:
	return {"ok": true, "code": "ok"}
