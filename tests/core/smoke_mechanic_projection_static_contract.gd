extends SceneTree

const COMPOSITION_PATH := "res://core/composition/core_composition.gd"
const PROJECTION_PATH := "res://core/battle/mechanics/mechanic_projection_service.gd"
const STATE_PATH := "res://core/state/game_state.gd"
const TRACE_FACTORY_PATH := "res://core/battle/battle_trace_factory.gd"
const ATTACK_STRIKE_HEAD_SHA256 := "5b4b5c6c9df1ef2246e363bdf604979a9e8796e44e0d2ec7672d3cfaf03af931"

const BUSINESS_CONSUMER_PATHS := [
	STATE_PATH,
	"res://core/commands/battle_query_projector.gd",
	"res://core/battle/auto_position/auto_position_evaluator.gd",
	TRACE_FACTORY_PATH,
	"res://core/battle/threat_target_policy.gd",
]

const REGISTRY_SERVICE_PATHS := {
	"round_lifecycle_service": "res://core/battle/round_lifecycle_service.gd",
	"damage_mechanic_service": "res://core/battle/mechanics/damage_mechanic_service.gd",
	"unit_lifecycle_mechanic_service": "res://core/battle/mechanics/unit_lifecycle_mechanic_service.gd",
	"element_mechanic_service": "res://core/battle/mechanics/element_mechanic_service.gd",
}

var failed := false


func _initialize() -> void:
	var composition_source := _source(COMPOSITION_PATH)
	var projection_source := _source(PROJECTION_PATH)
	_expect(not composition_source.is_empty(), "composition source exists")
	_expect(not projection_source.is_empty(), "mechanic projection source exists")

	for path_value in BUSINESS_CONSUMER_PATHS:
		var path := String(path_value)
		var source := _source(path)
		_expect(not source.is_empty(), "%s exists" % path)
		_expect(not source.contains('"mech_'), "%s contains zero mechanic business ID literals" % path)
		_expect(not source.contains("MechanicHandlerRegistryScript"), "%s does not construct a second mechanic registry" % path)
		_expect(not source.contains("mechanic_handler_registry"), "%s does not own a parallel mechanic registry" % path)
		_expect(not source.contains("MechanicCatalog") and not source.contains("mechanic_catalog"), "%s does not own a mechanic catalog authority" % path)

	for service_value in REGISTRY_SERVICE_PATHS:
		var service_name := String(service_value)
		var service_source := _source(String(REGISTRY_SERVICE_PATHS[service_name]))
		var configure_block := "func configure_handler_registry(registry: RefCounted) -> RefCounted:\n\t_handler_registry = registry\n\treturn self"
		var wire := "%s.call(&\"configure_handler_registry\", mechanic_handler_registry)" % service_name
		_expect(service_source.contains(configure_block), "%s exposes the frozen typed registry injection seam" % service_name)
		_expect(composition_source.contains(wire), "composition wires its registry into %s" % service_name)

	_expect(
		projection_source.contains("func configure(registry: RefCounted) -> RefCounted:\n\t_handler_registry = registry\n\treturn self"),
		"MechanicProjectionService stores only the injected registry"
	)
	_expect(
		composition_source.contains("mechanic_projection_service.call(&\"configure\", mechanic_handler_registry)"),
		"composition wires its registry into MechanicProjectionService"
	)
	_expect(
		_occurrences(composition_source, "mechanic_handler_registry = _resolve(overrides, &\"mechanic_handler_registry\", MechanicHandlerRegistryScript)") == 1,
		"composition resolves exactly one mechanic registry"
	)
	_expect(not composition_source.contains("MechanicHandlerRegistryScript.new("), "composition has no second mechanic registry construction path")
	_expect(not projection_source.contains("MechanicHandlerRegistryScript"), "projection service cannot construct or load a registry")
	_expect(not projection_source.contains("catalog"), "projection service owns no mechanic catalog")
	_expect(_occurrences(projection_source, "_handler_registry = registry") == 1, "projection registry assignment exists only in configure")

	var query_source := _source("res://core/commands/battle_query_projector.gd")
	var auto_position_source := _source("res://core/battle/auto_position/auto_position_evaluator.gd")
	_expect(
		query_source.contains("_mechanic_projection_service = mechanic_projection_service")
			and query_source.contains("_mechanic_projection_service.call("),
		"BattleQueryProjector stores and consumes the injected projection service"
	)
	_expect(
		auto_position_source.contains("_mechanic_projection_service = mechanic_projection_service")
			and auto_position_source.contains("_mechanic_projection_service.call("),
		"AutoPositionEvaluator stores and consumes the injected projection service"
	)

	var state_source := _source(STATE_PATH)
	_expect(not state_source.contains("func _cell_detail_unit("), "M2 preserves the live baseline where the leased _cell_detail_unit function is absent")
	var attack_strike_source := _function_source(_source(TRACE_FACTORY_PATH), "attack_strike_event")
	_expect(not attack_strike_source.is_empty(), "attack_strike_event is present")
	_expect(
		attack_strike_source.sha256_text() == ATTACK_STRIKE_HEAD_SHA256,
		"attack_strike_event remains byte-exact with the frozen M2 HEAD baseline"
	)

	if failed:
		quit(1)
		return
	print("SMOKE_MECHANIC_PROJECTION_STATIC_CONTRACT_OK consumers=%d registry_consumers=%d" % [
		BUSINESS_CONSUMER_PATHS.size(),
		REGISTRY_SERVICE_PATHS.size() + 1,
	])
	quit(0)


func _source(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _function_source(source: String, function_name: String) -> String:
	var lines := source.split("\n")
	var result: Array[String] = []
	var found := false
	for line_value in lines:
		var line := String(line_value)
		var is_function_start := line.begins_with("func ") or line.begins_with("static func ")
		if not found:
			if line.begins_with("func %s(" % function_name) or line.begins_with("static func %s(" % function_name):
				found = true
				result.append(line)
			continue
		if is_function_start:
			break
		result.append(line)
	return "\n".join(result)


func _occurrences(source: String, needle: String) -> int:
	if needle == "":
		return 0
	return source.split(needle, true).size() - 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
