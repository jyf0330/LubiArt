# 2026-08-03 `game_state.gd` 两套职责收敛方案对比

status: REVIEW_COMPLETE / CODEX_IMPLEMENTED_VERIFIED
reviewer: Codex
baseline: `d94be93b3e6b0f66ca07a2e44f17f22b2ad21904`
codex_implementation_head: `4a93e0e012e2721fd90c312885937751b9ff1a09`
codex_final_audit_commit: `806017dd88ccd0964eef0a55467bcc97cecd9079`
scope: 比较 Codex 已验证实现与 Claude 当前可见规格；不修改 Claude 规格

## 0. 对比对象与冻结口径

Codex 方案：

- `2026-08-03_CODEX_GAME_STATE_RESPONSIBILITY_DESCENT_SPEC.md`
- 578 行，覆盖 live 风险、保留/迁移/拒绝裁决、目标契约、C0～C9 实施顺序、测试与回滚门禁。
- `2026-08-03_CODEX_GAME_STATE_IMPLEMENTATION_PACK.md`
- 1049 行，把总纲补到普通程序员可实施颗粒度：冻结 SHA/checksum、C0～C9 方法处置、目标签名/schema、caller 替换、允许写入、顺序/失败语义、focused tests、提交与回滚均已定义。

Claude 方案当前可见部分：

- `2026-08-03_FACADE_DESCENT_MASTER_SPEC.md`，192 行。
- `2026-08-03_FACADE_DESCENT_B12_QUALITY_POLICY.md`，352 行。
- `2026-08-03_FACADE_DESCENT_B13_BOARD_QUERY.md`，300 行。
- `2026-08-03_FACADE_DESCENT_B4_ROSTER.md`，430 行。
- `2026-08-03_FACADE_DESCENT_B7_SHOP.md`，497 行。

冻结 SHA-256：MASTER `b260fbd4…`、B12 `cbc1173d…`、B13 `7ecbd47c…`、B4 `70ca481e…`、B7 `c09fde41…`。后续若任一文件变化，本报告仍代表上述版本的审查，不把新内容倒算进旧结论。

Claude 总纲列出的 B1、B2/B3、B5、B6、B8、B9、B10、B11 与 composition gate 在本次冻结时尚未落盘，因此本比较对其未出现部分只评价总纲决策，不推测未来细节。若后续文件补齐，应重新审查 Preview、Runtime Codec、Persistence、Battle 和 Operation Log 五个高风险域。

本报告比较的是架构边界、唯一权威、确定性、可回滚性和当前可执行度，不比较写作风格，也不以“谁删的行更多”直接判优。

## 1. 总结结论

两套方案都反对恢复旧继承链，都采用逐切片提交、冻结 hash/checksum、组合根审计和精确暂存；它们的根本分歧是：

- Claude 方案把“写顶层 authority 字段数”作为主分类器，目标是快速把大量方法体移到 11 个新服务，将 facade 约从 8049 行降到 5000 行。
- Codex 方案把“变化原因、事务顺序、允许写入和 I/O 边界”作为主分类器，先修四个现存 correctness 问题，再迁移纯投影与算法，不给 facade 设行数目标。

按本项目“一个权威、Command exactly-once、save/replay 可证明、复用既有 owner”的优先级，**Codex 方案更适合作为实施主线**。Claude 方案的调用图、逐方法清单、冻结基线和切片模板值得直接吸收，但其 `≤3` 字段规则、可变引用下沉、第二 runtime codec、总 PersistenceService、永久转发壳和 Preview/AutoPos 合并不应照搬。

## 2. 核心决策逐项对比

