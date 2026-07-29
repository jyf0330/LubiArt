extends Control

## Presentation boundary for the Board secondary group. Ordinary visual
## children stay scriptless; only independently stateful components such as the
## VFX host, action panel and reusable terrain/pet prefabs own child scripts.

@onready var board_grid: Control = $BoardGrid
@onready var primary_actions: Control = $BattlePrimaryActions
@onready var auto_arrange_button: TextureButton = $BattlePrimaryActions/AutoArrangeButton
@onready var position_difficulty_button: Button = $PositionDifficultyButton
@onready var begin_turn_button: TextureButton = $BattlePrimaryActions/BeginTurnButton
@onready var vfx_player: Control = $BattleVfxPlayer
@onready var action_panel: Control = $BattleActionPanel
@onready var attack_direction_drawer: Control = $AttackDirectionDrawer


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


func get_board_grid() -> Control:
	return board_grid


func get_primary_actions() -> Control:
	return primary_actions


func get_auto_arrange_button() -> TextureButton:
	return auto_arrange_button


func get_position_difficulty_button() -> Button:
	return position_difficulty_button


func get_begin_turn_button() -> TextureButton:
	return begin_turn_button


func get_vfx_player() -> Control:
	return vfx_player


func get_action_panel() -> Control:
	return action_panel


func get_attack_direction_drawer() -> Control:
	return attack_direction_drawer


func add_runtime_control(control: Control) -> void:
	if control != null:
		add_child(control)
