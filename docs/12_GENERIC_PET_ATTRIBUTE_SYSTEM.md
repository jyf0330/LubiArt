# 通用宠物属性、状态与效果系统

## 目标

本系统用数据驱动的 Type Object + Strategy + Registry 组合承载几十种乃至继续扩展的宠物属性。属性、状态、技能、特性和组合仍由唯一 `YsbzsState.units[]` 保存权威实例；服务均由每个 State 自己的 `CoreComposition` 创建，不使用 Autoload，也不复制第二份最终属性状态。

## 数据真相链

推荐的完整同步链是：

`ysbzs_master.xlsx -> data:export -> 39_stat_catalog.csv / 40_status_catalog.csv -> export_ysbzs_singleplayer_data.py -> data/content/**`

Godot 内容包允许先行生成或修改，并作为当前 checkout 的运行数据；未同步总表 / CSV 时记录 `DATA_SYNC_PENDING`，由用户后续手动同步，不阻塞实现、测试或提交。只有用户明确要求本轮全链同步时，上述链路才是强制范围。

- `stat_catalog` 定义属性 ID、默认值、上下界、显示单位和叠加规则。
- `status_catalog` 定义叠层上限、持续策略和通用效果数组。
- 技能、组合与特性只引用属性 ID、状态 ID 和白名单效果类型。
- 宠物的 `base_stats` 是基础输入；旧的 `atk`、`def`、`max_hp` 等字段在迁移期仍是兼容投影。

## 运行时模型

最终值不落盘，由 `StatResolver` 每次确定性计算：

`base -> flat_add -> percent_add -> multiplier -> override -> clamp_min/max -> catalog clamp`

修改器按 `phase -> priority -> source_id -> instance_id` 稳定排序。推荐 phase 为 `permanent / equipment / trait / status / runtime / final`。倍率统一使用整数千分比，避免浮点回放漂移。

单位可以保存：

- `permanent_modifiers[]`：永久成长来源；已经同步进旧基础字段的记录必须标记 `materialized: true`，防止重复计算。
- `equipment_modifiers[]`：装备提供的属性变化。
- `runtime_modifiers[]`：战斗中通用效果添加的变化。
- `statuses[]`：仅保存 `status_id / stacks / remaining_rounds / source_id / applied_seq`，实际效果由目录解析。

## 效果与条件安全边界

`EffectInterpreter` 仅分派仓库内 `core/effects/handlers/` 自动发现的效果 Handler。数据只能选择已注册的 `effect_id`，不能填写脚本路径或任意方法名。目标选择器位于 `core/effects/targets/`，效果与目标扩展均按稳定文件名发现。

`ConditionEvaluator` 自身只保留 all/any/not 组合语义；叶子条件从 `core/effects/conditions/` 自动发现。当前支持 hook/source、阵营、标签、元素、生命比例、回合、技能标签、属性比较和已由权威随机源给出的千分比点数。未知条件一律为 false。

属性运算从 `core/stats/operations/` 自动发现，并按每个 Handler 声明的 `order()` 执行。中央解析器不再持有具体 operation 分支。

属性的玩法语义从 `core/stats/consumers/` 自动发现。每个 Consumer 声明唯一 `plugin_id()`、事件 `event_id()`、稳定 `order()`、实际消费的 `consumed_stats()`，并只转换显式上下文。伤害、行动顺序、治疗、状态命中与持续、技能冷却、召唤倍率、行动费用和移动费用都通过这一管线；目录默认值是中性值，因此旧内容结果不变。重复 `plugin_id` 会使整个目录注册失败并暴露验证错误，不会静默选择其中一个文件。

## 技能、特性与组合

- 宠物最多 8 个技能的行动条顺序仍由 `skills[]` 保存；技能执行器按队列逐个执行效果数组。
- 特性输出统一 `modifiers[]` 与 `trigger_effects[]`；旧的物理倍率和元素层数字段只保留为迁移兼容投影。
- 组合执行基础设施仍与普通技能共用效果解释器、属性解析器和效果端口，但当前隐式技能标签组合已全局禁用。后续如重新启用组合，规则和玩家文案必须直接使用“左边/右边/前面/后面”等空间语言，并在规则本身显式验证对应位置，不使用难以理解的抽象连携名称替代触发条件。
- 伤害解析器通过注入的 `stat_value` 读取攻击、防御、穿甲、全局减伤、物理/元素减伤和九种元素抗性，并通过属性语义管线统一处理元素增伤、Boss 增伤、暴击、闪避、格挡与吸血；预览、AI 评分和权威结算共用同一最终值算法。
- `ModifierCollector` 是 permanent/equipment/trait/status/runtime 的唯一汇聚入口；`StatQueryService` 是普通攻击、移动、攻击次数、技能、治疗和 Snapshot 的唯一最终属性查询入口。
- `BattleHookPipeline` 统一 `round_start / round_end / skill / combo / before_* / after_*` 触发效果，玩家与敌方都走相同的回合开始 Hook 和回合结束过期推进，仍通过当前 State 的显式效果 Port 修改权威 `units[]`。
- `CoreComposition` 只创建一个 `ConditionEvaluator`，并注入 Effect、Trait、Status 与 Stat 服务；覆盖组合根时不会出现各服务判定规则不一致。
- 技能可选 `cooldown_ticks`；最终冷却由 `cooldown_rate_permille` 计算并保存在单位的 `skill_cooldowns`，每次该阵营 `round_start` 确定性推进。未配置冷却的技能仍可每回合按行动条触发。

## 可观测性

Snapshot 同时提供 snake_case 和现有 camelCase 兼容字段：`statCatalog`、`statusCatalog`、`selectedResolvedStats`、`selectedStatBreakdown`、`selectedStatuses`；棋盘占用格也投影同一份 `resolvedStats`。稳定 Snapshot 使用 `state_version + unit_id` 作为安全缓存代次；战斗中即时查询不缓存，避免同一命令内变更读到旧值。

所有成功的权威 Effect（包括伤害、铺元素、治疗、护盾、状态和属性修改）统一写 `EFFECT_APPLIED`。条件为 false 或没有实际目标时不写效果 Trace；`TRAIT_TRIGGERED` 只在当前技能真正消费了该特性修改器或执行了该特性的触发效果后写入，不能仅凭宠物持有特性就记录。

## 扩展方式

新增仅用于显示、存储或通用修改的普通属性时，只在总表属性目录增加一行并在效果 JSON 中引用新 ID；无需增加新的宠物子类或 Manager。新增会改变某类玩法决策的属性时，再新增一个 `core/stats/consumers/<id>_consumer.gd`，无需修改中央映射。

- 新效果语义：只新增 `core/effects/handlers/<id>_effect.gd`；优先组合现有效果 Port 原语。
- 新叶子条件：只新增 `core/effects/conditions/<id>_condition.gd`。
- 新属性运算：只新增 `core/stats/operations/<id>_operation.gd`，声明稳定顺序与整数运算。
- 新属性玩法语义：只新增 `core/stats/consumers/<id>_consumer.gd`，声明事件、消费属性和稳定顺序。
- 新目标选择：只新增 `core/effects/targets/<id>_target.gd`。
- 只有增加全新的权威能力原语或修改存档/命令协议时，才允许改多个基础文件。

未知状态定义在读旧存档时保留为 `orphaned` 状态实例，不参与效果计算；这样跨内容版本不会静默丢失原始状态记录。
