extends RefCounted

const PORT_CONTRACT_ID := &"ysbzs.shop-effect-port.v2"
const ALLOWED_DESCRIPTORS := [
	{"stat": "atk", "base_stat": "base_atk", "modifier_stat": "atk", "label": "攻击"},
	{"stat": "def", "base_stat": "base_def", "modifier_stat": "def", "label": "防御"},
	{"stat": "max_hp", "base_stat": "base_max_hp", "modifier_stat": "max_hp", "label": "生命上限"},
	{"stat": "shield", "base_stat": "base_shield", "modifier_stat": "starting_shield", "label": "护盾"},
]


func plugin_id() -> String:
	return "party_stat"


func execute(port: RefCounted, _offer: Dictionary, effect: Dictionary) -> Dictionary:
	if not _accepts(port) or String(effect.get("type", "")) != plugin_id() or not port.has_roster():
		return {}
	for field in ["stat", "base_stat", "modifier_stat", "label", "value"]:
		if not effect.has(field):
			return {}
	var descriptor := {
		"stat": String(effect.get("stat", "")),
		"base_stat": String(effect.get("base_stat", "")),
		"modifier_stat": String(effect.get("modifier_stat", "")),
		"label": String(effect.get("label", "")),
	}
	if not ALLOWED_DESCRIPTORS.has(descriptor):
		return {}
	var value: int = max(1, int(effect.get("value", 1)))
	var source_id := String(effect.get("legacy_source_id", ""))
	if source_id == "":
		source_id = String(effect.get("source_id", "party_stat:%s" % descriptor["stat"]))
	if not port.apply_party_modifier(descriptor, value, source_id):
		return {}
	return {"type": plugin_id(), "text": "所有现有宠物永久%s+%d" % [descriptor["label"], value]}


func _accepts(port: RefCounted) -> bool:
	return port != null and port.has_method(&"contract_id") and StringName(port.contract_id()) == PORT_CONTRACT_ID
