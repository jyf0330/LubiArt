# 2026-08-03 `game_state.gd` 职责收敛规格（Codex 独立方案）

author: Codex
status: IMPLEMENTED / VERIFIED
baseline: `d94be93b3e6b0f66ca07a2e44f17f22b2ad21904`
implementation_head: `4a93e0e012e2721fd90c312885937751b9ff1a09`
final_audit_commit: `806017dd88ccd0964eef0a55467bcc97cecd9079`
implementation_pack: `reports/architecture/2026-08-03_CODEX_GAME_STATE_IMPLEMENTATION_PACK.md`
scope: 保留原实施裁决并记录已验证结果；不修改 Claude 的任何规格，不把代码行数当成验收目标

## 0. 结论先行

`core/state/game_state.gd` 的问题不是“8049 行必须拆成若干文件”，而是同一个文件里同时存在以下四种不同责任：

1. 必须留在唯一权威上的状态、Command 事务、确定性和稳定协议门面。
2. 可以独立测试、只读且不应写权威状态的 Snapshot / Preview 投影。
3. 已经拥有 Planner / Policy / Repository，却仍通过 facade 反射回调的大块纯算法。
4. 生产 fallback、临时 capture/restore、薄兼容转发和切链残留等可删除堆积。

本方案不做一次性“63 个大方法整体搬家”，而按以下顺序收敛：

1. 先修查询写状态、预览真实落盘、临时快照不完整、生产 fallback 四个边界问题。
2. 再把只读投影与纯算法迁到已有领域 owner，消除反射式回调。
3. 保留 `dispatch`、`run_command`、`reset`、`snapshot`、存档/回放公开入口，以及严格顺序的战斗/结算协调器。
4. 每次只迁一个可独立验证的纵向切片；没有新 owner、契约和 focused test，就不因方法长而拆。

完成标准是职责与写路径可证明，而不是把 facade 压到某个行数或方法数。

## 1. Live baseline 与证据口径

### 1.1 当前规模只描述现状

对 baseline 的 live source 实测：

- `core/state/game_state.gd`：8049 行、518 个 `func`。
- 95 个权威/运行字段、134 个常量、71 个 preload。
- 跨旧六层反向依赖 `0 methods / 0 calls`，旧继承链已经删除。
- 跨度至少 30 行的方法为 67 个，合计约 3840 行；这个数字只用于导航，不是拆分门禁。
- `CoreComposition` 当前有 45 个实例字段；新增服务必须证明真实消费者、替换价值和测试边界。

`reports/architecture/METHOD_INVENTORY.md` 可用于定位直接调用、动态调用和测试调用，但不能单独证明死代码：当前扫描器按行识别调用，可能漏掉多行 `_core.call(...)`、Godot 生命周期和 Port `REQUIRED_METHODS` 契约。

### 1.2 已经完成、不得推倒的基础

- `YsbzsState` 已直接继承 `RefCounted`，旧六层链和空虚拟契约为零。
- 玩家入口已统一为 `GameSession -> Command -> YsbzsState -> Result/Trace/Snapshot`。
- 五个 Command handler 只通过版本化 Command Port 进入权威。
- 伤害、死亡、召唤、元素、回合、技能、品质、遗物、属性已有逐实例 Service / Policy / Port。
- `AuthoritativeStateCodec.FIELD_SPECS` 已是 save、load、history checkpoint、state hash 的唯一字段注册表。
- Save、Replay、Run History、Operation Log 已有分离的 Builder / Repository / Committer。
- 自动站位已经存在 `AutoPositionPlanner + AutoPositionPolicy + AutoPositionTurnOptimizer + AutoPositionReadPort`，不得再建立功能重叠的总 `AutoPositionService`。

### 1.3 当前必须先处理的正确性风险

#### R1：`snapshot()` 不是只读查询

`snapshot()` 第一行调用 `_normalize_roster_slots()`；`RosterCollectionService.normalize_*()` 会逐项回写 `roster`。因此 Snapshot 调用可能改变权威内容，却不经过 Command、版本递增和历史记录。

#### R2：`PREVIEW_MANUAL_FLOW` 在真实 authority 上执行真实 Command

`_preview_manual_flow()` capture 当前状态后调用真实 `dispatch()`，最后再 restore：

- `dispatch()` 会进入 `_record_dispatch_result()`。
- 被接受的变更 Command 会进入 `RunHistoryCommitter.record()`。
- `SessionFactory` 默认启用 run history。
- 内存 restore 无法撤销 Repository 已经 append 的命令或 checkpoint。
- `_manual_flow_preview_resolving` 只抑制部分伤害结构日志，并不暂停历史写入。

