# Godot 核心层架构

> 新人纵向读码路线见 [00_NEWCOMER_CODE_GUIDE.md](00_NEWCOMER_CODE_GUIDE.md)，工程目录和页面装配边界见 [06_PROJECT_STRUCTURE.md](06_PROJECT_STRUCTURE.md)，会话协议见 [05_GAME_SESSION_BOUNDARY.md](05_GAME_SESSION_BOUNDARY.md)。

`core/` 是正式规则、计算和权威状态层。它不读取 Godot 页面节点，不依赖 `art/` 或 `core_ui/`，也不承载美术资源路径。

## 当前权威门面

`core/state/game_state.gd` 的 `YsbzsState` 直接继承 `RefCounted`，持有唯一玩法字段集合，并稳定发布 Command、Result、Trace、Snapshot、save、replay 与 history API。旧六层 compatibility `extends` 链及其空虚拟契约已删除；不存在第二状态、第二写路径或兼容双轨。

领域算法和外部存取仍通过逐实例 `CoreComposition` 下沉到 Service / Policy / Port / Repository。Facade 保留同一权威状态必须执行的顺序协调，但不能重新引入机械继承层，也不能为了缩短文件把 `units`、`phase`、历史元数据或其他可写字段复制进服务。`tests/core/smoke_core_layer_structure.gd` 与 `tools/qa/inventory_core_methods.py` 会在旧路径重新出现、生产源码引用旧路径、同名 facade 方法重复或空 contract stub 回流时 fail closed。

## 初始化、内容装载与无 I/O 模拟

`YsbzsState` 构造采用 fail-closed 契约（C2，2026-08-03）：先装配 `CoreComposition`，再经 `ContentLoadService` 装载内容，全部成功才 `reset()`；失败不 reset、不 dispatch、不读第二路径。旧 `_fallback_game_data()` / `_pet()` / `_enemy()` / `_build_shop()` 生产兜底已删除，不存在第二内容真相源。

- 构造签名：`func _init(options: Dictionary = {})`，仅接受 `mode`（`production` / `simulation` / `test`）、`content_pack`（simulation/test 必填并立即深拷贝）、`core_overrides`（先构造 composition，再做任何读操作）。
- 稳定查询：`is_initialized() -> bool`、`initialization_result() -> Dictionary`（`ysbzs.init-result.v1`，失败为 `NOT_INITIALIZED`）。二者只读，`configure_core_services()` 保留原行为供既有测试运行期替换；长期新代码统一用构造 `core_overrides`。
- `ContentLoadService.load(input, repository)` 只做读与合并：production 读取 canonical pack 后按现有目录合并算法追加补充 JSON；simulation/test 只用注入包，不访问 repository，不合并路径补充。
- `session_factory.create_local_result(options)` 返回 `{ok, session, initialization}`；只有 initialized 才应用 seed、棋盘、history 并创建 `LocalGameSession`。`create_local` 是稳定兼容壳，失败 `push_error` 返回 null，不得返回半初始化 Session。

**模拟与预览隔离（C3a/C3b，2026-08-03 落地）**：预览在独立 canonical simulation fork 上执行，source 零写入、零 repository I/O，取代旧的 `_capture_runtime_state()` / `_restore_runtime_state()` 手写 capture/restore 与 `_manual_flow_preview_resolving` 递归预览标志（均已删除）。

```text
玩家输入
   │ PREVIEW_MANUAL_FLOW
   ▼
YsbzsState（source，只读）
   └─ ManualFlowSimulationService
        └─ SimulationAuthorityFactory.fork(source)
             ├─ SimulationIoGuard（五个 repository 全 fail-closed）
             └─ 新 YsbzsState(mode=simulation) ← canonical restore ← hash 校验
                  └─ 最多 limit(1-4) 次 dispatch（RUN_PLAYER_ALL_OUT → END_PLAYER_TURN）
                       └─ trace / snapshot / diff 返回，source 逐字段验证不变
```

