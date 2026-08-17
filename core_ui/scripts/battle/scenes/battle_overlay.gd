extends Control
class_name BattleOverlay

## Battle detail presentation owner. It renders only public Snapshot values and
## owns the lifecycle of the existing pet and terrain detail prefabs.

const BattleDetailControllerScript := preload("res://core_ui/scripts/battle/controllers/battle_detail_controller.gd")
const PetDetailPanelScene := preload("res://art/prefabs/battle/battle_pet_detail.tscn")
const TerrainDetailScene := preload("res://art/prefabs/terrain/terrain_detail.tscn")

var _assets: RefCounted = null
var _snapshot: Dictionary = {}
var _active_detail_grid := Vector2i(-1, -1)
var _active_detail_unit_id := ""
var _pet_detail_panel: Control = null
var _terrain_detail_panel: PanelContainer = null
var _detail_controller: RefCounted = BattleDetailControllerScript.new()


func _ready() -> void:
	_ensure_detail_panels()


func configure(assets: RefCounted) -> void:
	_assets = assets
	if _has_active_request() and not _snapshot.is_empty():
		_render_active_detail()


func request_detail(grid: Vector2i, unit_id: String) -> void:
	if grid.x < 0 or grid.y < 0:
		clear()
		return
	_active_detail_grid = grid
	_active_detail_unit_id = unit_id
	_render_active_detail()


func render_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	if _has_active_request():
		_render_active_detail()


func clear() -> void:
	_active_detail_grid = Vector2i(-1, -1)
	_active_detail_unit_id = ""
	_ensure_detail_panels()
	if _pet_detail_panel != null:
		if _pet_detail_panel.has_method("close"):
			_pet_detail_panel.call("close")
		else:
			_pet_detail_panel.visible = false
	if _terrain_detail_panel != null:
		_terrain_detail_panel.visible = false


func has_visible_detail() -> bool:
	return (
		(_pet_detail_panel != null and _pet_detail_panel.visible)
		or (_terrain_detail_panel != null and _terrain_detail_panel.visible)
	)


func _ensure_detail_panels() -> void:
	if _pet_detail_panel == null:
		_pet_detail_panel = PetDetailPanelScene.instantiate() as Control
		if _pet_detail_panel != null:
			_pet_detail_panel.name = "BattlePetDetailPanel"
			_pet_detail_panel.visible = false
			_pet_detail_panel.z_index = 42
			add_child(_pet_detail_panel)
	if _terrain_detail_panel == null:
		_terrain_detail_panel = TerrainDetailScene.instantiate() as PanelContainer
		if _terrain_detail_panel != null:
			_terrain_detail_panel.name = "BattleElementDetailPanel"
			_terrain_detail_panel.visible = false
			_terrain_detail_panel.z_index = 42
			_terrain_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
			add_child(_terrain_detail_panel)


func _render_active_detail() -> void:
	_ensure_detail_panels()
	if _pet_detail_panel == null or _terrain_detail_panel == null \
			or _snapshot.is_empty() or not _has_active_request():
		return
	var detail := Dictionary(_detail_controller.call(
		"resolve_detail",
		_snapshot,
		_active_detail_grid,
		_active_detail_unit_id
	))
	var unit := _dictionary(detail.get("unit", {}))
	var elements := _dictionary(detail.get("elements", {}))
	if unit.is_empty() and not bool(_detail_controller.call(
		"has_visible_elements",
		elements
	)):
		clear()
		return
	if unit.is_empty():
		if _pet_detail_panel.has_method("close"):
			_pet_detail_panel.call("close")
		else:
			_pet_detail_panel.visible = false
		_terrain_detail_panel.visible = true
		_active_detail_unit_id = ""
		if _terrain_detail_panel.has_method("render_detail"):
			_terrain_detail_panel.call(
				"render_detail",
				detail,
				elements,
				_detail_controller
			)
		return
	_terrain_detail_panel.visible = false
	_active_detail_unit_id = String(unit.get(
		"id",
		unit.get("unitId", _active_detail_unit_id)
	))
	var record := Dictionary(_detail_controller.call(
		"pet_record",
		unit,
		_detail_controller.call(
			"skill_text",
			unit,
			_snapshot,
			_selected_unit_id()
		),
		_detail_controller.call("attack_shape", detail, unit, _snapshot)
	))
	var texture := _detail_texture(unit)
	if _pet_detail_panel.has_method("show_context_detail"):
		_pet_detail_panel.call("show_context_detail", record, texture)
	else:
		_pet_detail_panel.visible = true


func _detail_texture(unit: Dictionary) -> Texture2D:
	if _assets == null or not _assets.has_method("texture_for_unit"):
		return null
	var resolved := Dictionary(_assets.call(
		"texture_for_unit",
		unit,
		String(unit.get("side", "player"))
	))
	return resolved.get("texture") as Texture2D


func _selected_unit_id() -> String:
	return String(_snapshot.get(
		"selected_unit_id",
		_snapshot.get("selectedUnitId", "")
	))


func _has_active_request() -> bool:
	return _active_detail_grid.x >= 0 or _active_detail_unit_id != ""


func _dictionary(value: Variant) -> Dictionary:
	return Dictionary(value) if value is Dictionary else {}
