extends Control

## Authored battle HUD responsibility root. It consumes public Snapshots and
## emits semantic command requests; Game remains the only Session owner.

signal command_requested(command: Dictionary)
signal direction_preview_changed(preview: Dictionary)

const BattleHudControllerScript := preload("res://core_ui/scripts/battle/controllers/battle_hud_controller.gd")
const BattleCommandBuilderScript := preload("res://core_ui/scripts/battle/controllers/battle_command_builder.gd")
const GameLogScript := preload("res://core/logging/game_log.gd")
const RuntimeUiPolicy := preload("res://core_ui/scripts/shared/runtime_ui_policy.gd")

@onready var auto_arrange_button: TextureButton = $BattlePrimaryActions/AutoArrangeButton
@onready var position_difficulty_button: Button = $PositionDifficultyButton
@onready var begin_turn_button: TextureButton = $BattlePrimaryActions/BeginTurnButton
@onready var action_panel: Control = $BattleActionPanel
@onready var attack_direction_drawer: Control = $AttackDirectionDrawer

var _snapshot: Dictionary = {}
var _input_locked := false
var _auto_position_feedback_pending := false
var _auto_position_feedback_visible := false
var _pending_state_version := -1
var _pending_command_log_size := -1
var _position_feedback_serial := 0
var _hud_controller: RefCounted = BattleHudControllerScript.new()
var _command_builder: RefCounted = BattleCommandBuilderScript.new()


func _ready() -> void:
	RuntimeUiPolicy.install()
	auto_arrange_button.pressed.connect(_on_auto_arrange_pressed)
	position_difficulty_button.toggled.connect(_on_position_difficulty_toggled)
	begin_turn_button.pressed.connect(_on_begin_turn_pressed)
	if action_panel.has_signal("command_requested"):
		action_panel.connect("command_requested", Callable(self, "_on_child_command_requested"))
	if attack_direction_drawer.has_signal("command_requested"):
		attack_direction_drawer.connect(
			"command_requested",
			Callable(self, "_on_child_command_requested")
		)
	if attack_direction_drawer.has_signal("direction_preview_changed"):
		attack_direction_drawer.connect(
			"direction_preview_changed",
			Callable(self, "_on_direction_preview_changed")
		)
	_apply_position_difficulty_label("normal")
	_apply_command_availability()


func render_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if action_panel.has_method("render_snapshot"):
		action_panel.call("render_snapshot", _snapshot)
	if attack_direction_drawer.has_method("render_snapshot"):
		attack_direction_drawer.call("render_snapshot", _snapshot)
	if _auto_position_feedback_pending:
		_consume_auto_position_feedback(_snapshot)
	elif not _auto_position_feedback_visible:
		_apply_position_difficulty_label(String(_snapshot.get("difficulty", "normal")))
	_apply_command_availability()


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if action_panel.has_method("set_input_locked"):
		action_panel.call("set_input_locked", locked)
	attack_direction_drawer.process_mode = (
		Node.PROCESS_MODE_DISABLED if locked else Node.PROCESS_MODE_INHERIT
	)
	if locked:
		direction_preview_changed.emit({})
	_apply_command_availability()


func _on_auto_arrange_pressed() -> void:
	if _input_locked or _auto_position_feedback_pending or not _phase_is_battle():
		GameLogScript.warning("表现/自动布置", "点击未发送：当前已有操作处理中", {
			"输入锁定": _input_locked,
			"正在计算": _auto_position_feedback_pending,
		})
		return
	_auto_position_feedback_pending = true
	_auto_position_feedback_visible = false
	_pending_state_version = _snapshot_state_version(_snapshot)
	_pending_command_log_size = _snapshot_command_log(_snapshot).size()
	_position_feedback_serial += 1
	position_difficulty_button.text = RuntimeUiPolicy.text("UI_POSITION_CALCULATING")
	auto_arrange_button.modulate = Color("#fff0ad")
	var pulse := create_tween()
	pulse.tween_property(auto_arrange_button, "modulate", Color.WHITE, 0.35)
	_apply_command_availability()
	GameLogScript.info("表现/自动布置", "玩家点击自动布置，界面进入计算状态", {
		"难度": String(_snapshot.get("difficulty", "normal")),
		"回合": int(_snapshot.get("battleRound", _snapshot.get("battle_round", 0))),
		"基线版本": _pending_state_version,
		"基线命令数": _pending_command_log_size,
	})
	_request_auto_position.call_deferred()


func _request_auto_position() -> void:
	if not _auto_position_feedback_pending:
		return
	if _input_locked:
		_cancel_auto_position_request("延迟发送前发现输入已锁定，取消本次请求")
		return
	var command := Dictionary(_command_builder.call(
		"build",
		"AUTO_POSITION_HEROES",
		_snapshot
	))
	if command.is_empty():
		_cancel_auto_position_request("自动布置命令构造失败，取消本次请求")
		return
	GameLogScript.debug("表现/自动布置", "向核心发送自动布置命令")
	command_requested.emit(command)


