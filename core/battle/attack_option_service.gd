extends RefCounted

const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")

## Builds directional attack options from catalog geometry plus a quality
## effect. Options describe coverage only; cadence belongs to action/skill
## definitions and is intentionally absent here.


func build_options(
	unit: Dictionary,
	width: int,
	height: int,
	definition: Dictionary,
	quality_effect: Variant,
	quality_upgrade_name: String
) -> Array:
	var offsets := Array(definition.get("offsets", []))
	if offsets.is_empty():
		offsets = [{"dr": 0, "dc": 1}]
	var options: Array = []
	for direction in ["right", "down", "left", "up"]:
		var cells: Array = []
		for offset in offsets:
			if typeof(offset) != TYPE_DICTIONARY:
				continue
			var cell := ShapeGeometryScript.offset_cell(unit, Dictionary(offset), direction)
			ShapeGeometryScript.append_unique_cell(
				cells,
				int(cell.get("x", -1)),
				int(cell.get("y", -1)),
				width,
				height
			)
		if cells.is_empty():
			continue
		cells = quality_effect.mutate_shape(unit, direction, cells, width, height)
		var shape_name := quality_shape_name(
			String(definition.get("label", "形状01")),
			quality_effect,
			quality_upgrade_name
		)
		options.append({
			"direction": direction,
			"direction_label": ShapeGeometryScript.direction_label(direction),
			"shape_id": String(definition.get("shape_id", "01")),
			"shape_name": shape_name,
			"cells": cells
		})
	return options


func quality_shape_name(base_name: String, quality_effect: Variant, quality_upgrade_name: String) -> String:
	if quality_effect.changes_shape_name:
		return "%s+%s" % [base_name, quality_upgrade_name]
	return base_name


func option_for_direction(options: Array, direction: String) -> Dictionary:
	var normalized := ShapeGeometryScript.normalize_direction(direction)
	for option in options:
		var row := Dictionary(option)
		if String(row.get("direction", "")) == normalized:
			return row
	return {}


func option_for_target(
	options: Array,
	target: Dictionary,
	direction: String = ""
) -> Dictionary:
	var target_x := int(target.get("x", -1))
	var target_y := int(target.get("y", -1))
	var normalized := ShapeGeometryScript.normalize_direction(direction) if direction != "" else ""
	for option in options:
		var row := Dictionary(option)
		if normalized != "" and String(row.get("direction", "")) != normalized:
			continue
		if ShapeGeometryScript.option_contains_cell(row, target_x, target_y):
			return row
	return {}
