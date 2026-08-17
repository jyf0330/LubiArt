extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var failed := false


func _initialize() -> void:
	var state: RefCounted = StateScript.new()
	_expect(state.dispatch({"type": "START_BATTLE"}), "boss-target fixture can start battle")
	for unit_value in state.units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == StateScript.ENEMY:
			unit["hp"] = 0
	state.pet_reset_charges[StateScript.ENEMY] = 0
	state.pet_reset_eligible[StateScript.ENEMY] = false
	state.ap = 1

	var plan := Dictionary(state.call("_build_auto_position_plan"))
	var actions := Array(plan.get("actions", []))
	_expect(not actions.is_empty(), "planner returns an executable action after all enemy pets are defeated")
	_expect(int(plan.get("bossDamage", 0)) > 0, "planner scores damage against the enemy boss")
	if not actions.is_empty():
		_expect(Array(Dictionary(actions[0]).get("targets", [])).has("enemy_boss"), "planned action targets the enemy boss")

	_expect(state.dispatch({"type": "AUTO_POSITION_HEROES"}), "boss-target auto-position is accepted")
	var boss_hp_before := int(state.enemy_hero_hp)
	_expect(state.dispatch({"type": "RUN_COMBAT_ROUND"}), "planned boss attack executes through the formal round command")
	_expect(int(state.enemy_hero_hp) < boss_hp_before, "formal round reduces enemy boss HP after its pets are defeated")
	_expect(_trace_has_boss_damage(state.battle_trace), "formal round emits boss DAMAGE_APPLIED trace")

	if failed:
		quit(1)
		return
	print("SMOKE_AUTO_POSITION_ATTACK_BOSS_OK")
	quit(0)


func _trace_has_boss_damage(events: Array) -> bool:
	for event_value in events:
		var event := Dictionary(event_value)
		if String(event.get("type", "")) != "DAMAGE_APPLIED":
			continue
		var target := Dictionary(event.get("target", {}))
		var payload := Dictionary(event.get("payload", {}))
		if String(target.get("id", "")) == "enemy_boss" and int(payload.get("finalDamage", 0)) > 0:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_AUTO_POSITION_ATTACK_BOSS_FAIL: %s" % message)
