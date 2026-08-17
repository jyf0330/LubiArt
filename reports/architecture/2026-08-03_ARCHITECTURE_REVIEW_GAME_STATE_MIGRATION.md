# 2026-08-03 架构全面审查：GameState 职责下沉迁移

author: Claude（架构师）
status: REVIEW_COMPLETE（审查记录，非实施规格）
审查对象：`core/state/game_state.gd` 与 C0-C9 职责下沉主线
基线：`HEAD f66397e`（C3b 已收口 `a865406`）+ 未提交 C4 工作树
范围：只读审查 + 正式架构文档同步（`docs/03`、`docs/15`）；未修改任何代码文件

## 0. 审查范围与方法

- 读取：`tasks/index.md`、`2026-08-03_CODEX_GAME_STATE_IMPLEMENTATION_PACK.md`（C0-C9 规格）、`2026-08-03_FACADE_DESCENT_MASTER_SPEC.md` 及 B-spec、`METHOD_INVENTORY.md`、`session/simulation_authority_factory.gd`、`session/simulation_io_guard.gd`、`core/commands/manual_flow_simulation_service.gd`、`docs/03_CORE_ARCHITECTURE.md`、`docs/06_PROJECT_STRUCTURE.md`、`docs/15_STS2_GUIDED_ARCHITECTURE_MAP.md`。
- 实测（全部只读）：`game_state.gd` parse；`dump_puzzle_refactor_baseline.gd`（P0 金丝雀）；`smoke_manual_flow_simulation_isolation.gd`；composition `services()` 计数；C4-C8 目标文件存在性；`tasks/doing/*` 写租约冲突审计。
- 结论以 live source 为准，不以文件名或文档断言为准。

## 1. 现状核实

| 切片 | 内容 | 状态 | 证据 |
|---|---|---|---|
| C0 | 24 个无调用 facade 方法删除 | ✅ | `3c1ce75`，518→494 |
| C1 | `snapshot()` 零写入 | ✅ | `0b1a60b` |
| C2 | 构造 fail-closed + `ContentLoadService` | ✅ | `9293c9d` |
| C3a | `SimulationIoGuard` + `SimulationAuthorityFactory` | ✅ | `c6c1aef` |
| C3b | `ManualFlowSimulationService` | ✅ | `a865406`（inventory 重生成、门禁 48、独立提交、归档） |
| C4 | 品质升级策略（`QualityProgressionPolicy`） | 🔶 进行中 | `core/party/quality_progression_policy.gd` 已落地，未提交 |
| C5-C9 | 查询/自动布置/日志/回放 | ⬜ 待执行 | 目标文件均不存在 |

- composition `services()` = **48**（43 DIRECT + 5 INJECTED_ONLY）；C0-C9 完成目标 **53**（+C4/C5/C6/C7/C8 各 1）。
- 反向依赖 `0 methods / 0 calls`；旧六层 0 文件 0 引用；空虚拟契约 0；facade 方法清单已在 `a865406` 重生成（当前值以 `METHOD_INVENTORY.md` 为准）。
- 唯一字段注册表：`AuthoritativeStateCodec.FIELD_SPECS`（65 项），无第二份 capture 字段表。

## 2. 验证证据（2026-08-03 实测）

| 验证 | 结果 |
|---|---|
| `game_state.gd` parse（check-only） | exit 0 |
| P0 金丝雀 | `assertions=pass`；`normalizedSha256=c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562`、save `875e3dbe`、replay `c53db478` 与冻结值**逐项一致** |
| C3b isolation smoke | `source=unchanged files=unchanged parity=exact limits=0,1,4` |
| composition 对账 | 48 = 43 DIRECT + 5 INJECTED_ONLY，与 C3b 任务卡一致 |

职责下沉零行为漂移：stateHash、save/replay schema、command checkpoint、contentHash 均未刷新。

## 3. 架构健康度结论

- **主干不变量全部保持**：`GameSession -> Command -> YsbzsState（唯一权威）-> Result/Trace/Snapshot`；零第二写路径、零全局 Manager、零 UI 可写缓存。
- **simulation fork 方向正确**：`PREVIEW_MANUAL_FLOW` 从手写 `_capture_runtime_state()` / `_restore_runtime_state()`（写 64 字段的易漂移路径）迁到 canonical fork + `SimulationIoGuard`，source 零写有机器门禁。这是对旧 capture/restore 的净改进，不是等价换名。
- **C2 内容 fail-closed 消除第二真相源**：生产 fallback（`_fallback_game_data` / `_pet` / `_enemy` / `_build_shop`）删除，构造契约明确，失败不 reset 不 dispatch。
- **逐切片提交纪律**：C0-C3 每片独立提交、可回滚，符合规格 §2.3。

## 4. 发现的问题 / 风险

### P1（当前阻塞 / 必须在实施前处理）

