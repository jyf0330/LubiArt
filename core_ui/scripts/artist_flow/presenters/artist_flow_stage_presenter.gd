extends RefCounted

const VIEW_THREE_OPTION := &"three_option"
const VIEW_BAG := &"bag"

const ANIM_SHOW_THREE_OPTION := &"show_Three_Option"
const ANIM_HIDE_THREE_OPTION := &"hide_Three_Option"
const ANIM_SHOW_BAG := &"show_Bag"
const ANIM_HIDE_BAG := &"hide_bag"

const FADE_SECONDS := 0.1
const HOLD_SECONDS := 0.08
const DIM_ALPHA := 0.72

var _host: Node = null
var _animation_player: AnimationPlayer = null
var _nodes: Dictionary = {}
var _before_clear: Callable


func configure(host: Node, animation_player: AnimationPlayer, nodes: Dictionary, before_clear: Callable = Callable()) -> void:
	_host = host
	_animation_player = animation_player
	_nodes = nodes
	_before_clear = before_clear


func show_immediate(view: StringName) -> void:
	reset_alpha()
	for key in _nodes.keys():
		var node := _node(StringName(key))
		if node != null:
				node.visible = _view_owns_node(view, StringName(key))


func dispose() -> void:
	_host = null
	_animation_player = null
	_nodes.clear()
	_before_clear = Callable()


func set_initial() -> void:
	reset_alpha()
	_set_visible(&"three_option", true)
	_set_visible(&"bag_overlay", false)
	_set_visible(&"bag", false)


func show_initial(view: StringName) -> void:
	prepare_show(view)
	await _play_show(view)
	await _fade(view, 1.0, FADE_SECONDS)
	reset_alpha()


func switch_view(from_view: StringName, target_view: StringName) -> void:
	var shared_keys := _shared_node_keys(from_view, target_view)
	await _fade(from_view, DIM_ALPHA, FADE_SECONDS, shared_keys)
	if shared_keys.is_empty():
		await _play_hide(from_view)
	_clear_except(target_view)
	if _host != null:
		await _host.get_tree().create_timer(HOLD_SECONDS).timeout
	prepare_show(target_view, shared_keys)
	if shared_keys.is_empty():
		await _play_show(target_view)
	await _fade(target_view, 1.0, FADE_SECONDS, shared_keys)
	reset_alpha()


func clear() -> void:
	if _before_clear.is_valid():
		_before_clear.call()
	for key in _nodes.keys():
		var node := _node(StringName(key))
		if node != null:
			node.visible = false


func prepare_show(view: StringName, excluded_keys: Dictionary = {}) -> void:
	for node in _nodes_for_view(view):
		if node != null:
			node.visible = true
	_set_alpha(view, DIM_ALPHA, excluded_keys)


func reset_alpha() -> void:
	for value in _nodes.values():
		var node := value as Control
		if node == null:
			continue
		var color := node.modulate
		color.a = 1.0
		node.modulate = color


func _play_hide(view: StringName) -> void:
	match view:
		VIEW_BAG:
			await _play_animation(ANIM_HIDE_BAG)
		_:
			await _play_animation(ANIM_HIDE_THREE_OPTION)


func _play_show(view: StringName) -> void:
	match view:
		VIEW_BAG:
			await _play_animation(ANIM_SHOW_BAG)
		_:
			await _play_animation(ANIM_SHOW_THREE_OPTION)


func _play_animation(animation_name: StringName) -> void:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return
	_animation_player.play(animation_name)
	await _animation_player.animation_finished


func _fade(view: StringName, alpha: float, seconds: float, excluded_keys: Dictionary = {}) -> void:
	var nodes := _nodes_for_view(view, excluded_keys)
	if nodes.is_empty() or _host == null:
		return
	var tween := _host.create_tween()
	tween.set_parallel(true)
	for node in nodes:
		if node != null:
			tween.tween_property(node, "modulate:a", alpha, seconds)
	await tween.finished


func _set_alpha(view: StringName, alpha: float, excluded_keys: Dictionary = {}) -> void:
	for node in _nodes_for_view(view, excluded_keys):
		if node == null:
			continue
		var color: Color = node.modulate
		color.a = alpha
		node.modulate = color


func _clear_except(view: StringName) -> void:
	if _before_clear.is_valid():
		_before_clear.call()
	for key in _nodes.keys():
		var node := _node(StringName(key))
		if node != null:
			node.visible = _view_owns_node(view, StringName(key))


func _nodes_for_view(view: StringName, excluded_keys: Dictionary = {}) -> Array:
	var nodes := []
	for key in _node_keys_for_view(view):
		if excluded_keys.has(key):
			continue
		nodes.append(_node(key))
	return nodes


func _node_keys_for_view(view: StringName) -> Array[StringName]:
	match view:
		VIEW_BAG:
			return [&"three_option", &"bag_overlay", &"bag"]
		_:
			return [&"three_option"]


func _shared_node_keys(from_view: StringName, target_view: StringName) -> Dictionary:
	var result := {}
	for key in _node_keys_for_view(from_view):
		if _view_owns_node(target_view, key):
			result[key] = true
	return result


func _view_owns_node(view: StringName, key: StringName) -> bool:
	match view:
		VIEW_BAG:
			return key == &"three_option" or key == &"bag_overlay" or key == &"bag"
		_:
			return key == &"three_option"


func _set_visible(key: StringName, visible: bool, position: Variant = null) -> void:
	var node := _node(key)
	if node == null:
		return
	node.visible = visible
	if position is Vector2:
		node.position = position


func _node(key: StringName) -> Control:
	return _nodes.get(key) as Control
