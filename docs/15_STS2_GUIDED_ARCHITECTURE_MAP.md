# STS2 参照下的架构收敛地图

> 本文保留架构对照、历史取舍和代码定位信息，供理解项目时参考。它不是 AI 的强制采用规则，后续方案可以依据当前源码和目标重新判断。

本文件记录 `/Users/ywh/Documents/Sts2RecoveredFull`（`Slay the Spire 2 (DEBUG)`）与当前项目的职责对照，以及每个热点为什么迁移、保留或拒绝。STS2 已在商业产品中验证的同目标做法是默认基线，但采用的是语言无关不变量和行为结果，不是复刻专有源码、资源或类树。以下判断基于 2026-08-03 的两边 live source（已随 C0-C9 职责下沉迁移同步更新）；STS2 文件名只能提供证据，不能充当结论。

## STS2 优先采用原则

当 STS2 与本项目都在解决同一个真实问题时，举证责任在“为什么不迁移”，不在“为什么要迁移”：默认裁决是迁移 STS2 已验证的规则、交互闭环、职责边界或生命周期语义，再按 Godot / GDScript 的成本模型实现。若本项目已经实现相同的不变量和可观察结果，只是类名、文件数量或语言表达不同，视为已经采用，不为表面一致重写。

历史评估主要关注下列显著代价：

- 会破坏 `GameSession -> Command -> YsbzsState -> Result/Trace/Snapshot`、确定性 RNG、stateHash、save/replay 或协议兼容。
- 会引入第二权威状态、第二写路径、全局 Manager / 静态规则中心，或冲突于内容包和本仓 `art/**` 的正式视觉资产边界。
- STS2 方案依赖 C# / 引擎能力，在 Godot / GDScript 中只能靠与收益不成比例的重写或维护成本实现。
- 涉及专有源码、资源、数值、品牌表达或其他版权 / 许可边界，无法只迁移语言无关不变量。

“当前已经能跑”“已有测试”“已经投入开发”“我们更熟悉”或单纯 sunk cost 都不是独立的保留理由。保留 / 拒绝记录必须写明具体代价、影响范围、替代方案和重新评估条件。

## 跨语言决策顺序

每次引用 STS2 前必须依次回答：

1. 参考点保护的语言无关不变量是什么，例如唯一权威、输入边界、确定性或外部存取隔离？
2. 当前项目是否存在同一真实目标和调用方？若存在，默认迁移；若不存在，不为未来预建抽象。
3. 当前 JSON + Schema、目录 Registry、纯 Policy、窄 Port 或协调器是否已保护同一不变量并产生同一可观察结果？若是，记为已采用，不做表面改写。
4. 若尚未采用，怎样用当前架构表达 STS2 做法，同时保持 `YsbzsState` 单一权威、Command/Result/Trace/Snapshot、确定性 RNG 和 save/replay 兼容？
5. 若考虑保留或拒绝，是否存在上节定义的显著代价，以及对应的 live 证据、影响范围、替代方案和重开条件？

这里的裁决含义固定为：

- `迁移`：默认裁决；采用语言无关职责、不变量或行为结果，但由当前 Godot / GDScript 架构重新表达。
- `保留`：本项目已语义等价采用，或迁移存在已举证的显著代价；不得只因现状或熟悉度保留。
- `拒绝`：采用会破坏项目硬契约、成本与收益明显不成比例或触及版权 / 许可边界；必须记录替代方案和重开条件。

## 固定主干

```text
玩家输入 / 自动化驱动
          │
          ▼
      GameSession
          │ Command
          ▼
      YsbzsState  ← 唯一权威状态
          │
          ├── CoreComposition（逐实例）
          │     ├── Application Service + narrow Port
          │     ├── pure Policy / Strategy
          │     └── Repository / Projector
          │
          └── Result / Trace / Snapshot
```

任何优化都不能在这条主干旁边创建第二套战斗状态、第二个 Session、全局 Manager、Autoload 规则中心或 UI 可写缓存。预览不例外：`PREVIEW_MANUAL_FLOW` 等只读查询在 `SimulationAuthorityFactory` 创建的 canonical fork 上执行；fork 是一次 service 调用内存活的临时 `YsbzsState`，经 `SimulationIoGuard` 与五个 repository 隔离，不得注册进 Session，source 始终保持零写入。

## 重点源码对照与裁决