| 维度 | Codex 方案 | Claude 方案 | 裁决 |
|---|---|---|---|
| 拆分依据 | 变化原因、事务边界、依赖方向、可独立测试 | 顶层 authority 写字段数：`≤3` 整体搬，`≥4` 留编排壳 | Codex 更稳；字段数不能代表真实副作用 |
| 唯一权威 | Service 不持有第二状态；纯模块不得写 authority | 声明无 authority 依赖，但 P 层允许接收可变 Array/Dictionary 并直接改 | Claude 的声明和能力边界不一致 |
| 当前 correctness | Snapshot purity、Preview 外部写、临时 codec 漂移、生产 fallback 前置处理 | 总纲先搬 Quality/Board/Roster；上述四项未前置 | Codex 优先级更符合风险大小 |
| 大型有序协调器 | 保留 `_execute_selected_action_option`、`_finish_battle_result`、`start_battle` | `_execute_selected_action_option` 因“写 2 字段”整体迁移到 ActionService | Codex；该方法实际有大量嵌套对象写与机制顺序 |
| Preview | 短命、无 I/O authority fork，复用 canonical codec 和同一 dispatch 路径 | Preview 与 AutoPos 合并进 BattleService；当前总纲未给 source no-I/O sandbox | Codex 边界完整；Claude 需补证据后再评 |
| Runtime capture | 删除手写 capture/restore，复用 `AuthoritativeStateCodec.FIELD_SPECS` | 新增 `runtime_state_codec.gd`，提取第二份字段清单 | Codex；不能扩大字段注册表漂移面 |
| Persistence | 保留 Codec/Builder/Repository/Committer 分责，补 ReplayVerifier | 新增总 `PersistenceService`，同时注入三类 Repository | Codex 更符合已有边界；Claude 更易形成新总层 |
| Auto-position | 复用 Planner/Policy/TurnOptimizer，补纯 Evaluator，ReadPort 改 immutable context | Preview 与 AutoPos 因当前互调合并进 BattleService | Codex；应打破反射回调，不应让当前环决定永久领域 |
| Roster | 复用 `RosterCollectionService` 与 `RosterSlotRules`，保留 acquisition 事务 | B4 新增 `RosterService`，直接接收并修改 authority 的 roster Array | Codex；数组元素与嵌套字典仍是权威写入 |
| Quality | Policy 返回转换结果，由 coordinator 应用 | B12 规格完整，但 Policy 直接修改传入 unit Dictionary | Claude 的算法清单可复用；应用边界采用 Codex |
| Query | 高层 BattleQueryProjector 接受不可变 Context，输出 ViewModel | B13 抽 17 个低层查询，facade 全保留转发壳 | Claude 更容易逐字迁移；Codex 长期边界更干净 |
| Operation Log | 纯 Projector 只组装 entry，Repository append 和事务时序不变 | P 方法返回 `_logs`，facade 延后写日志，并声明为允许的行为外变化 | Codex；延后日志可能改变与 Trace/失败点的相对顺序 |
| 兼容策略 | 稳定 public API 留壳；private/test caller 随 atom 迁移并删除旧入口 | 生产或 tests 引用的方法都保留 1 行壳 | Claude 初期风险低；长期会保留私有兼容层和 518 方法堆积 |
| Composition | 只有逐 State、可替换且有真实 consumer 的能力进 root | 一次新增 11 项，45→56 | Codex 控制依赖图和初始化成本更好 |
| 验证 | 每 atom 跑 P0、ownership、architecture、fast；高风险域加 no-I/O/purity 专项 | 每切片 V1～V6，P0/focused/log 顺序完整；全量收口另跑 | 两者都强；Codex 高风险负面断言更完整 |
| 预期速度 | 前期慢，不承诺行数；每个 correctness atom 可独立回滚 | 搬法机械、切片模板细，行数下降快且可预测 | Claude 在短期整理速度上占优 |

## 3. 为什么“写顶层字段数”不能作为 P/O 主门禁

Claude 总纲把写 `≤3` 个顶层字段的方法归 P 层，并允许把可变 Array/Dictionary 引用交给 Service。这个判定漏掉三类真实写入：

1. 对 authority 数组元素和嵌套 Dictionary 的修改。
2. 通过已有 Port/Service 对 unit、target、cell、trace、history 做的间接写入。
3. I/O、时间、日志、Repository append 等非字段副作用。

`_execute_selected_action_option()` 是最清楚的反例：

