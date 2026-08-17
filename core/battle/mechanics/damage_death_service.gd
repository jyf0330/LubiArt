extends RefCounted

const DamageResultScript := preload("res://core/battle/damage_result.gd")

## Resolves deaths only after damage state/history has been written. A caller
## may submit one packet or a whole multi-hit batch; candidate order is stable.

const PORT_CONTRACT_ID := &"ysbzs.damage-death-port.v1"
const REQUIRED_PORT_METHODS: Array[StringName] = [
	&"contract_id",
	&"should_die",
	&"on_death",
	&"after_ally_death",
	&"attacker_after_kill",
	&"publish_defeated",
]


func resolve(port: RefCounted, candidates: Array) -> Array:
	var logs: Array = []
	if not _accepts(port):
		return logs
	var settled_ids := {}
	for candidate_value in candidates:
		var candidate := Dictionary(candidate_value)
		var result := Dictionary(candidate.get("result", {}))
		var source := Dictionary(candidate.get("source", {}))
		var target := Dictionary(candidate.get("target", {}))
		var target_id := String(target.get("id", ""))
		if target.is_empty() or not bool(result.get("pending_death", false)):
			continue
		if target_id != "" and settled_ids.has(target_id):
			DamageResultScript.settle_death(result, bool(settled_ids[target_id]))
			continue
		if not bool(port.should_die(target)):
			DamageResultScript.settle_death(result, false)
			if target_id != "":
				settled_ids[target_id] = false
			continue
		for line in port.on_death(target, source):
			logs.append(String(line))
		var killed := bool(port.should_die(target))
		if killed:
			for line in port.after_ally_death(target):
				logs.append(String(line))
			for line in port.attacker_after_kill(source, target):
				logs.append(String(line))
			port.publish_defeated(source, target)
		DamageResultScript.settle_death(result, killed)
		if target_id != "":
			settled_ids[target_id] = killed
	return logs


func _accepts(port: RefCounted) -> bool:
	if port == null:
		return false
	for method_name in REQUIRED_PORT_METHODS:
		if not port.has_method(method_name):
			return false
	return StringName(port.call(&"contract_id")) == PORT_CONTRACT_ID
