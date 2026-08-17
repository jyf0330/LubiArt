# 2026-08-03 Facade 大方法下沉 — 总纲规格（MASTER）

author: Claude（架构师）
status: SPEC_READY
基准: `HEAD`（`d94be93`）+ 死代码清理规格（`2026-08-03_FACADE_DEAD_CODE_CLEANUP_SPEC.md`）执行后
前置: 死代码清理规格必须先于本规格执行（方法计数 518→494 后再开始下沉）

## 0. 本规格地位

本文件是**总纲**，决定迁移形态、层级判定、域划分、服务依赖、辅助方法策略、组合根接线、验证协议与执行顺序。**各域的可执行细节在独立规格文件**（见 §9 清单）。实现方必须先读本总纲，再按执行顺序逐个领取域规格。

## 1. 迁移形态（关键架构决策）

**组合服务无 authority 依赖**（硬约束：`CORE_COMPOSITION_SERVICE_AUDIT.md` + `inventory_core_methods.py` 门禁）。实测现有服务（`pet_reset_policy`/`save_document_builder`/`run_history_committer`）全部是纯计算：接收数据参数、返回结果，不持有也不写 authority。据此，63 个大方法按**写顶层 authority 字段数**分两层三类：

### 层级判定（依据实测副作用序列）

| 层级 | 判定 | 处理 |
|---|---|---|
| **P 层（纯下沉）** | 不写 authority（read，35 个）**或**写 ≤3 字段 | 方法**整体搬到服务**，参数化（所需 state 字段经参数传入；≤3 写字段传可变 Array/Dictionary 引用） |
| **O 层（编排壳）** | 写 ≥4 字段 | 方法体**保留在 facade** 作编排壳（读字段→调服务→写字段），方法内可分离的**纯计算子块提取为服务方法** |

> 实测写字段数：`_add_pet_to_roster`=1 `set_quality_mark`=1 `pick_reward`=1 `_move_roster_index_*`=1 `move_selected`=2 `_execute_selected_action_option`=2 `_record_dispatch_result`=2 `_apply_battle_prep_effects`=2 `_shop_offers_for_pool`=3 `set_action_direction`=3（→ P 层）；`reset_player_pets`=4 `_reset_side_pets`=4 `apply_shop_event`=4 `auto_position_heroes`=4 `_finish_battle_result`=7 `choose_route`=13 `start_battle`=22 `start_next_day`=25 `_restore_runtime_state`=64（→ O 层）。

### 三类处理

- **A 类 · 公共命令（10 个）**：被 `core/ports/*` + `core/commands/handlers/*` 生产引用的方法（`apply_shop_event` `auto_position_heroes` `choose_route` `pick_reward` `replay_document` `reset_player_pets` `set_action_direction` `set_quality_mark` `start_battle` `start_next_day`）。facade **保留 1 行转发壳**，外部调用点零改动。
- **P 类**：方法整体搬到服务，facade 内调用点改为 `_core_composition.<svc>.<method>(...)`。
- **O 类**：facade 保留编排壳（方法行数大幅瘦身），提取纯计算子块到服务。

### 转发壳规则

凡被外部（**生产或 tests**）引用的 facade 方法，搬移后 facade 保留 1 行转发壳，外部调用点零改动。已实测有外部引用的：A 类 10 个 + 私有方法 `_add_pet_to_roster` `_apply_quality_progression` `_deal_damage` `_action_slots_for_unit` `move_selected` `load_document` `verify_replay_document`（tests）+ 公共查询 `unit_at` `_cell_key` `_direction_label` `unit_by_id` `selected_unit`（现有组合服务与 core_ui 生产引用）。

## 2. 域划分 v2（基于真实调用图，已打破所有环）

> 与旧设计（`2026-08-03_FACADE_BIG_METHOD_DESCENT_SPEC.md`）的差异：实测 38 条跨域调用边后，**Preview 与 AutoPos 必须合并**（`_action_slots_for_unit` 与 `_threat_grid_by_cell` 互相被对方域使用，拆开成环），`set_action_direction`/`set_quality_mark` 归 BattleService（避免 Quality→Battle 环），`_apply_quality_progression` 独立为纯 Policy（叶子）。

### 服务依赖图（→ = 依赖方向，组合根注入；全图无环）

```
BoardQueryService   ←── BattleService ←── QualityPolicy(纯函数，无依赖)
   (只读棋盘查询)        BattleService ──→ ActionService
                         ActionService ──→ RunFlowService ──→ RosterService
                         RunFlowService ──→ ShopService        └──→ QualityPolicy
                         Battle/RunFlow/Roster ──→ QualityPolicy
                         RunFlow ──→ Roster
                         PetResetService ──→ BoardQueryService
                         OperationLogService ──→ RuntimeStateCodec
                         PersistenceService ──→（注入 save/replay/history repository）
```