- 直接修改 `slot` 和 `attacker`。
- 对多个 target 应用元素、伤害、死亡结算和品质/技能机制。
- 写 Trace、日志、AP、selection，并在末尾触发 battle end。
- 这些操作存在严格先后关系，且目标对象来自 `units` 的可变引用。

它不能因为扫描到的顶层赋值只有 `ap` 和 `selected_action_slot_index` 就被视为近似纯方法。类似地，`_add_pet_to_roster()` 虽然主要只写 `roster`，却执行实例 ID、合成升级、品质、active/bag placement 和 acquisition history 的完整权威事务。

更可靠的分类问题应是：

- 输入是否为不可变值或深拷贝？
- 方法能否在没有 authority、Port 和 Repository 的情况下独立运行？
- 输出是否为 Value/Plan/Delta/Result，而非修改传入的权威引用？
- 所有写入是否仍由一个 coordinator 原子应用？
- 失败时是否能证明没有部分写入和外部泄漏？

任一答案为否，就不能称为纯下沉。

## 4. 当前 live source 暴露、Claude 总纲尚未前置解决的四个问题

### 4.1 Snapshot 读操作会写 roster

`game_state.gd:1994-1995` 的 `snapshot()` 先调用 `_normalize_roster_slots()`；既有 collection service 的 normalize 方法会写数组元素。这破坏“Query 不改变 source authority”。Codex C1 把它列为首批修复；Claude C1/C2 从 Quality 和 BoardQuery 开始，未先封住这条写路径。

### 4.2 Manual flow Preview 会进入真实 dispatch/history

`game_state.gd:3354-3373` 在 source authority 上 capture 后执行真实 `dispatch()`；`_record_dispatch_result()` 会进入 history，`RunHistoryCommitter.record()` 又会 `apply_patch` 并 `append_command`。内存 restore 不能撤销已经写出的 Repository 数据。

因此，“Preview 最后 hash 恢复”不是充分验收。必须同时验证 source 全字段、history metadata、history 目录、operation log、save/replay 文件和 RNG 都不变。Codex 的 no-I/O fork 明确定义了这些负面断言；Claude 尚未出现的 B1 规格必须先证明同等边界，不能只把现有 capture/restore 搬进 BattleService。

### 4.3 手写 runtime capture 已与 canonical codec 漂移

`_capture_runtime_state()` 包含 `reward_fallback_audit`，`_restore_runtime_state()` 没恢复；两者都没有 canonical codec 中参与 hash 的 `defeated_units`。当前 `AuthoritativeStateCodec.FIELD_SPECS` 已是 save/load/history/hash 的权威字段注册表。

新增 `runtime_state_codec.gd` 即便只“提取字段清单”，也会形成第二个需要同步维护的 registry。正确方向是让 simulation fork 使用 canonical codec，最终删除临时 capture/restore。

### 4.4 正式内容为空时静默启用硬编码玩法

`_load_game_data()` 在 content pack 无错误但为空时返回 `_fallback_game_data()`；后者硬编码路线、宠物、敌人、商店和 wave。这不是拆文件问题，而是正式真相源竞争。Codex C3 要求生产 fail closed、fixture 只在显式 demo/test 模式注入。Claude B7 当前把硬编码 `_build_shop()` 搬进新 ShopService，仍然保留这套正式样式 fallback，而没有先消除竞争真相源。

## 5. Claude 方案的明确优点

Claude 方案不是不可用；以下部分比 Codex 方案更接近实现清单，应直接吸收：

1. **方法与调用方枚举细。** B12/B13 给出方法、HEAD 行号、端口/测试引用、迁移后签名，实施者不需要重新猜迁移闭包。
2. **冻结基线明确。** 每切片固定 normalized SHA、save checksum、replay checksum 和 facade 方法计数，便于发现无意漂移。
3. **切片接线完整。** 新服务、CoreComposition、ownership smoke、inventory 和提交被放进同一原子切片，不留半接线状态。
4. **兼容迁移阻力小。** 先保留 facade 壳可减少一次性修改大量动态 caller 的风险，适合短期过渡。
5. **对调用环做了实际审计。** 总纲不是按文件名猜域，而是统计了跨域调用；这个输入证据有价值。
6. **B12/B13 已达到 copy-level。** 对首两个切片，代码结构和替换点比 Codex 总体规格更具体。

