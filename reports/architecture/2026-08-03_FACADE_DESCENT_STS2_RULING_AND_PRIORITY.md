# 2026-08-03 Facade 下沉 — 总体设计裁决与优先顺序（总纲增补）

author: Claude（架构师）
status: ARCHITECTURE_READY（总纲级）
基准: `HEAD`（`d94be93`）+ `2026-08-03_FACADE_DESCENT_MASTER_SPEC.md` + `2026-08-03_FACADE_DEAD_CODE_CLEANUP_SPEC.md`
兼容标准: `.claude/skills/godot-latest-sts2-adoption` + `docs/15_STS2_GUIDED_ARCHITECTURE_MAP.md`

## 0. 职责边界（本次裁定）

- **本文档（架构师）**：整体设计 = 统一裁决标准、全计划裁决表、修正明细、优先顺序、长期边界。**不含实现代码。**
- **实施者（Codex）**：依据本文逐切片产出实施规格（实施包，含 GDScript 代码块）+ 实现 + V1-V6 验证 + 精确暂存提交。
- 既有 C1-C5 域规格（含代码块）作为实施包沿用；与本文冲突处以本文为准（冲突点见 §3）。

## 1. 统一裁决标准（真实职责 vs 机械减行）

**一句话判据：一个方法/方法族下沉，必须因为它"是什么职责"（有独立变更原因），而不是因为它"行数多"。** 文件长度不是拆分依据（skill 硬边界）。

### 1.1 真实职责判据（满足任一即有权下沉）

| 编号 | 判据 | 含义 |
|---|---|---|
| D1 | 独立变更原因 | 变更与 facade 编排无关（如商店/品质规则随内容变，不随战斗流程变） |
| D2 | 跨层复用 / 端口能力 | 被其他服务或 port 消费（`_authority.call(...)` 端口转发、多服务调用） |
| D3 | 破环 | 下沉消除循环 / 反向依赖 |
| D4 | 可独立测试的纯计算 | 无 authority 依赖，输入 → 输出确定 |
| D5 | 真实冲突热点 | 单一权威写路径上的并发冲突 |

### 1.2 保留判据（即使行数长也留在 facade）

| 编号 | 判据 | 含义 |
|---|---|---|
| R1 | 高内聚顺序协调器 | 维护清楚不变量（skill 明示允许保留为大单元） |
| R2 | O 层编排 | 写 / 协调 ≥4 权威字段或间接写（如 `_check_battle_end`→`_finish_battle_result`） |
| R3 | 外部引用 | 被 port / tests / 生产引用 → 保留转发壳（壳是义务，不是下沉理由） |

### 1.3 机械减行（不构成下沉理由）

文件 / 方法行数、"迁移便利"、与方法对称性、"和搬过的那个差不多"、预建未来抽象。

## 2. 全计划裁决表

每项：裁决 + 判据 + live 证据 + 代价 + 重开条件（skill 必需输出格式）。

### 0. 死代码清理（518→494，24 方法）

- 裁决：**迁移（删除）**
- 判据：D1 / D3（零引用 = 无 owner = 无独立不变量）
- 证据：全仓 grep 仅任务文档 / output / METHOD_INVENTORY 引用，零生产调用点；`_shape_catalog`/`_id_value` 词边界验证 0 引用；docs/15 L165"每个被删除的抽象都已证明没有稳定生命周期或独立不变量"
- 代价：低（零调用点）
- 重开：V2/V3 拦截出生产引用（动态调用）→ 撤回对应删除

### C1 品质（QualityPolicy）

- 裁决：**迁移**（`_apply_quality_progression` + 独属辅助）
- 判据：D1（品质规则独立变更）+ D4（纯函数，实测 0 顶层字段读写）
- 证据：B12 规格；MASTER §2 破环记录
- 代价：低-中（stateHash 须逐字节不变）
- 重开：V3 哈希漂移

### C2 棋盘查询（BoardQuery）— **修正**

- 裁决：**部分迁移（13 搬；4 撤回保留在 facade）**
- 13 搬判据：D2（端口转发 + 多服务 + ~470 tests 调用）+ D4（纯只读，17 个全部 0 顶层写 / 0 `_log`）
- **4 撤回**（`selected_unit` `_leader_at` `_normalize_elements` `_selected_action_ap`）：判据全不满足——零外部引用，搬移仅为迁移便利（§1.3 机械减行）；不为未来预建抽象
- `_preview_resolved_damage` 保留：port 自回传耦合（构造 `DamagePreviewPortScript.new(self)`，搬移会静默破坏端口名匹配）
- 证据：B13 §2.1 列出 17 个并标注 4 个"内部热路径（放宽）"；实测这 4 个零外部引用
- 代价：修正后 C2 少搬 4 个；facade 计数仍 482 不变（壳不降计数）
- 重开：C6/C7 下沉时若这 4 个出现跨服务调用 → 届时带证据重开（不预搬）

