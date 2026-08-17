extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const FACADE_PATH := "res://core/state/game_state.gd"
const LEGACY_CHAIN_PATHS := [
	"res://core/state/state_base.gd",
	"res://core/party/catalog_roster_core.gd",
	"res://core/commands/command_projection_core.gd",
	"res://core/battle/battle_rules_core.gd",
	"res://core/run/run_flow_core.gd",
	"res://persistence/compatibility/persistence_core.gd",
]
const PRODUCTION_ROOTS := ["res://core", "res://persistence", "res://session", "res://core_ui"]
const REMOVED_PRIVATE_HELPER_SIGNATURES := [
	"_best_auto_position_for_unit", "_evaluate_auto_position_choices",
	"_auto_position_planned_actions", "_auto_position_has_projected_on_death_damage",
	"_route_battle_options", "_apply_fire_explosion_after_attack", "_trace_definition_for_upgrade",
	"_apply_quality_board_trace",
	"_first_enemy_in_stored_direction", "_step_toward", "_first_adjacent_enemy",
	"_first_shape_enemy", "_validate_save_state_payload", "_validate_saved_units",
]


func _initialize() -> void:
	for path in LEGACY_CHAIN_PATHS:
		if FileAccess.file_exists(path):
			_fail("Legacy authority chain path returned: %s." % path)
			return
	var facade_source := FileAccess.get_file_as_string(FACADE_PATH)
	if not facade_source.begins_with("extends RefCounted"):
		_fail("YsbzsState must directly extend RefCounted.")
		return
	if not facade_source.contains("class_name YsbzsState"):
		_fail("YsbzsState public class name must remain stable.")
		return
	if facade_source.contains("extends \"res://"):
		_fail("YsbzsState must not reopen an authority inheritance chain.")
		return
	var names := _function_names(facade_source)
	if bool(names.get("duplicate", false)):
		_fail("YsbzsState contains a duplicate method definition: %s." % String(names.get("duplicateName", "")))
		return
	if facade_source.contains("\n\tpass\n"):
		_fail("YsbzsState contains an empty compatibility contract stub.")
		return
	for method_name in REMOVED_PRIVATE_HELPER_SIGNATURES:
		if facade_source.contains("func %s(" % method_name):
			_fail("Removed migration helper returned to YsbzsState: %s." % method_name)
			return
	for source_path in _production_gd_files():
		var source := FileAccess.get_file_as_string(source_path)
		for legacy_path in LEGACY_CHAIN_PATHS:
			if source.contains(legacy_path):
				_fail("Production source references deleted authority layer: %s -> %s." % [source_path, legacy_path])
				return
	var state := StateScript.new()
	for public_method in [
		"dispatch", "run_command", "snapshot", "save_document", "load_document",
		"replay_document", "verify_replay_document", "start_battle",
		"auto_position_heroes", "run_combat_round",
	]:
		if not state.has_method(public_method):
			_fail("Authoritative facade lost public method %s." % public_method)
			return
	var snapshot := Dictionary(state.snapshot())
	if String(snapshot.get("stateHash", "")) == "" or Array(Dictionary(snapshot.get("board", {})).get("cells", [])).is_empty():
		_fail("YsbzsState did not initialize a usable authoritative snapshot.")
		return
	print("SMOKE_CORE_LAYER_STRUCTURE_OK legacy_layers=0 contract_stubs=0 methods=%d" % int(names.get("count", 0)))
	quit(0)


func _function_names(source: String) -> Dictionary:
	var names: Dictionary = {}
	var count := 0
	for line in source.split("\n"):
		if not line.begins_with("func "):
			continue
		var tail := line.trim_prefix("func ")
		var open_paren := tail.find("(")
		if open_paren <= 0:
			continue
		var name := tail.substr(0, open_paren)
		if names.has(name):
			return {"duplicate": true, "duplicateName": name, "count": count}
		names[name] = true
		count += 1
	names["count"] = count
	return names


func _production_gd_files() -> Array[String]:
	var result: Array[String] = []
	for root in PRODUCTION_ROOTS:
		_collect_gd_files(String(root), result)
	return result


func _collect_gd_files(path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if directory.current_is_dir():
				_collect_gd_files(child, output)
			elif entry.ends_with(".gd"):
				output.append(child)
		entry = directory.get_next()
	directory.list_dir_end()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
