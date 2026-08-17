extends SceneTree

const ThreatTargetPolicyScript := preload("res://core/battle/threat_target_policy.gd")

var failed := false


func _initialize() -> void:
	var policy := ThreatTargetPolicyScript.new()
	var enemy := {"id": "enemy", "x": 3, "y": 3}
	var first := {"id": "first", "x": 2, "y": 3, "hp": 10, "side": "player"}
	var tied := {"id": "tied", "x": 3, "y": 2, "hp": 10, "side": "player"}
	var leader := {"id": "player_leader", "x": 4, "y": 3, "alive": true}

	var tie_result := policy.select(enemy, [first, tied], leader, [])
	_expect(String(Dictionary(tie_result.get("target", {})).get("id", "")) == "first", "unit order breaks equal-distance ties before the leader")

	leader["x"] = 3
	leader["y"] = 3
	var leader_result := policy.select(enemy, [first, tied], leader, [])
	_expect(String(Dictionary(leader_result.get("target", {})).get("id", "")) == "player_leader", "strictly closer living leader becomes the target")

	var distant_taunt := {"id": "distant_taunt", "x": 0, "y": 0, "hp": 10, "side": "player"}
	var close_taunt := {"id": "close_taunt", "x": 3, "y": 1, "hp": 10, "side": "player"}
	var taunt_result := policy.select(enemy, [first], leader, [
		{"target": distant_taunt, "range": 2, "mechanic_id": "fixture_distant_taunt", "mechanic_name": "远距嘲讽"},
		{"target": close_taunt, "range": 2, "mechanic_id": "fixture_close_taunt", "mechanic_name": "近距嘲讽"},
	])
	_expect(String(Dictionary(taunt_result.get("target", {})).get("id", "")) == "close_taunt", "in-range taunt overrides ordinary and leader targets")
	var redirect := Dictionary(taunt_result.get("redirect", {}))
	_expect(
		String(redirect.get("mechanic_id", "")) == "fixture_close_taunt"
		and String(redirect.get("mechanic_name", "")) == "近距嘲讽"
		and String(redirect.get("target_id", "")) == "close_taunt",
		"taunt result copies redirect identity and name from the selected candidate"
	)

	if failed:
		quit(1)
		return
	print("SMOKE_THREAT_TARGET_POLICY_OK")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Smoke failed: %s" % message)
