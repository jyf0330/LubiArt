# 外部框架采用决策

> 本文保留历史技术判断和当前实现背景，不是 AI 必须遵循的工作流。后续可以根据 live source、实际目标和验证结果自由重新评估。

- 状态：已采纳
- 决策日期：2026-07-23
- 适用项目：《纸上西游》Godot 客户端与本地规则核心
- 复审时机：见“重新评估条件”

## 结论

保留当前 `YsbzsState` 六层规则核心，不用 `godot-tactical-rpg`、Comedot、GodotGAS、Forge Gameplay System 或纯 ECS 替换现有底座。

短期采用原则：

1. 当前棋盘、回合、行动块、元素反应、AI、命令、投影、存档和回放继续由项目自身核心负责。
2. `godot_core_system` 只作为通用 Godot 基础设施的参考或可选模块来源，不整体接管项目。
3. `godot-tactical-rpg` 只参考局部实现，不作为可直接接入的战棋框架。
4. GodotGAS 仅在技能与状态效果复杂度达到明确门槛后做隔离验证，不预先迁移现有元素规则。
5. Forge Gameplay System 与 GodotGAS 二选一；当前项目是 GDScript，因此暂不引入 Forge 的 C#/.NET 边界。
6. 不进行全量 ECS 重写，也不在已有核心之上叠加 Comedot。

## 当前项目事实

本项目已经不是早期的 JS 规则内核加 Godot 表现壳。当前运行时规则已经迁入原生 GDScript，并形成稳定的单向继承链：

```text
YsbzsState facade
  -> persistence core
    -> run flow core
      -> battle rules core
        -> command projection core
          -> catalog roster core
            -> state base
```

各层职责以 [03_CORE_ARCHITECTURE.md](03_CORE_ARCHITECTURE.md) 为准。当前关键资产包括：

- `YsbzsState` 稳定公共入口；
- 命令协议与 snapshot/ViewModel 边界；
- 可配置棋盘和完整战斗生命周期；
- 行动槽、攻击形状、元素、品质和伤害规则；
- 自动布置与敌方行动规划；
- `stateVersion`、状态哈希、存档、回放和战斗 trace；
- 表格到 CSV、再到 Godot JSON 的策划数据真相源链路。

因此，“保留 UI 和行动块，再用通用战棋模板替换棋盘、回合和 AI”不是低成本接入，而是改写现有核心的状态模型、调用边界和规则执行顺序。

## 框架对比与决定

| 方案 | 实际定位 | 与现有核心的重叠 | 决定 |
|---|---|---:|---|
| 当前自研核心 | 《纸上西游》专用、命令驱动的确定性规则核心 | 基准 | 保留并继续收窄模块 |
| `godot_core_system` | 状态机、事件、输入、存档、场景、音频、资源、日志、Tag、Trigger 等通用服务 | 中 | 选择性参考或引入无重叠模块 |
| `godot-tactical-rpg` | Godot 战棋示例/项目模板，不是即插即用插件 | 高 | 只参考镜头、网格或编辑器组织方式 |
| GodotGAS | GDScript 的 Ability/Attribute/Effect/Tag 基础设施 | 高 | 暂不引入；满足门槛后做垂直验证 |
| Forge Gameplay System | C#/.NET 的 GAS 风格框架 | 高 | 当前不采用 |
| Comedot | 基于普通 Godot Node 的组件库与项目模板 | 高 | 不叠加整套；确有独立需求时只摘取无状态工具 |
| 纯 ECS | 数据导向实体/组件/系统架构 | 极高 | 不做全量迁移；BattleWorld 一期已冻结为隔离参考，不接正式写路径 |

## `godot_core_system` 与我们的区别

两者处在不同层级。

`godot_core_system` 主要处理引擎级、跨游戏通用能力：

- 输入与输入缓冲；
- 场景切换；
- 音频与资源管理；
- 日志；
- 序列化和存档工具；
- 通用状态机、事件总线、Tag 和 Trigger。

本项目核心主要处理《纸上西游》的领域规则：

- 棋盘状态和单位占位；
- 命令合法性与版本边界；
- 回合推进和双方行动；
- 行动槽、攻击形状与 AP；
- 格子元素层、元素包和元素反应；
- 品质效果、伤害、护盾与死亡；
- 自动布置、敌方规划与预览；
- 规则快照、回放和兼容存档。

