extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const TraitServiceScript := preload("res://core/battle/traits/trait_service.gd")
const StatResolverScript := preload("res://core/stats/stat_resolver.gd")

const TRAIT_ID := "trait_bloodthirst"
const PET_ID := "pal_005"

var failed := false


func _initialize() -> void:
	var state := StateScript.new()
	var data := Dictionary(state.game_data)
	var trait_catalog := Dictionary(data.get("trait_catalog", {}))
	var stat_catalog := Dictionary(data.get("stat_catalog", {}))
	var definition := Dictionary(trait_catalog.get(TRAIT_ID, {}))
	_expect(not definition.is_empty(), "bloodthirst is present in the runtime trait catalog")
	_expect(String(definition.get("name", "")) == "嗜血", "bloodthirst exposes its player-facing name")

	var pet := _shop_pet(data, PET_ID)
	_expect(not pet.is_empty(), "the bloodthirst owner exists in runtime pet data")
	_expect(Array(pet.get("traits", [])).has(TRAIT_ID), "pal_005 owns bloodthirst in addition to its existing trait")

	var trait_service := TraitServiceScript.new()
	var skill_bundle := Dictionary(trait_service.modifiers(pet, trait_catalog, "skill"))
	var modifier := _modifier_for(Array(skill_bundle.get("modifiers", [])), "lifesteal_permille")
	_expect(not modifier.is_empty(), "bloodthirst contributes the common lifesteal stat to skill effects")
	_expect(int(modifier.get("value", 0)) == 100, "bloodthirst grants exactly 100 permille lifesteal")
	_expect(String(modifier.get("source_id", "")) == TRAIT_ID, "the modifier keeps truthful trait attribution")

	var combo_bundle := Dictionary(trait_service.modifiers(pet, trait_catalog, "combo"))
	_expect(not _modifier_for(Array(combo_bundle.get("modifiers", [])), "lifesteal_permille").is_empty(), "bloodthirst applies to every authoritative damage hook")

	var resolver := StatResolverScript.new()
	var ratio: int = int(resolver.value(pet, "lifesteal_permille", stat_catalog, Array(skill_bundle.get("modifiers", []))))
	_expect(ratio == 100, "final stat resolution exposes 10 percent lifesteal")

	var source := pet.duplicate(true)
	source["side"] = StateScript.PLAYER
	source["hp"] = 10
	var target := {"id": "bloodthirst_target", "name": "目标", "side": StateScript.ENEMY, "hp": 50, "max_hp": 50, "def": 0, "shield": 0}
	state.units = [source, target]
	var damage_result := Dictionary(state.call("_deal_damage", source, target, 25, "", true, {"sourceType": "skill"}))
	_expect(int(damage_result.get("hp_damage", 0)) == 25, "integration fixture deals 25 actual hp damage")
	_expect(int(source.get("hp", 0)) == 13, "bloodthirst heals 3 through the authoritative damage resolver")

	var plain_source := source.duplicate(true)
	plain_source["id"] = "plain_source"
	plain_source["traits"] = []
	plain_source["hp"] = 10
	var plain_target := target.duplicate(true)
	plain_target["id"] = "plain_target"
	plain_target["hp"] = 50
	state.units = [plain_source, plain_target]
	state.call("_deal_damage", plain_source, plain_target, 25, "", true, {"sourceType": "skill"})
	_expect(int(plain_source.get("hp", 0)) == 10, "a unit without bloodthirst receives no lifesteal healing")

	if failed:
		quit(1)
		return
	print("SMOKE_BLOODTHIRST_TRAIT_OK trait=%s pet=%s ratio=%d" % [TRAIT_ID, PET_ID, ratio])
	quit(0)


func _shop_pet(data: Dictionary, pet_id: String) -> Dictionary:
	for item_value in Array(Dictionary(data.get("economy", {})).get("shop_items", [])):
		var item := Dictionary(item_value)
		if String(item.get("id", item.get("pet_id", ""))) == pet_id:
			return item
	return {}


func _modifier_for(modifiers: Array, stat_id: String) -> Dictionary:
	for modifier_value in modifiers:
		var modifier := Dictionary(modifier_value)
		if String(modifier.get("stat", modifier.get("stat_id", ""))) == stat_id:
			return modifier
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
