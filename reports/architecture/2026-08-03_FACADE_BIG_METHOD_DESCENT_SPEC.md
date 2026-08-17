# 2026-08-03 Facade 大方法下沉 — 可执行设计规格（下一阶段）

author: Claude（架构师）
status: SPEC_READY
基准: `HEAD`（`d94be93` 切链后）+ 死代码清理规格执行后

## 0. 现状核实与口径修正

对 `core/state/game_state.gd`（HEAD，8049 行 / 518 方法）实测：

- **跨度 ≥30 行的大方法：67 个，合计 3841 行**（逻辑行 3704）。此前"47 个 / ~2626 行"为旧口径，实测修正为 **67 个**。
- 第二梯队（跨度 15–29 行）：85 个，约 1700 行（本规格不覆盖，作为后续）。
- 每个大方法已实测：函数跨度、逻辑行、私有依赖闭包大小、直接读写顶层字段数、已用组合服务数。

### 不可下沉（契约/入口，留在 facade，仅内部瘦身）

| 方法 | 跨度 | 理由 |
|---|---:|---|
| `run_command` | 60 | 命令入口，facade 稳定契约 |
| `snapshot` | 228 | 投影入口，**已大量走组合服务**（skill_queue/trait/status/stat_query）；内部剩余私有查询可下沉，壳保留 |
| `reset` | 74 | 权威状态复位，属 state 自身生命周期 |
| `_record_damage_trace` | 41 | `damage_resolution_port.gd:67` REQUIRED_PORT_METHODS 契约方法 |
| `dispatch` | 20 | 命令分发入口（第二梯队但同性质） |

## 1. 下沉判定原则

组合服务不得缓存可写 authority 状态（`CORE_COMPOSITION_SERVICE_AUDIT.md` 硬约束），据此：

1. **只读投影**（读 state 字段 + 私有查询 → 返回只读 ViewModel，无副作用）→ **Projector**。搬移最安全，零哈希风险。
2. **纯决策/纯算法**（字段面 0，参数即输入）→ **Policy / 无状态 Service**。
3. **编排 + 状态变更**（扣 AP、写 roster/units/battle_trace 等）→ **Service**，通过窄 Port 或显式参数访问 authority。
4. **先并入现有服务**，无归属才建新文件（避免服务膨胀）。

## 2. 域分组与目标映射（67 = 4 留 + 63 下沉）

### P0 — 纯搬移，零逻辑变更，最高 ROI（24 个，约 1587 行）

| 域 | 方法（跨度） | 目标服务 | 风险 |
|---|---|---|---|
| 预览投影 | `_build_preview_grid`(149) `_selected_action_preview_by_cell`(49) `_action_preview_by_unit`(30) `_action_cells_for_unit`(30) `_action_slots_for_unit`(33) `_cell_detail_for_action`(33) `_cell_detail_unit`(49) `_board_cells`(58) `_build_core_summary`(36) `snapshot` 内剩余私有查询 | **`core/battle/preview/battle_preview_projector.gd`**（新，只读） | 极低 |
| 自动站位 | `_auto_position_candidates_for_unit`(174) `_auto_position_damage_metrics`(75) `_auto_position_retaliation_metrics`(74) `auto_position_heroes`(85) `_apply_auto_position_moves_atomically`(52) `_threat_grid_by_cell`(61) `_threat_add_cell`(33) `_apply_enemy_auto_position_plan`(68) `_best_enemy_shape_action`(36) `_execute_enemy_shape_action`(49) | **`core/battle/auto_position/auto_position_service.gd`**（新） | 低 |
| 队伍 | `_add_pet_to_roster`(94) `_clone_units`(39) `_move_roster_index_to_active_slot`(30) `_move_roster_index_to_bag_slot`(30) | **并入现有 `RosterCollectionService` / `RosterSlotRules`** | 低 |

### P1 — 编排服务化，中等风险（29 个，约 1481 行）

| 域 | 方法（跨度） | 目标服务 |
|---|---|---|
| 战斗行动 | `_execute_selected_action_option`(161) `move_selected`(63) `_finish_battle_result`(115) `_apply_action_skill_after_attack`(48) `_deal_damage`(34) `_apply_trap_stack_on_enter`(40) `_settle_threshold_elements`(75) `_sorted_action_units_for_side`(33) | **`core/battle/action/action_execution_service.gd`**（新）+ 现有 `battle_outcome_policy` |
| 品质 | `set_action_direction`(39) `set_quality_mark`(36) `_apply_quality_progression`(70) | **并入现有 `quality_runtime_service`**（已 configure 接线） |
| 跑图流程 | `start_next_day`(40) `choose_route`(47) `_apply_route_event`(31) `_post_battle_events_for_result`(31) `pick_reward`(30) `start_battle`(78) `_stall_for_node`(31) `_apply_battle_prep_effects`(37) `_outer_run_effect_from_event`(35) `_fallback_game_data`(32) | **`core/run/run_flow_service.gd`**（新）+ 现有 `run_automation_service`/`battle_startup_service` |
| 商店 | `_build_shop`(37) `_shop_offers_for_pool`(48) `_resolve_day1_shop_pool`(32) `apply_shop_event`(46) | **`core/run/shop_service.gd`**（新） |
| 宠物重置 | `_reset_side_pets`(33) `reset_player_pets`(34) `_record_pets_reset_trace`(38) | **并入现有 `pet_reset_policy`** |
| 领袖目标 | `_leader_unit`(32) | 并入现有 `threat_target_policy` |

