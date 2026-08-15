extends Control

const CARD_COUNT := 5
const CLOSED_OFFSET_X := 411.0
const SLIDE_DURATION := 0.22

@onready var toggle_button: TextureButton = $ToggleButton
@onready var toggle_arrow: TextureRect = $ToggleButton/Arrow
@onready var cards: Array[Control] = [
	$CardList/Card1,
	$CardList/Card2,
	$CardList/Card3,
	$CardList/Card4,
	$CardList/Card5,
]

var _assets: RefCounted = null
var _expanded := false
var _open_position := Vector2.ZERO
var _slide_tween: Tween = null
var _initial_player_grids: Dictionary = {}


func _ready() -> void:
	_open_position = position
	toggle_button.pressed.connect(_on_toggle_pressed)
	_apply_expanded_state(false)


func configure(assets: RefCounted) -> void:
	_assets = assets


func render_snapshot(snapshot: Dictionary) -> void:
	visible = String(snapshot.get("phase", "")) == "battle"
	if not visible:
		_initial_player_grids.clear()
		return
	_capture_initial_player_grids(snapshot)
	var card_data := _project_cards(snapshot)
	for index in range(CARD_COUNT):
		cards[index].call("set_card_data", card_data[index] if index < card_data.size() else {})


func is_expanded() -> bool:
	return _expanded


func set_expanded(expanded: bool, animate: bool = true) -> void:
	if _expanded == expanded and animate:
		return
	_expanded = expanded
	_apply_expanded_state(animate)


func _on_toggle_pressed() -> void:
	set_expanded(not _expanded)