- `SimulationIoGuard` 一个实例同时替换 save / replay / run_history / game_data / operation_log 五个 repository；每次被调先记录 `{repository, method, arguments}` 再返回 fail-closed 空值，`attempts()` 全程必须为空。
- `SimulationAuthorityFactory.fork(source, options)` 用 canonical `AuthoritativeStateCodec.capture` 取 payload，`source.get_script().new({mode:"simulation", content_pack, core_overrides})` 构造 fork，canonical restore 后清空 history metadata，校验 fork hash 等于 source hash、guard attempts 为空；失败返回 `SIMULATION_FORK_HASH_MISMATCH` 等错误并丢弃 authority。禁止调用 source `reset()`、共享 source composition、注册 Session 或读取路径。
- `ManualFlowSimulationService.preview(source, action, factory, diff_projector)` 在 fork 上执行并返回既有 `PREVIEW_MANUAL_FLOW` public schema（`commands/events/viewModel/cells/cellDiffs/unitDiffs/damageByUnit/...`）加 `simulation` 子对象；source canonical payload / hash / version / history 逐项验证不变。service 不持有 authority 或 repository，只在调用内接收 source 并验证只读。

## 领域职责

| 目录 | 职责 |
|---|---|
| `core/state` | 权威字段、稳定常量和 `YsbzsState` 公共门面 |
| `core/commands` | 命令协议、命令投影和 Snapshot/ViewModel |
| `core/run` | 路线、商店、奖励和整局流程编排 |
| `core/route` | 路线领域纯规则 |
| `core/economy` | 金币、刷新和购买领域纯规则 |
| `core/inventory` | 背包容量与记录规范化纯规则 |
| `core/party` | 阵容、图鉴和队伍领域规则 |
| `core/battle` | 战斗、元素、伤害、自动布置和棋盘尺寸规则 |
| `core/ports` | 组合服务所需的窄能力接口和回调上下文 |
| `core/composition` | 每个权威状态实例自己的组合根 |
| `core/logging` | 不依赖 UI 的结构化游戏日志 |

完整同步时，策划可调数据来自 `ysbzs_master.xlsx -> CSV -> data/content/**` 导出链；JSON 先行扩展放在 `data/content/extensions/` 并记录 `DATA_SYNC_PENDING`。代码内领域模块不能成为第二套策划真相源。

## 组合服务

每个 `YsbzsState` 实例持有一个自己的 `CoreComposition`：

当前完整清单以 `core/composition/core_composition.gd::services()` 为准，按职责分为：

```text
CoreComposition
  ├── 命令与查询：SnapshotProjector / CommandResponseBuilder
  ├── 战斗与整局编排：RoundLifecycleService / BattleSession / 双方回合服务
  │                  BattleStartupService / PetResetPolicy
  │                  BattleOutcomePolicy / RunAutomationService
  │                  DamageMechanicService / DamageDeathService
  ├── 行动与技能：ActionSlotService / SkillQueueService
  │              SkillExecutionService / SkillComboService
  ├── 品质运行时：QualityEffectRegistry / QualityRuntimeService
  ├── 效果与状态：TraitService / StatusService / ConditionEvaluator
  │              EffectInterpreter / ModifierCollector
  │              BattleHookPipeline / EffectTargetResolver
  ├── 属性语义：StatCatalogService（StatResolver 内部）/ StatResolver
  │              StatQueryService / StatSemanticPipeline
  ├── 遗物：RelicCatalogService / RelicCombatService
  ├── 预览与目标：DamageResolver / AttackOptionService / TargetingService
  │                QualityHitContextProjector / ThreatTargetPolicy
  ├── 内容与模拟：ContentLoadService / SimulationAuthorityFactory
  │                ManualFlowSimulationService
  │                （SimulationIoGuard 由 fork 临时构造，不常驻组合根）
  └── I/O 适配：SaveDocumentBuilder / RunHistoryCommitter
                  SaveRepository / ReplayRepository / RunHistoryRepository
                  GameDataRepository / OperationLogRepository
```

