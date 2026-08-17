extends SceneTree

const DamagePropsScript := preload("res://core/battle/damage_props.gd")
const BlockDamageConsumerScript := preload("res://core/stats/consumers/block_damage_consumer.gd")
const DodgeDamageConsumerScript := preload("res://core/stats/consumers/dodge_damage_consumer.gd")

var failed := false


func _initialize() -> void:
	_test_production_presets_and_source_mapping()
	_test_receiver_consumers_respect_props()
	_test_production_callers_close_the_lifecycle()
	if failed:
		quit(1)
		return
	print("SMOKE_STS2_DAMAGE_PRODUCTION_OK")
	quit(0)


func _test_production_presets_and_source_mapping() -> void:
	var action := DamagePropsScript.for_source_type("action")
	_expect(DamagePropsScript.is_move(action) and DamagePropsScript.is_powered(action) and DamagePropsScript.is_blockable(action), "actions default to powered blockable move damage")
	var effect := DamagePropsScript.for_source_type("element_settlement")
	_expect(not DamagePropsScript.is_move(effect) and not DamagePropsScript.is_powered(effect) and DamagePropsScript.is_blockable(effect), "non-attack effects fail safe to non-move unpowered damage")
	var hp_loss := DamagePropsScript.for_source_type("hp_loss")
	_expect(not DamagePropsScript.is_move(hp_loss) and not DamagePropsScript.is_powered(hp_loss) and not DamagePropsScript.is_blockable(hp_loss), "HP loss composes unpowered and unblockable without a second formula")
	var explicit := DamagePropsScript.resolve({"move": false}, "action")
	_expect(not DamagePropsScript.is_move(explicit) and DamagePropsScript.is_powered(explicit), "an explicit declaration overrides source inference even when its value is false")


func _test_receiver_consumers_respect_props() -> void:
	var block := BlockDamageConsumerScript.new()
	var dodge := DodgeDamageConsumerScript.new()
	var target := {"block_rate_permille": 1000, "block_value": 2, "dodge_rate_permille": 1000}
	var move_context := {"amount": 5, "target": target, "event_seed": "move", "damage_props": DamagePropsScript.move_damage()}
	var blocked := block.apply(move_context.duplicate(true))
	_expect(bool(blocked.get("blocked", false)) and int(blocked.get("amount", -1)) == 3, "block consumes only a blockable move packet")
	var dodged := dodge.apply(move_context.duplicate(true))
	_expect(bool(dodged.get("dodged", false)) and int(dodged.get("amount", -1)) == 0, "dodge consumes only a blockable move packet")
	var effect_context := {"amount": 5, "target": target, "event_seed": "effect", "damage_props": DamagePropsScript.non_move_unpowered()}
	_expect(int(block.apply(effect_context.duplicate(true)).get("amount", -1)) == 5 and int(dodge.apply(effect_context.duplicate(true)).get("amount", -1)) == 5, "environmental damage is not randomly blocked or dodged")
	var hp_loss_context := {"amount": 5, "target": target, "event_seed": "loss", "damage_props": DamagePropsScript.move_hp_loss()}
	_expect(int(block.apply(hp_loss_context.duplicate(true)).get("amount", -1)) == 5 and int(dodge.apply(hp_loss_context.duplicate(true)).get("amount", -1)) == 5, "unblockable packets bypass random receiver defenses even when marked move")


func _test_production_callers_close_the_lifecycle() -> void:
	var battle_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	var run_source := battle_source
	var skill_source := FileAccess.get_file_as_string("res://core/ports/skill_effect_port.gd")
	var mechanic_source := FileAccess.get_file_as_string("res://core/battle/mechanics/damage_mechanic_service.gd")
	var quality_splash_source := FileAccess.get_file_as_string("res://core/battle/quality/operations/adjacent_splash.gd")
	var quality_chase_source := FileAccess.get_file_as_string("res://core/battle/quality/operations/kill_chase.gd")
	_expect(battle_source.contains("DamagePropsScript.resolve(damage_props"), "authority maps undeclared production damage through one fail-safe props boundary")
	_expect(run_source.contains("DamagePropsScript.move_damage()") and run_source.contains("pending_damage_deaths"), "player and enemy actions declare move damage and share batch death settlement")
	_expect(skill_source.contains("deferDeathResolution") and skill_source.contains("_resolve_damage_deaths") and skill_source.contains("DamagePropsScript.move_damage()"), "multi-target skills finish packet hooks before one death safe point")
	_expect(not mechanic_source.contains("source[\"hp\"] = max(0, hp_before - reflect)") and mechanic_source.contains("DamagePropsScript.non_move_unpowered()"), "reflection and splash route through the unified pipeline instead of writing HP")
	_expect(
		mechanic_source.contains("resolve_damage_deaths")
			and quality_splash_source.contains("quality_splash")
			and quality_splash_source.contains("resolve_damage_deaths")
			and quality_splash_source.contains("DamagePropsScript.non_move_unpowered()")
			and quality_chase_source.contains("quality_chase")
			and quality_chase_source.contains("DamagePropsScript.move_damage()"),
		"mechanism and quality AoE declare source semantics and batch deaths"
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
