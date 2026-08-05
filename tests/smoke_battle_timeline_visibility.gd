extends SceneTree

const BATTLE_HUD_PATH := "res://art/prefabs/battle/hud/battle_hud.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var packed := load(BATTLE_HUD_PATH) as PackedScene
	var hud := packed.instantiate() as Control
	host.add_child(hud)
	await process_frame

	var layer := hud.get_node("AttackTimelineLayer") as CanvasLayer
	var timeline := hud.get_node("AttackTimelineLayer/AttackTimeline") as Control
	var toggle_button := hud.get_node("AttackTimelineLayer/AttackTimelineToggleButton") as Button
	assert(layer.visible)
	assert(not timeline.visible)

	host.visible = false
	await process_frame
	assert(not layer.visible)
	toggle_button.pressed.emit()
	assert(not timeline.visible)

	host.visible = true
	await process_frame
	assert(layer.visible)
	toggle_button.pressed.emit()
	assert(timeline.visible)

	host.queue_free()
	await process_frame
	print("SMOKE_BATTLE_TIMELINE_VISIBILITY_PASS")
	quit(0)
