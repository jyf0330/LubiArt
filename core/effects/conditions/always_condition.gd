extends RefCounted
func plugin_id() -> String: return "always"
func matches(_condition: Dictionary, _context: Dictionary) -> bool: return true
