# 2026-08-03 切片 C1 — 品质域下沉 `QualityPolicy`

author: Claude（架构师）
status: SPEC_READY
前置: `2026-08-03_FACADE_DEAD_CODE_CLEANUP_SPEC.md` 执行完（方法计数 518→494）→ 再读 `2026-08-03_FACADE_DESCENT_MASTER_SPEC.md` 总纲
切片: C1 / 提交数: 1

## 0. 本切片目标

把 facade `core/state/game_state.gd` 的品质纯函数闭包（15 个方法）整体搬到一个无 authority 依赖的纯服务 `core/battle/quality/quality_policy.gd`。`_apply_quality_progression` 只改传入的 `unit` 字典（实测 0 顶层字段写、0 `_log`），是理想的首个切片。搬移后 stateHash / save / replay 冻结哈希必须逐字节不变。

## 1. 冻结基线（验收必须逐项一致）

| 项目 | 冻结值 |
|---|---|
| P0 `normalizedSha256` | `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562` |
| P0 save `checksum` | `875e3dbe` |
| P0 replay `checksum` | `c53db478` |
| facade 方法计数 | 494 − 12（12 个方法搬出，3 个原地改转发壳，计数不变）→ 482 |
| 反向依赖 | `0 methods / 0 calls` |

P0 探针：`tests/core/dump_puzzle_refactor_baseline.gd`。

## 2. 方法处置表（15 个，全部在 HEAD L814..L998 连续闭包）

| 方法 | 行区间(HEAD) | 外部引用 | 处置 |
|---|---|---|---|
| `_apply_quality_progression(unit, fill_hp_to_max) -> void` | 929-998 | **port** `shop_effect_port.gd:42`（`_authority.call`）+ 4 tests | facade 改转发壳 |
| `_quality_data() -> Dictionary` | 823-824 | `capture_singleplayer.gd:443`、`singleplayer_smoke_suite.gd:434` | facade 改转发壳 |
| `_quality_upgrade_for(quality, shape_size, selection_seed="") -> Dictionary` | 843-854 | `smoke_quality_upgrade_selection_policy.gd:57,58` | facade 改转发壳 |
| `_normalize_quality(quality) -> String` | 814-816 | 无 | 搬入服务 |
| `_quality_key(quality) -> String` | 817-819 | 无 | 搬入服务 |
| `_next_quality(quality) -> String` | 820-821 | 无 | 搬入服务 |
| `_shape_size_for_unit(unit) -> int` | 826-831 | 无 | 搬入服务（参数化 game_data） |
| `_quality_growth_for(quality, shape_size) -> Dictionary` | 832-841 | 无 | 搬入服务（参数化 quality_data） |
| `_quality_existing_category_hit_probability(count) -> float` | 856-857 | 无 | 搬入服务 |
| `_quality_known_categories(categories) -> Array` | 859-860 | 无 | 搬入服务 |
| `_pick_from_list(list, random) -> Variant` | 862-866 | 无 | 搬入服务 |
| `_choose_quality_evolution_category(prev, random) -> String` | 868-882 | 无 | 搬入服务 |
| `_element_slots_for_evolution(unit) -> Array` | 884-896 | 无 | 搬入服务 |
| `_build_quality_evolution_points(quality, seed, unit) -> Array` | 898-924 | 无 | 搬入服务 |
| `_summarize_quality_evolution_points(points) -> Dictionary` | 926-927 | 无 | 搬入服务 |

> 实测写字段：15 个方法**全部 0 个顶层 `self.` 写**、0 个 `_log` 调用。纯函数，本切片无 `_log` 收集。

## 3. 新建服务 `core/battle/quality/quality_policy.gd`（逐字复制）

`extends RefCounted`，纯计算，不持有 authority。参数化后原 `_quality_data()`/`_shape_size_for_unit` 中读到的 `game_data`、`_quality_growth_for`/`_quality_upgrade_for` 中读到的 quality 子字典一律经参数传入。