### C3 队伍（Roster）

- 裁决：**迁移**（`add_pet_to_roster` 家族 → roster_service）
- 判据：D1（入队 / 来源 / 获取语义独立领域）+ D4（结构化返回，非权威写）
- 证据：B4 规格
- 代价：低-中
- 重开：V3 哈希漂移

### C4 商店（Shop）— 边界已正确

- 裁决：**部分迁移**（3 P 下沉：`build_shop` `resolve_day1_shop_pool` `offers_for_pool`；`apply_shop_event` 保留薄协调器；`construction_text_for_event` 纯子块）
- 判据：D1 / D4（商店规则独立）；`apply_shop_event` = R1 / R2（O 层事件派发）
- 证据：B7 规格（已修正 `_economy_data` 抽取、L459 调用点归 `_fallback_game_data`）
- 代价：低-中
- 重开：V3 哈希漂移

### C5 跑图流程（RunFlow）— 边界已正确

- 裁决：**部分迁移**（`_stall_for_node` 壳保留；4 适配器壳 `_apply_battle_prep_effects` `_battle_prep_effect_from_event` `_outer_run_effect_from_event` `pick_reward`；2 删除 `_post_battle_events_for_result` `_enemy_battle_roster_templates`；`_apply_route_event` 保留 facade；`match_route_option` 纯子块）
- 判据：D2（shop_inventory_command_port 外部 call → 壳义务）、D1 / D4（适配器纯转换）、删除 = 死代码规则、R1 / R2（route 事件编排 + 3 Callable 注入）
- 证据：B6 规格（已修正 §4.8 重复 `var kind`）
- 代价：低-中
- 重开：V3 哈希漂移；`_apply_route_event` 若出现独立变更原因再评估

### C6 行动执行（Action）— **修正（重分类）**

- 裁决：**2 真 P 下沉 + 编排器保留 facade + 纯子块提取**
- **下沉（真 P）**：`_sorted_action_units_for_side`、`_apply_action_skill_after_attack`（D4 纯计算 / D2 复用）
- **保留 facade（编排器，R1 / R2）**：
  - `_execute_selected_action_option`（L7011，161 行 / 约 30 辅助，动作序列顺序不变量）
  - `move_selected`（L6901，63 行）
  - `_settle_threshold_elements`（L4747）
  - `_apply_trap_stack_on_enter`（L4843）
  - （间接写 + `_check_battle_end`→`_finish_battle_result`）
- **`_finish_battle_result`（L6698）保留 facade**：docs/15 L82 明示"保留薄协调器"——机制 / 金币 / 路线奖励 / Trace / 阶段迁移仍按严格顺序编排；终局判定 / 基础奖励 / 失败审计归 `BattleOutcomePolicy`（现有策略，未来单独处理，非本批）
- **`_deal_damage`（L4932）保留 facade**：伤害应用 = 高内聚编排（间接写多）；纯计算段可提取
- 从编排器中**提取纯计算子块**下沉（无 authority 依赖的段：伤害值计算 / 日志拼装等），每块在实施包中带独立裁决 + 证据
- 证据：C6 研究（8 方法体逐字 + 写计数 + 调用点）；docs/15 L82；MASTER §1 顶层写计数（move_selected=2 / _execute_selected_action_option=2 / _finish_battle_result=7，间接写未计入）
- 代价：修正后 C6 范围大幅缩小（仅 2 P + 子块），facade 计数下降少于原投影，但职责边界正确
- 重开：某编排器出现独立变更原因（如伤害结算规则独立）→ 单独拆对应纯子块，不整体搬

### C7 战斗预览 + 自动站位（Battle）— 待实施包裁决

- 默认迁移纯计算（D1 / D4）；`_preview_resolved_damage` 经 `Callable(facade, "_preview_resolved_damage")` 注入（port 自回传，见 C2）
- `_auto_position_damage_metrics` / `_threat_grid_by_cell` / `_best_enemy_shape_action` 等 O 方法子块按 R1 / R2 裁决
- 冲突审计：MASTER §10 要求在提交前与 mouse-playtest day1-day2 owner 协商 `_cell_detail_unit()` 写范围

### C8-C12 — 实施包裁决

按 §1 判据逐方法裁决。本文给定原则：纯计算 / 跨层复用 → 迁移；高内聚编排 / O 层 → 保留 facade + 提取子块；零引用 → 删除（走死代码规则）。

### 组合根门禁 + 最终自查

- 裁决：**保留**（基础设施校验，非职责拆分）；V6 ownership 对账随每切片同步

## 3. 修正明细（覆盖 MASTER_SPEC 对应行，冲突以本文为准）