因此“最后 stateHash 恢复”不能证明预览无副作用。

#### R3：临时 runtime capture/restore 与 canonical codec 不一致

`_capture_runtime_state()` / `_restore_runtime_state()` 自己维护第二份字段清单：

- capture 包含 `reward_fallback_audit`，restore 没有恢复它。
- `defeated_units` 已进入 `AuthoritativeStateCodec` 且参与 hash，但临时清单没有覆盖。
- history 元数据和外部写入也不在该回滚能力内。

新增第二个 `runtime_state_codec.gd` 会扩大字段漂移面；正确方向是删除临时清单，复用 canonical codec，并在隔离模拟实例上执行。

#### R4：生产内容为空时回退到硬编码玩法数据

`_load_game_data()` 在正式内容包为空时调用 `_fallback_game_data()`，后者硬编码路线、宠物、敌人和商店。这会与 `data/content/**/*.json` 的正式真相源竞争，并把内容错误伪装成可运行状态。

## 2. 不变量与非目标

### 2.1 必须始终成立

1. `YsbzsState` 是唯一可对外观察和提交的玩法权威。
2. 玩家写入只经公开 Command；UI / Node 只消费 Result / Trace / Snapshot。
3. 每个接受的变更 Command 只递增一次 `state_version`、只写一次 command log/history。
4. Query / Preview 不得修改 source authority、不得写 Repository、不得推进 RNG 或历史计数。
5. `AuthoritativeStateCodec.FIELD_SPECS` 是权威字段 capture/restore/hash 的唯一注册处。
6. Service 不缓存第二份 `units`、roster、run、reward、history 或 content 可写状态。
7. Repository 只处理路径、bytes、原子性和外部存取，不执行游戏规则或模拟 Command。
8. 未知 Port 版本或缺少能力必须 fail closed，不允许部分写入。
9. stateHash、save/replay checksum、contentHash、Snapshot schema 和 Trace 顺序只有经显式协议迁移才可改变。

### 2.2 本轮明确不做

- 不恢复六层继承或 `part_01` 式分片。
- 不建立第二个正式 State、全局 Manager、Autoload 规则中心或静态 Hook 总线。
- 不把所有大方法都变成逐行 facade 转发。
- 不建立覆盖 Save/Replay/History Repository 的总 `PersistenceService`。
- 不建立第二套 runtime state field registry。
- 不因 500～700 行就继续机械拆一个高内聚纯 Projector/Policy；是否拆分仍看变化原因和依赖。
- 不在规格阶段修改任何运行代码。

## 3. STS2 对照裁决

| 热点 | STS2 live 证据 | 当前对应 | 裁决 | 代价与重开条件 |
|---|---|---|---|---|
| 唯一战斗权威 | `Core/Combat/CombatState.cs` 持有 creature、round、side 等可写状态，常用集合由状态派生 | `YsbzsState` + `AuthoritativeStateCodec` | **已采用 / 保留** | 不按字段拆多个 Store；只有旧写入口完全封闭且 save/replay 等价时才讨论字段 owner 迁移 |
| 玩家 Action 边界 | `Core/GameActions/GameAction.cs` 包装玩家动作生命周期，不等于全部内部规则 | Command handler + versioned Command Port | **已采用 / 保留** | handler 继续只解析输入；不得把完整 authority 交给 handler |
| 高内聚有序机制协调 | `CreatureCmd.cs` 的 Damage 与 `Hook.cs` 都保留较大的顺序协调单元 | `_execute_selected_action_option`、`_finish_battle_result`、Damage/Hook services | **保留协调器，迁移纯子计算** | 文件长度不是拆分理由；只有协调器出现第二个独立事务或无法独立验证时重开整体迁移 |
| 外部存储隔离 | `Core/Saves/ISaveStore.cs` 只抽象文件能力 | Save/Replay/History Repository | **已采用 / 保留** | Repository 不接管 preview、规则、checksum 或 schema |
| 伤害结果与安全点 | `CreatureCmd.Damage` 返回 rich result，并在批量 packet 后处理死亡 | DamageResolver、DamageResult、DamageDeathService | **已采用** | Action coordinator 继续复用它，不创建第二条预估/执行伤害公式 |
| 静态 Hook / 全局 Manager 形态 | `Hook.cs` 和 `CombatManager.Instance` | 当前逐实例 pipeline + Port | **拒绝实现形态** | 只迁移明确顺序与显式 state 输入，不引入全局规则中心 |
| 测试/调试隔离状态 | `CombatState` 构造允许显式 `IRunState`，测试场景可用 `NullRunState` | 当前 preview 在真 state 上 capture/restore | **迁移不变量** | 使用无 I/O 的短命模拟实例；它不是第二正式权威，不可注册到 Session 或持久化 |