### P2 — 权威生命周期瘦身 + 持久化域（10 个，约 536 行）

| 域 | 方法（跨度） | 目标 |
|---|---|---|
| 运行时快照 | `_capture_runtime_state`(70) `_restore_runtime_state`(68) | **`persistence/runtime_state_codec.gd`**（新，纯字典存取，零副作用；与 `reset` 的复位清单去重） |
| 持久化 | `replay_document`(76) `verify_replay_document`(82) `load_document`(30) `_resume_from_history_checkpoint`(63) | **`persistence/persistence_service.gd`**（新，编排现有 `save_repository`/`replay_repository`/`run_history_committer`） |
| 操作日志 | `_player_operation_state_summary`(34) `_player_operation_event_summaries`(32) `_record_dispatch_result`(35) `_preview_manual_flow`(68) | 并入现有 `operation_log_repository` 编排；`_preview_manual_flow` 为命令内联流程，拆子块 |

## 3. 搬移机制（⚠️ 与死代码清理同一铁律）

- **纯搬移**：把方法体及其私有闭包**原样**搬到目标服务，参数改为显式传 state 相关值（或经窄 Port）。**禁止改写任何计算逻辑、调用顺序、副作用序列**。
- 每搬一个方法：facade 原地替换为对 `_core_composition.<svc>` 的转发（保持同名）。GDScript 无 private 语义，`_x` 在服务内可保持原名或去下划线（由实现方按仓库惯例）。
- 由于搬移不改逻辑，**stateHash / save / replay / contentHash 必须逐字节不变**——这是"搬对了"的判定，不是可选验收。
- 组合服务无状态：**不得把 state 实例存进服务字段**；通过方法参数每调用传入。

## 4. 冻结基线（每步验收必须逐项一致）

| 项目 | 冻结值 |
|---|---|
| P0 `normalizedSha256` | `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562` |
| P0 save `checksum` | `875e3dbe` |
| P0 replay `checksum` | `c53db478` |
| 反向依赖 | `0 methods / 0 calls`（`inventory_core_methods.py --check`） |
| 方法计数 | 死代码清理后 494 → 按每步递减（转移到组合服务） |

P0 探针：`tests/core/dump_puzzle_refactor_baseline.gd`。

## 5. 执行顺序与提交边界

1. **P0（纯搬移）** → 单批可合并为若干小提交（每域一提交）。最低风险，先做以验证搬移姿势与冻结校验管道。
2. **P1（编排服务化）** → 每域一提交。方法内状态变更需逐条确认副作用序列不变（`_execute_selected_action_option` 是最重的一个，单独一提交）。
3. **P2（生命周期瘦身 + 持久化）** → 每域一提交。
4. 每提交验证：`--check` inventory → Godot `--check-only` → P0 探针三哈希 → `git diff --check`。精确暂存，禁止 `git add .`，不推送。
5. 冲突审计：`mouse-playtest` 声明 `_cell_detail_unit()` 写范围（P0 预览域目标）→ 该域提交前与其 owner 协商。

## 6. 组合服务新增汇总

| 新服务文件 | 域 | 方法数 | 约行数 |
|---|---|---|---|
| `core/battle/preview/battle_preview_projector.gd` | 预览投影 | 9 + snapshot 子块 | ~660 |
| `core/battle/auto_position/auto_position_service.gd` | 自动站位 | 10 | ~707 |
| `core/battle/action/action_execution_service.gd` | 战斗行动 | 8 | ~569 |
| `core/run/run_flow_service.gd` | 跑图流程 | 10 | ~392 |
| `core/run/shop_service.gd` | 商店 | 4 | ~163 |
| `persistence/runtime_state_codec.gd` | 运行时快照 | 2 | ~138 |
| `persistence/persistence_service.gd` | 持久化编排 | 4 | ~251 |

并入现有（不新增文件）：`RosterCollectionService`、`RosterSlotRules`、`quality_runtime_service`、`pet_reset_policy`、`threat_target_policy`、`battle_outcome_policy`、`run_automation_service`、`battle_startup_service`。

## 7. 完成态（此阶段达成后）

- facade 方法数 494 → 约 430（净转出 63 个大方法 + 其闭包内私有辅助）。
- facade 保留：命令入口、权威状态生命周期、跨域编排薄壳、Port 契约方法。
- 领域算法集中在可独立测试的 Projector/Policy/Service；组合服务目录为唯一注入边界。
- 下一阶段（第三梯队 15–29 行方法）不在本规格范围。
