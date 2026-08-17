extends SceneTree

const ShopEffectRegistryScript := preload("res://core/shop/shop_effect_registry.gd")

const VALID_DIRECTORY := "res://tests/fixtures/plugins/shop/valid"
const INVALID_CASES := {
	"res://tests/fixtures/plugins/shop/duplicate": ["fixture_duplicate", "Duplicate plugin id"],
	"res://tests/fixtures/plugins/shop/missing_method": ["fixture_missing_execute", "missing required methods"],
	"res://tests/fixtures/plugins/shop/wrong_arity": ["fixture_wrong_arity", "execute expected 3 found 2"],
}

var _failed := false


func _initialize() -> void:
	_verify_discovery_and_stable_order()
	_verify_invalid_registries_fail_closed()
	if _failed:
		quit(1)
		return
	print("SMOKE_SHOP_EFFECT_PLUGIN_DISCOVERY_OK valid=3 invalid=3")
	quit(0)


func _verify_discovery_and_stable_order() -> void:
	var registry: RefCounted = ShopEffectRegistryScript.new(VALID_DIRECTORY)
	_expect(registry.is_valid(), "fixture handlers are discovered without registry edits")
	_expect(registry.validation_errors().is_empty(), "valid fixture registry reports no errors")
	_expect(registry.registered_effects() == ["fixture_alpha", "fixture_beta", "fixture_new_handler"], "discovered IDs use stable lexical ordering")
	var handler: RefCounted = registry.handler_for("fixture_new_handler")
	_expect(handler != null, "new fixture handler resolves through the generic wrapper")
	if handler != null:
		var result := Dictionary(handler.execute(null, {"id": "offer"}, {"type": "fixture_new_handler", "value": 7}))
		_expect(result == {"type": "fixture_new_handler", "text": "fixture:7"}, "new fixture handler executes without registry branching")


func _verify_invalid_registries_fail_closed() -> void:
	for directory_value in INVALID_CASES.keys():
		var directory := String(directory_value)
		var case := Array(INVALID_CASES[directory])
		var plugin_id := String(case[0])
		var expected_error := String(case[1])
		var registry: RefCounted = ShopEffectRegistryScript.new(directory)
		_expect(not registry.is_valid(), "%s invalidates the whole registry" % directory)
		_expect(registry.registered_effects().is_empty(), "%s exposes no partial IDs" % directory)
		_expect(registry.handler_for(plugin_id) == null, "%s exposes no known handler" % directory)
		_expect(registry.handler_for("unknown") == null, "%s exposes no unknown handler" % directory)
		_expect("\n".join(registry.validation_errors()).contains(expected_error), "%s reports its deterministic contract error" % directory)


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("SMOKE_SHOP_EFFECT_PLUGIN_DISCOVERY_FAIL: %s" % label)