这些优点应该变成 Codex 实施任务的“方法/调用方 inventory、冻结值、每 atom 接线模板”，而不是连同 Claude 的 P/O 判定一起采用。

## 6. Claude 方案的具体风险与内部不一致

### 6.1 “现有服务全部纯计算”的前提不成立

总纲把 `run_history_committer` 与 policy/builder 一起描述为“全部纯计算”。live source 中它会：

- `port.apply_patch(...)` 修改 history identity/index。
- 调用 Repository `append_command()`。
- 使用系统时间创建 run identity。

它可以不持有 authority，但不能称为纯计算。由此推导“无 authority 依赖 = 纯”的分类前提需要修正。

### 6.2 Composition 数量在同一总纲内矛盾

live `CoreComposition.services()` 当前有 45 项。总纲一处写 45→56，另一处写 33→44，完成态再次写 33→44。实现/验收若按不同数字执行会产生假失败或漏项，必须统一为 live count。

### 6.3 B7 已经打破 MASTER 自己的 P/O 阈值

MASTER 规定写 `≥4` 个顶层字段属于 O 层；B7 实测 `_shop_offers_for_pool` 写 4 个字段，却仍按 P 层处理，做法是把这些字段装进一个可变 `shop_state` Dictionary。这样分类结果取决于参数包装形态，而不是副作用本身：把任意数量字段塞进一个 Dictionary，就能让 O 层重新变成 P 层。

这说明 `≤3/≥4` 不是可执行架构不变量。Shop roll、seen set、seed audit、discount 和 RNG counter 应返回显式 `ShopRollResult/Delta`，由 facade 在一个事务里校验并应用，而不是借一个可变总包绕过写入门禁。

### 6.4 可变引用绕过了 authority 写审计

P 层允许接收可变 Array/Dictionary；Service 即使没有 `_authority` 字段，仍能直接修改 authority 所持有的对象。ownership scanner 只能证明没有显式 authority reference，不能证明没有权威写入。

B12 的 `apply_quality_progression(unit, game_data, ...)` 原地写 `unit`；B4 的 RosterService 原地写 `roster`；B7 的 ShopService 原地写 `shop_state` 内的 Array/Dictionary。这已经从总纲风险变成三个已落盘切片的一致实现策略。建议统一改为接收深拷贝并返回 Result/Delta，由 authority coordinator 在通过校验后一次应用。

### 6.5 Permanent forwarding shell 会保留 facade API 堆积

B13 连 4 个内部独属辅助也保留壳，阶段性确实安全，但必须有“哪一个后续切片删除哪一个壳”的清单。否则 8049 行变短了，518 个方法和 private test coupling 仍长期存在，调用链还多一跳。

### 6.6 Opaque Callable 延续动态反射边界

总纲让 PersistenceService 接收 `_state_hash` Callable；B13 计划让 BattleService 接收 `_preview_resolved_damage` Callable。这使服务通过不透明函数继续反向调用 facade，静态 capability audit 难以证明依赖方向。

若必须回调，应使用版本化窄 Port，并列出 `contract_id`、`REQUIRED_METHODS`、输入/输出和 fail-closed 语义；对纯查询更优的做法是构造 immutable context 后一次传入。

### 6.7 Log 延后写是协议变化，不应默认视为允许

P 方法把原地 `_log` 改成返回 `_logs`，由 facade 最后统一写。文本顺序快照只能证明日志之间的相对顺序，不能证明它与 Trace、错误退出、死亡 safe point、Repository 写入之间的时序相同。应逐方法显式判断，而不是作为整个 P 层的统一规则。

## 7. Codex 方案的明确优点