- `RoundLifecycleService` 完整拥有回合开始/结束的冷却、属性 Hook、旧机制规则、日志和状态推进顺序，只接收版本化 `RoundLifecyclePort` 能力。旧 `MechanicsEngine + MechanicsTriggerContext` 类型和一次性 `Dictionary + Callable` 接缝已删除；`YsbzsState` 的显式 Hook adapter 委托给逐实例服务。
- `DamageResolver` 是唯一伤害管线：基础值、攻击方修正、护卫/机制、减伤、防御方修正、护盾、生命、Trace、after Hook 依次结算；`DamageProps` 的 `move / unpowered / unblockable / skip_hurt_anim` 是可组合性质，不是四套公式。它只接收 `DamageResolutionPort v2`，同一 Props 会贯穿 before / after Hook，并返回瞬态版本化 `DamageResult`（格挡、未格挡、实际掉血、过量伤害、破盾、全挡、接收者与待死亡状态）。生产行动/技能使用 move，非攻击效果使用 unpowered，HP loss 组合 unblockable；多目标伤害在整批 packet 与 Hook 完成后统一结算死亡，反伤也必须经该管线。
- `DamageDeathService` 在单包或多段伤害完成后按稳定目标顺序结算死亡、死亡后 Hook、击杀 Hook 与 `UNIT_DEFEATED`；原始伤害 primitive 不在生命扣减中途触发死亡链。该顺序经 `DamageDeathPort v1` 写回唯一权威状态。
- `BattleSession` 只负责单回合和自动战斗，只接收 `BattleSessionPort`。
- `PlayerTurnService`、`EnemyTurnService` 分别负责双方行动顺序，通过各自 Port 调用权威状态中的伤害、目标和落位能力。
- `BattleStartupService` 负责敌方模板选择、去重和我方开战部署准备。
- `PetResetPolicy`、`BattleOutcomePolicy` 是可替换纯策略，分别负责宠物重置次数、资格与确定性落位，以及终局判定、基础奖励和稳定结果文档。同一重置或结算规则不再按“计数/落位”“判定/结果”粗暴拆成多个文件。
- `RunAutomationService` 负责路线、商店、奖励、战斗结算和跨天的外层自动流程，只接收 `BattleSessionPort`。
- `SnapshotProjector` 只做只读 ViewModel 投影。
- `CommandResponseBuilder` 只拼装稳定命令响应。
- `CommandContract` 把 UI Command 定义为逐动作字段白名单内的纯玩家意图；`LocalGameSession` / `RemoteGameSession` 才生成 command ID 和权威基线，远端 Host 再校验 actor scope、schema、幂等和基线。`CommandHandlerRegistry` 把规范 authoritative Command 精确映射到 query/replay、route/reward、shop/inventory、run-flow、battle 五个 handler 域；handler 只解析已校验的业务意图，并只接收本域版本化 Command Port。`CommandPortFactory` 是兼容适配装配点，完整 `YsbzsState` 不再暴露给 handler。远端、复杂命令和完整校准使用 strict `stateVersion + stateHash`；本地三选商店的受限增量白名单使用 strict `stateVersion` 并返回领域 delta，最终存档/回放仍计算真实完整 hash。UI 不能提交版本/hash、免费刷新、拖拽来源或下一天编号。
- `SkillQueueService`、`SkillExecutionService`、`SkillComboService` 负责有序技能队列、声明式效果执行和组合匹配；权威单位字段仍写回唯一状态。
- `ActionSlotService` 负责行动槽 key、方向/AP choice、已用槽/AP 记账与下一可用槽等确定性规则；phase、单位/槽合法性、攻击预览、选择状态与日志继续由公开 Command 协调。
- `QualityEffectRegistry`、`QualityRuntimeService` 由每个 State 的同一组合根装配；前者解析品质策略，后者只拥有玩家可配置的 mode/mark 读写与规范化。phase、选中单位、棋盘/行动槽合法性和日志仍由 battle core 协调，其他品质 flags/计数仍由具体策略维护。
- `ConditionEvaluator`、`EffectInterpreter`、`ModifierCollector`、`BattleHookPipeline`、`EffectTargetResolver` 组成声明式效果与 Hook 管线；Type Object 数据不能指定任意脚本路径。
- `StatCatalogService`、`StatResolver`、`StatQueryService`、`StatSemanticPipeline` 统一属性定义、最终值查询和玩法语义消费，Snapshot 与详情不得各算一套最终属性。
- `RelicCatalogService`、`RelicCombatService` 负责遗物目录与高内聚战斗时间线执行；后者只接收版本化 `RelicCombatPort`，不能反射完整 core。遗物状态仍只经 Port 写回权威 codec、hash 和 Snapshot 边界。
- `SaveDocumentBuilder` 是普通存档与历史 checkpoint 的唯一文档装配器。`RunHistoryCommitter` 经版本化五能力 `RunHistoryPort v1` 独占 begin / append / checkpoint 顺序；history 关闭时只读取轻量 status scope，不复制完整内容或重复算 hash。
- `SaveRepository` 只接收序列化文档和路径配置，负责 slot、primary、backup、temp 的原子文件操作；`ReplayRepository` 与 `RunHistoryRepository` 分别拥有 replay/trace 导出和不可变运行历史文件。它们都由每个 State 的 `CoreComposition` 装配并可替换；`YsbzsState` 不硬构造 adapter，也不直接使用 `FileAccess` / `DirAccess`。
- `SaveDocumentValidator` 只校验 save schema、状态字段、棋盘尺寸和单位列表；兼容层不再保留文件路径、读写和删除包装函数。
- `GameDataRepository` 负责只读 JSON 文档加载，其内容缓存归 repository 实例所有，不在 Session 之间共享；`OperationLogRepository` 负责 JSONL 追加写入。
- `AutoPositionPlanner`、`AutoPositionPolicy`、`AutoPositionReadPort` 和 `AutoPositionTurnOptimizer` 是独立组合服务，不继承权威状态。
- 商店 Effect Handler 只描述一个已注册效果类型，并经版本化 `ShopEffectPort` 使用阵容、英雄生命或刷新能力；handler 不能直接读写 `roster`、`hero_hp`、`shop_free_rolls` 等权威字段。
- `ContentLoadService` 只做内容装载与目录补充合并，不成为第二内容真相源。
- `SimulationAuthorityFactory` / `SimulationIoGuard` / `ManualFlowSimulationService` 提供无 I/O 的 canonical simulation fork：预览命令只在 fork 上执行，source 保持只读；详见上文「初始化、内容装载与无 I/O 模拟」。