func _apply_expanded_state(animate: bool) -> void:
	var target := _open_position if _expanded else _open_position + Vector2(CLOSED_OFFSET_X, 0.0)
	toggle_button.tooltip_text = "收起敌人信息" if _expanded else "展开敌人信息"
	toggle_arrow.pivot_offset = toggle_arrow.size * 0.5
	var arrow_rotation := PI if _expanded else 0.0
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if animate:
		_slide_tween = create_tween().set_parallel(true)
		_slide_tween.tween_property(self, "position", target, SLIDE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_slide_tween.tween_property(toggle_arrow, "rotation", arrow_rotation, SLIDE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		position = target
		toggle_arrow.rotation = arrow_rotation


func _project_cards(snapshot: Dictionary) -> Array[Dictionary]:
	var unit_by_id := _unit_records(snapshot)
	var action_previews := Dictionary(snapshot.get(
		"action_preview_by_unit",
		snapshot.get("actionPreviewByUnit", {})
	))
	var result: Array[Dictionary] = []
	for cell_value in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		if not cell_value is Dictionary:
			continue
		var target := Dictionary(cell_value)
		var side := String(target.get("side", target.get("unitSide", "")))
		if side not in ["enemy", "monster", "boss", "enemy_leader"]:
			continue
		var target_id := String(target.get("unitId", target.get("unit_id", "")))
		if target_id == "":
			continue
		if result.size() >= CARD_COUNT:
			break
		var previews: Array[Dictionary] = []
		for preview_value in _preview_candidates(target):
			var preview := Dictionary(preview_value)
			var actor_id := String(preview.get("actorId", preview.get("actor_id", "")))
			if actor_id == "" or not _is_enemy_preview(preview):
				continue
			var actor := Dictionary(unit_by_id.get(actor_id, {}))
			var action_preview := Dictionary(action_previews.get(actor_id, {}))
			if not _actor_was_moved(actor_id, actor) \
					or not _action_preview_hits_target(action_preview, actor, target):
				continue
			if previews.all(func(existing): return String(Dictionary(existing).get("actorId", Dictionary(existing).get("actor_id", ""))) != actor_id):
				previews.append(preview.duplicate(true))
		previews.sort_custom(func(a, b): return int(Dictionary(a).get("order", 999)) < int(Dictionary(b).get("order", 999)))
		var base_hp := maxi(0, int(target.get("hp", target.get("max_hp", target.get("maxHp", 0)))))
		var max_hp := maxi(1, int(target.get("max_hp", target.get("maxHp", max(base_hp, 1)))))
		var base_shield := maxi(0, int(target.get("shield", target.get("max_shield", target.get("maxShield", 0)))))
		var max_shield := maxi(1, int(target.get("max_shield", target.get("maxShield", max(base_shield, 1)))))
		var projected := _final_preview(previews)
		var hp := clampi(_preview_int(projected, ["predictedHpTo", "predicted_hp_to", "hpTo", "hp_to"], base_hp), 0, max_hp)
		var shield := clampi(_preview_int(projected, ["predictedShieldTo", "predicted_shield_to", "shieldTo", "shield_to"], base_shield), 0, max_shield)
		var attacker_textures: Array = []
		var attacker_names: Array[String] = []
		for preview_value in previews:
			if attacker_textures.size() >= 4:
				break
			var preview := Dictionary(preview_value)
			var actor_id := String(preview.get("actorId", preview.get("actor_id", "")))
			var actor := Dictionary(unit_by_id.get(actor_id, {"id": actor_id, "name": preview.get("actorName", actor_id), "side": "player"}))
			attacker_textures.append(_texture_for(actor, String(actor.get("side", actor.get("unitSide", "player")))))
			attacker_names.append(String(actor.get("name", actor.get("unitName", actor_id))))
		result.append({
			"target_texture": _texture_for(target, String(target.get("side", target.get("unitSide", "enemy")))),
			"hp": hp,
			"max_hp": max_hp,
			"shield": shield,
			"max_shield": max_shield,
			"attacker_textures": attacker_textures,
			"tooltip": _target_tooltip(target, target_id, base_hp, hp, base_shield, shield, attacker_names),
		})
	return result


func _capture_initial_player_grids(snapshot: Dictionary) -> void:
	if not _initial_player_grids.is_empty():
		return
	for cell_value in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		if not cell_value is Dictionary:
			continue
		var cell := Dictionary(cell_value)
		if String(cell.get("side", cell.get("unitSide", ""))) not in ["player", "ally", "hero_leader", "player_leader"]:
			continue
		var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
		if unit_id != "":
			_initial_player_grids[unit_id] = _grid_for(cell)


func _actor_was_moved(actor_id: String, actor: Dictionary) -> bool:
	return _initial_player_grids.has(actor_id) and _grid_for(actor) != _initial_player_grids[actor_id]


func _action_preview_hits_target(preview: Dictionary, actor: Dictionary, target: Dictionary) -> bool:
	if preview.is_empty() or not preview.get("origin", null) is Dictionary \
			or not preview.get("cells", null) is Array:
		return false
	var origin := _grid_for(Dictionary(preview.get("origin", {})))
	var actor_grid := _grid_for(actor)
	var target_grid := _grid_for(target)
	if origin.x < 0 or actor_grid.x < 0 or target_grid.x < 0:
		return false
	var delta := actor_grid - origin
	for cell_value in Array(preview.get("cells", [])):
		if cell_value is Dictionary and _grid_for(Dictionary(cell_value)) + delta == target_grid:
			return true
	return false


func _grid_for(record: Dictionary) -> Vector2i:
	return Vector2i(
		int(record.get("x", record.get("c", -1))),
		int(record.get("y", record.get("r", -1)))
	)


func _final_preview(previews: Array[Dictionary]) -> Dictionary:
	var result := {}
	for preview in previews:
		if result.is_empty() or int(preview.get("order", -1)) >= int(result.get("order", -1)):
			result = preview
	return result

func _preview_int(preview: Dictionary, keys: Array, fallback: int) -> int:
	for key_value in keys:
		var key := String(key_value)
		if preview.has(key):
			return int(preview[key])
	return fallback


func _target_tooltip(
	target: Dictionary,
	target_id: String,
	base_hp: int,
	hp: int,
	base_shield: int,
	shield: int,
	attacker_names: Array[String]
) -> String:
	var target_name := String(target.get("name", target.get("unitName", target_id)))
	if attacker_names.is_empty():
		return "%s\n尚未进入我方攻击范围" % target_name
	return "%s\n预计总减少：%d\nHP 减少：%d\n护盾减少：%d\n攻击者：%s" % [
		target_name,
		maxi(0, base_hp + base_shield - hp - shield),
		maxi(0, base_hp - hp),
		maxi(0, base_shield - shield),
		"、".join(attacker_names),
	]


func _unit_records(snapshot: Dictionary) -> Dictionary:
	var result := {}
	for cell_value in Array(Dictionary(snapshot.get("board", {})).get("cells", [])):
		if cell_value is Dictionary:
			var cell := Dictionary(cell_value)
			var unit_id := String(cell.get("unitId", cell.get("unit_id", "")))
			if unit_id != "":
				result[unit_id] = cell
	for unit_value in Array(snapshot.get("units", [])):
		if unit_value is Dictionary:
			var unit := Dictionary(unit_value)
			var unit_id := String(unit.get("id", unit.get("unitId", unit.get("unit_id", ""))))
			if unit_id != "":
				result[unit_id] = Dictionary(result.get(unit_id, {})).merged(unit, true)
	return result


func _preview_candidates(cell: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in ["action_preview_data", "actionPreviewData", "preview"]:
		var value = cell.get(key, null)
		if value is Dictionary and not Dictionary(value).is_empty():
			result.append(Dictionary(value))
	for value in Array(cell.get("previews", [])):
		if value is Dictionary:
			result.append(Dictionary(value))
	return result


func _is_enemy_preview(preview: Dictionary) -> bool:
	return String(preview.get("preview_type", preview.get("previewType", ""))) in ["enemy", "target"] \
		or bool(preview.get("hitEnemy", preview.get("hit_enemy", false)))


func _texture_for(record: Dictionary, side: String) -> Texture2D:
	if _assets == null or not _assets.has_method("texture_for_unit"):
		return null
	var resolved := Dictionary(_assets.call("texture_for_unit", record, side))
	return resolved.get("texture", null) as Texture2D
