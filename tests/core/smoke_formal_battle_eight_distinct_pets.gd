extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")
const RepositoryScript := preload("res://persistence/game_data_repository.gd")
const AssetRegistryScript := preload("res://core_ui/scripts/battle/controllers/battle_asset_registry.gd")
const SessionFactoryScript := preload("res://session/session_factory.gd")
const CONTENT_ROOT := "res://data/content"

const PLAYER_IDS := ["pal_001", "pal_002", "pal_003", "pal_004"]
const ENEMY_IDS := ["pal_005", "pal_006", "pal_007", "pal_008"]

var failed := false


func _initialize() -> void:
	var repository := RepositoryScript.new()
	var data := Dictionary(repository.read_content_pack(CONTENT_ROOT))
	_expect(repository.content_errors().is_empty(), "formal content assembles without errors")
	_assert_production_rows(data)

	var creation := Dictionary(SessionFactoryScript.create_isolated_developer_result())
	var session := creation.get("session") as RefCounted
	_expect(session != null, "isolated developer session initializes")
	if session == null:
		quit(1)
		return
	var start := Dictionary(session.call("submit_command", {
		"type": "START_DEVELOPER_SCENARIO",
		"scenarioId": "debug_first_battle",
		"seed": "smoke-eight-distinct-pets",
		"playerRefs": _pet_refs(PLAYER_IDS),
		"enemyRefs": _pet_refs(ENEMY_IDS),
	}))
	_expect(bool(start.get("accepted", false)), "developer eight-pet battle command starts")
	var snapshot := Dictionary(session.call("current_snapshot"))
	var player_units := _side_units(Array(snapshot.get("units", [])), StateScript.PLAYER)
	var enemy_units := _side_units(Array(snapshot.get("units", [])), StateScript.ENEMY)
	_expect(player_units.size() == 4 and enemy_units.size() == 4, "formal battle contains four player and four enemy pets")
	_expect(_canonical_ids(player_units) == PLAYER_IDS, "player deploys master-table pets one through four")
	_expect(_canonical_ids(enemy_units) == ENEMY_IDS, "enemy deploys master-table pets five through eight")
	var all_ids := _canonical_ids(player_units) + _canonical_ids(enemy_units)
	_expect(_unique(all_ids).size() == 8, "all eight deployed canonical pet ids are distinct")

	# The formal board renders projected cells, not authoritative unit rows. Test
	# that exact presentation payload so a missing pet_id cannot silently fall
	# through to four same-element fallback textures.
	var board_cells := Array(Dictionary(snapshot.get("board", {})).get("cells", []))
	var player_cells := _occupied_side_cells(board_cells, StateScript.PLAYER)
	var enemy_cells := _occupied_side_cells(board_cells, StateScript.ENEMY)
	_expect(player_cells.size() == 4 and enemy_cells.size() == 4, "projected formal board contains all eight pets")
	_expect(_sorted(_canonical_cell_ids(player_cells)) == PLAYER_IDS, "player board cells preserve pets one through four")
	_expect(_sorted(_canonical_cell_ids(enemy_cells)) == ENEMY_IDS, "enemy board cells preserve pets five through eight")

	var registry := AssetRegistryScript.new()
	var resource_paths: Array = []
	for cell in player_cells:
		var player_texture := Dictionary(registry.texture_for_unit(Dictionary(cell), StateScript.PLAYER)).get("texture") as Texture2D
		resource_paths.append(player_texture.resource_path if player_texture != null else "")
	for cell in enemy_cells:
		var enemy_texture := Dictionary(registry.texture_for_unit(Dictionary(cell), StateScript.ENEMY)).get("texture") as Texture2D
		var shared_texture := Dictionary(registry.texture_for_unit(Dictionary(cell), StateScript.PLAYER)).get("texture") as Texture2D
		var enemy_path := enemy_texture.resource_path if enemy_texture != null else ""
		var shared_path := shared_texture.resource_path if shared_texture != null else ""
		_expect(enemy_path == shared_path, "%s uses the same pet image on both sides" % String(cell.get("pet_id", "")))
		resource_paths.append(enemy_path)
	_expect(not resource_paths.has(""), "all eight battle pets resolve a real texture")
	_expect(_unique(resource_paths).size() == 8, "all eight battle pets resolve different texture paths")
	for path_value in resource_paths:
		_expect(ResourceLoader.exists(String(path_value)), "mapped pet texture exists: %s" % String(path_value))

	if failed:
		quit(1)
		return
	print("SMOKE_FORMAL_BATTLE_EIGHT_DISTINCT_PETS_OK player=%s enemy=%s textures=%d" % [
		",".join(PLAYER_IDS), ",".join(ENEMY_IDS), resource_paths.size(),
	])
	quit(0)


func _assert_production_rows(data: Dictionary) -> void:
	var roster := Array(data.get("roster", []))
	_expect(roster.size() == 1, "formal production roster contains only upstream-enabled pets")
	if roster.size() == 1:
		_expect(String(Dictionary(roster[0]).get("id", "")) == "pal_002", "formal production roster keeps the upstream starter")


func _pet_refs(ids: Array) -> Array:
	var refs: Array = []
	for id_value in ids:
		refs.append({"kind": "pet", "id": String(id_value)})
	return refs


func _side_units(units: Array, side: String) -> Array:
	var result: Array = []
	for unit_value in units:
		var unit := Dictionary(unit_value)
		if String(unit.get("side", "")) == side:
			result.append(unit)
	return result


func _canonical_ids(units: Array) -> Array:
	var result: Array = []
	for unit_value in units:
		var unit := Dictionary(unit_value)
		result.append(String(unit.get("pet_id", unit.get("source_pet_id", unit.get("id", "")))))
	return result


func _occupied_side_cells(cells: Array, side: String) -> Array:
	var result: Array = []
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		if String(cell.get("side", "")) == side and String(cell.get("unitId", "")) != "":
			result.append(cell)
	return result


func _canonical_cell_ids(cells: Array) -> Array:
	var result: Array = []
	for cell_value in cells:
		var cell := Dictionary(cell_value)
		result.append(String(cell.get("pet_id", cell.get("petId", cell.get("unitId", "")))))
	return result


func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result


func _sorted(values: Array) -> Array:
	var result := values.duplicate()
	result.sort()
	return result


func _find(values: Array, key: String, expected: String) -> Dictionary:
	for value in values:
		var row := Dictionary(value)
		if String(row.get(key, "")) == expected:
			return row
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("SMOKE_FORMAL_BATTLE_EIGHT_DISTINCT_PETS_FAIL: %s" % message)
