# 拼图化重构 P0 基线

## 基线范围

- 路线图输入：`/Users/ywh/Desktop/架构重构路线图-拼图化改造.md`
- live source 基线提交：`598c216da92a5ccaff1df26480711080a0f9cf8b`
- 分支：`codex/full-project-structure-migration`
- 范围：六层兼容链、Command/Result/Trace/Snapshot、save/replay/stateHash；本阶段不改玩法、协议、数据或 UI。
- 机械逐方法报告：`reports/architecture/METHOD_INVENTORY.md`

## 行为冻结值

运行引擎为 `Godot 4.7.stable.official.5b4e0cb0f`。先用既有 `tests/core/dump_core_io.gd` 确认公开 core I/O 摘要，再用 fail-closed 的 `tests/core/dump_puzzle_refactor_baseline.gd` 验证命令、真实 save/replay checksum、首尾 checkpoint 与导出只读性。后一个探针连续运行两次，唯一的 `PUZZLE_REFACTOR_BASELINE_JSON ...` 基线行逐字节一致，且 `assertions=pass`；完整 stdout 含运行时耗时，不作为逐字节基线：

| 检查点 | 第一次 | 第二次 |
|---|---|---|
| 初始 `stateHash` | `7a510a2137368fce` | `7a510a2137368fce` |
| `START_BATTLE` 响应 hash | `71bdaf1a55c6bf6b` | `71bdaf1a55c6bf6b` |
| `SELECT_UNIT` 后 hash | `a08b391aa4beb858` | `a08b391aa4beb858` |
| `EXPORT_REPLAY` 后 hash | `a08b391aa4beb858` | `a08b391aa4beb858` |
| replay 前/后版本 | `1 -> 1` | `1 -> 1` |
| replay 前/后 hash | `a08b391aa4beb858 -> a08b391aa4beb858` | `a08b391aa4beb858 -> a08b391aa4beb858` |
| save schema | `ysbzs.save` v2 | `ysbzs.save` v2 |
| save checksum | `875e3dbe`（重算一致） | `875e3dbe`（重算一致） |
| replay checksum | `c53db478`（重算一致） | `c53db478`（重算一致） |
| 初始棋盘格数 | 56（8×7） | 56（8×7） |

完整协议冻结值：

| 项目 | 固定值 |
|---|---|
| probe contract | `puzzle_refactor_baseline_v1` |
| 整体规范化 SHA-256 | `c1bd5ff8da9ed925b69378795a3514f78828f0829254e8f27021bb2eeea62562` |
| save | `ysbzs.save` v2；规范化 SHA-256 `246c42135a3ea5882b042a1285c0797b27ecb54ee694486ff2804f14567070e2` |
| replay | `ysbzs.replay` v2；规范化 SHA-256 `cce4272c3afa592af424def11fb46f50703bc4f885571e7ce784cecb4f5c2292` |
| replay / rules / rng version | `ysbzs_replay_v4_versioned_history` / `ysbzs_rules_2026_08_01_v3_relic_timeline` / `ysbzs_seeded_selector_fnv1a_mulberry32_v1` |
| command stream | 1 项，仅冻结 `START_BATTLE` checkpoint；首尾都是 `0/7a510a2137368fce -> 1/71bdaf1a55c6bf6b`；当前 `SELECT_UNIT` 不写入 replay stream |
| replay final / summary | version 1；hash 均为 `a08b391aa4beb858` |

复现命令与本机证据：

```bash
python3 tools/qa/run_qa.py --test tests/core/dump_puzzle_refactor_baseline.gd --run-id puzzle-p0-probe-a --output output/validation/qa/puzzle-p0-probe-a --fail-fast
python3 tools/qa/run_qa.py --test tests/core/dump_puzzle_refactor_baseline.gd --run-id puzzle-p0-probe-b --output output/validation/qa/puzzle-p0-probe-b --fail-fast
```

两次运行分别为 1/1 PASS；规范化整包 SHA-256 都是上表的 `c1bd5ff8...`，原始 JSON 位于各证据目录的 `tests/dump_puzzle_refactor_baseline-d06113ac/stdout.log`。fast QA 的 P0 前置证据 `output/validation/qa/20260801-185043-fast` 为 9/9；P0 最终 fast 证据见本任务卡。后续阶段若有意改变上述值，必须先证明是协议/规则版本迁移；普通职责迁移必须保持这些值不变。

## 六层兼容链盘点