1. **先解决真实 correctness，再整理文件。** 四个高风险问题有 live evidence、失败语义和专项测试。
2. **纯与写边界可证明。** Policy/Projector 输入为副本或 immutable context，返回 Result/Plan/Delta，由 authority 原子应用。
3. **复用现有 owner。** 不重复建立 Roster、AutoPosition、Runtime Codec 和 Persistence 总层。
4. **保留必要复杂度。** 大型有序 coordinator 可以留在 facade，只迁其纯子计算，不把机制时序隐藏到远端服务。
5. **Preview/Replay 共用隔离能力。** SimulationAuthorityFactory 解决 source rollback 和 I/O 泄漏，而非扩大 capture/restore。
6. **每个 atom 有准入字段。** source、owner、inputs、outputs、allowed writes、ordering、failure、callers、old path removal、tests 和 frozen contracts 都必须填写。
7. **回滚边界更窄。** 每个 correctness/query/evaluator atom 都能独立回退，不需要把 11 个服务连锁撤销。

## 8. Codex 方案的代价与不足

1. **短期行数下降较慢。** Snapshot、Preview、content fail-closed 等工作会先增加边界代码和测试，不能迅速展示 8049→5000。
2. **实施稿维护成本高。** 1049 行实施包已补齐逐方法和逐 atom 契约，但 live source、Port 或并发 owner 变化后必须按指纹重基线，不能长期把行号当成真相。
3. **Simulation seam 实现难。** 需要显式 content pack、no-I/O capabilities、canonical restore 和同一 dispatch path，首个 atom 比“搬方法体”复杂。
4. **保留大 coordinator。** 这降低状态风险，但 `_execute_selected_action_option`、`start_battle` 等仍需要后续按纯子块持续瘦身。
5. **不承诺最终行数。** 管理上不如 Claude 的约 5000 行目标直观，需要用职责门禁和依赖审计解释成果。
6. **BattleQueryProjector 范围偏大。** 实施时要按 action preview、threat、board/detail 分 atom，避免出现新的 500～700 行查询总层。

## 9. 推荐合并法

以 Codex 的职责边界和实施顺序为主，吸收 Claude 的证据与交付颗粒度：

### 保留 Codex 决策

- C1 Snapshot purity、C2 production fail-closed、C3 no-I/O Preview 前置。
- canonical codec 单注册表。
- 有序 coordinator 留 authority。
- 纯模块不接收 authority 持有的可变引用。
- 复用现有 Roster/AutoPosition/Persistence owner。
- public API 稳定，private 壳必须有删除提交。

### 吸收 Claude 做法

- 每个 atom 的原方法行号、直接/动态/Port/test caller 清单。
- 每个切片冻结 normalized SHA、save checksum、replay checksum、Snapshot/Trace golden。
- 同一提交完成 service、composition、ownership smoke、inventory 和旧入口删除。
- B12 的品质算法闭包清单，但输出改为 Result/副本。
- B13 的查询调用方矩阵，但只保留真正的 public/Port 兼容壳，并为其标注删除阶段。

### 明确拒绝

- `≤3` 顶层字段即 P 层。
- Service 直接修改传入的 authority Array/Dictionary。
- 第二 `RuntimeStateCodec` 字段注册表。
- 总 `PersistenceService` 覆盖已有 Builder/Repository/Committer。
- 因现有互调把 Preview、AutoPos、行动配置永久合并为 BattleService。
- 把 `Callable(self, "...")` 当成常规依赖注入。
- 不带删除日期的永久 facade private 转发壳。

## 10. 最终实施排序

推荐顺序如下：

1. 完成 Claude 已声明的死代码清理，但重新验证 dynamic/Port/lifecycle caller。
2. 修 Snapshot purity，并建立 repeated query 不变测试。
3. 正式内容 fail closed，建立可注入 constructor seam，fallback 移出 production。
4. 建 SimulationAuthorityFactory，修 Preview 外部写泄漏。
5. 采用 Claude B12 的方法 inventory，实现 Codex 式 QualityProgressionResult。
6. 采用 Claude B13 的 caller inventory，按 Codex immutable context 分批迁 query。
7. 收紧 AutoPositionReadPort，补纯 evaluator，保留原子 executor。
8. 迁 Operation Log projector，但不改变 append 时点。
9. 补 ReplayBuilder/ReplayVerifier，并复用 simulation fork。
10. 重扫剩余大方法；只有出现第二变化原因时再拆有序 coordinator。