组合服务只能接收显式 port、context、值或 Callable，不接收完整 core，也不保存第二份权威状态。动态兼容调用只能封装在 port 适配器内；落位仍由 `_apply_auto_position_moves_atomically()` 单点写入。

## 纯领域服务

巨型兼容层中的确定性计算已经迁到可独立测试的纯服务：

- `core/battle/`：形状几何、单位生命、统一伤害管线、伤害性质/结果、死亡安全点和战斗 Trace 构造。
- `core/battle/quality/`：品质效果注册表、玩家 mode/mark 运行时服务与策略；命中伤害修正由声明式 `damage_rules` 表达，特殊状态行为才使用专用策略类。显示 mode 的首选项 fallback 与伤害上下文的原始 stored mode 是两个不同契约，不得混用。
- `TargetingService`、`ElementFieldService`：目标收集/排序与单位/格子元素层存取。
- `core/run/`：稳定随机与加权选择。
- `RouteOptionService`：路线节点、遭遇池与战斗入口的只读选项投影。
- `core/route/`、`core/economy/`：路线条件、按天/战斗奖池、商店权重/刷新成本、事件奖励倍率解析与金币倍率取整等无状态规则。`YsbzsState` 仍唯一协调 effect 消费顺序、权威金币写回、日志和 battle result 装配。
- `core/party/`：品质推进、进化汇总、出售价值与阵容/背包槽位分配；`RosterCollectionService` 负责图鉴/队伍集合规范化。
- `ManualFlowDiffProjector`：手动流程预览的格子差异、单位差异、伤害来源和汇总。
- `AttackOptionService`：形状攻击选项构造；方向、元素和伤害权威规则仍留在 battle core。
- `persistence/replay_builder.gd`：命令流、变更、checkpoint 和兼容战报投影。
- `persistence/authoritative_state_codec.gd`：save、load、历史 checkpoint 与 `stateHash` 共用的权威字段注册表；新增会影响后续命令的状态字段必须先进入该注册表。
- `persistence/run_history_repository.gd`：全局登记不可变内容修订，每局只引用修订点并保存 append-only 命令日志和每日直接 checkpoint；仓储不执行规则，也不成为第二权威状态。

