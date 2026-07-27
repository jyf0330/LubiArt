extends Control

## Composition-only boundary for the artist Mock battle scene. Snapshot replay,
## rendering and VFX remain owned by the single BattleView instance.

@onready var battle_view: Control = $Runtime/BattleView


func get_runtime_view() -> Control:
	if is_instance_valid(battle_view):
		return battle_view
	return get_node_or_null("Runtime/BattleView") as Control