| STS2 live 参考 | 语言无关不变量 | 本项目 live 对应 | 裁决 | 当前原因与重开条件 |
|---|---|---|---|---|
| `Core/GameActions/GameAction.cs` 的玩家输入边界 | 玩家意图与内部模拟步骤分离 | `session/game_session.gd`、五类 Command handler、五个版本化 Command Port、`PhasePolicy` | **迁移** | handler 只解析玩家意图并调用本域 Port，完整 `YsbzsState` 不再暴露给 handler；伤害/元素等内部规则仍不是玩家 Action。不复制 STS2 类树 |
| `GameAction.cs` 的 `TaskCompletionSource` pause/resume | 同一个内存 action execution 可暂停收集玩家选择，再以状态、ID、事件和取消语义恢复 | `GameSession + ActionLifecycle` 已有 queued / awaiting_choice / executing / terminal 元数据 seam | **保留** | 当前 seam 的 prepare/await/resume/cancel 没有生产调用方，也未接入权威命令中途暂停、save/replay；不得重复造第二套。只有真实流程需要时，才把现有 seam 接入 Command、选择同步、取消、存档与回放协议；不能把 `GameAction.cs` 本身解读为已经证明存档后 continuation |
| `Core/Combat/CombatState.cs` | 一个战斗权威拥有可写状态，查询可派生 | `YsbzsState`、`units`、战斗字段 | **迁移** | 保持一个高内聚权威；拒绝按字段拆成多份可写 Store。只有明确封闭旧写入口且 stateHash/save/replay 等价时才迁移字段所有权 |
| `Core/MonsterMoves/MonsterMoveStateMachine/*.cs` | 真状态身份、合法转移、进入/退出与历史 | `PhasePolicy`、双方回合服务 | **保留** | 当前阶段规则不需要复制一组 C# State 子类；只有同时出现状态身份和转移不变量时才增加 State，普通 trigger 不包装成状态机 |
| `Core/Random/Rng.cs`、`Core/Runs/RunRngSet.cs` | seed、调用计数/流隔离、保存后可重建 | `core/run/seeded_selector.gd`、replay/save 的 RNG version | **迁移** | 保持可复算和版本化；不照搬 C# `Rng` 对象图。只有多个随机域相互污染已被测试证明时才引入显式分流，且必须进入存档/回放契约 |
| `Core/Saves/ISaveStore.cs` | 外部存储能力与游戏规则分离 | `persistence/save_repository.gd`、`GameDataRepository`、`OperationLogRepository` | **迁移** | 保留窄 Repository/Port；schema、checksum 和权威字段仍由 codec/document builder 负责，Repository 不执行规则 |
| `Core/Nodes/NSceneContainer.cs` | Scene 替换时旧节点释放和新节点归属显式 | 正式三选一路由按需挂载/释放 battle Scene | **保留** | 当前唯一玩家路由已拥有生命周期，不新增全局 Scene Manager。只有第二条真实玩家流程出现且重复同一替换不变量时再抽公共容器 |
| `Core/Hooks/Hook.cs` 的静态调度门面 | listener 来自显式传入的 `ICombatState/IRunState`；顺序确定，combat 终止 guard 在 dispatch 起点只判断一次 | `BattleHookPipeline`、`ModifierCollector`、版本化窄 Port | **拒绝** | 迁移“显式 listener 顺序与 dispatch 起点一次性终止判断”的理念；拒绝静态 façade 和 `CombatManager.Instance` guard 的实现形态。STS2 不是全局 listener bus；当前项目也不应因此新增静态规则中心 |
| `CreatureCmd.Damage`、`ValueProp`、`DamageResult` | 一条伤害管线承载可组合性质；先修正数值，再格挡/掉血/记录/after Hook，最后批量死亡；结果对象保留格挡、未格挡、过量、破盾、全挡、击杀与接收者 | `DamageResolver`、`DamageProps`、瞬态 `DamageResult`、`DamageResolutionPort v2`、`DamageDeathService` | **迁移** | 生产行动、技能、品质与机制来源已声明 Props；同一 Props 贯穿 resolver 与 Hook，多目标 damage packet 完成后批量死亡，反伤也经统一管线。不复制静态 `CreatureCmd/Hook`、异步 VFX、全局 CombatManager 或 C# 对象图。现有 Trace/Save/Replay schema 不因瞬态结果扩展而变化 |
| `Core/Commands/RelicCmd.cs`、`Core/Models/RelicModel.cs` | 遗物内容/Hook 与获得、移除、运行协调分责；严格顺序由高内聚协调器维护 | `RelicCatalogService`、`RelicCombatService`、`RelicCombatPort v1` | **迁移** | 保留遗物时间线、同 tick 排序、冷却、连锁与 guard 的高内聚服务；权威状态、Trace、日志和 Effect 能力只经 Port。拒绝静态 `Instance`/`ModelDb` |
| `Core/Models/ModelDb.cs`、`AbstractModel.cs`、`AbstractModelSubtypes.cs` 与逐内容子类 | 内容 ID 唯一、可发现、canonical/mutable 身份和行为扩展契约明确 | `data/content/**/*.json`、Content Pack Schema、`ScriptPluginRegistry`、effect handlers | **拒绝** | STS2 内建 subtype 来自 `[GenerateSubtypes]` 生成的 `AbstractModelSubtypes.All`，仅 Mod subtype 用反射发现，再由静态 ModelDb 创建 canonical model；不照搬这套静态 DB、源生成/Mod 反射和每张卡/宠物一个子类。GDScript 当前优先“组合用数据、通用原语用 handler”；只有 JSON/Schema 无法表达新的权威原语才新增脚本插件 |