| 文件 | SHA-256 | 行数 | 方法数 | 当前职责事实 |
|---|---|---:|---:|---|
| `core/state/state_base.gd` | `cf4e89237deb71c18683f4815bd68bbbd162e46949fb6778c486ef6b54eaa6f6` | 2174 | 492 | 479 个空虚拟契约 + 13 个安全默认契约；不拥有上层业务实现 |
| `core/party/catalog_roster_core.gd` | `f3996b0c5a98e102189a75fe8cc8b5aabfcb8aaeab391b5b10d13e2d92881840` | 1886 | 99 | 图鉴、阵容、机制兼容入口；已有 RoundLifecycle/Roster 服务委托 |
| `core/commands/command_projection_core.gd` | `6ef84d1653318946a62ec5580608b5dfdb6eff0ca4127c0d6cda5726773350f0` | 2008 | 103 | 命令响应、Snapshot、预览；dispatch 已走 handler registry |
| `core/battle/battle_rules_core.gd` | `df0c35b7d83f0abe2b8f11487bc768169e5d53c5fbc8a18200d53f4b28a518b9` | 2075 | 139 | 行动槽、自动布置读模型、伤害/元素/品质协调；仍是 P1 主要热点 |
| `core/run/run_flow_core.gd` | `285addf816d3474a6cb214afe35861da1b085eea258292900c66e3de09e47d99` | 2368 | 130 | 路线/商店/奖励/战斗顺序协调；RouteOptionService 已接入，纯规则仍需逐项审计 |
| `persistence/compatibility/persistence_core.gd` | `7eb02668a98c3042ef8d3514cf07da8194de14aa938bb79921e328d3ad514116` | 838 | 63 | save/replay/history 兼容门面；文件 I/O 已委托 Repository |

逐方法机械分类合计 1026 个函数：479 个空契约、13 个安全默认契约、8 个公开兼容委托、9 个 Port/动态适配委托、113 个内部委托、391 个有观察调用的实现，以及 13 个经人工复核的迁移遗留无调用候选。

## P2 同名实现结论

机械报告中的 491 个同名跨层定义，都是 `state_base` 虚拟契约与上层唯一 owner 的组合。`state_base.gd` 文件头已明确其职责是 authoritative fields + virtual cross-layer contract，`smoke_core_layer_structure.gd` 也只把五个上层文件视作实现层；当前没有两份非契约业务实现。

因此路线图 P2 的 live 结论不是“在 state_base 和 catalog 之间二选一份实现”，而是：

- 保持唯一上层 owner；
- 对已迁移且无消费者的契约签名，连同上层遗留方法一起逐项删除；
- 禁止把 492 个契约按行数批量删除；每项仍需继承、反射、存档/回放和 focused/fast 证据。

## 13 个无调用候选的人工结论

以下项目已逐项扫描普通调用、`call`、`Callable`、`has_method`、明确 registry/contract、Godot 生命周期和 Git 迁移来源。结论均为 `confirmed_unobserved_migration_residue`。P0 只记录，不删除；后续必须单独任务卡、精确租约，并同时处理仍存在的 base contract（若有）和回归测试。

| 遗留方法 | 当前定义 | 替代 owner / 正式路径 | 人工结论 |
|---|---|---|---|
| `_best_auto_position_for_unit` | `battle_rules_core.gd:605` | `AutoPositionPlanner.build_plan` | 旧单单位取首候选逻辑；全局 candidate/beam 规划已接管 |
| `_evaluate_auto_position_choices` | `battle_rules_core.gd:801` | `AutoPositionTurnOptimizer.optimize` | 旧 ReadPort 回调，现 optimizer 直接拥有评估 |
| `_auto_position_planned_actions` | `battle_rules_core.gd:872` | `AutoPositionTurnOptimizer.selected_actions` | 旧 planned-actions 包装，无当前入口 |
| `_apply_quality_board_trace` | `battle_rules_core.gd:1889` | `QualityEffectStrategy` + `QualityBoardTrace` | 品质攻击后痕迹已由策略直接应用 |
| `_first_enemy_in_stored_direction` | `run_flow_core.gd:1991` | Player/EnemyTurnService + attack option / SkillEffectPort | 旧全部出击 fallback 目标助手 |
| `_step_toward` | `run_flow_core.gd:2207` | `AutoPositionPlanner` + `_apply_enemy_auto_position_plan` | 旧逐格敌方移动实现 |
| `_first_shape_enemy` | `run_flow_core.gd:2262` | EnemyTurnService/Port + `_best_enemy_shape_action` / SkillEffectPort | 旧目标与方向变更助手 |
| `_validate_save_state_payload` | `persistence_core.gd:443` | `SaveDocumentValidator.validate_document/validate_state_payload` | 读档入口已直接调用 validator |
| `_validate_saved_units` | `persistence_core.gd:456` | `SaveDocumentValidator.validate_units` | 旧校验包装，无当前入口 |
| `_route_battle_options` | `command_projection_core.gd:715` | `SnapshotProjector` + `_next_actions` / route flow | 旧展示过滤助手；当前投影和动作直接拥有职责 |
| `_apply_fire_explosion_after_attack` | `battle_rules_core.gd:1396` | `_settle_player_elements_after_all_out -> _settle_threshold_elements` | 旧即时爆炸副本；接回会造成第二计算路径和时序漂移 |
| `_trace_definition_for_upgrade` | `battle_rules_core.gd:1493` | `QualityEffectRegistry` + `QualityEffectStrategy` + `QualityBoardTrace` | 品质痕迹元数据与执行已迁移 |
| `_first_adjacent_enemy` | `run_flow_core.gd:2254` | action option / SkillEffectPort；品质追击走 `QualityEffectContext.nearest_enemy` | 旧全部出击 fallback 邻接目标助手 |

