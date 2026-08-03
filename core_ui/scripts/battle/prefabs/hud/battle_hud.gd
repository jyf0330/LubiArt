extends Control

## Authored battle HUD boundary. The battle page owns commands and Snapshot
## rendering; this prefab only exposes its stable authored controls.

@onready var auto_arrange_button: TextureButton = $BattlePrimaryActions/AutoArrangeButton
@onready var position_difficulty_button: Button = $PositionDifficultyButton
@onready var begin_turn_button: TextureButton = $BattlePrimaryActions/BeginTurnButton
@onready var action_panel: Control = $BattleActionPanel
@onready var attack_direction_drawer: Control = $AttackDirectionDrawer
@onready var attack_timeline: Control = $AttackTimelineLayer/AttackTimeline
@onready var attack_timeline_toggle_button: Button = $AttackTimelineLayer/AttackTimelineToggleButton


func _ready() -> void:
	attack_timeline.visible = false
	attack_timeline_toggle_button.pressed.connect(_toggle_attack_timeline)
	_refresh_attack_timeline_toggle_button()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.keycode != KEY_TAB or not key_event.pressed or key_event.echo:
		return
	_toggle_attack_timeline()
	get_viewport().set_input_as_handled()


func bind_primary_actions(
	auto_arrange_callback: Callable,
	position_difficulty_callback: Callable,
	begin_turn_callback: Callable
) -> void:
	if not auto_arrange_button.pressed.is_connected(auto_arrange_callback):
		auto_arrange_button.pressed.connect(auto_arrange_callback)
	if not position_difficulty_button.toggled.is_connected(position_difficulty_callback):
		position_difficulty_button.toggled.connect(position_difficulty_callback)
	if not begin_turn_button.pressed.is_connected(begin_turn_callback):
		begin_turn_button.pressed.connect(begin_turn_callback)


func get_auto_arrange_button() -> TextureButton:
	return auto_arrange_button


func get_position_difficulty_button() -> Button:
	return position_difficulty_button


func get_begin_turn_button() -> TextureButton:
	return begin_turn_button


func get_action_panel() -> Control:
	return action_panel


func get_attack_direction_drawer() -> Control:
	return attack_direction_drawer


func get_attack_timeline() -> Control:
	return attack_timeline


func _toggle_attack_timeline() -> void:
	attack_timeline.visible = not attack_timeline.visible
	_refresh_attack_timeline_toggle_button()


func _refresh_attack_timeline_toggle_button() -> void:
	attack_timeline_toggle_button.text = "关闭技能时间轴" if attack_timeline.visible else "技能释放时间轴"


func debug_is_attack_timeline_open() -> bool:
	return attack_timeline.visible