1. **FACADE 11 服务总纲已废弃但未标记**：`tasks/index.md` 已裁决"以 Codex C0-C9 为主，吸收对方方法清单与切片门禁"。但 `2026-08-03_FACADE_DESCENT_MASTER_SPEC.md` 与 9 份 B-spec 仍标 `SPEC_READY`。其中 S8 `RuntimeStateCodec`（capture/restore 字段清单）已被 C3 fork 方案**直接取代**；S1-S11 与 C0-C9 目标重叠或冲突。风险：后续实现者可能误按旧总纲执行。建议：在 FACADE 文档头部加 `SUPERSEDED_BY: C0-C9` 标记（由这些文档的 owner 执行），并在此审查记录留存裁决证据。

### P2（后续切片前置缺口）

3. **`SimulationAuthorityFactory` 缺 `create()`**：实施包 §12.1 要求 C3a 同时提供 `create(authority_script, content_pack, options)`（fresh create + reset，不 restore），用于 C8 `ReplayVerifier`。实测仅实现 `fork()`。这是 C8 的硬前置，需在 C8 实施前补上；`fork()` 内部可复用 `create()` 后 canonical restore。
4. **C5 需先建 battle query baseline fixture**：实施包 §9.4 要求 `dump_battle_query_baseline.gd` + `tests/fixtures/battle_query_baseline_v1.json` 在移动代码前独立提交，当前不存在。C5a 实施者必须先补 baseline 再搬方法。
5. **C5d 依赖 mouse-playtest 释放 `_cell_detail_unit()`**：`tasks/doing/2026-07-15_mouse-playtest-day1-day2.md` 持有该方法。C5d 必须等其释放；其他 C5 atom 不因它阻塞。

### P2（文档，本审查已处理）

6. `docs/03_CORE_ARCHITECTURE.md`、`docs/15_STS2_GUIDED_ARCHITECTURE_MAP.md` 原停在 8/1-8/2，未反映 C0-C3。本审查已同步更新（见 §7）。

## 5. 架构裁决汇总（本审查热点）

| 热点 | 裁决 | 证据 / 代价 | 重开条件 |
|---|---|---|---|
| 预览执行位置 | 迁移到 canonical simulation fork | C3b isolation smoke：source 零写、文件树零变化、parity exact；旧 capture/restore 写 64 字段易漂移 | 只有真实需求（如 preview 需要非确定性或真实 I/O）才重开，且必须重新论证零写不变量 |
| 构造 / 内容装载 | 已采用 fail-closed | C2：`mode/content_pack/core_overrides` + `ContentLoadService`，第二真相源删除 | 新 fixture 场景必须显式 `mode=test` 注入，不得恢复自动 fallback |
| 无 I/O 模拟隔离 | 已采用 | `SimulationIoGuard` 一次替换五 repository；fork hash == source hash 校验 | — |
| 早期 FACADE 11 服务（S1-S11） | 拒绝 / 被 C0-C9 取代 | tasks 归档裁决；S8 与 C3 冲突 | 除非 C0-C9 全量失败且有可量化收益，否则不复用 |
| `YsbzsState` 唯一权威 + 逐实例 CoreComposition | 保留 | 反向依赖 0/0、FIELD_SPECS 唯一注册表 | — |
| `BattleWorld` 数据导向纵切 | 保留冻结参考 | 无生产调用方；不注册组合根 | 明确生产入口 + 等价证据 + 旧入口删除计划 |

## 6. 建议与后续门禁

- **C3b 收口**：已完成（`a865406`）：inventory 重生成、门禁 48、独立提交并归档；审查时点该切片遗留已清零。
- **C4 前置**：normalize/key/next/summarize 直接复用 `QualityRules`，不复制常量；`BattleStartupService.prepare_player_deployment` 删除 `apply_quality` callback。
- **C8 前置**：先补 `SimulationAuthorityFactory.create()`，再建 `ReplayVerifier`。
- **文档状态纪律**：任何架构文档的 `IMPLEMENTATION_READY` 必须满足技能门禁的九项；本审查记录不声称 C4-C8 已实现。
- **机器门禁**：`inventory_core_methods.py`、`smoke_manual_flow_simulation_isolation.gd`、`smoke_composition_service_ownership.gd` 继续 fail-closed；C4-C8 每切片同步门禁，不留不一致中间态。

## 7. 交付（本审查已落地）

- `docs/03_CORE_ARCHITECTURE.md`：新增「初始化、内容装载与无 I/O 模拟」「C0-C9 职责下沉迁移路线图」小节；组合服务清单加入内容/模拟分组；稳定门禁加入 isolation smoke。
- `docs/15_STS2_GUIDED_ARCHITECTURE_MAP.md`：更新证据日期与 game_state 热点行；新增 preview/simulation fork、构造 fail-closed、无 I/O 模拟、FACADE 废弃四行裁决；固定主干补充 fork 边界。
- 本文件：审查记录。

## 8. 参考

- `reports/architecture/2026-08-03_CODEX_GAME_STATE_IMPLEMENTATION_PACK.md`
- `reports/architecture/2026-08-03_FACADE_DESCENT_MASTER_SPEC.md`（废弃标记建议）
- `reports/architecture/METHOD_INVENTORY.md`（C3b 收口后需重生成）
- `docs/03_CORE_ARCHITECTURE.md`、`docs/15_STS2_GUIDED_ARCHITECTURE_MAP.md`
- `tasks/done/2026-08-03_game-state-c3b-manual-flow-simulation.md`（C3b 收口 `a865406`）