所以 `godot_core_system` 不能替代战斗核心，但其中无业务状态的输入、音频、日志或资源工具可能有复用价值。

### 可采用边界

采用某个 `godot_core_system` 模块前必须满足：

- 不改变 `YsbzsState` 的权威状态归属；
- 不绕过 command 和 snapshot/ViewModel 边界；
- 不建立第二套存档、Tag、Trigger 或状态机真相源；
- 模块可以单独移除，不影响战斗规则结果；
- 先用一个独立调用点验证收益，再决定是否扩大使用。

优先候选是日志、音频、输入辅助和无状态资源工具。存档、Tag、Trigger、事件总线和状态机与现有能力更容易重叠，默认不接。

## 为什么不采用 `godot-tactical-rpg` 作为底座

该项目官方定位是简单战棋模板/演示，不是完整专业框架。它提供回合、网格移动、单位移动/攻击和基础 AI，但这些名称相同的功能并不等于规则兼容。

本项目的移动、攻击和 AI 依赖：

- 可配置棋盘尺寸和出生区；
- 四宠协同站位；
- AP 与行动槽；
- 多格攻击形状和方向；
- 格子元素与元素反应；
- 击杀、伤害、生存和接近等组合评分；
- 命令响应、预览、trace 和回放一致性。

替换底座会同时影响战斗状态 schema、预览、UI 投影、AI、存档和回放，不能按“删除 40%～60% 基础代码”估算。

允许借鉴的内容应保持局部，例如镜头控制、网格坐标工具或编辑器组织方式；借鉴前仍需证明它比现有实现更简单，并通过核心 I/O 与存档兼容验证。

## GodotGAS 的正确位置

GodotGAS 可以减少下列通用基础设施的重复实现：

- Attribute；
- Gameplay Tag；
- 有持续时间或层数的 Effect；
- 冷却和消耗；
- Ability 的授予、激活和结束生命周期。

它不会自动实现具体技能，也不能直接取代本项目的格子元素反应。推荐的概念边界是：

| 现有概念 | 若采用 GAS 时的候选映射 |
|---|---|
| 生命、攻击、护盾、AP | Attribute |
| 燃烧、潮湿、免疫等单位状态 | Gameplay Tag |
| 数值增减、持续伤害、冷却 | Gameplay Effect |
| 主动技能的授予与激活 | Ability |
| 格子元素层、扩散、催化、爆炸、陷阱 | 保留项目专用 Reaction Resolver |

在决定采用前，必须以一个隔离分支或实验目录完成垂直验证：一个角色、一个行动槽、一个持续 Buff、火水反应、存档恢复和一条可回放命令。只有代码量、调试能力和规则确定性均优于现有实现才允许继续。

## 为什么不叠加 Comedot 或全量纯 ECS

Comedot 是 Godot Node 组件化模板，不是 LeoECS 风格的纯数据 ECS。它在 stats、abilities、combat、inventory 等方面与本项目和 GAS 都会形成职责重叠。

在已存在稳定命令协议、权威状态和六层业务核心的情况下，引入第二套组件生命周期会产生：

- 同一属性的多个真相源；
- Node 生命周期与规则状态生命周期不一致；
- 存档和回放需要额外序列化桥接；
- UI 不清楚应读取核心 snapshot 还是组件节点；
- 联机时更难保证确定性执行。

纯 ECS 全量迁移的代价更高，等同于重写状态、技能、AI、存档、回放和 UI 投影，因此仍不考虑整体替换。项目曾用战斗限定的 `BattleWorld` 验证稳定 EntityId、分列组件存储、显式 System 读写集合和确定性 Schedule；该验证只保留 Command/Snapshot/Trace 外壳下的隔离实验，不代表当前采用方向。

2026-07-29 曾批准第一段“伤害 -> 死亡”纵切，只处理完成护卫、机制与防御修正后的伤害包；路线、商店、背包、存档、UI 和 Godot Scene 未进入 BattleWorld。该实验没有接管正式生产写入口，也没有改变 GameSession、命令响应、Snapshot、Trace 或策划数据真相源。

2026-08-01 复审结论是**冻结纵切、保留参考，不继续迁入正式写路径**。现有等价 smoke 能证明生命、护盾、回合受伤、伤害/死亡事件顺序和显式 write-back 与旧 `DamageResolver` 一致，fast QA 也恢复为 9/9；但 live source 中 BattleWorld 仍只有专项测试和文档调用，没有生产命令调用方，也没有基准证明性能或维护清晰度优于现有路径。继续扩展 Position、Targeting、Element 或 ActionIntent 只会先增加第二条计算路径，而不会封闭旧入口。

