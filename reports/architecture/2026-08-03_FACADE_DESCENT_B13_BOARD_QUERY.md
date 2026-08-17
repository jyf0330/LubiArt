# 2026-08-03 切片 C2 — 棋盘查询域下沉 `BoardQueryService`

author: Claude（架构师）
status: SPEC_READY
前置: C1 执行完（facade 计数 482）→ 总纲 `2026-08-03_FACADE_DESCENT_MASTER_SPEC.md`
切片: C2 / 提交数: 1

## 0. 本切片目标

把 facade 中**跨域共享的只读棋盘查询辅助**（17 个）逻辑搬到一个无 authority 依赖的服务 `core/battle/board_query_service.gd`。**每个方法 facade 保留 1 行转发壳**（含内部独属、无外部引用的 4 个——刻意决策，见 §2）。`_preview_resolved_damage` **延后不搬**（`DamagePreviewPortScript.new(self)` 端口 self 耦合，见 §2.2）。搬移后冻结哈希逐字节不变。

## 1. 冻结基线

| 项目 | 冻结值 |
|---|---|
| P0 `normalizedSha256` | `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562` |
| P0 save `checksum` | `875e3dbe` |
| P0 replay `checksum` | `c53db478` |
| facade 方法计数 | 482（**不变**：17 个方法体改 1 行转发壳，计数不降） |
| 反向依赖 | `0 methods / 0 calls` |

P0 探针：`tests/core/dump_puzzle_refactor_baseline.gd`。

## 2. 方法处置表（17 搬 + 1 延后）

### 2.1 搬入服务 + facade 转发壳（17 个）

> 转发壳规则：凡被 `_authority.call(...)` 端口转发、tests、或其他生产服务引用的方法，facade 必须保留**同签名** 1 行转发壳（端口 `call` 会被静默破坏）。实测 C2 域 13 个被端口/测试引用 → 必有壳。剩余 4 个内部独属（`selected_unit` `_leader_at` `_normalize_elements` `_selected_action_ap`）**也保留壳**：它们是跨域热路径（被 C6/C7 十余方法调用），删除会引发 ~25 处散乱调用点编辑；保留壳使本切片零调用点变更、零风险，后续 C6/C7 搬移时改调服务即可。这是对"无外部引用则不设壳"规则的**刻意放宽**，记录于此。

| 方法（HEAD 行） | 服务签名（参数化后） | 壳必需原因 |
|---|---|---|
| `unit_at` (312-317) | `unit_at(units: Array, x: int, y: int) -> Dictionary` | **端口转发**（summon/damage/round_lifecycle/skill_effect port）+ 多服务调用 |
| `unit_by_id` (318-323) | `unit_by_id(units: Array, unit_id: String) -> Dictionary` | ~25 测试文件 ~470 处调用 |
| `selected_unit` (331-333) | `selected_unit(units: Array, selected_unit_id: String) -> Dictionary` | 内部热路径（放宽） |
| `_living_unit_count` (324-330) | `living_unit_count(units: Array, side: String) -> int` | **端口转发**（battle_session_port）+ tests |
| `_inside` (334-336) | `inside(board_dimensions: Vector2i, x: int, y: int) -> bool` | **端口转发**（element/summon/damage_mechanic port）+ tests |
| `_cell_key` (275-277) | `cell_key(x: int, y: int) -> String` | 外部引用（manual_flow_diff_projector、pet_reset_policy）+ tests |
| `_leader_at` (673-679) | `leader_at(x: int, y: int, leaders: Dictionary) -> Dictionary` | 内部热路径（放宽） |
| `_resolved_stat_value` (2537-2540) | `resolved_stat_value(unit: Dictionary, game_data: Dictionary, stat_id: String, context: Dictionary = {}) -> int` | **端口转发**（damage_resolution/preview/mechanic port）+ quality_effect_context |
| `_direction_label` (2541-2543) | `direction_label(direction: String) -> String` | tests（smoke_sts2_guided_capability_boundaries:98） |
| `_normalize_direction` (2544-2546) | `normalize_direction(direction: String) -> String` | tests（:99） |
| `_cell_elements_at` (2547-2549) | `cell_elements_at(x: int, y: int, cell_elements: Dictionary) -> Dictionary` | **端口转发**（element_mechanic_port）+ 大量 tests |
| `_attack_option_for_direction` (1414-1419) | `attack_option_for_direction(shape_options: Array, direction: String) -> Dictionary` | **端口转发**（skill_effect_port）+ tests |
| `_enemies_in_attack_option` (1432-1444) | `enemies_in_attack_option(attacker: Dictionary, option: Dictionary, units: Array, opposing_leader: Dictionary, target_side: String) -> Array` | **端口转发**（skill_effect_port）+ tests |
| `_effective_move_range` (3870-3872) | `effective_move_range(unit: Dictionary, game_data: Dictionary) -> int` | **端口转发**（auto_position_read_port）+ tests |
| `_enemy_attack_count` (3873-3875) | `enemy_attack_count(unit: Dictionary, game_data: Dictionary) -> int` | **端口转发**（enemy_turn_port）+ tests |
| `_normalize_elements` (2697-2699) | `normalize_elements(raw: Dictionary) -> Dictionary` | 内部热路径（放宽） |
| `_selected_action_ap` (2739-2741) | `selected_action_ap(unit: Dictionary, index: int, action_ap_choices: Array, ap: int) -> int` | 内部热路径（放宽） |