### 破环决策记录（实现方禁止改动）

| 原环 | 破法 |
|---|---|
| Preview ↔ AutoPos（`_action_slots_for_unit` / `_threat_grid_by_cell` 互用） | 合并为 BattleService |
| Quality→Battle（`set_quality_mark` 调 Battle 辅助） | `set_quality_mark` 归 BattleService |
| Roster→Quality→Battle | `_apply_quality_progression` 独立为纯 Policy（只改传入 unit dict，实测 0 顶层字段读写），Roster/RunFlow/Battle 直接注入，无环 |
| Action→RunFlow→Roster→Quality | 单向链，无环（`_finish_battle_result` 归 ActionService，依赖 RunFlowService） |

## 3. 服务划分总表（含 P/O 层级标注）

| # | 服务文件 | 域 | P 层下沉 | O 层提取 | 依赖注入 |
|---|---|---|---|---|---|
| S1 | `core/battle/board_query_service.gd`（新） | 只读棋盘查询 | 17 个共享辅助（见 §4） | — | 无（参数传 units/game_data） |
| S2 | `core/battle/battle_service.gd`（新） | Preview+AutoPos+行动配置 | 16 个（P） | 5 个 O 方法子块 | BoardQuery, Action, QualityPolicy |
| S3 | `core/battle/action_service.gd`（新） | 战斗执行 | 6 个（P） | 2 个 O 方法子块 | BoardQuery, RunFlow, QualityPolicy |
| S4 | `core/run/run_flow_service.gd`（新） | 跑图流程 | 4 个（P） | 6 个 O 方法子块 | Roster, Shop, QualityPolicy, BoardQuery |
| S5 | `core/party/roster_service.gd`（新） | 队伍 | 4 个（P） | — | QualityPolicy, BoardQuery |
| S6 | `core/run/shop_service.gd`（新） | 商店 | 3 个（P） | 1 个 O 方法子块 | BoardQuery, QualityPolicy |
| S7 | `core/battle/pet_reset_service.gd`（新） | 宠物重置 | 1 个（P） | 2 个 O 方法子块 | BoardQuery |
| S8 | `persistence/runtime_state_codec.gd`（新） | 运行时快照 | 0（`_capture`/`_restore` 整表序列化留 facade，仅提取字段清单配置） | — | 无 |
| S9 | `persistence/persistence_service.gd`（新） | 持久化编排 | 2 个（P） | 2 个 O 方法子块 | save/replay/history repo（经现有 Port） |
| S10 | `core/commands/operation_log_service.gd`（新） | 操作日志 | 3 个（P） | 1 个 O 方法子块 | RuntimeStateCodec |
| S11 | `core/battle/quality/quality_policy.gd`（新） | 品质纯函数 | 1 个（P） | — | 无 |
| S12 | `core/battle/threat_target_policy.gd`（并入现有） | 领袖目标 | 1 个（P） | — | BoardQuery |
| S13 | `core/state/stat_query_service.gd`（并入现有） | 共享只读统计 | 0（`_resolved_stat_value` 并入） | — | — |

> 最终组合服务新增 11 个文件（S1-S11）、并入 2 个。每个服务的方法级 P/O 清单见对应域规格。
> 实测组合根当前 45 项（`smoke_composition_service_ownership.gd` 对账 40 DIRECT + 5 INJECTED_ONLY）；收口后 56 项（+11，见 §5）。

## 4. 辅助方法策略（决定每个服务的文件内容）

每个 MOVE 方法有 1–16 个辅助闭包（实测）。处理规则：

1. **跨域共享 ≥3 个 MOVE 方法的辅助 → 下沉 S1 `BoardQueryService`**（无状态只读，方法参数传 `units`/`game_data`/坐标）。清单：`_inside` `unit_at` `_cell_key` `_resolved_stat_value` `_cell_elements_at` `_attack_option_for_direction` `_direction_label` `_leader_at` `_living_unit_count` `_enemies_in_attack_option` `_effective_move_range` `_enemy_attack_count` `_normalize_elements` `_normalize_direction` `unit_by_id` `selected_unit` `_preview_resolved_damage` `_selected_action_ap`。其中公共查询 `unit_at` `_cell_key` `_direction_label` `unit_by_id` `selected_unit`（有外部生产引用）→ facade 保留转发壳。
2. **域内独属辅助（只被该域 MOVE 方法调）→ 随 MOVE 方法进对应服务**。各域清单见域规格。
3. **`_log`（被 24 个方法用）**：O 层方法留在 facade，`_log` 直接可用；P 层方法体内不直接 `_log`，改为向返回值追加结构化日志项 `{"kind":"log","text":"<原文案>"}`（key `_logs`），facade 转发壳收集后 `_log` 写 `log_lines`。日志项顺序必须与原方法体 `_log` 调用顺序一致。**这是唯一允许的"行为外"变更。**
4. **`_state_hash` → 留在 facade**；PersistenceService 需要时经构造参数传 `Callable(self, "_state_hash")`。
5. 每个辅助方法**只能在一个服务定义一次**（`inventory_core_methods.py` 无重复实现断言 fail-closed）。

