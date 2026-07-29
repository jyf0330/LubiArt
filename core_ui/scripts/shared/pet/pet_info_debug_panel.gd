extends PanelContainer
class_name PetInfoDebugPanel

const SessionFactory := preload("res://session/session_factory.gd")
const PetAssetResolverScript := preload("res://core_ui/scripts/shared/pet/pet_asset_resolver.gd")
const PET_MAP_PATH := "res://art/manifests/shared/pets/sheets/pet_id_map.json"
const PET_SLICE_DIR := "res://art/images/shared/pets/sheets/slices"
const PET_IMAGE_DIR := "res://art/images/shared/pets/portraits"

@export var target_card_path: NodePath

@onready var _source_label: Label = $Margin/Content/SourceStatus
@onready var _previous_button: Button = $Margin/Content/SwitchRow/PreviousButton
@onready var _index_label: Label = $Margin/Content/SwitchRow/IndexLabel
@onready var _next_button: Button = $Margin/Content/SwitchRow/NextButton
@onready var _data_editor: TextEdit = $Margin/Content/DataEditor
@onready var _apply_button: Button = $Margin/Content/ActionRow/ApplyButton
@onready var _reload_button: Button = $Margin/Content/ActionRow/ReloadButton
@onready var _status_label: Label = $Margin/Content/StatusLabel
@onready var _result_output: TextEdit = $Margin/Content/ResultOutput

var _info_card: Control
var _session: RefCounted
var _resolver: RefCounted
var _snapshot: Dictionary = {}
var _records: Array[Dictionary] = []
var _current_index := -1
var _last_result: Dictionary = {}


func _ready() -> void:
	_apply_panel_style()
	_previous_button.pressed.connect(_on_previous_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_apply_button.pressed.connect(_on_apply_pressed)
	_reload_button.pressed.connect(_reload_from_session)
	_info_card = get_node_or_null(target_card_path) as Control
	if _info_card != null and _info_card.has_signal("info_updated"):
		_info_card.connect("info_updated", _on_info_updated)
	_resolver = PetAssetResolverScript.new()
	_resolver.call("configure", PET_SLICE_DIR, PET_IMAGE_DIR)
	_resolver.call("load_map", PET_MAP_PATH)
	_reload_from_session()


func inspect_record(record: Dictionary, _texture: Texture2D = null) -> void:
	_data_editor.text = JSON.stringify(record, "\t")
	_index_label.text = "运行时数据"
	_refresh_result()
	_set_status("已读取当前卡片数据", true)


func debug_record_count() -> int:
	return _records.size()


func debug_current_index() -> int:
	return _current_index


func debug_next() -> Dictionary:
	_show_index(_current_index + 1)
	return debug_last_result()


func debug_previous() -> Dictionary:
	_show_index(_current_index - 1)
	return debug_last_result()


func debug_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func debug_apply_text(json_text: String) -> bool:
	_data_editor.text = json_text
	return _apply_editor_data()


func _reload_from_session() -> void:
	_session = SessionFactory.create_local()
	_snapshot = Dictionary(_session.call("current_snapshot"))
	_records.clear()
	for value in Array(_snapshot.get("roster", [])):
		var record := Dictionary(value).duplicate(true)
		record["attack_shape"] = _attack_shape_for_record(record)
		_records.append(record)
	var state_version := int(_snapshot.get("stateVersion", _snapshot.get("state_version", -1)))
	var state_hash := String(_snapshot.get("stateHash", _snapshot.get("state_hash", "")))
	_source_label.text = "Mock Snapshot · stateVersion=%d · stateHash=%s" % [
		state_version,
		state_hash.left(12),
	]
	_previous_button.disabled = _records.is_empty()
	_next_button.disabled = _records.is_empty()
	if _records.is_empty():
		_current_index = -1
		_index_label.text = "没有可调试宠物"
		_data_editor.text = "{}"
		_refresh_result()
		_set_status("Snapshot 的 roster 为空", false)
		return
	_show_index(0)


func _show_index(index: int) -> void:
	if _records.is_empty() or _info_card == null:
		return
	_current_index = posmod(index, _records.size())
	var record := _records[_current_index].duplicate(true)
	_data_editor.text = JSON.stringify(record, "\t")
	_index_label.text = "%d / %d · %s" % [
		_current_index + 1,
		_records.size(),
		String(record.get("name", record.get("id", "未知宠物"))),
	]
	var texture := _resolver.call("texture_for", record) as Texture2D
	_info_card.call("set_info", record, texture)
	_refresh_result()
	_set_status("成功：已切换并写入卡片", true)


func _apply_editor_data() -> bool:
	var parsed: Variant = JSON.parse_string(_data_editor.text)
	if not (parsed is Dictionary):
		_set_status("失败：编辑区必须是 JSON 对象", false)
		return false
	if _info_card == null:
		_set_status("失败：找不到 SpriteInfoCard", false)
		return false
	var record := Dictionary(parsed)
	var texture := _resolver.call("texture_for", record) as Texture2D
	_info_card.call("set_info", record, texture)
	_refresh_result()
	_set_status("成功：JSON 已写入并完成规范化", true)
	return true


func _refresh_result() -> void:
	if _info_card == null:
		_last_result = {"ok": false, "error": "SpriteInfoCard missing"}
	else:
		_last_result = {
			"ok": true,
			"normalized": Dictionary(_info_card.call("get_info_snapshot")),
			"attack_cell_count": int(_info_card.call("get_attack_shape_cell_count")),
			"target_indices": Array(_info_card.call("get_target_cell_indices")),
			"source_psd": String(_info_card.call("get_source_psd")),
			"component_source": String(_info_card.call("get_component_source")),
		}
	_result_output.text = JSON.stringify(_last_result, "\t")


func _attack_shape_for_record(record: Dictionary) -> Dictionary:
	var shape_id := String(record.get("shape_id", record.get("shapeId", ""))).strip_edges()
	var shape_text := String(record.get("shape", record.get("shape_name", ""))).strip_edges()
	for value in Array(Dictionary(_snapshot.get("battle", {})).get("shape_catalog", [])):
		var shape := Dictionary(value)
		var candidate_id := String(shape.get("shape_id", shape.get("shapeId", ""))).strip_edges()
		var candidate_label := String(shape.get("label", "")).strip_edges()
		if candidate_id != "" and (
			candidate_id == shape_id
			or shape_text == candidate_id
			or shape_text == candidate_label
			or shape_text.contains(candidate_id)
		):
			return shape.duplicate(true)
	return {}


func _on_previous_pressed() -> void:
	debug_previous()


func _on_next_pressed() -> void:
	debug_next()


func _on_apply_pressed() -> void:
	_apply_editor_data()


func _on_info_updated(_record: Dictionary) -> void:
	_refresh_result()


func _set_status(message: String, success: bool) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override(
		"font_color",
		Color("83e6a6") if success else Color("ff8b8b")
	)


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("162536f2")
	style.border_color = Color("5f91b8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", style)