## 4. 目标职责图

```text
GameSession
  │ public Command
  ▼
YsbzsState                                      唯一正式 authority
  ├─ authoritative fields + reset/load apply
  ├─ dispatch/run_command transaction boundary
  ├─ stable snapshot/save/replay/history facade
  └─ ordered mutation coordinators
       │
       ▼
CoreComposition                                 每个 State 一份
  ├─ Application Service + versioned mutating Port
  ├─ pure Policy / Projector                    只收不可变值/Context
  ├─ Simulation service                         只操作短命、无 I/O fork
  └─ Repository / Builder / Codec               外部存取与协议分责
```

Command 事务与查询投影必须分开：

```text
Mutation Command
  validate version/phase
  -> one handler + one domain port
  -> ordered mutation
  -> Result/Trace
  -> version/hash/command log/history exactly once

Query / Preview
  capture immutable context
  -> pure projector
  or -> no-I/O simulation fork
  -> response only
  -> source version/hash/history/files unchanged
```

## 5. 必须保留在 facade 的组成

| 责任 | 代表方法 | 决定 | 原因 |
|---|---|---|---|
| 权威字段和生命周期 | `_init`、`reset`、`configure_core_services` | **保留** | State 自己拥有初始化、复位和逐实例组合根 |
| Command 事务 | `dispatch`、`run_command`、`_record_dispatch_result`、`_record_rejected_dispatch` | **保留并收紧** | 统一版本、hash、Trace、Replay、History 的 exactly-once 边界 |
| 确定性身份 | `_state_hash*`、`_content_hash*`、`_determinism_context` | **保留薄壳** | 调用 canonical codec/contract，外部协议需要稳定入口 |
| Snapshot 稳定入口 | `snapshot` | **保留、修成只读** | Snapshot schema 是一个协议变化原因；内部派生投影可以迁移 |
| Save/Replay/History 稳定入口 | `save_document`、`load_document`、`replay_document`、`verify_replay_document`、slot/history 公共 API | **保留薄壳** | GameSession 和测试调用稳定，内部 builder/verifier/repository 可替换 |
| 严格战斗行动顺序 | `_execute_selected_action_option` | **保留协调器** | AP、element、damage packet、death safe point、quality、skill、mechanic、log、battle end 有顺序不变量 |
| 严格战斗终局顺序 | `_finish_battle_result` | **保留协调器** | mechanics、金币、run effect、奖励池、relic、phase、日志需要单一顺序 owner |
| 战斗开场与回合提交 | `start_battle`、`_start_next_battle_round`、`end_player_turn` | **保留协调器，继续复用现有服务** | 它们是 Command application boundary，不是纯算法 |
| 原子站位应用 | `auto_position_heroes`、`_apply_auto_position_moves_atomically` | **保留** | Planner 只产计划；身份、唯一落点、AP/方向与 Trace 必须由权威原子提交 |
| Port 必需能力 | `_record_damage_trace` 等 `REQUIRED_METHODS` | **保留或显式迁移契约** | 零文本引用不等于无运行调用 |

以上方法可以因内部委托而变短，但不得以“必须把大方法移出 facade”为目标。

## 6. 应迁移、删除或拒绝的组成

### 6.1 查询投影：迁移到一个明确的 battle query owner

目标文件：`core/commands/battle_query_projector.gd`。
它只处理“同一 authority 时刻的战斗查询投影”，不执行 Command、不写 state、不写 Repository。

迁移候选：

- action slots/cells：`_action_slots_for_unit`、`_action_cells_for_unit`、`_action_preview_by_unit`、`_action_block_ranges_by_unit`。
- selected preview：`_selected_action_preview_by_cell`、`_preview_rows_by_cell`、`_active_preview_row`、`_board_preview_payload`。
- preview request：`_preview_unit_for_action`、slot/direction/AP helpers、damage/quality/settlement helpers、`_build_preview_grid`。
- threat projection：`_threat_add_cell`、`_project_enemy_next_step`、`_threat_grid_by_cell`。
- board/detail：`_board_cells`、`_board_snapshot`、`_cell_detail_for_action`、`_all_cell_details`、`_unit_diff_rows`、`_cell_detail_unit`。

公开契约：

```text
project_action_grid(context: Dictionary, request: Dictionary) -> Array
project_board(context: Dictionary, action_grid: Array, threats: Dictionary) -> Dictionary
project_cell_detail(context: Dictionary, request: Dictionary) -> Dictionary
project_unit_diff_rows(context: Dictionary) -> Array
```