实测写字段：17 个**全部 0 顶层 `self.` 写**、0 `_log`。纯只读。

### 2.2 延后不搬（1 个）

| 方法 | 行 | 延后原因 |
|---|---|---|
| `_preview_resolved_damage` | 1302-1326 | 方法体构造 `DamagePreviewPortScript.new(self)` 把 facade 自身作为端口回传（port 会 `_authority.call` 回本对象）；搬到服务后端口回传对象变为服务，端口所需方法名（`_resolved_stat_value` 等带下划线）与服务公开名不匹配会静默破坏。留在 facade。**C7 影响**：`_auto_position_damage_metrics`/`_threat_grid_by_cell`/`_best_enemy_shape_action` 移到 BattleService 时需经 configure 注入 `Callable(facade, "_preview_resolved_damage")`，C7 规格再处理。 |

## 3. 新建服务 `core/battle/board_query_service.gd`（逐字复制）

`extends RefCounted`。configure 注入 5 个无状态服务；`_element_field_service` 自行实例化（与 facade 现模式一致，非 authority）。`game_data`/`units`/`cell_elements`/`action_ap_choices`/`ap`/`leaders`/`board_dimensions`/`shape_options` 一律经参数传入。

```gdscript
extends RefCounted

const ElementRulesScript := preload("res://core/battle/elements/element_rules.gd")
const ShapeGeometryScript := preload("res://core/battle/shape_geometry.gd")
const BattleBoardDimensionsScript := preload("res://core/battle/board_dimensions.gd")
const EffectHookIdsScript := preload("res://core/effects/effect_hook_ids.gd")
const ElementFieldServiceScript := preload("res://core/battle/element_field_service.gd")

var _stat_query_service: RefCounted = null
var _action_slot_service: RefCounted = null
var _targeting_service: RefCounted = null
var _quality_effect_registry: RefCounted = null
var _attack_option_service: RefCounted = null
var _element_field_service := ElementFieldServiceScript.new()


func configure(
	stat_query_service,
	action_slot_service,
	targeting_service,
	quality_effect_registry,
	attack_option_service
) -> void:
	_stat_query_service = stat_query_service
	_action_slot_service = action_slot_service
	_targeting_service = targeting_service
	_quality_effect_registry = quality_effect_registry
	_attack_option_service = attack_option_service


func unit_at(units: Array, x: int, y: int) -> Dictionary:
	for unit in units:
		if int(unit["hp"]) > 0 and int(unit["x"]) == x and int(unit["y"]) == y:
			return unit
	return {}


func unit_by_id(units: Array, unit_id: String) -> Dictionary:
	for unit in units:
		if String(unit["id"]) == unit_id:
			return unit
	return {}


func selected_unit(units: Array, selected_unit_id: String) -> Dictionary:
	return unit_by_id(units, selected_unit_id)


func living_unit_count(units: Array, side: String) -> int:
	var count := 0
	for unit in units:
		if String(Dictionary(unit).get("side", "")) == side and int(Dictionary(unit).get("hp", 0)) > 0:
			count += 1
	return count


func inside(board_dimensions: Vector2i, x: int, y: int) -> bool:
	return BattleBoardDimensionsScript.contains(board_dimensions, x, y)


func cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func leader_at(x: int, y: int, leaders: Dictionary) -> Dictionary:
	for leader_value in leaders.values():
		var leader := Dictionary(leader_value)
		if bool(leader.get("alive", false)) and int(leader.get("x", -1)) == x and int(leader.get("y", -1)) == y:
			return leader
	return {}


func resolved_stat_value(unit: Dictionary, game_data: Dictionary, stat_id: String, context: Dictionary = {}) -> int:
	var hook := String(context.get("hook", EffectHookIdsScript.BATTLE))
	return int(_stat_query_service.value(unit, game_data, stat_id, hook, context))


func direction_label(direction: String) -> String:
	return ShapeGeometryScript.direction_label(direction)


func normalize_direction(direction: String) -> String:
	return ShapeGeometryScript.normalize_direction(direction)


func cell_elements_at(x: int, y: int, cell_elements: Dictionary) -> Dictionary:
	return _element_field_service.elements_at(cell_elements, cell_key(x, y), Callable(self, "normalize_elements"))


func attack_option_for_direction(shape_options: Array, direction: String) -> Dictionary:
	return _attack_option_service.option_for_direction(shape_options, direction)


func enemies_in_attack_option(
	attacker: Dictionary,
	option: Dictionary,
	units: Array,
	opposing_leader: Dictionary,
	target_side: String
) -> Array:
	var targets: Array = _targeting_service.targets_in_option(
		attacker,
		option,
		units,
		opposing_leader,
		target_side
	)
	_quality_effect_registry.effect_for_unit(attacker).sort_targets(targets, option)
	return targets


func effective_move_range(unit: Dictionary, game_data: Dictionary) -> int:
	return max(0, resolved_stat_value(unit, game_data, "move_range", {"hook": EffectHookIdsScript.MOVEMENT}))


func enemy_attack_count(unit: Dictionary, game_data: Dictionary) -> int:
	return max(0, resolved_stat_value(unit, game_data, "attack_count", {"hook": EffectHookIdsScript.ACTION_COUNT}))


func normalize_elements(raw: Dictionary) -> Dictionary:
	return ElementRulesScript.normalize_layers(raw)


func selected_action_ap(unit: Dictionary, index: int, action_ap_choices: Array, ap: int) -> int:
	return _action_slot_service.selected_ap(unit, index, action_ap_choices, ap)
```