## 11. 最终裁决

如果目标是“尽快把 8049 行降下来、外部 caller 尽量不动”，Claude 方案的机械搬迁路线仍更快。

如果目标是“长期只有一个权威、Preview/Save/Replay 不泄漏、已有服务不重复、未来能证明每条写路径”，Codex 方案更安全；补充实施包后，它也已达到普通程序员不需重新做架构裁决的实施颗粒度。

本项目的硬规则属于第二类，所以建议：

> **Codex 方案作为主架构；Claude 方案作为方法清单、调用图、冻结基线和切片交付模板。**

在 Claude 的 B1、B5/B6、B8～B11 尚未落盘且 Preview no-I/O、canonical codec 单注册表、可变引用写入三项未修正前，不建议直接按其 MASTER 继续大规模迁移。

## 12. 实装后的最终对比（2026-08-03）

### 12.1 比较状态已经变化

前 11 节冻结的是“规划对规划”。现在 Codex C0-C9 已实际落盘并通过完成门禁，而 Claude 当前可见内容仍是规格和并行 WIP；因此最终比较必须区分“设计质量”和“已经证明的运行结果”。

Codex 实装结果：

- `game_state.gd` 8049→6096 行，518→416 methods；不是按目标行数裁切，而是删除 102 个不再需要的 facade 方法。
- `CoreComposition` 45→53 services，53 项均有 direct 或 injected consumer。
- Snapshot purity、production content fail-closed、no-I/O Preview、canonical codec 单注册表四项 correctness 风险全部处理。
- P0/save/replay 与六份 Battle Query hash 均不变；20/20 关键测试和正式 fast 15/15 通过。
- 每个 atom 有独立实现/归档提交，旧路径清理和回滚边界可追溯。

### 12.2 Claude 当前可见规格的完整度

本次最终复核只读了下列当前文件，没有修改或暂存它们：

| 文件 | 行数 | SHA-256 前缀 | 状态判断 |
|---|---:|---|---|
| `FACADE_BIG_METHOD_DESCENT_SPEC` | 109 | `9bdf03b3` | 方向总览 |
| `FACADE_DEAD_CODE_CLEANUP_SPEC` | 106 | `ac93b46a` | 可执行的浅清理输入 |
| `FACADE_DESCENT_MASTER_SPEC` | 192 | `b260fbd4` | 总体切片地图 |
| `FACADE_DESCENT_B12_QUALITY_POLICY` | 352 | `cbc1173d` | 细化 atom |
| `FACADE_DESCENT_B13_BOARD_QUERY` | 300 | `7ecbd47c` | 细化 atom |
| `FACADE_DESCENT_B4_ROSTER` | 430 | `70ca481e` | 细化 atom |
| `FACADE_DESCENT_B6_RUNFLOW` | 521 | `e0bea84e` | 细化 atom |
| `FACADE_DESCENT_B7_SHOP` | 502 | `033b5b6a` | 细化 atom |
| `FACADE_DESCENT_STS2_RULING_AND_PRIORITY` | 179 | `424f3330` | 新裁决/优先级 |

Claude 新增的 STS2 裁决稿是实质改进：它开始用职责和耦合证据，而不是只看行数；修正了 Board Query 的 damage-preview 回传问题和 RunFlow 的协调器边界，并明确保留高耦合 coordinator。它的方法清单、caller 证据、目标签名、冻结值和迁移接线仍是这套规格最强的部分。

但当前仍缺 B1、B2/B3、B5、B8、B9、B10、B11 与 composition gate 的完整落盘规格。按“source/disposition、准确签名/schema/default、全 caller、生命周期、顺序/原子性、失败/回滚、冲突、测试、完成条件”门禁，它只能标 `ARCHITECTURE_READY`，不能标 `IMPLEMENTATION_READY`。

