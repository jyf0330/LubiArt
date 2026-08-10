extends Control

signal start_requested(seed: String, player_pet_ids: Array, enemy_pet_ids: Array)
signal reopen_requested

const TEAM_SIZE := 4

@onready var seed_edit: LineEdit = $PanelMargin/Panel/VBox/SeedRow/SeedEdit
@onready var player_selectors: Array[OptionButton] = [
	$PanelMargin/Panel/VBox/Teams/PlayerTeam/PlayerSlots/PlayerPet1,
	$PanelMargin/Panel/VBox/Teams/PlayerTeam/PlayerSlots/PlayerPet2,
	$PanelMargin/Panel/VBox/Teams/PlayerTeam/PlayerSlots/PlayerPet3,
	$PanelMargin/Panel/VBox/Teams/PlayerTeam/PlayerSlots/PlayerPet4,
]
@onready var enemy_selectors: Array[OptionButton] = [
	$PanelMargin/Panel/VBox/Teams/EnemyTeam/EnemySlots/EnemyPet1,
	$PanelMargin/Panel/VBox/Teams/EnemyTeam/EnemySlots/EnemyPet2,
	$PanelMargin/Panel/VBox/Teams/EnemyTeam/EnemySlots/EnemyPet3,
	$PanelMargin/Panel/VBox/Teams/EnemyTeam/EnemySlots/EnemyPet4,
]
@onready var status_label: Label = $PanelMargin/Panel/VBox/StatusLabel
@onready var preset_button: Button = $PanelMargin/Panel/VBox/Actions/PresetButton
@onready var start_button: Button = $PanelMargin/Panel/VBox/Actions/StartButton
@onready var reopen_button: Button = $ReopenButton

var _catalog_rows: Array = []
var _default_player_pet_ids: Array = []
var _default_enemy_pet_ids: Array = []


func _ready() -> void:
	preset_button.pressed.connect(apply_recommended_preset)
	start_button.pressed.connect(_request_start)
	reopen_button.pressed.connect(func(): reopen_requested.emit())
	set_error("")


func set_catalog(payload: Dictionary, seed: String = "") -> void:
	_catalog_rows = Array(payload.get("pets", [])).duplicate(true)
	var defaults := Dictionary(payload.get("defaults", {}))
	_default_player_pet_ids = Array(defaults.get("playerPetIds", [])).duplicate()
	_default_enemy_pet_ids = Array(defaults.get("enemyPetIds", [])).duplicate()
	if seed.strip_edges() != "":
		seed_edit.text = seed.strip_edges()
	for selector in _all_selectors():
		selector.clear()
		for row_value in _catalog_rows:
			var row := Dictionary(row_value)
			var pet_id := String(row.get("petId", ""))
			selector.add_item(_option_label(row))
			selector.set_item_metadata(selector.item_count - 1, pet_id)
	apply_recommended_preset()
	start_button.disabled = _catalog_rows.is_empty()
	if _catalog_rows.is_empty():
		set_error("正式内容包没有可用宠物，无法进入战斗。")


func apply_recommended_preset() -> void:
	_select_ids(player_selectors, _default_player_pet_ids)
	_select_ids(enemy_selectors, _default_enemy_pet_ids)
	set_error("")


func selected_player_pet_ids() -> Array:
	return _selected_ids(player_selectors)


func selected_enemy_pet_ids() -> Array:
	return _selected_ids(enemy_selectors)


func selected_seed() -> String:
	return seed_edit.text.strip_edges()


func catalog_count() -> int:
	return _catalog_rows.size()


func set_error(message: String) -> void:
	status_label.text = message
	status_label.visible = message != ""


func show_configuration() -> void:
	visible = true
	$Backdrop.visible = true
	$PanelMargin.visible = true
	reopen_button.visible = false
	start_button.grab_focus()


func enter_battle_mode() -> void:
	$Backdrop.visible = false
	$PanelMargin.visible = false
	reopen_button.visible = true
	reopen_button.grab_focus()


func _request_start() -> void:
	var seed := selected_seed()
	var player_ids := selected_player_pet_ids()
	var enemy_ids := selected_enemy_pet_ids()
	var all_ids := player_ids.duplicate()
	all_ids.append_array(enemy_ids)
	if seed == "":
		set_error("请输入战斗种子。")
		return
	if player_ids.size() != TEAM_SIZE or enemy_ids.size() != TEAM_SIZE:
		set_error("我方和敌方都必须各选择 4 只宠物。")
		return
	for pet_id in all_ids:
		if String(pet_id) == "" or all_ids.count(pet_id) != 1:
			set_error("第一场战斗需要 8 只不重复的宠物。")
			return
	set_error("")
	start_requested.emit(seed, player_ids, enemy_ids)


func _all_selectors() -> Array[OptionButton]:
	var result: Array[OptionButton] = []
	result.append_array(player_selectors)
	result.append_array(enemy_selectors)
	return result


func _selected_ids(selectors: Array[OptionButton]) -> Array:
	var result: Array = []
	for selector in selectors:
		if selector.selected < 0:
			continue
		result.append(String(selector.get_item_metadata(selector.selected)))
	return result


func _select_ids(selectors: Array[OptionButton], pet_ids: Array) -> void:
	for index in range(mini(selectors.size(), pet_ids.size())):
		var target_id := String(pet_ids[index])
		for item_index in range(selectors[index].item_count):
			if String(selectors[index].get_item_metadata(item_index)) == target_id:
				selectors[index].select(item_index)
				break


func _option_label(row: Dictionary) -> String:
	return "%s  %s｜%s｜%s  HP%d ATK%d AP%d" % [
		String(row.get("petId", "")),
		String(row.get("name", "")),
		String(row.get("quality", "")),
		String(row.get("role", "")),
		int(row.get("maxHp", 0)),
		int(row.get("atk", 0)),
		int(row.get("ap", 0)),
	]
