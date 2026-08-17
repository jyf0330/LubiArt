extends RefCounted

## Shared presentation shortcut catalog. Every visible binding in the settings
## page is backed by one of these keys and consumed by the matching UI owner.

const ACTION_SETTINGS := &"settings"
const ACTION_SAVE_LOAD := &"save_load"
const ACTION_AUTO_ARRANGE := &"auto_arrange"
const ACTION_RESET_ARRANGE := &"reset_arrange"
const ACTION_BATTLE_SPEED := &"battle_speed"
const ACTION_ATTACK_ORDER := &"attack_order"
const ACTION_BATTLE_BAG := &"battle_bag"
const ACTION_ALL_OUT := &"all_out"
const ACTION_SELL_ITEM := &"sell_item"

const INPUT_KEY := "key"
const INPUT_MOUSE := "mouse"

const BATTLE_BUTTON_PATHS := {
	KEY_A: ^"AutoArrangeButton",
	KEY_R: ^"ResetButton",
	KEY_D: ^"SpeedButton",
	KEY_TAB: ^"AttackOrderButton",
	KEY_B: ^"BagButton",
	KEY_ESCAPE: ^"SettingsButton",
	KEY_SPACE: ^"AllOutButton",
}

const SELL_ITEM_KEY := KEY_E
const SAVE_LOAD_KEY := KEY_J

const DISPLAY_BINDINGS := [
	{"id": ACTION_SETTINGS, "node": "Settings", "label": "进入设置", "keycode": KEY_ESCAPE},
	{"id": ACTION_SAVE_LOAD, "node": "SaveLoad", "label": "打开/关闭快速存读档栏", "keycode": SAVE_LOAD_KEY},
	{"id": ACTION_AUTO_ARRANGE, "node": "AutoArrange", "label": "自动布阵", "keycode": KEY_A},
	{"id": ACTION_RESET_ARRANGE, "node": "ResetArrange", "label": "重置布阵", "keycode": KEY_R},
	{"id": ACTION_BATTLE_SPEED, "node": "BattleSpeed", "label": "打开战斗日志", "keycode": KEY_D},
	{"id": ACTION_ATTACK_ORDER, "node": "AttackOrder", "label": "查看攻击顺序", "keycode": KEY_TAB},
	{"id": ACTION_BATTLE_BAG, "node": "BattleBag", "label": "回撤到上一回合开始", "keycode": KEY_B},
	{"id": ACTION_ALL_OUT, "node": "AllOut", "label": "全军出击", "keycode": KEY_SPACE},
	{"id": ACTION_SELL_ITEM, "node": "SellItem", "label": "出售物品", "keycode": SELL_ITEM_KEY},
]

const BATTLE_BUTTON_ACTIONS := {
	ACTION_AUTO_ARRANGE: ^"AutoArrangeButton",
	ACTION_RESET_ARRANGE: ^"ResetButton",
	ACTION_BATTLE_SPEED: ^"SpeedButton",
	ACTION_ATTACK_ORDER: ^"AttackOrderButton",
	ACTION_BATTLE_BAG: ^"BagButton",
	ACTION_SETTINGS: ^"SettingsButton",
	ACTION_ALL_OUT: ^"AllOutButton",
}

static var _binding_overrides: Dictionary = {}


static func default_binding(action_id: StringName) -> Dictionary:
	for binding_value in DISPLAY_BINDINGS:
		var definition := Dictionary(binding_value)
		if StringName(definition.get("id", &"")) == action_id:
			return {"type": INPUT_KEY, "code": int(definition.get("keycode", KEY_NONE))}
	return {}


static func get_binding(action_id: StringName) -> Dictionary:
	if _binding_overrides.has(action_id):
		return Dictionary(_binding_overrides[action_id]).duplicate(true)
	return default_binding(action_id)


static func set_binding(action_id: StringName, binding: Dictionary) -> bool:
	if default_binding(action_id).is_empty() or not _is_valid_binding(binding):
		return false
	_binding_overrides[action_id] = _normalized_binding(binding)
	return true


