extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const RegistryScript := preload("res://core/content/content_object_registry.gd")

const BASE_STAT_KEYS := ["max_hp", "atk", "def", "starting_shield", "action_points"]
const TOP_LEVEL_KEYS := {
	"max_hp": "max_hp",
	"atk": "atk",
	"def": "def",
	"starting_shield": "shield",
	"action_points": "ap",
}

var failed := false


func _initialize() -> void:
	var data := Dictionary(StateScript.new().game_data)
	var pets := Array(Dictionary(data.get("economy", {})).get("shop_items", []))
	_expect(pets.size() == 369, "formal content exports all 369 pets")
	for value in pets:
		var pet := Dictionary(value)
		var pet_id := String(pet.get("pet_id", pet.get("id", "")))
		var base_stats_value: Variant = pet.get("base_stats")
		_expect(base_stats_value is Dictionary, "%s carries base_stats" % pet_id)
		if not base_stats_value is Dictionary:
			continue
		var base_stats := Dictionary(base_stats_value)
		for stat_key in BASE_STAT_KEYS:
			_expect(base_stats.has(stat_key), "%s base_stats has %s" % [pet_id, stat_key])
			var top_level_key := String(TOP_LEVEL_KEYS[stat_key])
			_expect(pet.has(top_level_key), "%s top level has %s" % [pet_id, top_level_key])
			_expect(int(pet.get(top_level_key)) == int(base_stats.get(stat_key)), "%s %s has one data value" % [pet_id, stat_key])
	_expect(pets.all(func(value: Variant) -> bool: return int(Dictionary(value).get("def")) == 0), "base defense is explicitly data-owned and currently zero")
	_verify_registry_fails_closed(data)
	_verify_no_pet_panel_defaults_in_code()
	if failed:
		quit(1)
		return
	print("SMOKE_PET_BASE_STATS_DATA_DRIVEN_OK pets=%d" % pets.size())
	quit(0)


func _verify_registry_fails_closed(data: Dictionary) -> void:
	var broken := data.duplicate(true)
	var economy := Dictionary(broken.get("economy", {})).duplicate(true)
	var items := Array(economy.get("shop_items", [])).duplicate(true)
	var first := Dictionary(items[0]).duplicate(true)
	first.erase("base_stats")
	items[0] = first
	economy["shop_items"] = items
	broken["economy"] = economy
	var prepared := Dictionary(RegistryScript.new().prepare_configuration(broken, &"test"))
	_expect(not bool(prepared.get("ok", true)), "missing pet base_stats fails closed")
	_expect(Array(prepared.get("errors", [])).any(func(value: Variant) -> bool: return String(value).begins_with("PET_BASE_STATS_")), "missing pet base_stats reports a data error")


func _verify_no_pet_panel_defaults_in_code() -> void:
	var exporter := FileAccess.get_file_as_string("res://tools/export_pet_catalogs.py")
	for field in ["HP", "攻", "防", "盾", "行动"]:
		_expect(exporter.find("as_int(row.get(\"%s\")," % field) < 0, "exporter has no numeric fallback for %s" % field)
	var panel := FileAccess.get_file_as_string("res://core_ui/scripts/shared/pet/pet_info_panel_v2.gd")
	_expect(panel.find("\"hp\": 24") < 0 and panel.find("\"attack\": 4") < 0, "pet panel has no example base stats")
	var rank := FileAccess.get_file_as_string("res://core_ui/scripts/shared/pet/sprite_rank_stats.gd")
	for field in ["hp_current", "hp_max", "ap_current", "ap_max", "attack", "defense", "shield", "regen"]:
		_expect(not RegEx.create_from_string("@export var %s\\s*:?[^=\\n]*=\\s*-?\\d+" % field).search(rank), "rank resource has no numeric default for %s" % field)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