> 行为差异说明（唯一参数化改动）：`_enemies_in_attack_option` 原方法体内 `_opponent_side`/`_leader_unit` 两行计算移到 facade 转发壳（见 §4），服务方法接收已算好的 `target_side`/`opposing_leader`。其余方法体与 facade 逐字一致，`_x` → `x`、`_resolved_stat_value` → `resolved_stat_value`（in-service）。

## 4. facade 编辑（17 处方法体原地替换为 1 行转发壳，**零调用点变更**）

每个方法：保留 `func <原签名>:` 行，方法体替换为下面对应的一行。锚点 = 唯一 `func <name>(` 签名。

```gdscript
func unit_at(x: int, y: int) -> Dictionary:
	return _core_composition.board_query_service.unit_at(units, x, y)

func unit_by_id(unit_id: String) -> Dictionary:
	return _core_composition.board_query_service.unit_by_id(units, unit_id)

func selected_unit() -> Dictionary:
	return _core_composition.board_query_service.selected_unit(units, selected_unit_id)

func _living_unit_count(side: String) -> int:
	return _core_composition.board_query_service.living_unit_count(units, side)

func _inside(x: int, y: int) -> bool:
	return _core_composition.board_query_service.inside(board_dimensions(), x, y)

func _cell_key(x: int, y: int) -> String:
	return _core_composition.board_query_service.cell_key(x, y)

func _leader_at(x: int, y: int) -> Dictionary:
	return _core_composition.board_query_service.leader_at(x, y, _leaders())

func _resolved_stat_value(unit: Dictionary, stat_id: String, context: Dictionary = {}) -> int:
	return _core_composition.board_query_service.resolved_stat_value(unit, game_data, stat_id, context)

func _direction_label(direction: String) -> String:
	return _core_composition.board_query_service.direction_label(direction)

func _normalize_direction(direction: String) -> String:
	return _core_composition.board_query_service.normalize_direction(direction)

func _cell_elements_at(x: int, y: int) -> Dictionary:
	return _core_composition.board_query_service.cell_elements_at(x, y, cell_elements)

func _attack_option_for_direction(attacker: Dictionary, direction: String) -> Dictionary:
	return _core_composition.board_query_service.attack_option_for_direction(_shape_attack_options(attacker), direction)

func _enemies_in_attack_option(attacker: Dictionary, option: Dictionary) -> Array:
	var target_side := _opponent_side(String(attacker.get("side", PLAYER)))
	return _core_composition.board_query_service.enemies_in_attack_option(
		attacker, option, units, _leader_unit(target_side == PLAYER), target_side)

func _effective_move_range(unit: Dictionary) -> int:
	return _core_composition.board_query_service.effective_move_range(unit, game_data)

func _enemy_attack_count(unit: Dictionary) -> int:
	return _core_composition.board_query_service.enemy_attack_count(unit, game_data)

func _normalize_elements(raw: Dictionary) -> Dictionary:
	return _core_composition.board_query_service.normalize_elements(raw)

func _selected_action_ap(unit: Dictionary, index: int) -> int:
	return _core_composition.board_query_service.selected_action_ap(unit, index, action_ap_choices, ap)
```

