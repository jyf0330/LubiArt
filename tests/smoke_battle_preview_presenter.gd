extends SceneTree

const BattlePreviewPresenter := preload(
	"res://core_ui/scripts/battle/controllers/battle_preview_presenter.gd"
)
const PRESENTER_PATH := \
	"res://core_ui/scripts/battle/controllers/battle_preview_presenter.gd"


func _initialize() -> void:
	var presenter := BattlePreviewPresenter.new()
	var snapshot := {
		"action_preview_by_unit": {
			"pet_a": {
				"origin": {"x": 1, "y": 1},
				"direction": "right",
				"cells": [
					{"x": 1, "y": 1},
					{"x": 2, "y": 1},
					{"x": 2, "y": 1},
					{"x": 1, "y": 0},
				],
			},
		},
		"board": {
			"cells": [
				{"x": 2, "y": 2, "unitId": "pet_a"},
			],
		},
		"placement_damage_by_unit": {
			"pet_a": {"totalDamage": 7, "hpTo": 13},
		},
	}

	assert(presenter.action_cells_for_drag(
		snapshot,
		"pet_a",
		Vector2i(3, 2),
		Vector2i(4, 4)
	) == [Vector2i(3, 1), Vector2i(3, 2)])
	assert(presenter.action_cells_for_drag(
		snapshot,
		"missing",
		Vector2i.ZERO,
		Vector2i(4, 4)
	).is_empty())
	assert(presenter.direction_cells(
		snapshot,
		"pet_a",
		"down",
		Vector2i(4, 4)
	) == [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2)])
	assert(presenter.direction_cells(
		{},
		"pet_a",
		"down",
		Vector2i(4, 4)
	).is_empty())
	assert(presenter.direction_cells(
		snapshot,
		"pet_a",
		"diagonal",
		Vector2i(4, 4)
	).is_empty())
	assert(presenter.action_cells_for_drag(
		{"action_preview_by_unit": {"pet_a": {"origin": [], "cells": "bad"}}},
		"pet_a",
		Vector2i.ZERO,
		Vector2i(4, 4)
	).is_empty())

	var incoming := presenter.incoming_preview(snapshot, "pet_a")
	assert(int(incoming.get("totalDamage", 0)) == 7)
	incoming["totalDamage"] = 99
	assert(int(Dictionary(snapshot["placement_damage_by_unit"])["pet_a"]["totalDamage"]) == 7)
	assert(presenter.incoming_preview(snapshot, "missing").is_empty())
	assert(presenter.incoming_preview({"placement_damage_by_unit": []}, "pet_a").is_empty())

	var cell := {
		"previews": [
			{"actorId": "pet_a", "preview_type": "ally", "hitEnemy": false},
			{"actorId": "pet_a", "preview_type": "target", "hitEnemy": true, "token": "public"},
		],
		"mock_target_previews_by_actor": {
			"missing": {"actorId": "missing", "hitEnemy": true},
		},
	}
	var target := presenter.target_preview(cell, "pet_a")
	assert(String(target.get("token", "")) == "public")
	target["token"] = "mutated"
	assert(String(Dictionary(Array(cell["previews"])[1]).get("token", "")) == "public")
	assert(presenter.target_preview(cell, "missing").is_empty())
	assert(presenter.target_preview(cell, "").is_empty())
	assert(presenter.target_preview({"previews": "bad"}, "pet_a").is_empty())

	var source_file := FileAccess.open(PRESENTER_PATH, FileAccess.READ)
	assert(source_file != null)
	var source := source_file.get_as_text()
	for forbidden in [
		"mock_",
		"predictedHpTo",
		"predicted_hp_to",
		"predictedShieldTo",
		"predicted_shield_to",
		"hpTo",
		"shieldTo",
		"mini(",
		"maxi(",
	]:
		assert(not source.contains(forbidden), "Presenter contains forbidden projection: %s" % forbidden)

	print("BATTLE_PREVIEW_PRESENTER_SMOKE_PASS")
	quit(0)