```gdscript
extends RefCounted

const QualityRulesScript := preload("res://core/party/quality_rules.gd")
const SkillShapeRulesScript := preload("res://core/battle/skills/skill_shape_rules.gd")
const QualityUpgradeSelectionPolicyScript := preload("res://core/party/quality_upgrade_selection_policy.gd")
const QualitySeededSelectorScript := preload("res://core/run/seeded_selector.gd")
const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")

## Pure quality evolution rules. No authority access; game_data is passed per call.

func normalize_quality(quality: String) -> String:
	return QualityRulesScript.normalize(quality)

func quality_key(quality: String) -> String:
	return QualityRulesScript.key(quality)

func next_quality(quality: String) -> String:
	return QualityRulesScript.next(quality)

func quality_data(game_data: Dictionary) -> Dictionary:
	return Dictionary(game_data.get("quality", {}))

func shape_size_for_unit(unit: Dictionary, game_data: Dictionary) -> int:
	var size: int = max(1, int(unit.get("hit_cells", 1)))
	if size <= 1:
		size = max(size, int(SkillShapeRulesScript.shape_definition(unit, game_data).get("cell_count", size)))
	return clamp(size, 1, 3)

func quality_growth_for(quality: String, shape_size: int, quality_data: Dictionary) -> Dictionary:
	var quality_key_local := quality_key(quality)
	var wanted_size: int = clamp(shape_size, 1, 3)
	for item in Array(quality_data.get("growth", [])):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := Dictionary(item)
		if String(row.get("quality", "")) == quality_key_local and int(row.get("shape_size", 1)) == wanted_size:
			return row
	return {"quality": quality_key_local, "label": normalize_quality(quality), "shape_size": wanted_size, "hp_bonus": 0, "atk_bonus": 0}

func quality_upgrade_for(quality: String, shape_size: int, quality_data: Dictionary, selection_seed: String = "") -> Dictionary:
	return QualityUpgradeSelectionPolicyScript.select_upgrade(
		Array(quality_data.get("upgrades", [])),
		quality_key(quality),
		shape_size,
		selection_seed
	)

func quality_existing_category_hit_probability(existing_category_count: int) -> float:
	return QualityRulesScript.existing_category_hit_probability(existing_category_count, QualityRulesScript.EVOLUTION_POINT_CATEGORIES)

func quality_known_categories(categories: Array) -> Array:
	return QualityRulesScript.known_categories(categories, QualityRulesScript.EVOLUTION_POINT_CATEGORIES)

func pick_from_list(list: Array, random: Dictionary) -> Variant:
	if list.is_empty():
		return null
	var index: int = min(list.size() - 1, int(floor(QualitySeededSelectorScript.next(random) * list.size())))
	return list[index]

func choose_quality_evolution_category(previous_categories: Array, random: Dictionary) -> String:
	var existing := quality_known_categories(previous_categories)
	var all: Array = []
	for row in QualityRulesScript.EVOLUTION_POINT_CATEGORIES:
		all.append(String(Dictionary(row).get("id", "")))
	var missing: Array = []
	for category in all:
		if not existing.has(String(category)):
			missing.append(category)
	if existing.is_empty():
		return String(pick_from_list(all, random))
	if missing.is_empty():
		return String(pick_from_list(existing, random))
	var hit_existing := QualitySeededSelectorScript.next(random) < quality_existing_category_hit_probability(existing.size())
	return String(pick_from_list(existing if hit_existing else missing, random))

func element_slots_for_evolution(unit: Dictionary) -> Array:
	var elements := Dictionary(unit.get("elements", {}))
	var positive: Array = []
	for key in elements.keys():
		if int(elements.get(key, 0)) > 0:
			positive.append(String(key))
	positive.sort()
	if not positive.is_empty():
		return positive
	var element := String(unit.get("element", ""))
	if element != "":
		return [element]
	return ElementRulesScript.active_elements()

func build_quality_evolution_points(quality: String, seed: String, unit: Dictionary) -> Array:
	var quality_key_local := quality_key(quality)
	var count: int = int(QualityRulesScript.EVOLUTION_POINT_TOTALS.get(quality_key_local, 0))
	var random := QualitySeededSelectorScript.rng("quality:evolution:%s:%s" % [quality_key_local, seed])
	var previous_categories: Array = []
	var points: Array = []
	for index in range(count):
		var category := choose_quality_evolution_category(previous_categories, random)
		var meta := {}
		for row in QualityRulesScript.EVOLUTION_POINT_CATEGORIES:
			if String(Dictionary(row).get("id", "")) == category:
				meta = Dictionary(row)
				break
		var point := {
			"index": index + 1,
			"category": category,
			"label": String(meta.get("label", category)),
			"description": String(meta.get("description", "")),
			"amount": 1
		}
		if category == "hp":
			point["amount"] = 5 + int(floor(QualitySeededSelectorScript.next(random) * 6.0))
		elif category == "element":
			point["element"] = String(pick_from_list(element_slots_for_evolution(unit), random))
		points.append(point)
		previous_categories.append(category)
	return points

func summarize_quality_evolution_points(points: Array) -> Dictionary:
	return QualityRulesScript.summarize_evolution_points(points)

func apply_quality_progression(unit: Dictionary, fill_hp_to_max: bool, game_data: Dictionary) -> void:
	var quality := normalize_quality(String(unit.get("quality", "青铜")))
	unit["quality"] = quality
	if not unit.has("base_max_hp"):
		unit["base_max_hp"] = max(1, int(unit.get("max_hp", unit.get("hp", 1))))
	if not unit.has("base_atk"):
		unit["base_atk"] = max(0, int(unit.get("atk", 0)))
	if not unit.has("base_def"):
		unit["base_def"] = max(0, int(unit.get("def", 0)))
	if not unit.has("base_shield"):
		unit["base_shield"] = max(0, int(unit.get("shield", 0)))
	if not unit.has("base_elements"):
		unit["base_elements"] = Dictionary(unit.get("elements", {})).duplicate(true)
	var shape_size := shape_size_for_unit(unit, game_data)
	var growth_mode := "evolution_points" if String(unit.get("quality_growth_mode", "")) == "evolution_points" else "quality_table"
	var growth := quality_growth_for(quality, shape_size, quality_data(game_data))
	var evolution_points: Array = []
	var evolution_summary := {"hp_bonus": 0, "attack_bonus": 0, "defense_bonus": 0, "element_layers": {}}
	var hp_bonus: int = int(growth.get("hp_bonus", 0))
	var atk_bonus: int = int(growth.get("atk_bonus", 0))
	var def_bonus := 0
	if growth_mode == "evolution_points":
		var seed := String(unit.get("quality_growth_seed", unit.get("pet_id", unit.get("id", unit.get("name", "")))))
		evolution_points = build_quality_evolution_points(quality, seed, unit)
		evolution_summary = summarize_quality_evolution_points(evolution_points)
		hp_bonus = int(evolution_summary.get("hp_bonus", 0))
		atk_bonus = int(evolution_summary.get("attack_bonus", 0))
		def_bonus = int(evolution_summary.get("defense_bonus", 0))
		growth = {
			"quality": quality_key(quality),
			"label": quality,
			"shape_size": shape_size,
			"growth_mode": growth_mode,
			"hp_bonus": hp_bonus,
			"atk_bonus": atk_bonus,
			"def_bonus": def_bonus,
			"element_layers": Dictionary(evolution_summary.get("element_layers", {})).duplicate(true)
		}
	unit["max_hp"] = max(1, int(unit.get("base_max_hp", 1)) + hp_bonus)
	unit["atk"] = max(0, int(unit.get("base_atk", 0)) + atk_bonus + int(unit.get("skill_bonus_atk", 0)))
	unit["def"] = max(0, int(unit.get("base_def", 0)) + def_bonus)
	unit["shield"] = max(0, int(unit.get("base_shield", 0)))
	if growth_mode == "evolution_points":
		var current_elements := Dictionary(unit.get("base_elements", {})).duplicate(true)
		for element in Dictionary(evolution_summary.get("element_layers", {})).keys():
			current_elements[element] = int(current_elements.get(element, 0)) + int(Dictionary(evolution_summary.get("element_layers", {})).get(element, 0))
		unit["elements"] = current_elements
	unit["quality_growth"] = growth.duplicate(true)
	var upgrade_seed := String(unit.get("quality_upgrade_seed", ""))
	var upgrade := quality_upgrade_for(quality, shape_size, quality_data(game_data), upgrade_seed)
	unit["quality_upgrade"] = upgrade.duplicate(true)
	unit["quality_progression"] = {
		"growth_mode": growth_mode,
		"quality": quality_key(quality),
		"label": quality,
		"shape_size": shape_size,
		"hp_bonus": hp_bonus,
		"atk_bonus": atk_bonus,
		"def_bonus": def_bonus,
		"evolution_points": evolution_points.duplicate(true),
		"evolution_summary": evolution_summary.duplicate(true),
		"upgrade_selection": "seeded" if upgrade_seed != "" else "legacy_first",
		"upgrade_id": String(upgrade.get("id", "")),
		"upgrade_name": String(upgrade.get("name", ""))
	}
	if fill_hp_to_max or not unit.has("hp"):
		unit["hp"] = int(unit["max_hp"])
	else:
		unit["hp"] = min(int(unit.get("hp", unit["max_hp"])), int(unit["max_hp"]))
```