以上不是“GDScript 优于 C#”或相反，而是两套成本模型下对同一不变量的不同表达。STS2 的市场验证决定默认方向；本项目的调用方、失败模式、兼容成本和测试证据决定怎样迁移，以及是否达到保留 / 拒绝的显著代价门槛。

## 当前热点决策

| 热点 | 结论 | 原因 / 边界 |
|---|---|---|
| `core/state/game_state.gd` | C0-C9 职责下沉进行中 | 直接继承 `RefCounted` 并持有唯一权威字段；旧六层、空虚拟契约和反向依赖均已归零（0 / 0）。C0-C3 已落地，C4-C8 按 `CODEX_GAME_STATE_IMPLEMENTATION_PACK` 逐切片下沉，最终组合服务 53 项；高内聚协调顺序保留，独立规则继续下沉到逐实例 Service / Policy / Port（见 docs/03 路线图） |
| `YsbzsState::snapshot()` | 保留 | 它一次性发布稳定 Snapshot schema，变化原因是协议而非行数；细节计算复用既有 Projector/Service |
| 五类 Command handler | 已完成能力收口 | handler 对应薄玩家 Action，只接收由 `CommandPortFactory` 装配的本域版本化 Port；新增同域命令不再获得完整权威状态。新增全新能力域仍必须显式增加 Port，这是应有成本 |
| Shop Effect handler | 已完成能力收口 | 已注册效果只经 `ShopEffectPort v1` 使用明确能力；组合效果优先继续用 JSON，只有新权威原语才扩 Port/handler |
| `RelicCombatService` | 已完成能力收口 | 高内聚时间线保留，完整 authority 已替换为 `RelicCombatPort v1`；行为、Trace 与 stateHash 由专项等价 smoke 守护 |
| `YsbzsState::_finish_battle_result()` | 保留薄协调器 | 机制、金币、路线奖励、Trace、阶段迁移仍按严格顺序编排；终局判定、基础奖励、失败审计和稳定结果文档统一由现有 `BattleOutcomePolicy` 承担 |
| `SaveDocumentBuilder` / `RunHistoryCommitter` | 完成能力收口 | 普通 save 与 checkpoint 共用 builder；历史 begin/append/checkpoint 只经五能力 `RunHistoryPort v1`，Repository 负责外部存取且不成为第二权威 |
| battle / party 顺序 Hook | 完成能力收口 | 权威 facade 只保留显式 adapter；Hook、召唤、死亡和元素机制由逐实例 Service 与版本化 Port 单点实现，party 目录规则不再是隐藏战斗 owner |
| `MechanicsEngine` / `MechanicsTriggerContext` | 类型删除，职责显式化 | 被删的是无版本 `Dictionary + Callable` 类型，不是战斗机制本身；运行入口现在由 battle 层经逐实例 Service、`DamageResolutionPort v2` 和 `DamageDeathPort v1` 组合，不新增全局 Hook 总线 |
| 两个 debug controller | 收口到 Session | `battle_debug.gd` 经 `SessionFactory -> GameSession -> Command/Snapshot` 驱动；无正式 Scene 路由、直接 new State 并直调持久化的 1934 行 legacy controller 已删除 |
| 空 `parts/layers` scaffold | 删除 | 22 个空目录不承载 owner、契约或运行时发现语义，不能继续作为按 part 分片的暗示；未来按真实职责和依赖新增模块 |
| `ScriptPluginRegistry` | 保留并收紧 | handler 拥有独立 ID 和注册生命周期；目录扫描会校验加载、实例化、ID、必需方法和重复项，任一错误整体 fail-closed |
| `PetResetPolicy` | 合并完整规则 | 次数、资格、安全区和确定性落位同属“宠物重置”一个变更原因；不再拆成第二个 placement 文件 |
| 自动布置、目标、元素、属性、技能队列 | 保留现有服务 | 已有独立输入输出、不拥有权威状态，并有 focused 契约测试 |
| `BattleWorld` | 冻结为隔离参考 | 等价 smoke 已通过，但当前无生产调用方或可度量收益；不注册进 CoreComposition/Session，不继续铺开。只有明确生产入口、兼容证据、收益和旧入口删除计划齐全时才重开 |
| 预览与模拟隔离（C3） | 迁移到 canonical simulation fork | 旧手写 `_capture_runtime_state()` / `_restore_runtime_state()` 与递归预览标志已删除；`PREVIEW_MANUAL_FLOW` 在 `SimulationIoGuard` 守护的 fork 上执行，source 零写零 I/O，public schema 与投影结果不变。对应 STS2 的暂停/恢复语义，但不复制 `GameAction.cs` 的 continuation 对象图 |
| 构造与内容装载（C2） | 已完成 fail-closed | `mode/content_pack/core_overrides` 构造契约 + `ContentLoadService`；生产 fallback 第二内容真相源删除，初始化失败不 reset、不 dispatch。对应 STS2 明确的外部存储与初始化边界 |
| 无 I/O 模拟隔离 | 已采用 | `SimulationIoGuard` 一个实例同时替换五个 repository 并 fail-closed，`attempts()` 全程必须为空；fork hash 必须等于 source hash。以 canonical fork + guard 表达，不建第二套状态 |
| 早期 FACADE 11 服务总纲（S1-S11） | 拒绝 / 被 C0-C9 取代 | 当时采用 Codex 单一权威 + correctness-first 方案，并吸收其方法清单；S8 RuntimeStateCodec 被 C3 fork 方案直接取代，当时未新增 runtime codec |