| MASTER 位置 | 原文 | 修正 |
|---|---|---|
| §2 破环表末行 | "`_finish_battle_result` 归 ActionService，依赖 RunFlowService" | `_finish_battle_result` 保留 facade（docs/15 L82 薄协调器）；ActionService 实际依赖以实施包实测调用为准 |
| §3 S3 ActionService | "6 个（P）\| 2 个 O 方法子块" | "2 个（P）\| 编排器纯子块提取" |
| §4 #1 辅助清单 | 17 项 | 移除 `selected_unit` `_leader_at` `_normalize_elements` `_selected_action_ap` → 13 项 |
| §8 C2 行 | "17 共享辅助下沉，facade 调用点改组合 + 5 公共查询转发壳" | "13 共享辅助下沉（4 内部独属保留 facade，不设壳）；其余同原文" |
| §8 C6 行 | "ActionService（6 P + 2 O 子块）" | "ActionService（2 P + 编排器纯子块提取）" |

> 计数影响：C2 少搬 4 个不影响服务数（V6 services=47 不变）；C6 修正后的 facade 计数以实施包实测为准，不预设投影。

## 4. 优先顺序（修订 MASTER §8，每切片一个提交，精确暂存，不推送）

| 序 | 切片 | 内容 | 依赖（前置） | 提交 |
|---|---|---|---|---|
| 0 | 死代码清理 | 24 方法删除（518→494） | 无（前提，所有计数投影基于它） | 1 |
| 1 | C1 | QualityPolicy（纯函数，最可验） | 无 | 1 |
| 2 | C2 | BoardQuery 13 搬（按 §3 修正） | 无 | 1 |
| 3 | C3 | RosterService | 无（为 C4/C5 提供 roster_service） | 1 |
| 4 | C4 | ShopService 3 P | roster_service | 1 |
| 5 | C5 | RunFlowService | roster / shop / board_query | 2 |
| 6 | C6 | ActionService 2 P + 子块（按 §3 修正） | board_query / quality_policy / run_flow | 1 |
| 7 | C7 | BattleService（最大，2-3 提交） | board_query / action | 2-3 |
| 8 | C8 | PetResetService | board_query | 1 |
| 9 | C9 | RuntimeStateCodec | 无 | 1 |
| 10 | C10 | PersistenceService | save/replay/history repo | 1 |
| 11 | C11 | OperationLogService | runtime_state_codec | 1 |
| 12 | C12 | Leader/Stat（`_leader_unit` 下沉 / `_resolved_stat_value` 若已在 S1 则跳过） | board_query | 1 |
| 13 | — | 组合根接线收口 + smoke 门禁 + 全量验证 | 全部 | 1 |

**顺序理由（不可打乱）**：DI 注入顺序（MASTER §5）决定切片顺序——无依赖的 BoardQuery / QualityPolicy 先行；Roster→Shop→RunFlow 为注入链；Action 依赖 RunFlow；Battle 依赖 Action；剩余域各自依赖前序服务。C2 修正后风险更低（少搬 4 个），保持原位。C6 修正后范围缩小，仍按注入顺序排在 C5 后。

## 5. 长期边界（facade 最终形态）

**永久保留在 facade 的：**

- 10 个 A 类公共命令（1 行转发壳）
- 所有被 port / tests / 生产引用的方法（转发壳）
- 高内聚编排器：`_execute_selected_action_option` `move_selected` `_settle_threshold_elements` `_apply_trap_stack_on_enter` `_finish_battle_result` `_apply_route_event` `_apply_shop_event` `_deal_damage`
- 状态机机制：`_fallback_game_data`（依赖 `_pet`/`_enemy`）、`_restore_runtime_state`、snapshot / save / replay
- 单一权威 `YsbzsState` 不变；组合服务无状态 / 被动，不缓存权威状态

**下沉到服务的（最终形态）：** 领域纯算法集中在无 authority 依赖的服务，可独立测试；`log_lines` 由 facade 统一编排（P 层经 `_logs` 结构化日志回传）。

## 6. 实施者入口

1. 按 §4 顺序领取切片。
2. 每切片：读本文 §1 判据 + MASTER_SPEC + 对应域规格（C1-C5 已有，实施时按 §3 修正应用；C6+ 由实施者按本文裁决产出实施包）。
3. 实现 → V1-V6 全绿 → 精确暂存提交 → 不推送。
4. 每切片同时同步组合根（§5 接线）与 smoke 门禁（V6）。

## 7. 验证门禁

V1-V6 与 MASTER §7 不变；V3 三哈希（`c1bd5ff8…` / `875e3dbe` / `c53db478`）与 V6 ownership 对账为硬门禁。被修正切片（C2 / C6）验证协议不变，仅方法清单按 §3 生效。
