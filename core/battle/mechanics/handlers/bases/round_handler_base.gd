extends RefCounted

const ROUND_PORT_CONTRACT_ID := &"ysbzs.round-lifecycle-port.v1"


func _accepts_round_port(port: RefCounted) -> bool:
	return (
		port != null
		and port.has_method(&"contract_id")
		and StringName(port.call(&"contract_id")) == ROUND_PORT_CONTRACT_ID
	)


func _shield_gain(port: RefCounted, unit: Dictionary, mechanism: Dictionary, fallback: int) -> Array:
	if not _accepts_round_port(port) or unit.is_empty():
		return []
	var gain: int = int(port.mechanic_param_int(unit, mechanism, "shield", fallback))
	var before := int(unit.get("shield", 0))
	unit["shield"] = before + gain
	return ["%s 回合开始触发护盾恢复：护盾 %d→%d。" % [
		String(unit.get("name", "单位")), before, int(unit.get("shield", 0))
	]]


func _attack_gain(port: RefCounted, unit: Dictionary, mechanism: Dictionary) -> Array:
	if not _accepts_round_port(port) or unit.is_empty():
		return []
	var gain: int = int(port.mechanic_param_int(unit, mechanism, "atk", 1))
	var before: int = int(unit.get("atk", unit.get("attack", 0)))
	unit["atk"] = before + gain
	return ["%s 回合开始攻击+%d：攻击 %d→%d。" % [
		String(unit.get("name", "单位")), gain, before, int(unit.get("atk", 0))
	]]