### 12.3 另一方案仍未解决的具体风险

| 风险 | 当前规格证据 | 为什么仍不能直接实施 |
|---|---|---|
| 可变 `ctx` 写 authority | B6 明列 `units`、`battle_prep_effects`、`outer_run_effects` 为“原地可变” | Service 没有 `_authority` 字段不代表没有权威写能力；部分失败和原子提交无法静态证明 |
| 可变 `shop_state` 总包 | B7 把 4 个字段和多个 Array/Dictionary 装进一个可变 Dictionary | 这是绕过字段数门禁，不是建立显式 `ShopRollResult/Delta` |
| 第二 runtime registry | MASTER/C9 仍计划 `RuntimeStateCodec` | 与已存在的 `AuthoritativeStateCodec.FIELD_SPECS` 形成字段漂移面 |
| 总 PersistenceService | MASTER/C10 计划同时接入 save/replay/history repositories | 会重新聚合已分开的 Builder/Verifier/Repository/Committer 变化原因 |
| 动态反向依赖 | B13/C7 计划注入 `Callable(facade, "_preview_resolved_damage")` | capability 无版本、无 REQUIRED_METHODS，依赖方向和 fail-closed 难以审计 |
| 长期边界已过时 | STS2 裁决仍把 `_fallback_game_data`、`_restore_runtime_state` 列为 facade 长期责任 | Codex 实装已证明二者可删除且应删除；继续保留会恢复双真相源/第二字段清单 |
| 永久 adapter/private 壳 | B4/B6/B7/B13 大量保留 facade 壳 | 短期迁移安全，但没有逐壳删除 atom 会保留方法堆积和 private test coupling |

### 12.4 双方利弊的最终裁决

| 维度 | Codex 已实施方案 | Claude 当前规格 | 最终裁决 |
|---|---|---|---|
| 普通程序员可实施性 | C0-C9 owner/schema/caller/order/failure/test/rollback 已经实际走通 | 已落盘 B4/B6/B7/B12/B13 很细，但全切片不完整 | Codex 已被实施事实验证 |
| 唯一权威 | immutable context/value result + authority 原子应用 | 多处 mutable Array/Dictionary 传入 Service | Codex |
| correctness 优先级 | 先修 Snapshot/Preview/codec/fallback | 新裁决承认部分问题，但总纲/长期边界仍残留 | Codex |
| 迁移速度与易读清单 | atom 较多、前期成本高 | 方法表和机械接线更快、更直观 | Claude 有优势 |
| 协调器判断 | 保留严格时序，迁纯子块 | 新裁决稿已明显修正早期“整体搬”倾向 | 接近；Codex 已有运行证据 |
| 长期依赖图 | 复用既有 owner，新增 8 项并证明 consumer | 仍规划 RuntimeStateCodec、PersistenceService 和 facade Callable | Codex |
| 可验证结果 | 20/20 + fast 15/15 + frozen hashes | 尚未实施，无同等结果 | Codex |

Codex 方案的现实代价也已得到验证：实施 atom 多、需要 clean import 和较长回归时间；保留的 6096 行仍包含大型有序 coordinator，未来优化必须继续找纯子块，不能宣称 facade 已经“小而简单”。这些是可见成本，不影响其边界正确性。

### 12.5 最终采用建议

> **以 Codex 已验证实现作为新的 live baseline；Claude 文件只作为方法 inventory、caller 证据和下一轮评审输入。**

若要继续采用 Claude 的后续切片，必须先对 6096 行/416 methods/53 services 的当前源码 `REBASE_REQUIRED`，删除已完成或已过时的迁移项，并补齐缺失 B 规格与 composition gate；同时把 mutable context 改为 immutable input + explicit Result/Delta，取消第二 RuntimeStateCodec、总 PersistenceService 和 facade Callable 反向依赖。未完成这些修正前，不应把其 8049 行时期计划直接应用到当前实现。