## 2026-08-02 权威核心组合化裁决

本轮没有把“少了几行”当作拆分完成，而是以 owner、写路径、Port 能力和反向依赖作为门禁。当前落地结构为：

```text
YsbzsState（唯一权威字段）
  └─ CoreComposition（每个 State 实例一份）
       ├─ DamageMechanicService       ← DamageMechanicPort v2
       ├─ DamageDeathService          ← DamageDeathPort v1
       ├─ SummonService               ← SummonPort v1
       ├─ UnitLifecycleMechanicService← UnitLifecycleMechanicPort v1
       ├─ ElementMechanicService      ← ElementMechanicPort v1
       └─ RoundLifecycleService       ← RoundLifecyclePort v1
```

伤害生产纵切不另建 `CombatState` 或全局 Hook：`YsbzsState` 用 `DamageResolutionPort v2` 把唯一权威能力交给 `DamageResolver`，resolver 返回瞬态 `ysbzs.damage-result v1`；普通单包立即进入死亡安全点，同一技能、敌方范围行动、品质溅射和机制范围伤害先完成全部 packet / after Hook，再由 `DamageDeathService` 稳定批量结算。`DamageProps` 只改变声明的阶段：行动、技能、追击和反击为 `move`，元素、痕迹、溅射与反伤为 non-move `unpowered`，HP loss 为 `unpowered + unblockable`；block / dodge 只消费可格挡的 move。Props 经 v2 Port 传给 before / after Hook，反伤不得直接写 HP。`skip_hurt_anim` 尚无正式内容生产者，只有真实内容声明它时才同步升级表现 Trace 证据；默认 packet 的 Trace、stateHash、save/replay 字段保持不变。