## 5. 组合根接线（`core/composition/core_composition.gd`）

> **接线策略：逐切片注册，不集中在 C13。** 每个切片创建新服务后，facade 转发壳/调用点立即引用 `_core_composition.<svc>`，因此该切片**必须同时**：(a) 在组合根加 preload const + 字段 + `_init` 末尾 `_resolve`（+ `configure` 若依赖其他服务）+ `services()` 条目；(b) 在 `smoke_composition_service_ownership.gd` 加对应 `DIRECT_CONSUMERS`/`INJECTED_ONLY_CONSUMERS` 审计项（needle = 该切片建立的第一个 `_core_composition.<svc>.<method>` 调用点，字符串子串匹配，不依赖行号）。追加位置恒为 `_init` 末尾（现有服务已在前面 resolve，新服务依赖的前置服务必已就绪；切片顺序 = 注入顺序）。

新增 11 项（S1-S11），模式照抄现有 45 项：

```gdscript
const BoardQueryServiceScript := preload("res://core/battle/board_query_service.gd")
const BattleServiceScript := preload("res://core/battle/battle_service.gd")
const ActionServiceScript := preload("res://core/battle/action_service.gd")
const RunFlowServiceScript := preload("res://core/run/run_flow_service.gd")
const RosterServiceScript := preload("res://core/party/roster_service.gd")
const ShopServiceScript := preload("res://core/run/shop_service.gd")
const PetResetServiceScript := preload("res://core/battle/pet_reset_service.gd")
const RuntimeStateCodecScript := preload("res://persistence/runtime_state_codec.gd")
const PersistenceServiceScript := preload("res://persistence/persistence_service.gd")
const OperationLogServiceScript := preload("res://core/commands/operation_log_service.gd")
const QualityPolicyScript := preload("res://core/battle/quality/quality_policy.gd")
```

**configure 注入顺序（破环后必须按此）**：
1. `BoardQueryService`（无依赖）
2. `QualityPolicy`（无依赖）
3. `RosterService.configure(board_query, quality_policy)`
4. `ShopService.configure(board_query, quality_policy)`
5. `RunFlowService.configure(roster_service, shop_service, quality_policy, board_query)`
6. `ActionService.configure(board_query, run_flow_service, quality_policy)`
7. `BattleService.configure(board_query, action_service, quality_policy)`
8. `PetResetService.configure(board_query)`
9. `RuntimeStateCodec`（无依赖）
10. `OperationLogService.configure(runtime_state_codec)`
11. `PersistenceService.configure(save_repository, replay_repository, run_history_repository)`

`services()` 从 33 项 → 44 项。门禁 `tests/core/smoke_composition_service_ownership.gd` 需同步新增 11 项审计（与 S1-S11 精确对应）。

## 6. `_log` 副作用变更（仅 P 层方法，唯一允许的行为外改动）

见 §4 规则 3。O 层方法保留在 facade，不受影响。

## 7. 验证协议（每个切片必须全绿）

| 序号 | 命令 | 期望 |
|---|---|---|
| V1 | `python3 tools/qa/inventory_core_methods.py --check reports/architecture/METHOD_INVENTORY.md`（搬移后先 `--output` 重生成） | `METHOD_INVENTORY_OK`；方法计数按切片递减；反向依赖 `0/0`；无重复实现 |
| V2 | `godot --headless --check-only --script core/state/game_state.gd` | exit 0 |
| V3 | `godot --headless --script tests/core/dump_puzzle_refactor_baseline.gd` | `assertions: pass`；`normalizedSha256=c1bd5ff8…`、save `875e3dbe`、replay `c53db478` 逐项一致 |
| V4 | `git diff --check` | 无输出 |
| V5 | 日志顺序快照测试（新增 focused test，断言 log_lines 序列搬移前后一致） | pass |
| V6 | 该域对应 focused 架构 smoke | pass |