`context` 最少包含：phase/version、board dimensions、selection/AP、units、cell elements、board traces、action direction/AP choice、content catalogs，以及预先计算的 stat/shape/damage capabilities。它必须是深拷贝或不可变输入，Projector 不得保留引用。

边界：

- `snapshot()` 仍负责最终 schema 组装与兼容 alias。
- 现有 `SnapshotProjector` 继续只做 raw Snapshot -> public ViewModel，不与 battle query projector 合并。
- `_cell_detail_unit` 当前与 `2026-07-15_mouse-playtest-day1-day2` 的写租约有冲突；未来实现必须把它作为独立 atom，等待 owner 释放后再迁。

### 6.2 Manual flow preview：迁移到无 I/O 模拟

新增：

- `session/simulation_authority_factory.gd`
- `core/commands/manual_flow_simulation_service.gd`

建议契约：

```text
SimulationAuthorityFactory.fork(
    authority_script: Script,
    source_state: Dictionary,
    content_pack: Dictionary,
    options: Dictionary
) -> RefCounted

ManualFlowSimulationService.preview(
    source: Object,
    action: Dictionary,
    factory: RefCounted,
    diff_projector: RefCounted
) -> Dictionary
```

fork 必须：

1. 通过内部 constructor option 使用显式 `content_pack`，不得从文件系统重新读内容。
2. 用 `AuthoritativeStateCodec.capture(source, false)` / `restore(fork, payload)` 复制正式字段。
3. 禁用 run history、operation repository、save/replay writes 和任何真实路径能力。
4. 不共享带 cache 的 state-bound service 实例。
5. 只在 service 内可见，用完释放；不得交给 UI、Session 或 Repository。

preview service 在 fork 上执行同一个 `dispatch()` 规则路径，收集 Snapshot/Trace，再由现有 `ManualFlowDiffProjector` 生成差异。source authority 不再 capture/restore，也不再设置 `_manual_flow_preview_resolving`。

原 `_capture_runtime_state()`、`_restore_runtime_state()` 在迁移完成后删除；禁止新增第二个 runtime codec。

### 6.3 自动站位：收紧现有组合，不新建总 Service

新增候选：`core/battle/auto_position/auto_position_evaluator.gd`。
复用：现有 Planner、Policy、TurnOptimizer、Config。

迁移到 evaluator：

- candidate context/cells/damage/approach 计算。
- `_auto_position_candidates_for_unit`。
- projected retaliation、on-death incoming、retaliation metrics。
- 只读 threat/target facts。

直接并入现有 `AutoPositionPolicy`：

- candidate/evaluation/enemy-response 比较。
- choices/signature/conflict/prune 等纯排序规则。

重写 `AutoPositionReadPort`：constructor 接收一次性 immutable `AutoPositionContext` 和 evaluator，不再持有 `_core`，不再 `_core.call()` / `_core.get()`。

建议契约：

```text
AutoPositionEvaluator.candidates_for_unit(context, unit, options) -> Array
AutoPositionEvaluator.retaliation(context, choices) -> Dictionary
AutoPositionPlanner.build_plan(input, read_model) -> Dictionary
```

保留在 authority：

- `_build_auto_position_plan` 薄适配。
- `auto_position_heroes` 的阶段/重用/日志/Result 协调。
- `_apply_auto_position_moves_atomically` 的最终原子写入与身份断言。

敌方 `_best_enemy_shape_action` / `_execute_enemy_shape_action` / `_apply_enemy_auto_position_plan` 属于 Enemy Turn execution，不并入 planner。若以后迁移，只能进入现有 `EnemyTurnService + EnemyTurnPort`，不能进入纯 evaluator。

### 6.4 品质成长：迁移纯 transformation，不吞并 Command

新增：`core/party/quality_progression_policy.gd`。

迁移：quality normalize/key/next、growth/evolution point、upgrade selection、`_apply_quality_progression` 的纯转换逻辑。

建议契约：

```text
progress(unit: Dictionary, context: Dictionary, fill_hp_to_max: bool) -> Dictionary
```

输入 unit 必须复制，返回完整 next unit；Policy 不直接修改 roster/units。`context` 包含 quality table、shape definition、确定性 seed 和 upgrade catalog。

`set_quality_mode`、`set_quality_mark`、roster acquire/upgrade、battle spawn 仍由各自 Command coordinator 应用返回值并写回。`quality_runtime_service` 继续拥有 mode/mark 运行规则，不与 progression 合并。

### 6.5 Roster：复用现有 owner，保留事务协调器

明确不新建总 `RosterService`：

- identity/lookup/normalization 已属于 `RosterCollectionService`。
- slot allocation 已属于 `RosterSlotRules`。
- party/bench count 已属于 `PartyRules` / `InventoryRules`。