> 唯一非逐字的改动：`_quality_growth_for`/`_build_quality_evolution_points` 内原局部变量 `var quality_key := _quality_key(quality)` 改为 `var quality_key_local := quality_key(quality)`，避免与方法同名（GDScript 局部遮蔽方法名）。其余方法体与 facade 逐字一致，内部调用 `_x` → `x`、`_quality_data()` → 参数。

## 4. facade 编辑

### 4a. 把连续闭包 L814..L998 替换为 3 个转发壳

锚点（不依赖行号，基于唯一签名）：
- 起：`func _normalize_quality(quality: String) -> String:`（其后到 `_apply_quality_progression` 结束前的**所有方法**均属于本闭包，实测无夹杂其他方法）
- 止：`_apply_quality_progression` 的最后 4 行
```
	if fill_hp_to_max or not unit.has("hp"):
		unit["hp"] = int(unit["max_hp"])
	else:
		unit["hp"] = min(int(unit.get("hp", unit["max_hp"])), int(unit["max_hp"]))
```
整块（含其中所有 `## ` 注释）替换为：

```gdscript
func _quality_data() -> Dictionary:
	return _core_composition.quality_policy.quality_data(game_data)

func _quality_upgrade_for(
	quality: String,
	shape_size: int,
	selection_seed: String = ""
) -> Dictionary:
	return _core_composition.quality_policy.quality_upgrade_for(
		quality,
		shape_size,
		_quality_data(),
		selection_seed
	)

func _apply_quality_progression(unit: Dictionary, fill_hp_to_max: bool) -> void:
	_core_composition.quality_policy.apply_quality_progression(unit, fill_hp_to_max, game_data)
```

