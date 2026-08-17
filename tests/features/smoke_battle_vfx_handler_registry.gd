extends SceneTree

const BattleVfxControllerScript := preload("res://core_ui/scripts/battle/controllers/battle_vfx_controller.gd")


func _init() -> void:
	var ok := true
	var controller: Control = BattleVfxControllerScript.new()
	var registry: RefCounted = controller.call("vfx_handler_registry")
	var sequence_types: Array = registry.call("sequence_event_types")
	var instant_types: Array = registry.call("instant_event_types")
	for event_type in ["DAMAGE_APPLIED", "ATTACK_STRIKE", "ELEMENT_APPLIED", "PETS_RESET", "MOVE_MONSTER"]:
		ok = _expect(sequence_types.has(event_type), "sequence registry covers %s" % event_type) and ok
	for event_type in ["MOVE_HERO", "DAMAGE_APPLIED", "round_start", "shoot_projectile", "melee_bite", "damage", "spawn_trap", "death"]:
		ok = _expect(instant_types.has(event_type), "instant registry covers %s" % event_type) and ok
	ok = _expect(Callable(registry.call("sequence_handler", "MOVE_HERO", "")).is_valid(), "event type resolves sequence handler") and ok
	ok = _expect(Callable(registry.call("sequence_handler", "UNKNOWN", "movement")).is_valid(), "kind fallback resolves sequence handler") and ok
	ok = _expect(not Callable(registry.call("sequence_handler", "UNKNOWN", "unknown")).is_valid(), "unknown trace uses default delay") and ok
	controller.free()

	print("SMOKE_BATTLE_VFX_HANDLER_REGISTRY_%s" % ["OK" if ok else "FAIL"])
	quit(0 if ok else 1)


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		push_error("Failed: %s" % label)
	return condition