`METHOD_INVENTORY` 现在盘点单一 facade 的真实方法 owner：旧链、反向依赖、空 contract stub 和同名 facade 实现均为 0。文件长度不是拆分依据；只有出现独立变更原因、禁止依赖或可单独验证能力时才提取服务。纯服务不得读写文件、节点或全局单例。

## 确定性运行历史

正式本地 Session 默认启用运行历史。每个 run 固定记录：

- 完整 `seed` 与带命名空间的 RNG 算法版本；
- 策划运行快照的单调 `contentRevision` 与 SHA-256 `contentHash`；同一内容修订全局只保存一份压缩不可变包，run/branch 只保存直接引用；
- 显式 `rulesVersion`；
- 不截断的接受命令 JSONL，包含命令序号、前后版本和前后状态 hash；
- 第一天开局、每天日结、下一天开局和终局压缩 checkpoint；每局另有固定大小的 `run.json` 运行头，以及按 `day_index/day_NNN_kind.json` 命名的独立时间点指针。

内容自动演化发生变化时，仓储按完整内容 hash 自动登记下一个不可变修订；旧修订不得覆盖或垃圾回收。新增宠物、商品、波次或事件后，旧历史仍通过原 `contentRevision` 直接装载原内容，不能按当前候选池和同一 seed 重新推测旧结果。

按日继续时只读取固定大小的 `run.json`、指定日的单个指针文件、对应 checkpoint 与所引用的内容修订，校验规则/RNG/内容 hash 后直接恢复进唯一 `YsbzsState`。该路径不解析随历史增长的 manifest，也不为恢复第 N 天从开局线性重放前 N 天命令；命令流只用于审计、回放验证和诊断。恢复成功后创建带 `parentRunId` / `parentCheckpointId` 的新 run 分支，并复用原内容修订，原历史永不覆盖。

这不是完整 Event Sourcing：当前权威仍是 `YsbzsState`。manifest 和命令日志可以随时间增长，但它们不在按日恢复的必经路径上；每日 checkpoint 是随机访问恢复点。`run_plan` 由固定内容修订、seed 和规则版本恢复时重新生成，非玩法 audit 投影不在每个 checkpoint 重复保存。旧 run 内 `content_pack.json`、无独立日指针的 manifest 与 `.json` checkpoint 继续只读兼容。任何缺失修订、规则版本或 RNG 版本必须明确拒绝，禁止静默使用当前内容继续旧历史。

## BattleWorld 数据导向纵切（冻结实验）