3 个转发壳保持**原签名**（含 `_quality_upgrade_for` 的默认参数），`shop_effect_port.gd:42` 的 `_authority.call("_apply_quality_progression", pet, true)` 与 tests 全部零改动。

### 4b. 调用点变更（7 处，字符串替换；括号内为 HEAD 参考行号）

`_normalize_quality` → `_core_composition.quality_policy.normalize_quality`
| 所在方法 | 原文 | 新文 |
|---|---|---|
| `_clone_units` (L574) | `unit["quality"] = _normalize_quality(String(unit.get("quality", "青铜")))` | `unit["quality"] = _core_composition.quality_policy.normalize_quality(String(unit.get("quality", "青铜")))` |
| `_add_pet_to_roster` (L1131) | `var incoming_quality := _normalize_quality(String(source.get("quality", "青铜")))` | `var incoming_quality := _core_composition.quality_policy.normalize_quality(String(source.get("quality", "青铜")))` |
| `_add_pet_to_roster` (L1136) | `var quality_from: String = _normalize_quality(String(existing.get("quality", incoming_quality)))` | `var quality_from: String = _core_composition.quality_policy.normalize_quality(String(existing.get("quality", incoming_quality)))` |
| `_add_roster_summary` (L1949) | `var tier := _normalize_quality(String(row.get("quality", catalog.get("quality", "青铜"))))` | `var tier := _core_composition.quality_policy.normalize_quality(String(row.get("quality", catalog.get("quality", "青铜"))))` |
| `_upgrade_roster_pet_for_event` (L6169) | `var quality_from := _normalize_quality(String(pet.get("quality", "青铜")))` | `var quality_from := _core_composition.quality_policy.normalize_quality(String(pet.get("quality", "青铜")))` |

