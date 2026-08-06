extends Control

signal start_game_requested(continue_existing: bool)
signal settings_requested
signal back_requested
signal abandon_confirmed
signal button_shortcut_hints_visibility_changed(hints_visible: bool)
signal shortcut_bindings_changed(bindings: Dictionary)

const ABANDON_GAME_DIALOG := preload("res://art/prefabs/menu/dialogs/abandon_game_dialog.tscn")

@onready var start_game_button: FantasyGameButton = $"CompleteStartScenePrefab/01_StartVisual/StartGameButton"
@onready var back_button: ActionButton = $"CompleteStartScenePrefab/01_StartVisual/BackButton"
@onready var settings_button: ActionButton = $"CompleteStartScenePrefab/01_StartVisual/SettingsButton"
@onready var settings_overlay = $"CompleteStartScenePrefab/01_StartVisual/SettingsOverlay"

var _has_active_game := false
var _abandon_game_dialog: Control


func _ready() -> void:
	start_game_button.button_pressed.connect(_on_start_game_pressed)
	back_button.button_pressed.connect(_on_action_button_pressed)
	settings_button.button_pressed.connect(_on_action_button_pressed)
	settings_overlay.button_shortcut_hints_toggled.connect(
		_on_button_shortcut_hints_toggled
	)
	settings_overlay.shortcut_bindings_changed.connect(_on_shortcut_bindings_changed)
	_apply_active_game_state()


func set_has_active_game(has_active_game: bool) -> void:
	_has_active_game = has_active_game
	if is_node_ready():
		_apply_active_game_state()


func set_button_shortcut_hints_visible(hints_visible: bool) -> void:
	settings_overlay.call("set_button_shortcut_hints_visible", hints_visible)


func are_button_shortcut_hints_visible() -> bool:
	return bool(settings_overlay.call("are_button_shortcut_hints_visible"))


func is_capturing_shortcut() -> bool:
	return settings_overlay.visible \
			and settings_overlay.has_method("is_capturing_shortcut") \
			and bool(settings_overlay.call("is_capturing_shortcut"))


func _apply_active_game_state() -> void:
	back_button.visible = _has_active_game
	start_game_button.button_text = "继续游戏" if _has_active_game else "开始游戏"


func _on_start_game_pressed() -> void:
	start_game_requested.emit(_has_active_game)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or is_instance_valid(_abandon_game_dialog):
		return
	if settings_overlay.visible:
		settings_overlay.close()
	else:
		settings_overlay.open()
	get_viewport().set_input_as_handled()


func _on_action_button_pressed(action: ActionButton.ActionType) -> void:
	match action:
		ActionButton.ActionType.BACK:
			back_requested.emit()
			_open_abandon_game_dialog()
		ActionButton.ActionType.SETTINGS:
			settings_requested.emit()
			settings_overlay.open()


func _on_button_shortcut_hints_toggled(hints_visible: bool) -> void:
	button_shortcut_hints_visibility_changed.emit(hints_visible)


func _on_shortcut_bindings_changed(bindings: Dictionary) -> void:
	shortcut_bindings_changed.emit(bindings.duplicate(true))


func _open_abandon_game_dialog() -> void:
	if not _has_active_game or is_instance_valid(_abandon_game_dialog):
		return
	_abandon_game_dialog = ABANDON_GAME_DIALOG.instantiate() as Control
	_abandon_game_dialog.connect("abandon_confirmed", _on_abandon_confirmed)
	_abandon_game_dialog.tree_exited.connect(_on_abandon_game_dialog_closed)
	add_child(_abandon_game_dialog)


func _on_abandon_confirmed() -> void:
	set_has_active_game(false)
	abandon_confirmed.emit()


func _on_abandon_game_dialog_closed() -> void:
	_abandon_game_dialog = null