func _cancel_auto_position_request(message: String) -> void:
	_auto_position_feedback_pending = false
	_pending_state_version = -1
	_pending_command_log_size = -1
	_apply_position_difficulty_label(String(_snapshot.get("difficulty", "normal")))
	_apply_command_availability()
	GameLogScript.warning("表现/自动布置", message)


func _consume_auto_position_feedback(snapshot: Dictionary) -> void:
	if not _auto_position_feedback_pending:
		return
	var incoming_version := _snapshot_state_version(snapshot)
	var command_log := _snapshot_command_log(snapshot)
	if incoming_version <= _pending_state_version \
			or command_log.size() <= _pending_command_log_size:
		return
	var completed := Dictionary(command_log.back())
	if _command_type(completed) != "AUTO_POSITION_HEROES":
		return
	var result_value: Variant = snapshot.get(
		"lastCommandResult",
		snapshot.get("last_command_result", {})
	)
	if not (result_value is Dictionary) or not Dictionary(result_value).has("ok"):
		return
	_auto_position_feedback_pending = false
	_pending_state_version = -1
	_pending_command_log_size = -1
	var result := Dictionary(result_value).duplicate(true)
	var difficulty := String(snapshot.get("difficulty", "normal"))
	var feedback_text := String(_hud_controller.call(
		"auto_position_feedback",
		snapshot,
		result
	))
	GameLogScript.info("表现/自动布置", "核心结果已显示给玩家", {
		"结果": "成功" if bool(result.get("ok", false)) else "失败",
		"提示": feedback_text,
		"移动宠物": Array(result.get("moves", [])).size(),
		"难度": difficulty,
	})
	_show_auto_position_feedback(feedback_text, difficulty)


func _show_auto_position_feedback(text: String, difficulty: String) -> void:
	_position_feedback_serial += 1
	var serial := _position_feedback_serial
	_auto_position_feedback_visible = true
	position_difficulty_button.text = text
	position_difficulty_button.modulate = Color("#d9ffc9")
	var fade := create_tween()
	fade.tween_property(position_difficulty_button, "modulate", Color.WHITE, 0.45)
	_apply_command_availability()
	await get_tree().create_timer(3.0, true, false, true).timeout
	if serial != _position_feedback_serial or not is_inside_tree():
		return
	_auto_position_feedback_visible = false
	_apply_position_difficulty_label(String(_snapshot.get("difficulty", difficulty)))
	_apply_command_availability()


func _on_position_difficulty_toggled(use_easy: bool) -> void:
	if _input_locked or _auto_position_feedback_pending or not _phase_is_battle():
		_apply_position_difficulty_label(String(_snapshot.get("difficulty", "normal")))
		return
	_position_feedback_serial += 1
	_auto_position_feedback_visible = false
	var difficulty := "easy" if use_easy else "normal"
	_apply_position_difficulty_label(difficulty)
	command_requested.emit({"type": "SET_DIFFICULTY", "difficulty": difficulty})


func _on_begin_turn_pressed() -> void:
	if _input_locked or not _phase_is_battle():
		return
	command_requested.emit({"type": "RUN_COMBAT_ROUND"})


func _on_child_command_requested(command: Dictionary) -> void:
	if _input_locked or not _phase_is_battle() or command.is_empty():
		return
	command_requested.emit(command.duplicate(true))


func _on_direction_preview_changed(preview: Dictionary) -> void:
	if _input_locked or not _phase_is_battle():
		return
	direction_preview_changed.emit(preview.duplicate(true))


func _apply_position_difficulty_label(difficulty: String) -> void:
	var normalized := "easy" if difficulty == "easy" else "normal"
	position_difficulty_button.set_pressed_no_signal(normalized == "easy")
	position_difficulty_button.text = String(_hud_controller.call(
		"difficulty_label",
		normalized
	))
	position_difficulty_button.tooltip_text = String(_hud_controller.call(
		"difficulty_tooltip"
	))


func _apply_command_availability() -> void:
	if not is_node_ready():
		return
	var phase_is_battle := _phase_is_battle()
	auto_arrange_button.disabled = (
		_input_locked or _auto_position_feedback_pending or not phase_is_battle
	)
	position_difficulty_button.disabled = (
		_input_locked or _auto_position_feedback_pending or not phase_is_battle
	)
	begin_turn_button.disabled = _input_locked or not phase_is_battle


func _snapshot_state_version(snapshot: Dictionary) -> int:
	return int(snapshot.get("stateVersion", snapshot.get("state_version", -1)))


func _phase_is_battle() -> bool:
	return String(_snapshot.get("phase", "")) == "battle"


func _snapshot_command_log(snapshot: Dictionary) -> Array:
	return Array(snapshot.get("command_log", snapshot.get("commandLog", [])))


func _command_type(entry: Dictionary) -> String:
	var command_value: Variant = entry.get("command", {})
	var nested := Dictionary(command_value) if command_value is Dictionary else {}
	return String(entry.get("type", nested.get("type", ""))).strip_edges().to_upper()