处理方式：

- 删除已确认无调用的薄 wrapper。
- 单一内部调用的 wrapper 改为直接调用现有 Rules/Service，前提是不会破坏 Port 契约。
- `_add_pet_to_roster` 保留为 acquire/merge/quality/placement 的权威事务协调器。
- sell/toggle/move-to-slot 保留为 Command 事务；不要把 coins、roster、battle unit 的联合写入塞进纯 collection service。
- roster normalization 只在 reset、load/migration 和 roster mutation 提交点执行；Snapshot 不再调用。

### 6.6 Operation log：Projector 与 Repository 分责

新增：`core/logging/player_operation_projector.gd`。

迁移纯投影：

- `_player_operation_state_summary`
- `_player_operation_event_summaries`
- `_player_operation_result_summary`
- `_player_operation_new_logs`

保留：

- `run_command` 决定何时 capture before/after。
- `OperationLogRepository.append()` 只负责外部写入。
- `_record_dispatch_result` 绝不进入 Repository；它是 Command 事务 owner。
- Manual flow simulation 不进入 Operation Log Repository。

### 6.7 内容 fallback：从生产路径删除

正式 `_load_game_data()` 必须返回结构化 `LoadResult` 或设置明确初始化失败：

```text
{ ok, content_pack, errors, source }
```

当模块化内容为空或校验失败时，Session 创建失败并暴露错误，不生成可玩的硬编码内容。

迁移/删除：

- `_fallback_game_data` 从生产删除。
- `_pet`、`_enemy`、`_build_shop` 若只剩测试使用，移到 `tests/fixtures/`。
- `shop_offers` 的正式默认只能来自 content pack / ShopCatalogService。

重开 fallback 的唯一条件：产品明确批准离线 demo 模式，并通过显式 `mode=demo` 注入 fixture；不能静默触发。

### 6.8 Persistence：复用现有 Builder/Codec/Repository，拒绝总层

保留：

- `AuthoritativeStateCodec` 唯一字段注册表。
- `SaveDocumentBuilder`、`ReplayBuilder`、各 Repository、`RunHistoryCommitter`。
- facade 的 save/load/replay/history 公共方法。

迁移：

- 把 `replay_document()` 内纯文档 assembly 补进现有 `ReplayBuilder`，facade 只提供当前 payload、command stream、determinism 和 meta。
- 新增 `persistence/replay_verifier.gd`，复用 `SimulationAuthorityFactory` 在无 I/O fork 上回放并返回 checkpoints。
- `verify_replay_document()` 保留稳定壳，不再自己创建并操纵完整 replay state。

拒绝：

- `persistence/persistence_service.gd` 总层：它会把 schema、验证、I/O、history 和模拟重新混在一起。
- `persistence/runtime_state_codec.gd`：与 canonical codec 重复。
- 把 `_preview_manual_flow` 放进 `operation_log_repository`：Repository 不是 Command simulator。

## 7. Command 事务收紧规格

`dispatch()` / `run_command()` 的最终顺序固定为：

1. normalize command type。
2. capture `before_version` / `before_hash` / `before_phase` / trace cursor。
3. 校验 base version。
4. 校验 phase。
5. 创建唯一 domain Port，执行唯一 handler。
6. 若为接受的 mutation：
   - 应用完全部权威写入与 Trace。
   - `state_version += 1` 恰好一次。
   - 计算 after hash。
   - append command log / replay timeline / run history 恰好一次。
7. 若为 Query：不得执行第 6 步。
8. Snapshot 只读生成。
9. Response Builder 组装 Result / Trace / Snapshot。
10. Operation Log 在事务外记录人类审计，不参与确定性状态。

新增机器门禁：

- Query/Projector 路径禁止对 source authority 调用 `dispatch`。
- `_record_dispatch_result` 禁止递归调用 Command。
- history append 只能来自一次 transaction finalize。
- Port 可以动态适配 authority，但 Service/Policy/Projector 内不得出现 `_core.call`、`_core.get`、`_core.set`。

## 8. 分阶段实施与提交边界

每个阶段都要创建独立实现任务卡；本规格不授予代码写入租约。普通程序员实施时以 `2026-08-03_CODEX_GAME_STATE_IMPLEMENTATION_PACK.md` 的 source 行、目标签名、schema、caller、测试、提交和回滚定义为准；本节只保留架构摘要。

### C0：审计器增强与死残留清理

范围：

- 扫描器识别多行动态 `call`、Port required methods、Godot lifecycle 和测试动态调用。
- 在增强后的证据上确认并删除 23 个死方法及切链过时注释。
- 不修改任何有调用方方法体。