`_quality_key` → `_core_composition.quality_policy.quality_key`
| `_next_roster_instance_id` (L1018) | `_quality_key(quality),`（`RosterCollectionServiceScript.next_instance_id(roster, pet_id, _quality_key(quality), preferred)` 内） | `_core_composition.quality_policy.quality_key(quality),` |

`_next_quality` → `_core_composition.quality_policy.next_quality`
| `_add_pet_to_roster` (L1140) | `var next_quality: String = _next_quality(quality_from)` | `var next_quality: String = _core_composition.quality_policy.next_quality(quality_from)` |
| `_upgrade_roster_pet_for_event` (L6170) | `var quality_to := _next_quality(quality_from)` | `var quality_to := _core_composition.quality_policy.next_quality(quality_from)` |

**不改**（调用点指向保留的转发壳，保持 `_apply_quality_progression`/`_quality_data` 原名）：`_clone_units` L586、`_add_pet_to_roster` L1171/1207、`_upgrade_roster_pet_for_event` L6174、`start_battle` L6458、`_spawn_team_from_templates` L6528、`snapshot` L2205/2206。

## 5. 组合根注册（`core/composition/core_composition.gd`，本切片同时做）

在 `_init` **末尾**（`run_history_committer` 的 configure 之后）追加：

```gdscript
const QualityPolicyScript := preload("res://core/battle/quality/quality_policy.gd")
```
（const 放文件顶部其他 const 一起；字段声明区追加）
```gdscript
var quality_policy: RefCounted = null
```
（`_init` 末尾追加）
```gdscript
	quality_policy = _resolve(overrides, &"quality_policy", QualityPolicyScript)
```
（`services()` 字典追加一个条目）
```gdscript
		"quality_policy": quality_policy,
```

QualityPolicy 无依赖，不需要 `configure`。位置不限（`_init` 末尾即可），因它是叶子。

## 6. smoke 门禁同步（`tests/core/smoke_composition_service_ownership.gd`）

`DIRECT_CONSUMERS` 字典追加一条（needle 为 4a 转发壳建立的调用点，子串匹配）：

```gdscript
	"quality_policy": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.quality_policy.apply_quality_progression"},
```

## 7. `_log` 处理

15 个方法全部无 `_log` 调用，本切片无日志收集逻辑。

## 8. 验证（按序全绿才提交）

| 序 | 命令 | 期望 |
|---|---|---|
| V1 | `python3 tools/qa/inventory_core_methods.py --output reports/architecture/METHOD_INVENTORY.md` 后 `--check` | `METHOD_INVENTORY_OK`；facade 计数 482；反向依赖 `0/0`；无重复实现 |
| V2 | `godot --headless --check-only --script core/state/game_state.gd` | exit 0 |
| V3 | `godot --headless --script tests/core/dump_puzzle_refactor_baseline.gd` | `assertions: pass`；三哈希与 §1 逐项一致 |
| V4 | `git diff --check` | 无输出 |
| V5 | 日志顺序快照 | 无 `_log` 变更，跳过 |
| V6 | `godot --headless --script tests/core/smoke_composition_service_ownership.gd` | `SMOKE_COMPOSITION_SERVICE_OWNERSHIP_OK services=46` |

## 9. 提交边界

单提交，精确暂存：`core/battle/quality/quality_policy.gd`（新）、`core/state/game_state.gd`、`core/composition/core_composition.gd`、`tests/core/smoke_composition_service_ownership.gd`、`reports/architecture/METHOD_INVENTORY.md`（重生成）。禁止 `git add .`，不推送。提交信息建议：`refactor(core): extract quality progression into pure QualityPolicy (C1)`。

## 10. 完成态

facade 删除 12 个方法体、3 个改转发壳（净 -12 方法、约 -350 行）；`quality_policy.gd` 约 185 行纯函数。品质逻辑集中在叶子 Policy，`RosterService`(C3)/`RunFlowService`(C5)/`BattleService`(C7) 后续切片直接注入使用。
