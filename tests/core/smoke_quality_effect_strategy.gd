extends SceneTree

const RegistryScript := preload("res://core/battle/quality/quality_effect_registry.gd")
const LegacyCatalogScript := preload("res://core/battle/quality/legacy_quality_runtime_catalog.gd")
const ContextScript := preload("res://core/battle/quality/quality_effect_context.gd")
const GameStateScript := preload("res://core/state/game_state.gd")

var _failed := false


func _initialize() -> void:
	var registry := _legacy_registry()
	var context := ContextScript.new().configure(Callable(self, "_heal"))

	var gold_stance = registry.effect_for_id("G01")
	_expect(gold_stance.mode_options == ["攻", "守"], "G01 strategy exposes modes")
	_expect(gold_stance.normalize_mode("attack") == "攻", "G01 strategy normalizes attack alias")
	_expect(gold_stance.normalize_mode("防守") == "守", "G01 strategy normalizes guard alias")
	_expect(registry.effect_for_id("G17").supports_mark, "G17 strategy exposes mark capability")
	_expect(registry.effect_for_id("D11").actor_order == -1, "D11 strategy moves before default actors")
	_expect(registry.effect_for_id("D12").actor_order == 1, "D12 strategy moves after default actors")
	_expect(registry.effect_for_id("D01").changes_shape_name, "D01 strategy marks shape-name mutation")

	var silver_shield := _unit("S01", "银色护体", 10, 20, 1)
	var shield_logs: Array = registry.effect_for_unit(silver_shield).on_round_start(context, silver_shield)
	_expect(int(silver_shield.get("shield", 0)) == 16, "S01 strategy adds 15 shield")
	_expect(shield_logs.size() == 1, "S01 strategy preserves one trigger log")

	var silver_heal := _unit("S02", "银色疗愈", 5, 20, 0)
	registry.effect_for_unit(silver_heal).on_round_start(context, silver_heal)
	_expect(int(silver_heal.get("hp", 0)) == 20, "S02 strategy heals through narrow context")

	var silver_vitality := _unit("S03", "银色强命", 8, 10, 0)
	registry.effect_for_unit(silver_vitality).on_round_start(context, silver_vitality)
	registry.effect_for_unit(silver_vitality).on_round_start(context, silver_vitality)
	_expect(int(silver_vitality.get("max_hp", 0)) == 20, "S03 strategy applies max-hp growth once")
	_expect(int(silver_vitality.get("hp", 0)) == 18, "S03 strategy preserves existing hp delta semantics")

	var gold_guard := _unit("G01", "攻守转换", 8, 20, 0)
	var guard_logs: Array = registry.effect_for_unit(gold_guard).on_round_start(context, gold_guard)
	_expect(int(gold_guard.get("shield", 0)) == 8, "G01 strategy chooses guard below half hp")
	_expect(String(Dictionary(gold_guard.get("quality_runtime", {})).get("mode", "")) == "守", "G01 strategy stores deterministic mode")
	_expect(guard_logs.size() == 1, "G01 guard strategy preserves trigger log")

	var core := GameStateScript.new()
	_expect(core._quality_mode_options({"quality_upgrade": {"id": "G24"}}) == ["同", "主副"], "battle core delegates mode options to the composed runtime")
	_expect(core._unit_supports_quality_mark({"quality_upgrade": {"id": "G22"}}), "battle core delegates mark capability to the composed runtime")
	_expect(core._quality_actor_order({"quality_upgrade": {"id": "D12"}}) == 1, "battle core delegates actor order")
	var core_shield := _unit("S01", "银色护体", 10, 20, 2)
	core._apply_quality_round_start_to_unit(core_shield)
	_expect(int(core_shield.get("shield", 0)) == 17, "battle core delegates round start to strategy")
	_expect(core._quality_shape_name({"quality_upgrade": {"id": "D01", "name": "镜像"}}, "形状01") == "形状01+镜像", "battle core delegates shape naming")
	var battle_source := FileAccess.get_file_as_string("res://core/state/game_state.gd")
	_expect(not battle_source.contains("QualityEffectRegistryScript.new()"), "battle core does not cache a local quality registry")
	_expect(battle_source.contains("_core_composition.quality_runtime_service"), "mode and mark rules use the composed runtime service")
	_expect(battle_source.contains("_core_composition.quality_effect_registry"), "quality strategy calls use the current composed registry")
	var hit_projector_source := FileAccess.get_file_as_string("res://core/battle/quality/quality_hit_context_projector.gd")
	_expect(hit_projector_source.contains("var mode := String(runtime.get(\"mode\", \"\"))"), "damage context keeps raw stored mode instead of the display fallback")

	if _failed:
		quit(1)
		return
	print("SMOKE_QUALITY_EFFECT_STRATEGY_OK")
	quit(0)


func _legacy_registry() -> QualityEffectRegistry:
	var registry: QualityEffectRegistry = RegistryScript.new()
	var prepared := registry.prepare_configuration(
		LegacyCatalogScript.upgrades(),
		0,
		RegistryScript.PERSISTED_SNAPSHOT
	)
	_expect(bool(prepared.get("ok", false)), "legacy fixture configuration prepares")
	registry.commit_configuration(Dictionary(prepared.get("candidate", {})))
	_expect(registry.is_configured(), "legacy fixture configuration commits")
	return registry


func _unit(effect_id: String, effect_name: String, hp: int, max_hp: int, shield: int) -> Dictionary:
	return {
		"id": "unit_%s" % effect_id,
		"name": "测试宠物",
		"hp": hp,
		"max_hp": max_hp,
		"shield": shield,
		"quality_upgrade": {
			"id": effect_id,
			"name": effect_name,
		},
		"quality_runtime": {},
	}


func _heal(unit: Dictionary, amount: int) -> int:
	var before := int(unit.get("hp", 0))
	var after: int = min(int(unit.get("max_hp", before)), before + amount)
	unit["hp"] = after
	return after - before


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Quality strategy smoke failed: %s" % message)