static func assign_binding(action_id: StringName, binding: Dictionary) -> bool:
	if default_binding(action_id).is_empty() or not _is_valid_binding(binding):
		return false
	var normalized := _normalized_binding(binding)
	var previous := get_binding(action_id)
	for binding_value in DISPLAY_BINDINGS:
		var other_action := StringName(Dictionary(binding_value).get("id", &""))
		if other_action != action_id and get_binding(other_action) == normalized:
			set_binding(other_action, previous)
			break
	set_binding(action_id, normalized)
	return true


static func reset_binding(action_id: StringName) -> void:
	_binding_overrides.erase(action_id)


static func is_default(action_id: StringName) -> bool:
	return get_binding(action_id) == default_binding(action_id)


static func load_bindings(saved_bindings: Dictionary) -> void:
	_binding_overrides.clear()
	for action_value in saved_bindings:
		var action_id := StringName(action_value)
		var binding_value: Variant = saved_bindings[action_value]
		if binding_value is Dictionary:
			set_binding(action_id, Dictionary(binding_value))


static func serialized_bindings() -> Dictionary:
	var result := {}
	for binding_value in DISPLAY_BINDINGS:
		var action_id := StringName(Dictionary(binding_value).get("id", &""))
		result[String(action_id)] = get_binding(action_id)
	return result


static func binding_from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var keycode := event_keycode(event as InputEventKey)
		return {"type": INPUT_KEY, "code": int(keycode)} if keycode != KEY_NONE else {}
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not _is_supported_mouse_button(mouse_event.button_index):
			return {}
		return {"type": INPUT_MOUSE, "code": int(mouse_event.button_index)}
	return {}


static func event_matches_action(event: InputEvent, action_id: StringName) -> bool:
	var event_binding := binding_from_event(event)
	return not event_binding.is_empty() and event_binding == get_binding(action_id)


static func action_for_event(event: InputEvent, allowed_actions: Array = []) -> StringName:
	var event_binding := binding_from_event(event)
	if event_binding.is_empty():
		return &""
	for binding_value in DISPLAY_BINDINGS:
		var action_id := StringName(Dictionary(binding_value).get("id", &""))
		if not allowed_actions.is_empty() and action_id not in allowed_actions:
			continue
		if get_binding(action_id) == event_binding:
			return action_id
	return &""


static func display_binding_name(binding: Dictionary) -> String:
	var input_type := String(binding.get("type", ""))
	var code := int(binding.get("code", 0))
	if input_type == INPUT_MOUSE:
		match code:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			_:
				return "MOUSE %d" % code
	return display_key_name(code as Key)


static func _normalized_binding(binding: Dictionary) -> Dictionary:
	return {"type": String(binding.get("type", "")), "code": int(binding.get("code", 0))}


static func _is_valid_binding(binding: Dictionary) -> bool:
	var input_type := String(binding.get("type", ""))
	var code := int(binding.get("code", 0))
	if input_type == INPUT_KEY:
		return code > 0
	return input_type == INPUT_MOUSE and _is_supported_mouse_button(code as MouseButton)


static func _is_supported_mouse_button(button_index: MouseButton) -> bool:
	return button_index in [
		MOUSE_BUTTON_LEFT,
		MOUSE_BUTTON_RIGHT,
		MOUSE_BUTTON_MIDDLE,
		MOUSE_BUTTON_XBUTTON1,
		MOUSE_BUTTON_XBUTTON2,
	]


static func event_keycode(event: InputEventKey) -> Key:
	if event.keycode != KEY_NONE:
		return event.keycode
	return event.physical_keycode


static func matches_key(event: InputEventKey, expected_keycode: Key) -> bool:
	return event.keycode == expected_keycode or event.physical_keycode == expected_keycode


static func display_key_name(keycode: Key) -> String:
	match keycode:
		KEY_ESCAPE:
			return "ESC"
		KEY_SPACE:
			return "SPACE"
		KEY_TAB:
			return "TAB"
		_:
			return OS.get_keycode_string(keycode).to_upper()