> `_leaders()`/`_opponent_side`/`_shape_attack_options`/`board_dimensions()` 均为 facade 既有辅助，留在 facade。`_leader_unit`（C12 将下沉）保持 facade 壳（被 auto_position_read_port 引用），故 C2 壳内 `_leader_unit(...)` 调用在 C12 后依然有效。

## 5. 组合根注册（`core/composition/core_composition.gd`）

`_init` 末尾（`run_history_committer` configure 之后）追加 `_resolve` + `configure`；const/字段/`services()` 各加一项：

```gdscript
const BoardQueryServiceScript := preload("res://core/battle/board_query_service.gd")
var board_query_service: RefCounted = null
# _init 末尾：
	board_query_service = _resolve(overrides, &"board_query_service", BoardQueryServiceScript)
	board_query_service.call(&"configure", stat_query_service, action_slot_service, targeting_service, quality_effect_registry, attack_option_service)
# services() 追加：
		"board_query_service": board_query_service,
```

> 5 个依赖全部在 `_init` 前段 resolve（quality_effect_registry L122、action_slot_service L121、attack_option_service L156、targeting_service L157、stat_query_service L145），末尾 configure 安全。

## 6. smoke 门禁同步

`DIRECT_CONSUMERS` 追加：

```gdscript
	"board_query_service": {"path": "res://core/state/game_state.gd", "needle": "_core_composition.board_query_service.unit_at"},
```

## 7. `_log` 处理

17 个方法全部无 `_log`，本切片无日志收集。

## 8. 验证

| 序 | 命令 | 期望 |
|---|---|---|
| V1 | `inventory_core_methods.py --output` 后 `--check` | `METHOD_INVENTORY_OK`；计数 482（不变）；反向依赖 `0/0`；无重复实现 |
| V2 | `godot --headless --check-only --script core/state/game_state.gd` | exit 0 |
| V3 | P0 探针 | 三哈希与 §1 一致 |
| V4 | `git diff --check` | 无输出 |
| V5 | 日志快照 | 无 `_log` 变更，跳过 |
| V6 | smoke_composition_service_ownership | `SMOKE_COMPOSITION_SERVICE_OWNERSHIP_OK services=47` |

## 9. 提交边界

单提交，精确暂存：`core/battle/board_query_service.gd`（新）、`core/state/game_state.gd`、`core/composition/core_composition.gd`、`tests/core/smoke_composition_service_ownership.gd`、`reports/architecture/METHOD_INVENTORY.md`。禁止 `git add .`，不推送。建议提交信息：`refactor(core): extract shared board queries into BoardQueryService (C2)`。

## 10. 后续切片影响（记录，不在本切片处理）

- C5/C6/C7 搬移的编排方法仍调用 facade 壳（`unit_at`/`_resolved_stat_value`/`_cell_elements_at` 等），搬移时改为 `_board_query.<m>(...)`（传对应 state 字段参数）。
- `_preview_resolved_damage` 留在 facade，C7 需为搬入 BattleService 的 `_auto_position_damage_metrics` 等注入 `Callable(facade, "_preview_resolved_damage")`。
- `_leader_at`/`_leaders()` 依赖 `_leader_unit`（C12 下沉到 threat_target_policy）；C7 搬移时经 `_board_query.leader_at(x, y, leaders)` + `leaders` 来源（threat_target_policy）解析。