## 8. 执行顺序（切片流水线，每切片一个提交）

> 原则：先纯函数/只读（零 authority 写，哈希不变最可验），后编排。**每个切片同时注册该切片新服务到组合根与 smoke 门禁（§5）**；每切片独立验证 V1-V6 后提交，精确暂存，不推送。

| 序 | 切片 | 域规格 | 内容 | 提交 |
|---|---|---|---|---|
| 1 | C1 | B12 | `QualityPolicy`（`_apply_quality_progression` + 独属辅助） | 1 |
| 2 | C2 | B13 | `BoardQueryService`（17 共享辅助下沉，facade 调用点改组合 + 5 公共查询转发壳） | 1 |
| 3 | C3 | B4 | `RosterService`（4 方法，P 层） | 1 |
| 4 | C4 | B7 | `ShopService`（4 方法） | 1 |
| 5 | C5 | B6 | `RunFlowService`（4 P + 6 O 子块） | 2 |
| 6 | C6 | B5 | `ActionService`（6 P + 2 O 子块） | 1 |
| 7 | C7 | B1 | `BattleService`（16 P + 5 O 子块，最大） | 2-3 |
| 8 | C8 | B8 | `PetResetService`（1 P + 2 O 子块） | 1 |
| 9 | C9 | B9 | `RuntimeStateCodec`（字段清单提取；`_capture`/`_restore` 留 facade） | 1 |
| 10 | C10 | B10 | `PersistenceService`（2 P + 2 O 子块） | 1 |
| 11 | C11 | B11 | `OperationLogService`（3 P + 1 O 子块） | 1 |
| 12 | C12 | B2/B3 | `_leader_unit` → threat_target_policy；`_resolved_stat_value` 若已在 S1 则跳过 | 1 |
| 13 | — | — | 组合根接线收口 + `smoke_composition_service_ownership.gd` 同步 + 全量验证 | 1 |

## 9. 域规格文件清单（实现方逐切片领取）

| 切片 | 文件 |
|---|---|
| C1 | `2026-08-03_FACADE_DESCENT_B12_QUALITY_POLICY.md` |
| C2 | `2026-08-03_FACADE_DESCENT_B13_BOARD_QUERY.md` |
| C3 | `2026-08-03_FACADE_DESCENT_B4_ROSTER.md` |
| C4 | `2026-08-03_FACADE_DESCENT_B7_SHOP.md` |
| C5 | `2026-08-03_FACADE_DESCENT_B6_RUNFLOW.md` |
| C6 | `2026-08-03_FACADE_DESCENT_B5_ACTION.md` |
| C7 | `2026-08-03_FACADE_DESCENT_B1_BATTLE.md` |
| C8 | `2026-08-03_FACADE_DESCENT_B8_PETRESET.md` |
| C9 | `2026-08-03_FACADE_DESCENT_B9_RUNTIME_CODEC.md` |
| C10 | `2026-08-03_FACADE_DESCENT_B10_PERSISTENCE.md` |
| C11 | `2026-08-03_FACADE_DESCENT_B11_OPERATIONLOG.md` |
| C12 | `2026-08-03_FACADE_DESCENT_B2_B3_LEADER_AND_STAT.md` |
| — | 组合根 + 门禁 | `2026-08-03_FACADE_DESCENT_COMPOSITION_GATE.md`（C13 收口：逐切片注册全量对账 + 最终自查，非首个注册点） |

## 10. 冲突审计

- `2026-07-15_mouse-playtest-day1-day2` 声明 `_cell_detail_unit()` 写范围（C7 BattleService 目标）→ C7 切片提交前与其 owner 协商。
- 其余 `tasks/doing/*` 均未声明本规格涉及文件的写范围。
- 本迁移触碰 `core/composition/core_composition.gd` 与 `core/state/game_state.gd`。`tests/core/smoke_composition_service_ownership.gd` 随**每个切片**新增对应审计项（保持 fail-closed 校验，绝不留不一致中间态）；`METHOD_INVENTORY.md` 每个切片后由 `inventory_core_methods.py --output` 重生成再 `--check`。`tools/qa/inventory_core_methods.py` 自身断言不改。

## 11. 完成态

- facade 行数 8049 → 约 5000（P 层方法体搬出；O 层编排壳瘦身；转发壳/权威字段/底层小查询保留）。
- 组合服务目录 33 → 44 项；新增 11 文件、并入 2 文件。
- 领域纯算法集中在无 authority 依赖的服务，可独立测试；`log_lines` 由 facade 统一编排。
- 第二梯队（85 个 15-29 行方法）不在本规格范围。