2026-07-29 曾建立一个 Bevy 风格、但不绑定外部 ECS 框架的隔离实验，位于 `core/battle/world/`。它从未接入正式命令写路径；2026-08-01 已决定冻结并只保留为参考：

```text
GameSession / Command / Save / Replay
                    │
                    ▼
          YsbzsState authoritative state
                    │ explicit import/write-back
                    ▼
               BattleWorld
        ┌───────────┼───────────┐
     Position      Camp       Vitals
        └───────────┼───────────┘
                    ▼
        DamageSystem -> DeathSystem
                    │
                    ▼
             structured events
```

- `EntityId` 是按导入顺序稳定分配的整数；外部单位 id 只由 Identity 组件映射，不让系统遍历松散对象图。
- Position、Camp、Vitals 与 Alive 使用分列组件存储；System 通过组件 mask 做稳定升序查询。
- 每个 System 必须声明 `reads()`、`writes()` 和 `stage()`；Schedule 按阶段和系统名确定执行顺序，并拒绝同阶段未排序的读写冲突。
- 伤害纵切只接收已完成护卫、机制和防御修正的 resolved damage，依次更新护盾/生命、输出 `DAMAGE_APPLIED`，再由死亡系统更新 Alive 并输出 `UNIT_DEFEATED`。
- `BattleWorldAdapter` 是当前 Dictionary 权威状态的显式迁移缝。World 目前只允许存在于一次命令或一次模拟的生命周期内；结果必须通过明确 write-back 接受，不能被 UI、存档或其他服务直接读取。
- Command、Snapshot、Trace、状态哈希和存档 schema 继续由现有外壳拥有。纵切的等价 smoke 使用相同输入比较旧 `DamageResolver` 与新 System 的生命、护盾、回合伤害和事件顺序。

2026-08-01 决策点已选择“冻结并保留参考”：现有纵切通过结果等价与确定性 smoke，但没有生产调用方，也没有可度量的性能或维护收益，因此不继续迁入 Position/Targeting、Element、ActionIntent。重新开启前必须先声明一个明确的生产写入口、同输入等价与 stateHash/save/replay 证据、可复现收益，以及接管后删除旧入口的计划；否则 BattleWorld 不得注册进 CoreComposition 或正式 Session。

若未来满足上述重新开启条件，仍必须一次只迁一个写入口，并在同一任务中删除或封闭对应旧写入口，禁止长期双写、双算或保留两份权威战斗状态。

## C0-C9 职责下沉迁移路线图

`core/state/game_state.gd` 的 facade 继续按真实职责下沉（执行规格见 `reports/architecture/2026-08-03_CODEX_GAME_STATE_IMPLEMENTATION_PACK.md`；该路线取代早期 FACADE 11 服务总纲，详见 `docs/15`）。进度（2026-08-03）：

| 切片 | 内容 | 状态 |
|---|---|---|
| C0 | 24 个无调用 facade 方法删除 | ✅ `3c1ce75` |
| C1 | `snapshot()` 零写入 + roster 规范化写点收口 | ✅ `0b1a60b` |
| C2 | 构造 fail-closed + `ContentLoadService` | ✅ `9293c9d` |
| C3a | `SimulationIoGuard` + `SimulationAuthorityFactory` | ✅ `c6c1aef` |
| C3b | `ManualFlowSimulationService`（preview 迁到 fork） | 🔶 实现 + 专项验证完成，待收口提交 |
| C4 | `QualityProgressionPolicy` 纯 Policy | ⬜ 待执行 |
| C5a-d | `BattleQueryContext` / `BattleQueryProjector` 查询下沉 | ⬜ 待执行 |
| C6 | `AutoPositionEvaluator` 去 authority 反射 | ⬜ 待执行 |
| C7 | `PlayerOperationProjector` 操作日志纯投影 | ⬜ 待执行 |
| C8a/b | `ReplayBuilder` 补全 + `ReplayVerifier` 无 I/O | ⬜ 待执行 |
| C9 | 最终删除、依赖审计与完成门禁 | ⬜ 待执行 |