若重新评估迁移，可以重点检查：明确的生产写入口、同输入等价测试、stateHash/save/replay 漂移、可复现的性能或维护收益，以及接管后是否能删除旧写入口。当前 `core/battle/world/**` 仍只是隔离实验和架构参考，尚未由 CoreComposition 或正式 Session 注册。

## 联机架构约束

未来联机不以任何外部 Gameplay Ability 框架自动解决。无论是否采用 GAS，都必须保持：

```text
Player Input
  -> Versioned Command
    -> Authoritative Rule Execution
      -> State Hash / Event Trace
        -> Snapshot or Delta Projection
          -> Godot Presentation
```

以下内容必须继续由项目掌控：

- 命令 ID、玩家和单位控制权；
- `stateVersion` 与冲突拒绝；
- 可复现 RNG；
- 权威状态哈希；
- 断线重连所需 snapshot；
- 回放和版本迁移；
- 规则层与动画层分离。

框架如果不能在此边界内运行，就不应进入权威规则核心。

## 推荐目标架构

```text
Godot UI / Scene / Animation / Audio
  -> command + readonly query
YsbzsState facade
  -> persistence / flow / battle / projection / catalog / state
  -> project-owned effect hooks and reaction resolver
  -> table-exported game data

Optional isolated utilities
  -> input / audio / logging / resource helpers
```

核心原则是“一个权威状态、一个命令入口、一条数据真相源链路”。外部库只能补充边缘能力，不能建立平行核心。

## 重新评估条件

只有满足下列至少一项，才重新评估 GodotGAS、Comedot 或 ECS：

- 可交互技能超过约 100 个，且大多数共享冷却、消耗、Tag、叠层和持续时间语义；
- Buff/Debuff 数量超过约 50 个，现有 effect hooks 出现大量重复生命周期代码；
- 规则需求频繁组合，新增角色主要时间消耗在通用 Effect 基建而不是具体玩法；
- 性能分析证明现有状态结构是主要瓶颈，并且局部缓存、索引或纯模块拆分无法解决；
- 联机权威执行已经稳定，有能力验证第三方框架的确定性和版本兼容性。

数字是启动评估的信号，不是自动迁移命令。重评仍需先做垂直验证和迁移成本估算。

## 禁止事项

- 不同时引入 GodotGAS 和 Forge。
- 不让 Comedot 与 GAS 同时管理 Attribute、Buff 或 Ability。
- 不让 UI 直接改规则组件或绕过 command。
- 不把格子元素反应全部强行编码成单位 Gameplay Effect。
- 不因模板已有同名功能就替换经过验证的现有实现。
- 不在没有 benchmark、兼容测试和回滚方案时进行 ECS 重写。

## 后续行动

当前无需安装上述框架。后续架构工作优先级为：

1. 继续保持六层核心文件边界，避免业务重新堆回 facade。
2. 把新增 Buff、品质和元素机制接入项目自己的统一 effect hook，而不是新增散落分支。
3. 为未来联机继续维护命令、版本、哈希、RNG、snapshot 和回放兼容门禁。
4. 遇到明确通用基础设施需求时，对 `godot_core_system` 单模块做收益验证。
5. 达到重评条件后，再对 GodotGAS 做最小垂直验证。

## 外部参考

- [LiGameAcademy/godot_core_system](https://github.com/LiGameAcademy/godot_core_system)
- [ramaureirac/godot-tactical-rpg](https://github.com/ramaureirac/godot-tactical-rpg)
- [Godot Tactical RPG 架构说明](https://github.com/ramaureirac/godot-tactical-rpg/wiki/0.a.-Detailed-Project-Architecture)
- [InvadingOctopus/comedot](https://github.com/InvadingOctopus/comedot)
- [yulrun/godot-gas](https://github.com/yulrun/godot-gas)
- [GodotGAS 文档](https://www.yulrun.dev/GodotGAS/)
- [gamesmiths-guild/forge-godot](https://github.com/gamesmiths-guild/forge-godot)

外部框架版本、维护状态和网络能力会变化。真正准备采用时必须重新核对官方仓库，不能只依赖本决策日期时的状态。
