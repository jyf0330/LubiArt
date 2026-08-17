extends SceneTree

const StateScript := preload("res://core/state/game_state.gd")

var _failed := false


func _initialize() -> void:
	var state: RefCounted = StateScript.new()
	state.call("set_board_dimensions", 8, 8)
	state.set("day", 6)
	state.set("coins", 10)

	_expect(bool(state.call("dispatch", {"type": "APPLY_ROUTE_EVENT", "eventId": "evt_curse_gold"})), "public route command queues the gold-risk event")
	var queued := Dictionary(state.call("snapshot"))
	_expect(int(queued.get("coins", 0)) == 14, "risk event grants its immediate gold before battle")
	var queued_effects := Array(Dictionary(queued.get("route_effects", {})).get("outer_run", []))
	_expect(queued_effects.size() == 1, "risk event creates exactly one outer-run effect")
	if queued_effects.size() == 1:
		_expect(int(Dictionary(queued_effects[0]).get("multiplier", 0)) == 90, "queued effect stores the parsed 90-percent multiplier")

	var before_battle_gold := int(queued.get("coins", 0))
	_expect(bool(state.call("dispatch", {"type": "START_BATTLE"})), "public command starts the affected battle")
	state.set("enemy_hero_hp", 0)
	state.call("_check_battle_end")
	var settled := Dictionary(state.call("snapshot"))
	var result := Dictionary(settled.get("battle_result", {}))
	_expect(int(result.get("gold_base_delta", 0)) == 6, "settlement records the unmodified fast-clear gold")
	_expect(int(result.get("gold", 0)) == 5, "settlement floors six gold at the 90-percent multiplier")
	_expect(int(result.get("gold_to", 0)) == before_battle_gold + 5, "settlement writes the adjusted authoritative gold total")
	var consumed := Array(result.get("run_effects", []))
	_expect(consumed.size() == 1, "settlement consumes the effect exactly once")
	if consumed.size() == 1:
		var effect := Dictionary(consumed[0])
		_expect(String(effect.get("status", "")) == "consumed", "settlement marks the risk effect consumed")
		_expect(int(effect.get("uses_remaining", -1)) == 0, "settlement exhausts the risk effect")
		_expect(int(effect.get("gold_delta_from", 0)) == 6 and int(effect.get("gold_delta_to", 0)) == 5, "settlement keeps before/after gold audit values")
	var authoritative_effects := Array(Dictionary(settled.get("route_effects", {})).get("outer_run", []))
	_expect(authoritative_effects.size() == 1, "authoritative outer-run state keeps exactly one risk effect")
	if authoritative_effects.size() == 1:
		_expect(String(Dictionary(authoritative_effects[0]).get("status", "")) == "consumed", "authoritative risk effect is written back as consumed")
		_expect(int(Dictionary(authoritative_effects[0]).get("uses_remaining", -1)) == 0, "authoritative risk effect is written back with zero uses")
	var gold_after_settlement := int(settled.get("coins", 0))
	var second_application := Dictionary(state.call("_apply_outer_run_effects_to_gold_delta", gold_after_settlement))
	_expect(Array(second_application.get("consumed", [])).is_empty(), "consumed risk effect cannot be applied a second time")
	_expect(int(second_application.get("gold_delta", -1)) == 0, "second application cannot reduce another reward delta")
	_expect(int(state.get("coins")) == gold_after_settlement, "second application preserves authoritative gold")
	var log_lines := Array(settled.get("log_lines", []))
	_expect(_log_index(log_lines, "节点事件【贪婪诅咒】") >= 0, "event queueing remains visible in the log")
	_expect(_log_index(log_lines, "奖励折损") < _log_index(log_lines, "节点事件【贪婪诅咒】"), "reverse-chronological log keeps reward reduction later than event queueing")

	print("SMOKE_RUN_FLOW_ECONOMY_RULES_%s" % ["OK" if not _failed else "FAIL"])
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Smoke failed: %s" % message)


func _log_index(lines: Array, needle: String) -> int:
	for index in range(lines.size()):
		if String(lines[index]).contains(needle):
			return index
	return -1