## 路线图与 live source 对应关系

| 路线图项 | 当前对应 | P0 结论 |
|---|---|---|
| P1 战斗规则下沉 | QualityEffectRegistry/Strategy、SkillQueueService、AutoPositionPlanner/Policy/ReadPort/TurnOptimizer 已存在 | 部分完成；`battle_rules_core` 仍保留品质输入校验、行动槽写入和大量自动布置读模型/权威应用，需按写入口逐项处理 |
| P2 同义重复 | `state_base` 虚拟契约 + 五层唯一实现 | “双业务实现”已经不存在；真实工作是删除 13 个迁移遗留及其无用契约，不是再造 Roster 层 |
| P3 Command handler 化 | `command_handler_registry.gd` + 5 个领域 handler；`_dispatch_action` 已按类型查表 | 已完成，后续只补“新增 handler 模板/契约 smoke”，不重复重构 dispatch |
| P4 RunFlow 纯规则下沉 | `RouteOptionService`、RouteRules、EconomyRules、ShopCatalog/Stall 服务已接入 | 部分完成；保留 `_finish_battle_result` 顺序协调器，继续审计商店/奖励纯计算 seam |
| P5 State/Persistence 收敛 | state_base 是契约地基；SaveRepository/GameDataRepository/OperationLogRepository 与 codec/validator 已接入 | 部分完成；先清无调用契约/包装，再审计 persistence 门面是否仍含 I/O 或重复校验 |
| P6 机器门禁 | 已有 `smoke_core_layer_structure`、`smoke_core_composition_complete`、`smoke_architecture_boundaries`、`smoke_project_structure`、`smoke_view_model_schema` | 部分完成；缺方法清单 freshness、无调用迁移遗留和新逻辑依赖方向的精确门禁；不恢复行数预算 |
| §8.1 BattleWorld | 隔离纵切 + 等价 smoke | 已决定冻结为参考，不接 CoreComposition/Session；提交 `3d74aac` + `598c216` |
| §8.2 魔法字符串 | ScriptPluginRegistry 已 fail-closed，Content Pack 有 Validator | 仍缺 effect/stat/operation/hook 常量与入站 schema 的全覆盖盘点 |
| §8.3 handler 生态 | 7 个 effect handler，目录发现已存在 | 仍缺开发模板、每 handler 最小契约/专项 smoke 的一致门禁 |
| §8.4 做减法 | CoreComposition 已逐实例装配 | 仍缺逐 service 的生产调用方审计；无调用或单纯转发层才进入删除候选 |
| §8.5 STS2 取舍 | `docs/15_STS2_GUIDED_ARCHITECTURE_MAP.md` | 已有并已补 BattleWorld 冻结决策；后续只随真实架构决策更新 |

## P0 收口标准

- `METHOD_INVENTORY.md` 可由工具确定性重建并用 `--check` 验证 freshness。
- 调用扫描语料为 407 个 source 文件，聚合 SHA-256 `64351eb03f391980bb2a7eef675705b31942939db40cdaf11cfc3f933c4cbfc0`；报告同时记录扫描根、后缀和聚合算法。
- 13 个静态无调用候选均已人工复核实际 owner，未在 P0 擅自删除。
- fast QA、两次 core I/O hash、save schema/checksum、replay 不变性均已冻结。
- 下一阶段一次只领取一个真实写入口；不得以“缩短大文件”或“路线图写了”替代 live source 证据。