原则：每切片独立任务卡、独立提交、可回滚；`AuthoritativeStateCodec.FIELD_SPECS` 是 capture/restore/hash 唯一字段注册表；`YsbzsState` 仍是唯一权威，Service 只写回同一权威状态。最终组合服务 53 项（当前 48 + C4/C5/C6/C7/C8 各 1）；facade 保留权威字段、`dispatch/run_command` 事务、`snapshot` schema、save/load/replay/history 公开入口与严格顺序 mutation coordinator，方法可缩短但不因大而强迁。

## 后续需求扩展点

| 需求 | 扩展点 | 模式 |
|---|---|---|
| 新增品质命中增伤、倍率、首击/末击条件 | `QualityEffectRegistry.damage_rules` | Strategy + Registry |
| 新增需要独立状态行为的品质 | `QualityEffectStrategy` 子类并注册 | Strategy |
| 新增同类特性/技能/效果 | `data/content/extensions/*.json` + 已有 effect type | Type Object + validated Registry |
| 新增已有回合时机的内容 | JSON 声明 `round_start` / `round_end` Hook，复用 effect pipeline | Data-driven Hook |
| 新增当前 effect type 无法表达的能力原语 | 新 handler 脚本，通过 `plugin_id + execute` 契约扫描注册 | Strategy + fail-closed Registry |
| 新增全新回合阶段或权威能力 | 升级 `RoundLifecyclePort` 契约并修改 `RoundLifecycleService` | Versioned Port + ordered Application Service |
| 更换敌方行动顺序或 AI | 替换 `EnemyTurnService`，复用 `EnemyTurnPort` | Application Service + DIP |
| 更换我方全部出击顺序 | 替换 `PlayerTurnService`，复用 `PlayerTurnPort` | Application Service + DIP |
| 新遭遇模板选择或开场部署方式 | 替换 `BattleStartupService` | Factory-like preparation + Domain Service |
| 新模式采用不同宠物重置规则 | 注入 `PetResetPolicy` | Policy / Strategy |
| 新胜负、平局或基础奖励规则 | 注入 `BattleOutcomePolicy` | Policy / Strategy |
| 调整完整日/完整局阶段推进 | `RunAutomationService` | State-machine orchestrator |
| 新目标优先级或元素存储规则 | `TargetingService` / `ElementFieldService` | Domain Service |

所有可替换项由每个 `YsbzsState` 自己的 `CoreComposition` 注入；不能升级成全局 Manager 或 Autoload。新增策略不得直接持有 `units`、`phase`、经济或存档，只能通过值、Context 或窄 Port 工作。

### `Slay the Spire 2 (DEBUG)` 参考边界

本地恢复工程 `/Users/ywh/Documents/Sts2RecoveredFull` 是同目标职责、交互闭环和生命周期的优先基线：输入封装为 `GameAction`、规则下沉到 Command、复杂阶段使用显式 State、场景切换由装配容器负责、存档依赖窄 `ISaveStore`。本项目存在对应问题时默认迁移这些语言无关不变量；只有 `docs/15_STS2_GUIDED_ARCHITECTURE_MAP.md` 定义的显著迁移 / 兼容代价有任务证据时才保留本项目方案。若现有实现已保护相同不变量和可观察结果，则视为已经采用，不为类名或文件形态重写。STS2 同样保留了高内聚的大型协调器，说明文件长度本身不是拆分依据。

不复制该工程的专有源码、资源、数值或品牌表达；全局单例、静态 Hook/数据库、C# 生命周期或逐内容类只有在保护同一不变量、且不触发显著代价门槛时才按本项目架构重新表达，不能原样照搬。落地仍以本项目的 `GameSession -> Command -> YsbzsState -> Result/Trace/Snapshot`、逐实例 `CoreComposition` 和显式 Repository/Port 为唯一依赖方向。