Service 不保存第二份 `units`、元素层、奖励或运行状态；所有修改都经 Port 写回同一个 `YsbzsState` Dictionary/Array。未知 Port 版本、缺少能力的方法集合都 fail-closed，focused smoke 同时验证无部分写入。

常量与元数据按以下模式归位：

| 类型 | owner | 模式 | 兼容处理 |
|---|---|---|---|
| 内容包与补充目录 | `ContentSourceConfig` | Config | `StateScript.DATA_PATH` 等暂为只读别名 |
| save/replay schema/version | `SaveContract` / `ReplayContract` | Contract | `SaveDocumentBuilder` / facade 装配文档，Repository 只收路径和 bytes |
| save/replay 默认路径 | `PersistenceConfig` | Config | Repository 仍可注入其他路径 |
| 品质词汇/进化点 | `QualityRules` | Rules / Policy | 数值和顺序未变 |
| 元素规范名/alias/结算顺序 | `ElementRules` | Rules | `ElementFieldService` 继续只负责存取 |
| 旧技能显示兜底 | `LegacySkillCatalog` | Catalog | 新技能仍优先来自内容包 |
| 技能形状/槽元素投影 | `SkillShapeRules` | Pure Rules | roster、projection、battle 共用同一实现 |
| 自动站位搜索阈值 | `AutoPositionConfig` | Immutable Config | planner 输入键和值未变 |

冻结探针在各迁移阶段都保持同一个规范化 SHA-256 `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562`，因此 stateHash、save/replay schema/checksum、command checkpoint 和 contentHash 都没有因职责搬家变化。

### 继承链门禁结论

最终切链已完成。live inventory 的硬结论为：

- 旧六层文件与 UID：0；生产源码对旧路径的 preload / extends / load 引用：0。
- 跨层反向依赖：0 methods / 0 calls；机械 ratchet 固定为 `0 / 0`。
- 空虚拟契约：0；单 facade 同名重复实现：0。
- `YsbzsState` 仍只有一个字段集合和一个 `CoreComposition`；Service 不缓存 `units`、`game_data` 或 history 的可写副本。

三个原阻断纵切均已按真实职责收口：battle preview 复用唯一 `DamageResolver`、`AttackOptionService`、`TargetingService` 和品质/元素投影；threat target 由无状态 `ThreatTargetPolicy` 单点决定；persistence identity/history 复用权威 codec/hash、`SaveDocumentBuilder` 与 `RunHistoryCommitter + RunHistoryPort v1`。未引入巨型 Port、第二 hash/history 实现或兼容双轨。

今后重新出现任一旧路径、生产引用、空 contract stub、facade 同名实现或 history committer 绕过 Port，`inventory_core_methods.py` 与结构 smoke 都会 fail closed。文件长度不作为反向恢复继承链或制造转发层的理由。

## 模式使用门槛

### State

只有同时存在“状态身份、合法转移、进入/退出行为或转移历史”时使用。阶段合法性属于 `PhasePolicy`；单次机制触发名不属于 State。

### Strategy / Policy

适用于确定性算法、输入输出明确、可以不持有权威状态的规则。调用方只收集事实、调用策略、应用结果。宠物重置、安全落位、胜负判定和目标优先级属于这类。

### Application Service + Port

适用于必须串联多个权威操作、但自身不应拥有状态的流程。`RoundLifecycleService`、`BattleSession`、双方回合服务和整局自动化通过窄 Port 调用 `YsbzsState`，不得反射完整 core。动态兼容调用只能收口在 Port 适配器内。

### Registry

只有条目拥有独立扩展生命周期、按 ID/类型发现的真实实现，或者需要集中校验重复/缺失注册时使用。命令 handler、脚本插件与品质策略满足条件；仅包装一个 Dictionary 的转发文件不满足。

### Repository

只负责外部存取、路径和原子性；checksum、schema 和权威字段由 codec / document builder / facade 定义，Repository 不执行规则。

## 本轮完成标准

- 每个迁移点都有旧入口到新职责的唯一委托，没有并行实现。
- 每个被删除的抽象都已证明没有稳定生命周期或独立不变量。
- `YsbzsState` 仍是唯一权威；Command、Result、Trace、Snapshot、save/replay schema 不变。
- focused、architecture 和 fast 回归通过。
- 未涉及 Scene、布局、图片和玩家可见表现，因此本轮不制造 UI 视觉差异。
