extends RefCounted

## Minimal system contract. Concrete systems declare their resource/component
## access so the schedule can reject ambiguous same-stage mutations.


func system_name() -> StringName:
	return &"battle_system"


func stage() -> int:
	return 0


func reads() -> Array[StringName]:
	return []


func writes() -> Array[StringName]:
	return []


func run(_world: RefCounted, _context: Dictionary = {}) -> Dictionary:
	return {"ok": true}
