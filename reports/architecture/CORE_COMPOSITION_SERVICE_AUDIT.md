# CoreComposition service ownership audit

本报告完成拼图化路线图 §8.4 的做减法审计。结论来自当前 live source，不以 service 数量、文件行数或未来可能复用作为保留理由。

## 判定规则

- `direct`：组合实例被权威状态兼容链、窄 Port 或持久化边界直接调用。
- `injected-only`：外部不直接取该实例，但组合根把它注入另一个 service，且下游当前确实调用它；这不是死层。
- `remove-entry`：组合根只创建并导出实例，没有直接调用方、没有注入消费者，也不参与 override；删除装配入口。
- 本审计只删除无效装配。服务实现若仍被领域对象内部拥有和调用，必须保留。

机器门禁 `tests/core/smoke_composition_service_ownership.gd` 独立提取组合根的 `var <service>: RefCounted`、`_resolve` 左值与 override key，再与 `services()` key、下表 33 项做四方精确比对，并逐项检查代表性 live consumer。即使新增 service 忘记导出到 `services()`，也会失败。injected-only 项还必须同时存在 root configure 接线、下游 configure assignment 和实际调用。

## 直接消费者（28）

| service | 当前代表性消费者 | 决定 |
|---|---|---|
| `round_lifecycle_service` | `core/party/catalog_roster_core.gd` 的 round start/end | 保留窄生命周期 Port |
| `battle_session` | `core/run/run_flow_core.gd` 的 combat round/auto | 保留应用编排边界 |
| `snapshot_projector` | `core/commands/command_projection_core.gd` 的 ViewModel 投影 | 保留读模型边界 |
| `command_response_builder` | `core/commands/command_projection_core.gd` 的 Command Result | 保留响应契约边界 |
| `save_repository` | `persistence/compatibility/persistence_core.gd` 的 slot read/write | 保留文件 Port |
| `replay_repository` | `persistence/compatibility/persistence_core.gd` 的 replay/trace write | 保留文件 Port |
| `run_history_repository` | `persistence/compatibility/persistence_core.gd` 的历史、checkpoint 与 revision | 保留文件 Port |
| `game_data_repository` | `core/party/catalog_roster_core.gd` 的 content pack read | 保留内容包边界 |
| `operation_log_repository` | `core/commands/command_projection_core.gd` 的 operation append | 保留文件 Port |
| `player_turn_service` | `core/run/run_flow_core.gd` 的 all-out turn | 保留玩家回合职责 |
| `enemy_turn_service` | `core/run/run_flow_core.gd` 的 enemy turn | 保留敌方回合职责 |
| `pet_reset_policy` | `core/run/run_flow_core.gd` 的 reset placement/charges | 保留确定性策略 |
| `battle_outcome_policy` | `core/run/run_flow_core.gd` 的 terminal/result assembly | 保留结算规则职责 |
| `battle_startup_service` | `core/run/run_flow_core.gd` 的 deployment/enemy templates | 保留开战职责 |
| `run_automation_service` | `core/run/run_flow_core.gd` 的 full day/run | 保留应用自动化职责 |
| `skill_queue_service` | battle/command 层的 queue catalog/reorder/projection | 保留技能队列职责 |
| `action_slot_service` | battle/command 层的 direction/AP/used slot | 保留动作槽职责 |
| `skill_execution_service` | player/enemy turn Port 的 skill execute | 保留窄执行 Port |
| `skill_combo_service` | player/enemy turn Port 与 command projection 的 combo match | 保留组合规则职责 |
| `quality_effect_registry` | `core/battle/battle_rules_core.gd` 的 quality strategy lookup | 保留策略 Registry |
| `quality_runtime_service` | `core/battle/battle_rules_core.gd` 的 mode/mark runtime | 保留品质运行职责 |
| `trait_service` | command projection 的 trait entries，并供 modifier collector 使用 | 保留特性职责 |
| `status_service` | command projection/skill/round Port，并供 modifier collector 使用 | 保留状态职责 |
| `battle_hook_pipeline` | `core/ports/round_lifecycle_port.gd` 和 skill execution | 保留 Hook 顺序边界 |
| `effect_target_resolver` | `core/ports/skill_effect_port.gd` 的 target resolution | 保留目标规则职责 |
| `stat_query_service` | state/battle/command/skill Port 的统一 stat query | 保留统一查询入口 |
| `stat_semantic_pipeline` | `core/battle/battle_rules_core.gd` 的 semantic event apply | 保留属性语义顺序 |
| `relic_combat_service` | `core/battle/battle_rules_core.gd` 的 timeline start/advance/publish | 保留遗物战斗职责 |

## 仅注入但有真实下游（5）

| service | 组合接线 | 下游真实调用 | 决定 |
|---|---|---|---|
| `stat_resolver` | 注入 `stat_query_service` | `StatQueryService` 调用 resolve/resolve_all | 保留 |
| `condition_evaluator` | 注入 interpreter/resolver/status/trait | 各下游调用 `matches` | 保留共享判定语义 |
| `effect_interpreter` | 注入 relic/skill/hook pipeline | 下游调用 effect execute | 保留共享效果语义 |
| `modifier_collector` | 注入 stat query/hook pipeline | 下游调用 collect | 保留统一 modifier 汇集 |
| `relic_catalog_service` | 注入 `relic_combat_service` | 下游调用 inventory/definition 查询 | 保留；无外部直调不等于死层 |

## 已删除的无消费者装配（1）

| composition entry | 删除证据 | 保留内容 |
|---|---|---|
| `stat_catalog_service` | 仓库内除组合根与旧完整性清单外，没有 `_core_composition.stat_catalog_service`、override 或下游注入；组合出的实例从未使用 | 保留 `core/stats/stat_catalog_service.gd`。`StatResolver` 仍直接创建 `_catalog_service`，并调用 `definition` / `base_value`；删除的只是重复 composition entry |

## 结果

- `CoreComposition.services()` 从 34 个有效 key 收敛为 33 个；没有新增 wrapper、Facade 或未来占位接口。
- `smoke_core_composition_complete.gd` 同时补入之前漏盘点的 `stat_semantic_pipeline` 和默认实例断言，完整性清单与 live root 对齐。
- 新门禁检查 28 个 direct、5 个 injected-only、1 个 removed-entry 决定；root 字段、resolve 左值、override key、公开 services 与审计表必须精确一致，任何未审计或漏导出的 service 都不能静默进入组合根。