验收：目标列表精确、P0 hash/save/replay 不变、architecture + fast 通过。

### C1：Snapshot purity

范围：

- 从 `snapshot()` 删除 roster normalization。
- 在 reset、load/migration、add/sell/toggle/drop/move 等 mutation commit 点维护 roster invariant。
- 新增连续两次 Snapshot 的 source payload/version/hash 零变化测试。

验收：Snapshot 内容兼容，source `AuthoritativeStateCodec.capture()` 前后逐值一致。

### C2：构造顺序与生产内容 fail closed

范围：ContentLoadService、constructor options、结构化初始化失败、SessionFactory 失败语义、删除生产 fallback。

验收：

- 正式内容正常启动结果不变。
- 缺包、非法包、空包明确失败，不返回半初始化 Session。
- simulation/test 内容只能显式注入且零 repository read。
- demo fixture 不得从 production 路径静默触发。

### C3：Manual flow 无 I/O 模拟

范围：SimulationIoGuard、SimulationAuthorityFactory、ManualFlowSimulationService、删除临时 capture/restore。

验收：source 全字段、hash、version、command log、history metadata 和文件树前后完全一致；guard 零尝试；fork 与正式规则产生同样预览 Trace/Snapshot；异常/拒绝命令也不泄漏副作用。

### C4：品质成长纯 Policy

范围：QualityProgressionPolicy + 调用方适配。

验收：固定 seed 的 unit before/after golden、roster/battle/shop 路径一致、P0 不变。

### C5：Battle query projector

先迁 action preview，再迁 threat/board/detail；每个子域独立提交。`_cell_detail_unit` 等待冲突 owner 释放。

验收：

- Snapshot schema/aliases 完全相同。
- Preview 与正式 DamageResolver/quality/element 语义一致。
- Projector 输入不被修改。
- 重复 query 不改 source。

### C6：Auto-position evaluator 与 read model

范围：纯 candidate/retaliation 下沉，ReadPort 不再持有 authority，保留原子应用。

验收：现有 search precision、difficulty、order independence、survival、boss、execution parity、candidate purity 全过；同 seed 同计划签名；source 在 plan 阶段零变化。

### C7：Operation log projector

范围：只迁纯 summary/diff；append 与 transaction 时序不变。

验收：相同 Command 的 JSONL 语义字段一致；关闭 operation log 时零文件写入。

### C8：Replay builder/verifier

范围：ReplayBuilder assembly、ReplayVerifier + simulation fork，保留 facade API。

验收：现有 replay checksum/checkpoints/final hash 不变；验证过程不写 history/save/log；错误 replay 结构化失败。

### C9：重新审计剩余协调器

只在 C0～C8 完成后重跑方法依赖/冲突/测试审计。以下方法默认不因长度继续拆：

- `_execute_selected_action_option`
- `_finish_battle_result`
- `start_battle`
- `reset`
- `snapshot` 的最终 schema assembler

重开整体迁移需要同时满足：出现独立变化原因、能定义窄 Port、可以独立测试、不会复制写路径，并有删除旧入口计划。

## 9. 每个迁移 atom 的必填实施表

实现任务不能只写“把方法搬到 Service”。每个 atom 必须填写：

| 字段 | 要求 |
|---|---|
| source | 原文件、方法、当前调用方 |
| owner decision | `迁移 / 已采用 / 保留 / 拒绝` |
| target | 目标文件与公开方法签名 |
| inputs | 每个值/Context/Port 能力及可变性 |
| outputs | Result/Delta/Trace/ViewModel 结构 |
| allowed writes | 允许写的 authority 字段；纯模块必须为“无” |
| ordering | 与 Hook/Trace/death/history 的前后关系 |
| failures | fail-closed 结果及是否允许部分写入 |
| callers | 所有 direct、dynamic、Port、lifecycle、test caller |
| old path removal | 同提交删除的旧实现/转发/反射能力 |
| focused tests | 正常、边界、拒绝、确定性、无副作用案例 |
| frozen contracts | stateHash/save/replay/content/Snapshot/Trace 哪些必须不变 |

缺少任一项，atom 不进入实现。

## 10. 验证矩阵

### 所有提交

1. 修改脚本 `godot --headless --check-only --script <file>`。
2. `inventory_core_methods.py` 重生成并 `--check`。
3. `tests/core/dump_puzzle_refactor_baseline.gd`：规范 SHA、save checksum、replay checksum。
4. `tests/core/smoke_authority_ownership_contracts.gd`。
5. `tests/core/smoke_composition_service_ownership.gd` 与 `smoke_core_composition_complete.gd`。
6. `tests/integration/smoke_architecture_boundaries.gd`。
7. `python3 tools/qa/run_qa.py --suite fast`。
8. `git diff --check`，精确暂存。

