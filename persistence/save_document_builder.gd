extends RefCounted

const DocumentCodecScript := preload("res://persistence/save_codec.gd")
const SaveContractScript := preload("res://persistence/save_contract.gd")

## Canonical save/checkpoint document assembly. Ordinary saves and run-history
## checkpoints must pass through this same builder.


func build(
	state_payload: Dictionary,
	player_id: String,
	meta: Dictionary,
	determinism: Dictionary,
	history: Dictionary
) -> Dictionary:
	var summary := summary_from_state(state_payload)
	var document := DocumentCodecScript.build_save_document(
		SaveContractScript.SCHEMA,
		SaveContractScript.SCHEMA_VERSION,
		state_payload,
		player_id,
		meta,
		summary
	)
	document["determinism"] = determinism.duplicate(true)
	document["history"] = history.duplicate(true)
	document["checksum"] = DocumentCodecScript.save_checksum(document)
	return document


func summary_from_state(saved: Dictionary) -> Dictionary:
	var summary := {
		"phase": String(saved.get("phase", "")),
		"phaseLabel": phase_label(String(saved.get("phase", ""))),
		"stateVersion": int(saved.get("stateVersion", saved.get("state_version", 0))),
		"day": int(saved.get("day", 1)),
		"nodeIndex": int(saved.get("node_index", 0)),
		"coins": int(saved.get("coins", saved.get("gold", 0))),
		"heroHp": int(saved.get("hero_hp", 0)),
		"battleRound": int(saved.get("battle_round", saved.get("round", 0))),
		"unitCount": Array(saved.get("units", [])).size(),
		"rosterCount": Array(saved.get("roster", [])).size(),
	}
	summary["text"] = summary_text(summary)
	return summary


func phase_label(value: String) -> String:
	match value:
		"route": return "路线"
		"shop": return "商店"
		"reward": return "奖励"
		"battle": return "战斗"
		"battle_end": return "战斗结算"
		"day_end": return "日结"
		"game_over": return "终局"
		_: return value


func summary_text(summary: Dictionary) -> String:
	var parts := [
		"第%d天" % int(summary.get("day", 1)),
		String(summary.get("phaseLabel", summary.get("phase", ""))),
		"v%d" % int(summary.get("stateVersion", 0)),
	]
	if String(summary.get("phase", "")) == "battle":
		parts.insert(2, "回合%d" % int(summary.get("battleRound", 1)))
	parts.append("金币%d" % int(summary.get("coins", 0)))
	return " ".join(parts)