## Facade 与能力接口规则

- 不新增机械 authority 继承层或没有调用方、实现、替换需求的空契约。新增 Port 必须说明消费者、能力集合、版本和 fail-closed 行为。
- 删除签名前检查定义、普通调用、`call()` / `Callable`、Godot 生命周期和协议消费者，并通过存档/回放/命令契约回归。
- `smoke_core_layer_structure` 要求旧六路径不存在且无生产引用、facade 直接继承 `RefCounted`、公开入口和可用 Snapshot 稳定。
- Facade 可在职责不变且顺序更清楚时增长；若新增的是独立变更原因、禁止依赖或可独立验证能力，则进入所属 Service / Policy / Port / Repository。
- 拆分模块不得复制 `units`、`phase`、`battle_trace`、经济、历史或存档状态。

## 持久化兼容边界

`persistence/` 拥有 codec、document builder、history committer、repository、replay repository 和 migrations。`game_state.gd` 直接装配这些能力并保留稳定 save/load 公共 API；旧 persistence compatibility 继承门面已经删除。

新增持久化能力应进入 repository/codec/migration，通过显式接口被组合根使用；不得把新的文件操作写回 `core/run`、`core/battle` 或 UI controller。

## ViewModel Schema

`session/view_model_schema.gd` 定义 UI 读取模型的稳定 schema id、版本、规范化和校验。`SnapshotProjector` 在发布前统一补齐 schema 元数据和稳定顶层字段，`SessionProtocol` 在本地/远端边界校验收到的 ViewModel。

ViewModel 是权威 Snapshot 的只读投影，不是第二份状态；UI 可以依赖版本化字段，但不得修改 ViewModel 后回写核心。新增破坏性字段变化必须提升 schema 版本、保留协议错误信息并增加迁移或双读窗口。

## 稳定门禁

- UI 只经 `GameSession`、命令和 Snapshot/ViewModel 与权威状态交互。
- debug harness 也遵守同一边界：`battle_debug.gd` 只经 `SessionFactory` 创建本地 Session，命令、查询和持久化不得绕过 Session；未路由的旧单机控制器不作为第二入口保留。
- `core`、`session`、`persistence` 不得反向引用 `art`、`core_ui`、`shared` UI 或 legacy `game/features`；`core` GDScript 不得继承 Node/SceneTree/Control/CanvasItem，也不得遍历节点树。版本化 ViewModel schema 只能经当前显式投影边界使用。
- 命令响应、`stateVersion`、`stateHash`、save/replay schema 和棋盘投影保持兼容。
- `tests/core/smoke_core_layer_structure.gd` 守住单一 facade、旧链零文件/零生产引用、零重复方法、零空契约和稳定公共 API。
- `tests/core/smoke_core_composition_complete.gd` 守住组合服务、逐实例组合根和 repository 委托。
- `tests/core/smoke_manual_flow_simulation_isolation.gd` 守住 preview 的 source 零写入、零 repository I/O、与独立 production 投影的 parity 精确相等，以及 limit/phase/拒绝边界。
- `tests/integration/smoke_architecture_boundaries.gd` 守住 P0/P1 服务委托、依赖方向、唯一权威和巨型 smoke 的语义分组，不检查代码行数。
- `tests/session/smoke_view_model_schema.gd` 守住 ViewModel 版本、规范化与协议拒绝边界。
- `tests/integration/smoke_project_structure.gd` 递归守住 core/session/persistence 反向依赖、core Node 生命周期隔离、主入口和正式数据/美术边界。

新增规则进入拥有该不变量的最清楚内聚单元。只有出现独立变更原因或依赖隔离价值时才新建模块；不得重新制造 authority 继承链或为了缩短文件增加一层层转发。门禁不使用固定文件行数、方法总数或 Scene/prefab 数量；这些只能提示审计，不能替代职责、依赖和行为证据。