### Query / Preview 专项

- `smoke_action_preview_single_source.gd`
- `smoke_placement_damage_preview.gd`
- 新增 `smoke_snapshot_purity.gd`
- 新增 `smoke_manual_flow_simulation_isolation.gd`
- `smoke_command_snapshot_reuse.gd`

### Auto-position 专项

- `smoke_auto_position_candidate_purity.gd`
- `smoke_auto_position_planner_composition.gd`
- `smoke_auto_position_turn_optimizer.gd`
- `smoke_auto_position_search_precision.gd`
- difficulty/order/survival/boss/execution parity 全组

### Persistence 专项

- `smoke_persistence_composition_boundaries.gd`
- `smoke_run_history_committer_contract.gd`
- `smoke_deterministic_run_history.gd`
- `smoke_singleplayer_persistence.gd`

## 11. 组合服务准入门禁

新增 CoreComposition entry 必须同时满足：

1. 有生产 direct consumer 或明确 injected consumer。
2. 有独立变化原因，不与现有 Service/Policy/Builder 重叠。
3. 需要逐 State 配置、替换或隔离测试；纯 static helper 不进入 root。
4. `services()`、override key、ownership audit 和代表性调用方同步更新。
5. 不缓存可写 authority 状态。

按本方案：

- `ContentLoadService`、`SimulationAuthorityFactory`、`ManualFlowSimulationService`、`QualityProgressionPolicy`、`BattleQueryProjector`、`AutoPositionEvaluator`、`PlayerOperationProjector`、`ReplayVerifier` 都有逐 State override、隔离测试或真实 injected consumer，按实施包登记 composition。
- `BattleQueryContext`、`ValueDamagePreviewPort` 等一次性值 helper / Port 不进入 composition。
- 若实施时发现已有等价 owner，复用它并减少 composition entry；禁止为了达到固定数量保留重复服务。

## 12. 风险、回滚和重开条件

| 风险 | 防护 | 回滚边界 |
|---|---|---|
| Query 迁移后 Snapshot schema 漂移 | golden Snapshot + alias 契约 + repeated query purity | 只回滚当前 projector atom |
| 模拟 fork 与正式内容/服务不一致 | 显式 content pack、canonical codec、同一 Command path | 保留旧 API，回滚 simulation atom；不得恢复外部写泄漏 |
| Auto-position 计划排序漂移 | plan signature、全组 focused、固定 seed | evaluator atom 独立回滚，原子 executor 不动 |
| Quality 转换改变 unit 数据 | before/after golden、固定 seed、P0 | policy atom独立回滚 |
| Replay verifier 产生 I/O | 注入 no-I/O capabilities、文件快照测试 | verifier atom独立回滚 |
| 新 Service 膨胀 | ownership audit + 准入门禁 | 删除未证明消费者的 composition entry |
| 活动任务冲突 | 每 atom 新任务卡；`_cell_detail_unit` 单独等待 | 输出 `FILE_CONFLICT_STOP`，不抢租约 |

## 13. 最终比较口径

后续比较不同架构方案时，按下列问题逐项评分，不按“删了多少行”评分：

1. 是否明确保留唯一 authority 和 exactly-once Command 事务？
2. 是否先修现有 correctness 问题，还是把问题原样搬走？
3. 是否复用已有 Planner/Policy/Codec/Repository，还是建立重叠服务？
4. 每个新模块是否有明确输入、输出、允许写入和失败语义？
5. 是否区分纯规划与原子应用、投影与 mutation、Builder 与 Repository？
6. 是否保留高内聚有序协调器，而不是按方法长度机械迁移？
7. 是否有逐 atom 的旧入口删除、focused tests 和冻结契约？
8. 是否能独立回滚一个切片而不恢复继承链或双写？

本方案允许 `game_state.gd` 在完成后仍然是较大的 authority facade；只要剩余内容都服务于单一权威、稳定协议或严格有序事务，这些代码属于必要复杂度，不算堆积。

## 14. 实施结果（2026-08-03）

### 14.1 结果概览

C0-C8、C5d 与 C9 已按本规格完成。结果不是把 8049 行平均切到若干新文件，而是先删除错误边界和重复职责，再让纯计算、只读投影、隔离模拟与持久化构造落到可单测 owner。

