extends RefCounted

const VIEW_THREE_OPTION := &"three_option"
const VIEW_SHOP := &"shop"
const VIEW_BAG := &"bag"
const VIEW_BATTLE := &"battle"

const ANIM_SHOW_THREE_OPTION := &"show_Three_Option"
const ANIM_HIDE_THREE_OPTION := &"hide_Three_Option"
const ANIM_SHOW_SHOP := &"show_Shop"
const ANIM_HIDE_SHOP := &"hide_Shop"
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
	_set_visible(&"three_option", true, Vector2(27.0, 0.0))
	_set_visible(&"shop", false, Vector2(15.0, 0.0))
	_set_visible(&"bag", false, Vector2(12.0, 0.0))
	_set_visible(&"shop_top", false, Vector2(1046.0, 112.0))
	_set_visible(&"battle", false)


func show_initial(view: StringName) -> void:
	prepare_show(view)
	await _play_show(view)
	await _fade(view, 1.0, FADE_SECONDS)
	reset_alpha()


func switch_view(from_view: StringName, target_view: StringName) -> void:
	await _fade(from_view, DIM_ALPHA, FADE_SECONDS)
	await _play_hide(from_view)
	clear()
	if _host != null:
		await _host.get_tree().create_timer(HOLD_SECONDS).timeout
	prepare_show(target_view)
	await _play_show(target_view)
	await _fade(target_view, 1.0, FADE_SECONDS)
	reset_alpha()


func clear() -> void:
	if _before_clear.is_valid():
		_before_clear.call()
	for key in _nodes.keys():
		var node := _node(StringName(key))
		if node != null:
			node.visible = false


func prepare_show(view: StringName) -> void:
	for node in _nodes_for_view(view):
		if node != null:
			node.visible = true
	_set_alpha(view, DIM_ALPHA)


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
		VIEW_SHOP:
			await _play_animation(ANIM_HIDE_SHOP)
		VIEW_BAG:
			await _play_animation(ANIM_HIDE_BAG)
		VIEW_BATTLE:
			return
		_:
			await _play_animation(ANIM_HIDE_THREE_OPTION)


func _play_show(view: StringName) -> void:
	match view:
		VIEW_SHOP:
			await _play_animation(ANIM_SHOW_SHOP)
		VIEW_BAG:
			await _play_animation(ANIM_SHOW_BAG)
		VIEW_BATTLE:
			return
		_:
			await _play_animation(ANIM_SHOW_THREE_OPTION)


func _play_animation(animation_name: StringName) -> void:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return
	_animation_player.play(animation_name)
	await _animation_player.animation_finished


func _fade(view: StringName, alpha: float, seconds: float) -> void:
	var nodes := _nodes_for_view(view)
	if nodes.is_empty() or _host == null:
		return
	var tween := _host.create_tween()
	tween.set_parallel(true)
	for node in nodes:
		if node != null:
			tween.tween_property(node, "modulate:a", alpha, seconds)
	await tween.finished


func _set_alpha(view: StringName, alpha: float) -> void:
	for node in _nodes_for_view(view):
		if node == null:
			continue
		var color: Color = node.modulate
		color.a = alpha
		node.modulate = color


func _nodes_for_view(view: StringName) -> Array:
	match view:
		VIEW_SHOP:
			return [_node(&"shop"), _node(&"shop_top")]
		VIEW_BAG:
			return [_node(&"bag")]
		VIEW_BATTLE:
			return [_node(&"battle")] if _node(&"battle") != null else []
		_:
			return [_node(&"three_option")]


func _view_owns_node(view: StringName, key: StringName) -> bool:
	match view:
		VIEW_SHOP:
			return key == &"shop" or key == &"shop_top"
		VIEW_BAG:
			return key == &"bag"
		VIEW_BATTLE:
			return key == &"battle"
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