| 指标 | 冻结 baseline | 已实施 | 变化 | 解释 |
|---|---:|---:|---:|---|
| `game_state.gd` 行数 | 8049 | 6096 | -1953（-24.3%） | 结果指标，不是验收门槛 |
| facade 方法数 | 518 | 416 | -102（-19.7%） | 删除无 caller 私有壳和已迁实现 |
| `CoreComposition.services()` | 45 | 53 | +8 | 只加入有真实 consumer、逐 State 隔离价值和专项测试的 owner |
| 组合消费 | 未冻结 | 47 direct + 6 injected-only | 53/53 | 无孤儿 service |

实施后 `game_state.gd` SHA-256 为 `09906eea808d6120a2ce8461a2687b2b740b363b208c31b365189e1cbc2ce9ba`。C5d 提交树 inventory 为 580 个引用文件，aggregate SHA-256 为 `4d4c5dbe5a8765b2e544afa4516d0ded0019bf9c7b88e841b028e12f18442630`，旧继承、反向依赖、空虚拟契约和重复实现均为 0。

### 14.2 原四项 correctness 风险的处置

| 风险 | 已实施处置 | 结果 |
|---|---|---|
| Snapshot 查询写 roster | Snapshot 只投影规范化副本，权威规范化只在写事务执行 | repeated Snapshot、异常 slot fixture 均不改 source |
| Manual Flow 在 source 上真实 dispatch | `SimulationAuthorityFactory` 创建短命 no-I/O authority，`ManualFlowSimulationService` 只在 fork 上走相同 Command 路径 | source payload/hash/version/history/files/RNG 不变 |
| 第二 runtime capture/restore 清单漂移 | 删除 facade `_capture_runtime_state/_restore_runtime_state`，模拟恢复复用 `AuthoritativeStateCodec.FIELD_SPECS` | runtime field registry 只剩一份 |
| production fallback 与内容包竞争 | `ContentLoadService` fail closed；fixture 必须显式注入 | production fallback helper 全部删除 |

### 14.3 已落位的职责

- `QualityProgressionPolicy` 返回转换后的 value，不持有或原地写 authority。
- `BattleQueryContext + BattleQueryProjector` 接受不可变上下文，负责路线、战斗、配置、预览、双方详情和 cell detail；private facade 详情壳已删除。
- `AutoPositionEvaluator` 只做候选评价；Planner/Policy/TurnOptimizer 继续各守原责，权威只原子应用最终计划。
- `PlayerOperationProjector` 只组装日志 entry，append 时点仍由原事务 coordinator 控制。
- `ReplayDocumentBuilder` 只构造文档；`ReplayVerifier` 通过 no-I/O simulation authority 校验，Repository 仍只负责外部存取。

### 14.4 6096 行里哪些仍是必要责任

当前保留内容按“必须在唯一权威或稳定 facade”解释，而不是按长度豁免：

1. 权威字段、初始化/reset、composition adapter 和 initialization status。
2. `dispatch/run_command`、Command handler、Port capability 与 exactly-once history/log/version 事务。
3. Snapshot/save/load/replay/history 的公开兼容入口；具体 codec、builder、verifier、repository 已分责。
4. `start_battle`、round/end、`_execute_selected_action_option`、`_finish_battle_result` 等具有明确机制顺序和 safe point 的 mutation coordinator。
5. `auto_position_heroes` 的最终校验与原子应用，以及 Port `REQUIRED_METHODS` 明确要求的窄能力。

继续下沉这些内容必须先得到新的纯子块、显式 Delta/Result 和顺序 golden；不能再以“方法大”或“写顶层字段少”为理由整体搬迁。

### 14.5 完成门禁

- P0：normalized SHA-256 `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562`，save checksum `875e3dbe`，replay checksum `c53db478`，全部与冻结值一致。
- Battle Query 六份 golden：route `085524b4...`、battle `f2450e2c...`、configured `c1ec969a...`、preview `4f53cda1...`、player `9916f730...`、enemy `ca86d62f...`，全部逐字一致。
- 20 个关键测试全部通过，覆盖 purity、fail-closed、simulation isolation、query、auto-position、operation log、replay、codec/migration、composition 和 architecture boundary。
- clean worktree 完成 Godot import 后，正式 fast suite 15/15；证据目录：`/private/tmp/codex-c5d-final-validation.gv6eyZ/output/validation/qa/20260803-193042-fast`。
- 静态禁止项全部为 0：第二 runtime registry、source capture/restore、production fallback、AutoPosition authority reflection、已迁 private 壳、纯 service I/O 与旧 private test coupling。

因此本文件由 `IMPLEMENTATION_READY` 正式升级为 `IMPLEMENTED / VERIFIED`。后续若 live source 改变这些不变量，应以当前实现为新 baseline 做小切片 rebase，而不是重新套用 8049 行时期的行号或迁移表。
