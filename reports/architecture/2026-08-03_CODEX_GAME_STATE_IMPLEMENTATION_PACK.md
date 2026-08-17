# 2026-08-03 `game_state.gd` 完整实施规格包（Codex）

author: Codex
status: IMPLEMENTED / VERIFIED
architecture_source: `reports/architecture/2026-08-03_CODEX_GAME_STATE_RESPONSIBILITY_DESCENT_SPEC.md`
game_source_baseline_commit: `d94be93b3e6b0f66ca07a2e44f17f22b2ad21904`
implementation_head: `4a93e0e012e2721fd90c312885937751b9ff1a09`
final_audit_commit: `806017dd88ccd0964eef0a55467bcc97cecd9079`
document_checkout_head: `a6d305f495d643b2ad76626b4274d7adc7ae989b`
scope: 保留供普通 Godot / GDScript 程序员复核的逐 atom 规格，并登记实际提交、验证和完成证据

## 0. “完整”在本文件里的含义

本文件不是方向建议，而是执行规格。实施者仍需要编写和调试代码，但不应再决定以下架构问题：

- 哪个方法保留、迁移或删除。
- 新 owner 的路径、职责、构造方式和公开签名。
- Dictionary 的必填键、默认值和失败码。
- 哪些对象允许写，哪些对象必须深拷贝。
- 原有直接、动态、Port、生命周期和测试调用方如何迁移。
- 哪些顺序不能改变，失败时允许留下什么状态。
- 哪个旧入口在什么 atom 删除。
- 应新增哪些测试、断言什么、执行哪些命令。
- 每个提交的边界和可逆回滚点。

`IMPLEMENTATION_READY` 只对第 1 节冻结基线有效。开始任一 atom 前若 `game_state.gd` SHA、方法数、Port 契约或 active task owner 已变化，先执行第 2.3 节重新基线；不得把旧行号机械套到新源码。

## 1. 冻结基线与金丝雀

### 1.1 源码和依赖基线

| 项目 | 冻结值 |
|---|---|
| `core/state/game_state.gd` | 8049 行、518 个 `func` |
| facade SHA-256 | `d56658a6379276bb9076fbd94c13ce88523d7f1030c6f278de95756ae9fdeb52` |
| METHOD_INVENTORY reference corpus | 479 文件，`3aa62d5d872f3f8440b78a690332bb5889fda980f33cfff3b7687e5b4462c4b5` |
| legacy compatibility chain | 6 个旧层均不存在，跨层反向依赖 `0 methods / 0 calls` |
| `CoreComposition.services()` | 45 项 |
| canonical authoritative registry | `AuthoritativeStateCodec.FIELD_SPECS`，65 项；不得复制第二份列表 |
| Godot | `4.7.1.stable.official.a13da4feb` |

源 SHA 检查：

```bash
test "$(shasum -a 256 core/state/game_state.gd | awk '{print $1}')" = "d56658a6379276bb9076fbd94c13ce88523d7f1030c6f278de95756ae9fdeb52"
python3 tools/qa/inventory_core_methods.py --check reports/architecture/METHOD_INVENTORY.md
```

### 1.2 行为金丝雀

命令：

```bash
/opt/homebrew/bin/godot --headless --path . --script tests/core/dump_puzzle_refactor_baseline.gd
```

冻结输出中的关键值：

| 合同 | 冻结值 |
|---|---|
| probe | `puzzle_refactor_baseline_v1` |
| initial stateHash | `7a510a2137368fce` |
| after START_BATTLE | `71bdaf1a55c6bf6b` |
| after SELECT_UNIT | `a08b391aa4beb858` |
| save schema/version | `ysbzs.save` / `2` |
| save checksum | `875e3dbe` |
| save normalized SHA-256 | `246c42135a3ea5882b042a1285c0797b27ecb54ee694486ff2804f14567070e2` |
| replay schema/version | `ysbzs.replay` / `2` |
| replay checksum | `c53db478` |
| replay normalized SHA-256 | `cce4272c3afa592af424def11fb46f50703bc4f885571e7ce784cecb4f5c2292` |
| replay command count | `1` |
| rules version | `ysbzs_rules_2026_08_01_v3_relic_timeline` |
| RNG version | `ysbzs_seeded_selector_fnv1a_mulberry32_v1` |

有意修改协议时，必须单独建立协议迁移任务并同时更新 contract/version/golden；职责下沉本身不授权刷新这些值。

### 1.3 当前并发所有权

- `2026-08-03_facade-dead-code-cleanup` 拥有 `FACADE_*` 规格及 C0 的未来源码清理。C0 实施前先与该 owner 合并或等待其完成，不能并行删除同一方法。
- `2026-07-15_mouse-playtest-day1-day2` 拥有 `_cell_detail_unit()`。C5d 必须等待其释放；其他 C5 atom 不因它阻塞。
- 任一 atom 写入前重新读 `tasks/index.md`、`tasks/doing/*.md`、`tasks/paused/*.md`；出现路径或方法重叠即输出 `FILE_CONFLICT_STOP`。

## 2. 实施协议

### 2.1 不可改变的不变量

1. `YsbzsState` 是唯一正式可写玩法权威；模拟 fork 只在一次 service 调用内存活。
2. 玩家写入只经公开 Command；接受的变更 Command 只递增一次 `state_version`、只追加一次 command/history。
3. Query / Preview 不得改变 source 的 canonical payload、hash、version、RNG、history metadata 或任何文件。
4. 纯 Policy / Projector 只接收深拷贝值和无状态 service，不接收 authority 或其内部可变引用。
5. 纯模块返回 Result / Plan / Delta / 完整 next value；只有 facade coordinator 应用权威写入。
6. `AuthoritativeStateCodec.FIELD_SPECS` 是 capture/restore/hash 唯一字段注册表。
7. Repository 只负责外部存取；Builder/Projector/Verifier 不得自行读写路径。
8. 公开 Command、Snapshot、Trace、save/replay schema 和错误语义默认保持兼容。
9. private 兼容壳只能跨一个 atom，且必须在表中指定删除 atom；未指定即不允许新增。
10. 不以 facade 行数、方法长度或写几个顶层字段判断纯度。

### 2.2 通用 Result 合同

新 Dictionary 合同统一使用 camelCase 对外键；内部旧 schema 不在本任务顺手改名。

`InitResultV1`：

```gdscript
{
    "schema": "ysbzs.init-result.v1",
    "ok": bool,
    "mode": "production" | "simulation" | "test",
    "source": String,
    "contentHash": String,
    "errors": Array[String]
}
```

`ValueResultV1`：

```gdscript
{
    "schema": String,       # 领域固定值，不由调用方传入
    "ok": bool,
    "value": Variant,       # 失败时为该领域空值
    "changes": Array,       # 纯描述；不得含 Callable/Object
    "errors": Array[String]
}
```

规则：

- `ok=false` 时 `errors` 至少一项，调用方不得应用 `value`。
- 所有 Array/Dictionary 入参在入口 `duplicate(true)`；返回前再次深拷贝。
- 任何 Result 不得持有 `Object`、`Callable`、Repository 或 authority。
- 错误码为稳定英文 ASCII；玩家可见中文由 facade/UI 映射。

### 2.3 每个 atom 的固定工作流

1. 新建独立任务卡并声明本 atom 的 source/target/test 写范围。
2. 重新生成 inventory 到临时路径或先核对冻结 inventory；列出直接、动态、Port、生命周期和 test caller。
3. 先新增 RED contract/negative test，再加 target owner。
4. 机械复制算法时先保持表达式与排序不变，只做 `self field -> context key`、`helper -> target method/service` 替换。
5. 接线后同一 atom 删除指定旧入口；禁止留下无删除阶段的私有转发壳。
6. 跑本 atom focused tests、P0 架构门禁、inventory、fast suite。
7. 对照第 1.2 节金丝雀；非协议 atom 必须完全一致。
8. 精确暂存 atom 文件并独立提交；不要使用 `git add .` / `git add -A`。

通用验证尾部：

```bash
/opt/homebrew/bin/godot --headless --path . --check-only --script core/state/game_state.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_core_layer_structure.gd
/opt/homebrew/bin/godot --headless --path . --script tests/integration/smoke_architecture_boundaries.gd
python3 tools/qa/inventory_core_methods.py --output reports/architecture/METHOD_INVENTORY.md
python3 tools/qa/inventory_core_methods.py --check reports/architecture/METHOD_INVENTORY.md
python3 tools/qa/run_qa.py --suite fast --fail-fast
git diff --check
```

### 2.4 统一 mutation 规则

Facade 应用纯结果时使用以下顺序，不得由每个实现者自行选择：

1. validate `ok`、schema、identity/version 前置条件。
2. 从 Result 取完整 next value 或 Delta，在局部变量上再次校验。
3. 一次赋给权威字段或数组元素。
4. 按原有顺序生成 Trace / log / public Result。
5. 由现有 `run_command` / `_record_dispatch_result` 完成 version、hash、command/history exactly-once。

失败发生在第 3 步前必须零写入；第 3 步后的异常视为实现 bug，测试必须让 atom 失败，不能用补偿写掩盖。

## 3. 目标文件与依赖顺序

| 阶段 | 动作 | 文件 | 进入 `CoreComposition` |
|---|---|---|---:|
| C0 | DELETE | 24 个确认无调用的 facade 方法 | 否 |
| C1 | NEW | `tests/core/smoke_snapshot_purity.gd` | 否 |
| C2 | NEW | `core/content/content_load_service.gd` | 是，`content_load_service` |
| C2 | NEW | `tests/core/smoke_state_initialization_fail_closed.gd` | 否 |
| C3a | NEW | `session/simulation_io_guard.gd` | 否 |
| C3a | NEW | `session/simulation_authority_factory.gd` | 是，`simulation_authority_factory` |
| C3b | NEW | `core/commands/manual_flow_simulation_service.gd` | 是，`manual_flow_simulation_service` |
| C3 | NEW | `tests/core/smoke_manual_flow_simulation_isolation.gd` | 否 |
| C4 | NEW | `core/party/quality_progression_policy.gd` | 是，`quality_progression_policy` |
| C5a | NEW | `core/commands/battle_query_projector.gd` | 是，`battle_query_projector` |
| C5a | NEW | `core/commands/battle_query_context.gd` | 否；纯 schema/factory helper |
| C5a | NEW | `core/ports/value_damage_preview_port.gd` | 否；Projector/Evaluator 按调用构造 |
| C5 | NEW | `tests/core/smoke_battle_query_projector_parity.gd` | 否 |
| C6 | NEW | `core/battle/auto_position/auto_position_evaluator.gd` | 是，`auto_position_evaluator` |
| C6 | EDIT | `core/battle/auto_position/auto_position_read_port.gd` | 已由 planner 临时构造，不单列 |
| C7 | NEW | `core/logging/player_operation_projector.gd` | 是，`player_operation_projector` |
| C8 | NEW | `persistence/replay_verifier.gd` | 是，`replay_verifier` |
| C9 | EDIT | ownership/architecture tests、inventory、架构文档 | 否 |

最终 composition 为 53 项：当前 45 + C2 1 + C3 2 + C4 1 + C5 1 + C6 1 + C7 1 + C8 1。若实施时已有等价 owner，必须复用并在任务卡说明，不能同时保留两个能力；此时最终数量相应减少，不以 53 作为硬性产品指标。

严格依赖顺序：`C0 -> C1 -> C2 -> C3a -> C3b -> C4 -> C5a -> C5b -> C5c -> C5d -> C6 -> C7 -> C8 -> C9`。C5d 可因并发 owner 延后到 C8 后，但 C9 不得在 C5d 未裁决时完成。

## 4. C0：确认无调用的堆积删除

### 4.1 准入和 owner

本阶段与 `2026-08-03_facade-dead-code-cleanup` 重叠，只能由其 owner 实施，或在其任务完成后由新任务接手。删除前必须重新生成 METHOD_INVENTORY，并额外执行字符串动态调用和 Port `REQUIRED_METHODS` 搜索。

### 4.2 精确删除表

以下行号只对应冻结 SHA：

| 原方法 | 冻结行 | 处置 |
|---|---:|---|
| `_roster_index_for_pet` | 999-1001 | DELETE；保留实际使用的 `_roster_index_for_pet_quality` / `_roster_index_for_ref` |
| `_roster_instance_id_exists` | 1011-1013 | DELETE；需要者直接用 `RosterCollectionService.instance_id_exists` |
| `_active_slot_available` | 1097-1099 | DELETE；owner 已是 `RosterSlotRules.active_slot_available` |
| `_next_active_slot_excluding` | 1100-1102 | DELETE；owner 已是 `RosterSlotRules.next_active_slot` |
| `_bag_slot_available` | 1112-1114 | DELETE；owner 已是 `RosterSlotRules.bag_slot_available` |
| `_farthest_cell_index` | 1346-1348 | DELETE |
| `_target_exists_at_cell_index` | 1359-1365 | DELETE |
| `_replay_initial_json_safe` | 1795-1797 | DELETE |
| `_shape_catalog` | 2648-2650 | DELETE；不能顺带删 `_shape_id_for_unit` / `_shape_definition` |
| `_quality_mark_matches_cell` | 3819-3821 | DELETE |
| `_auto_position_choices_signature` | 4236-4238 | DELETE |
| `_auto_position_choices_placement_signature` | 4239-4241 | DELETE |
| `_auto_position_beam_is_better` | 4395-4397 | DELETE |
| `_damage_trace_protocol` | 5100-5102 | DELETE |
| `_hash_seed` | 5874-5876 | DELETE |
| `_id_value` | 5886-5888 | DELETE |
| `_seeded_weighted_unique` | 5889-5891 | DELETE |
| `_replay_event_id` | 7645-7647 | DELETE |
| `_replay_battle_trace_change` | 7653-7655 | DELETE |
| `_replay_battle_trace_protocol` | 7656-7658 | DELETE |
| `_replay_battle_trace_text` | 7659-7661 | DELETE |
| `_replay_error_payload` | 7665-7667 | DELETE |
| `_save_phase_label` | 7703-7705 | DELETE |
| `_save_summary_text` | 7706-7708 | DELETE |

### 4.3 负面门禁、测试与回滚

- `rg -n` 搜索方法名必须只剩历史报告/任务记录，不得有 `.call("name")`、`Callable(..., "name")`、`REQUIRED_METHODS`、`has_method`、StringName 或测试引用。
- Godot parse、P0、fast 和第 1.2 节金丝雀全部不变。
- inventory 方法数应由 518 变为 494；若另有并发源码变化，以“减少恰好 24”而不是绝对 494 验收。
- 一个提交只含 24 个删除、C0 规格算术修正、inventory 和任务卡；回滚该提交即可完整恢复。

## 5. C1：Snapshot 纯度与 roster 规范化写点

### 5.1 源和目标

| 原位置 | 决定 |
|---|---|
| `snapshot()` 1994-1995 | 删除 `_normalize_roster_slots()`；Snapshot 从入口起零写入 |
| `_normalize_roster_slots()` 1050-1053 | 保留为 mutation/migration helper，不迁新 service |
| `reset()` 5297-5374 | 保留 normalization，正式初始 roster 在提交前合法化 |
| `_move_roster_index_to_active_slot()` 6311-6338 | 保留前后 normalization |
| `_move_roster_index_to_bag_slot()` 6339-6368 | 保留前后 normalization |
| `load_document()` 7750-7779 | canonical restore 后、history metadata 前新增一次 normalization |
| `_active_roster_for_battle()` 1055 起 | 保留；只从 mutating `start_battle` 路径调用，不得被 Snapshot 使用 |

`load_document()` 固定顺序：validate document -> validate determinism/content -> canonical restore -> board dimensions/difficulty normalize -> roster normalize -> rebuild run plan if empty -> restore history metadata -> log success。现代存档若 normalization 改变 canonical payload，测试失败；不得静默接受 hash 漂移。

### 5.2 新测试 `smoke_snapshot_purity.gd`

必须覆盖：

1. 创建正式 state，保存 `AuthoritativeStateCodec.capture(state, false)`、`stateHash`、`stateVersion`、history status。
2. 连续调用 `snapshot()` 三次；三个 Snapshot 深等价，capture/hash/version/history 全不变。
3. 直接放入重复 active slot 的 roster 测试夹具后调用 Snapshot；source roster 仍逐字不变，证明查询没有偷偷修复。
4. 调用 `_normalize_roster_slots()` 后重复槽被修复，证明 mutation helper 仍有效。
5. 生成 save、加载到新 state；加载后的 roster 合法，随后 Snapshot 仍零写。

focused 命令：

```bash
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_snapshot_purity.gd
/opt/homebrew/bin/godot --headless --path . --script tests/integration/smoke_command_snapshot_reuse.gd
/opt/homebrew/bin/godot --headless --path . --script tests/integration/smoke_singleplayer_persistence.gd
```

允许写入：只有显式 normalization、reset、load、roster Command。Snapshot 零写。提交只含 state、该测试、inventory/ownership 调整；单提交回滚。

## 6. C2：构造顺序、内容 fail-closed 与 fixture 边界

### 6.1 要解决的事实

当前 `_core_composition` 在字段初始化时构造，`_init()` 无参数并立即读文件；`configure_core_services()` 发生得太晚。`_load_game_data()` 在正式内容为空时静默调用 `_fallback_game_data()`，`reset()` 又用 `_build_shop()` 兜底。这既阻碍无 I/O fork，也制造第二内容真相源。

### 6.2 `ContentLoadService` 精确合同

NEW `core/content/content_load_service.gd`：

```gdscript
extends RefCounted

func load(input: Dictionary, repository: RefCounted) -> Dictionary
```

`input`：

```gdscript
{
    "mode": "production" | "simulation" | "test", # 必填
    "contentPack": Dictionary,                       # simulation/test 必填；production 可省略
    "contentPath": String,                           # production 必填
    "supplementPath": String                         # production 可空
}
```

返回严格为 `InitResultV1` 加 `contentPack: Dictionary`。错误码：

| 条件 | errors |
|---|---|
| 未知 mode | `INIT_MODE_UNSUPPORTED` |
| simulation/test 未注入内容 | `CONTENT_PACK_REQUIRED` |
| repository 为 null 或缺方法 | `CONTENT_REPOSITORY_UNAVAILABLE` |
| repository errors 非空 | 原错误码按原顺序复制 |
| 读取结果为空且无更具体错误 | `CONTENT_PACK_EMPTY` |
| supplement 非空但解析失败 | `CONTENT_SUPPLEMENT_INVALID` |

production 读取 canonical pack 后按现有 `_merge_bazaar_day1_catalog()` / `_append_unique_catalog_rows()` 算法合并补充目录；这两个方法迁入该 service 并从 facade 删除。simulation/test 只使用注入包，不访问 repository，也不合并路径补充。

### 6.3 `YsbzsState` 构造合同

字段改为：

```gdscript
var _core_composition: RefCounted = null
var _initialization_result: Dictionary = {
    "schema": "ysbzs.init-result.v1", "ok": false,
    "mode": "production", "source": "", "contentHash": "", "errors": ["NOT_INITIALIZED"]
}
```

构造签名：

```gdscript
func _init(options: Dictionary = {}) -> void
```

仅接受：

| key | 默认 | 规则 |
|---|---|---|
| `mode` | `production` | 仅 production/simulation/test |
| `content_pack` | `{}` | simulation/test 必填；立即深拷贝 |
| `core_overrides` | `{}` | 先构造 composition，再做任何读操作 |

固定顺序：validate option keys/mode -> `CoreComposition.new(core_overrides)` -> `content_load_service.load` -> 保存 `_initialization_result` -> 成功才设置 `game_data`、invalidate content hash、`reset()`。失败时不调用 reset，不 dispatch，不读第二路径。

新增稳定查询：

```gdscript
func is_initialized() -> bool
func initialization_result() -> Dictionary
```

二者只读；result 返回深拷贝。`configure_core_services()` 保留原行为供既有测试运行期替换；长期新代码统一用 constructor `core_overrides`。本 atom 不额外引入“是否已 dispatch”的第二生命周期字段。

### 6.4 SessionFactory 和生产 caller

`session/session_factory.gd`：

```gdscript
static func create_local_result(options: Dictionary = {}) -> Dictionary
static func create_local(options: Dictionary = {}) -> RefCounted
```

`create_local_result` 返回：

```gdscript
{
    "ok": bool,
    "session": RefCounted, # 失败为 null；该字段只在应用边界使用，不序列化
    "initialization": InitResultV1
}
```

它把 `mode/content_pack/core_overrides` 传给 State constructor；只有 initialized 才应用 run seed、board dimensions、history 并创建 `LocalGameSession`。`create_local` 是稳定兼容壳，内部调用 result，失败 `push_error` 后返回 null；不得返回半初始化 Session。

迁移 caller：

- `core_ui/scripts/app/game_controller.gd:39` 使用 `create_local_result`；失败时不 bind session，`push_error("GAME_SESSION_INIT_FAILED:...")`，保持页面未启动状态。
- `core_ui/scripts/debug/battle_debug.gd:49` 使用 result；失败时 `push_error` 并 return，禁止对 null submit。
- `tools/export_public_battle_capture.gd:17` 使用 result；失败退出码固定 `3` 并输出 initialization JSON。
- Session boundary tests 增加 null/failure 分支，原 successful `create_local` API 继续通过。

### 6.5 删除和默认值

从生产 facade 删除：

- `_fallback_game_data()` 447 起。
- 只被 fallback 使用的 `_pet()`、`_enemy()`、`_build_shop()`。
- `reset()` 的 `game_data.get("shop_offers", _build_shop())` 改为 `Array(game_data.get("shop_offers", []))`。

当前 live tests 没有直接调用上述 fixture helper，所以不创建测试副本。未来 demo 必须显式 `mode=test` 并由 test 自己注入 fixture；不得恢复自动 fallback。

### 6.6 测试和失败语义

`smoke_state_initialization_fail_closed.gd` 使用 repository fake 覆盖：

1. production 返回有效 pack：initialized=true，只读一次 canonical path。
2. production 空 pack：`CONTENT_PACK_EMPTY`，state 不 reset，SessionFactory 返回 null。
3. production errors：保持原顺序，不能 fallback。
4. simulation 注入 pack：repository read count 为 0。
5. simulation 空 pack：`CONTENT_PACK_REQUIRED`。
6. supplement 重复 `nodeId`：保持 canonical 首项，新增项只追加一次。
7. 正式现有 content pack 初始化后的第 1.2 节所有 hash/checksum 不变。

focused：

```bash
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_state_initialization_fail_closed.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_modular_content_pack.gd
/opt/homebrew/bin/godot --headless --path . --script tests/session/smoke_session_first_bootstrap.gd
/opt/homebrew/bin/godot --headless --path . --script tests/session/smoke_game_session_boundary.gd
```

允许写入：新 state 自身初始化字段；失败时除 `_core_composition`、`_initialization_result` 外零玩法写入、零 I/O。C2 单提交回滚；不得和 C3 合并。

## 7. C3：无 I/O 模拟与 Manual Flow Preview

### 7.1 C3a `SimulationIoGuard`

NEW `session/simulation_io_guard.gd`，一个实例同时注入五个 repository override key。字段仅有 `_attempts: Array`；它不是玩法状态。

```gdscript
func attempts() -> Array
func clear() -> void
```

实现所有 production repository 的公开方法。每次被调用先追加 `{repository, method, arguments}`，再返回 fail-closed 空值：写方法 `false` 或 `{ok:false,error:"SIMULATION_IO_FORBIDDEN"}`，读方法 `{}` / `[]` / `0`；`content_errors()` 返回 `["SIMULATION_IO_FORBIDDEN"]`。测试以 `attempts().is_empty()` 为成功条件，不能因 guard 拦住了写而把尝试视为成功。

覆盖的 override key：`save_repository`、`replay_repository`、`run_history_repository`、`game_data_repository`、`operation_log_repository`。

### 7.2 C3a `SimulationAuthorityFactory`

NEW `session/simulation_authority_factory.gd`：

```gdscript
func fork(source: Object, options: Dictionary = {}) -> Dictionary
```

返回：

```gdscript
{
    "schema": "ysbzs.simulation-fork-result.v1",
    "ok": bool,
    "authority": RefCounted, # 失败 null，仅 service 内使用
    "ioGuard": RefCounted,
    "sourceStateHash": String,
    "forkStateHash": String,
    "errors": Array[String]
}
```

固定算法：

1. 验证 source 提供 `get_script`、`is_initialized`、`initialization_result`、`_state_hash` 所需能力；失败 `SIMULATION_SOURCE_INVALID`。
2. `payload = AuthoritativeStateCodec.capture(source, false)`；`content_pack = source.game_data.duplicate(true)`；记录 source hash。
3. 创建一个 guard，把五个 repository key 都指向该 guard；再用 `source.get_script().new({mode:"simulation", content_pack, core_overrides})` 构造 fork。
4. 验证 fork initialized；用 canonical codec restore payload；显式设 `history_recording_enabled=false`、`_history_suspended=true`，清空 history identity/index（这些 history metadata 不在 codec 内）。
5. fork hash 必须等于 source hash，否则返回 `SIMULATION_FORK_HASH_MISMATCH` 并丢弃 authority。
6. guard attempts 必须为空，否则 `SIMULATION_CONSTRUCTION_IO_ATTEMPT`。

禁止：调用 source `reset()`、共享 source composition/service、注册 Session、读取路径、使用 `_capture_runtime_state`。

### 7.3 C3b `ManualFlowSimulationService`

NEW `core/commands/manual_flow_simulation_service.gd`：

```gdscript
func preview(source: Object, action: Dictionary, factory: RefCounted, diff_projector: RefCounted) -> Dictionary
```

输出保持现有 `_preview_manual_flow()` 3354-3421 的完整 public schema，不删键、不改默认：`commands/events/viewModel/beforeCells/beforeCellDetails/cells/cellDetails/cellDiffs/unitDiffs/damageByUnit/projectedStateHash/rolledBack/stateVersion/stateHash/phaseBefore/phaseAfter/roundBefore/roundAfter/timing`。新增可选诊断键只能放在 `simulation` 子对象：

```gdscript
"simulation": {"schema":"ysbzs.simulation.v1", "ioAttempts":0, "isolated":true}
```

固定算法：source snapshot/cells/details/unit rows -> factory fork -> 只在 fork 上循环最多 4 次同一 `dispatch` -> 收集 fork trace/snapshot -> diff -> 验证 source canonical payload/hash/version 未变且 guard attempts 为空 -> 返回。任何失败返回现有 schema 的空投影并加 `ok=false/errors`，source 零写。

`_next_manual_flow_command_type()` 3422-3434 迁入 service；命令顺序固定 `RUN_PLAYER_ALL_OUT` 后 `END_PLAYER_TURN`。`_all_cell_details()` / `_unit_diff_rows()` 暂留 facade，C5 再迁。

### 7.4 facade 与旧路径删除

- `_preview_manual_flow()` 保留一个 atom 的稳定 private 壳，只调用 composition service；C5c 完成 query 接线后删除该壳，并让 Command handler 直接调用 service 的 facade public adapter。
- 同一 C3b 提交删除 `_capture_runtime_state()` 3461-3530、`_restore_runtime_state()` 3531-3598。
- `_manual_flow_preview_resolving` 若 C3 后无生产/Port引用，同提交删除；不能保留为“也许有用”。
- 不新增 runtime codec。

### 7.5 专项测试

`smoke_manual_flow_simulation_isolation.gd` 必须在临时 `user://` history/log/save/replay root 上覆盖：

1. source 开启 run history，执行 preview 前后 canonical payload、stateHash、stateVersion、history metadata、command log、trace、RNG counters 完全相等。
2. preview 前后 history 文件树、operation JSONL、save/replay 文件树字节级相等。
3. preview 结果与在独立 production test state 上执行相同命令的 projected Snapshot/Trace/diff 相等。
4. canonical `defeated_units` 与 `reward_fallback_audit` 在 fork 中保真，防止重现旧 capture 漂移。
5. limit 0/1/4、非 battle、首命令拒绝、第二命令拒绝均有固定结果。
6. guard `attempts()` 始终为空；非空即失败，不是警告。

focused：

```bash
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_manual_flow_simulation_isolation.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_action_preview_single_source.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_placement_damage_preview.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_authoritative_state_codec.gd
```

C3a、C3b 分两个提交；C3b 可回滚而保留 factory 供 C8 使用。

## 8. C4：品质成长纯 Policy

### 8.1 方法闭包与目标签名

把下列冻结方法 814-998 迁入 NEW `core/party/quality_progression_policy.gd`：

`_normalize_quality`、`_quality_key`、`_next_quality`、`_quality_data`、`_shape_size_for_unit`、`_quality_growth_for`、`_quality_upgrade_for`、`_quality_existing_category_hit_probability`、`_quality_known_categories`、`_pick_from_list`、`_choose_quality_evolution_category`、`_element_slots_for_evolution`、`_build_quality_evolution_points`、`_summarize_quality_evolution_points`、`_apply_quality_progression`。

其中 normalize/key/next/summarize 直接复用 `QualityRules`，不复制常量。

公开签名：

```gdscript
func progress(unit: Dictionary, context: Dictionary, fill_hp_to_max: bool) -> Dictionary
```

`context` 严格为：

```gdscript
{
    "gameData": Dictionary # 正式 content pack 深拷贝
}
```

返回：

```gdscript
{
    "schema": "ysbzs.quality-progression-result.v1",
    "ok": bool,
    "unit": Dictionary,       # 完整 next unit
    "changes": Array,         # {field, before, after}
    "errors": Array[String]
}
```

Policy 第一行复制 unit，所有现有算法只改副本；原入参逐字不变。确定性 seed 继续来自 unit 的 `quality_growth_seed/pet_id/id/name` 和 `quality_upgrade_seed`，不得调用时间或全局 RNG。

### 8.2 六个生产 caller 的固定替换

| caller | 冻结调用行 | 替换方式 |
|---|---:|---|
| `_clone_units` | 586 | `unit = _progressed_unit_or_fail(unit, true)`；失败时跳过该 unit 并 push error，不能追加半成品 |
| `_add_pet_to_roster` merge | 1171 | 先 progress 局部 `existing`，ok 后一次写 `roster[index]` |
| `_add_pet_to_roster` new | 1207 | 先 progress 局部 `pet`，ok 后 append |
| `_upgrade_roster_pet_for_event` | 6174 | 先设置局部 quality，再 progress，ok 后写回；失败返回 `{}` 且 roster 不变 |
| `start_battle` deployment | 6458 | facade 先把 active roster 映射为 progressed 副本；删除 `prepare_player_deployment` 的 `apply_quality` callback |
| `_spawn_team_from_templates` | 6528 | progress 局部 pet，ok 后再设置 cell/side 并 append |

新增 facade helper：

```gdscript
func _quality_progression_context() -> Dictionary
func _progressed_unit(unit: Dictionary, fill_hp_to_max: bool) -> Dictionary
```

`_progressed_unit` 返回 Result，不允许返回裸 unit；调用者必须检查 `ok`。它是 composition adapter，C4 完成后删除原 15 个 private 算法方法和 `_apply_quality_progression`。

更新 `BattleStartupService.prepare_player_deployment`：删除 `apply_quality` callback 和对应 `_call`；传入 roster 已经是 progressed 副本。其他 deploy/mechanic callback 本阶段不改。

### 8.3 测试 caller 迁移与断言

- `tests/core/smoke_quality_upgrade_selection_policy.gd` 不再调用 state private method，直接测 `QualityProgressionPolicy.progress`。
- `tests/helpers/singleplayer_smoke_suite.gd` 和 quarantine quality 测试改用 policy fixture helper；禁止为测试保留 facade 壳。
- 新增/扩展 purity 断言：input unit、context 在成功/失败后均深等价；同 seed 100 次相等；不同 seed 只影响原算法允许的 upgrade/evolution selection。
- 四个 quality runtime/effect tests 保持通过，证明 progression 没吞并 mode/mark/runtime Hook。

focused：

```bash
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_quality_upgrade_selection_policy.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_quality_runtime_service.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_quality_runtime_command_contract.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_quality_effect_strategy.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_quality_effect_full_hooks.gd
```

允许写入：Policy 零写入输入；facade 只在 Result ok 后写一个局部 unit/roster 元素/append。一个提交包含 policy、composition、六 caller、BattleStartup 合同、tests、inventory；整体回滚。

## 9. C5：Battle Query 分四个原子迁移

### 9.1 为什么分四个 atom

冻结查询闭包跨 `game_state.gd:2339-3460`，并与 ActionSlot、DamagePreview、AutoPosition 和 UI cell detail 共享低层能力。一次整体搬迁会让 parity 失败无法定位，因此固定拆为：

- C5a：Context、ActionSlot projection 和纯格式器。
- C5b：action preview / threat / board 投影。
- C5c：cell detail / manual flow 查询接线。
- C5d：`_cell_detail_unit`，等待并发 owner 释放。

### 9.2 `BattleQueryContextV1`

NEW `core/commands/battle_query_context.gd` 只负责验证、正规化和深拷贝，不接收 authority：

```gdscript
static func build(values: Dictionary) -> Dictionary
static func validate(context: Dictionary) -> Array[String]
```

context 固定 schema：

```gdscript
{
    "schema": "ysbzs.battle-query-context.v1",
    "phase": String,
    "stateVersion": int,
    "battleRound": int,
    "difficulty": String,
    "board": {"width": int, "height": int},
    "selection": {"unitId": String, "slotIndex": int, "ap": int},
    "units": Array[Dictionary],
    "defeatedUnits": Array[Dictionary],
    "leaders": {"player": Dictionary, "enemy": Dictionary},
    "cellElements": Dictionary,
    "boardTraces": Dictionary,
    "actionDirections": Dictionary,
    "actionApChoices": Dictionary,
    "placementDamageByUnit": Dictionary,
    "gameData": Dictionary
}
```

必填键缺失时 `validate` 返回 `BATTLE_QUERY_CONTEXT_MISSING:<key>`；board 非正数返回 `BATTLE_QUERY_BOARD_INVALID`。`build` 对所有容器深拷贝。context 不含 Object、Callable、Node、Repository 或 authority。

Facade 新增一个 adapter：

```gdscript
func _battle_query_context() -> Dictionary
```

它只读当前字段，调用 `_leaders()` 得到值后交给 `BattleQueryContext.build`。它不得缓存 context；每次 Snapshot/Command 查询只构造一次并在同一调用内复用。

### 9.3 `BattleQueryProjector` 构造和能力

NEW `core/commands/battle_query_projector.gd`：

```gdscript
func configure(
    action_slot_service: RefCounted,
    attack_option_service: RefCounted,
    targeting_service: RefCounted,
    stat_query_service: RefCounted,
    quality_effect_registry: RefCounted,
    quality_hit_context_projector: RefCounted,
    threat_target_policy: RefCounted,
    damage_resolver: RefCounted,
    stat_semantic_pipeline: RefCounted
) -> RefCounted

func action_slots(context: Dictionary, unit: Dictionary) -> Array
func project_action_grid(context: Dictionary, request: Dictionary) -> Array
func project_board(context: Dictionary) -> Dictionary
func project_cell_detail(context: Dictionary, request: Dictionary) -> Dictionary
func project_all_cell_details(context: Dictionary) -> Array
func project_unit_diff_rows(context: Dictionary) -> Array
func project_damage(context: Dictionary, source: Dictionary, target: Dictionary, amount: int, element: String, trace_context: Dictionary, damage_props: Variant = {}) -> Dictionary
```

所有配置依赖必须是逐 State 的既有无状态 service；Projector 不保存 context 或 result。`project_damage` 内按调用构造下面的 value port，再调用既有 `DamageResolver.preview`；不得构造 authority-backed `DamagePreviewPort`。

NEW `core/ports/value_damage_preview_port.gd` 实现同一个 `ysbzs.damage-preview-port.v1`：constructor 接收 context 深拷贝、`stat_query_service`、`stat_semantic_pipeline`。`leader_guard_active` 从 context units/leaders 的存活数推导；`stat_value` 使用 context.gameData；`is_boss` 机械复制现有纯身份判断；`apply_stat_semantics` 调既有 pipeline。Pipeline 当前要求 `stat_value` Callable 时，只允许 Port 内部把自身只读 `stat_value` 绑定进去；Callable 不得越过 Port 或进入 Result。该 Port 不持有 authority，也没有 mutation 方法。

扩展现有 `ActionSlotService`：

```gdscript
func project_slots(unit: Dictionary, input: Dictionary) -> Array
```

`input` 固定为 `{availableAp, selectedApChoices, directions, shapeDefinition}`。方法体来自 `_action_slots_for_unit`，但 slot key/stored direction/selected AP 直接调用自身现有方法。输入和 unit 不变，返回新 Array。

### 9.4 C5a 精确处置

| 原方法 | 冻结行 | target / 决定 |
|---|---:|---|
| `_action_slots_for_unit` | 2706-2738 | 保留为 facade 必要 adapter，因为 mutation/auto/enemy execution 共用；方法体改为 `ActionSlotService.project_slots` |
| `_selected_action_ap` | 2739-2741 | 保留现有薄 adapter；mutation coordinator 使用 |
| `_selected_action_slot` | 2742-2748 | 保留；mutation coordinator 使用 |
| `_action_slot_key` | 2869-2871 | 保留；auto execution 使用 |
| `_action_slot_direction` | 2872-2876 | 保留；mutation/auto 使用 |
| `_preview_rows_by_cell` | 2926-2941 | MOVE 到 Projector private `_preview_rows_by_cell`；删除 facade |
| `_active_preview_row` | 2942-2953 | MOVE 到 Projector private；删除 facade |
| `_board_preview_payload` | 2954-2966 | MOVE 到 Projector private；删除 facade |
| `_threat_add_cell` | 3209-3241 | MOVE 到 Projector private；删除 facade |
| `_unit_diff_rows` | 3442-3460 | MOVE 到 `project_unit_diff_rows`；删除 facade |

先新增 `tests/core/dump_battle_query_baseline.gd`，对固定 seed 的 route Snapshot、battle Snapshot、选中单位/槽/方向/AP 后 Snapshot、BUILD_PREVIEW 和两个 cell detail 做 stable JSON SHA-256；把输出保存为 `tests/fixtures/battle_query_baseline_v1.json`。该 baseline commit 必须在移动代码前独立提交，之后只能显式协议任务刷新。

### 9.5 C5b action/board/threat 方法迁移表

以下方法整体 MOVE 到 Projector；facade caller 改为 composition 调用并删除原定义：

| 闭包 | 原方法与冻结行 |
|---|---|
| board | `_board_cells` 2339-2396；`_board_snapshot` 2397-2403 |
| action cells | `_selected_action_cells` 2749-2757；`_action_cells_for_unit` 2758-2787 |
| per-unit summary | `_action_preview_by_unit` 2788-2817；`_action_block_ranges_by_unit` 2818-2846；`_preview_slot_index_for_unit` 2847-2854 |
| selected grid | `_selected_action_preview_by_cell` 2877-2925 |
| request parse | `_preview_unit_for_action` 2967-2990；`_preview_slot_index_for_action` 2991-2997；`_preview_direction_for_action` 2998-3003；`_preview_ap_for_action` 3004-3008 |
| damage/settlement | `_preview_damage_projection` 3009-3028；`_preview_hit_index_for_target` 3029-3034；`_preview_quality_damage_for_hit` 3035-3045；`_preview_settlement_for_cell` 3046-3059 |
| grid | `_build_preview_grid` 3060-3208 |
| threat | `_project_enemy_next_step` 3242-3259；`_threat_grid_by_cell` 3260-3320 |

机械替换规则：

| facade read | Projector read |
|---|---|
| `phase/state_version/battle_round/difficulty` | context 同名键 |
| `board_width/board_height` | `context.board.width/height` |
| `units`、`cell_elements`、`board_traces` | context 深拷贝 |
| `selected_* / ap / action_*` | `context.selection` / action maps |
| `game_data` | `context.gameData` |
| `unit_at/leader_at` | Projector 私有 value lookup，不能回调 facade |
| `_resolved_stat_value` | configured `stat_query_service` + context.gameData |
| `_shape_definition` | `SkillShapeRules.shape_definition(unit, context.gameData)` |
| `_shape_attack_options` / `_attack_option_for_direction` | configured attack option service + quality effect |
| `_enemies_in_attack_option` | configured targeting service + context units/leaders，再由 quality effect 排序 |
| `_quality_cell_damage_delta/_quality_hit_context` | configured quality hit context projector/effect |
| `_preview_resolved_damage` | `project_damage` + `ValueDamagePreviewPort`；不回调 authority |
| `_nearest_player` | configured threat target policy + context values |

`snapshot()` 只构造一次 context，然后填：action slots、selected cells、preview by unit、block ranges、board。Snapshot schema、alias 和 `SnapshotProjector` 不迁。

`_preview_settlement_for_cell` 同时被 C6 auto-position 使用；C5b 删除 facade 后，C6 前的临时调用必须改为 `battle_query_projector.project_settlement(context, ...)`。为避免隐式 private 调用，Projector 增加公开纯方法：

```gdscript
func project_settlement(context: Dictionary, after_elements: Dictionary, element: String, source: Dictionary) -> Dictionary
```

C6 完成后 AutoPositionEvaluator 复用该方法；不复制公式。

### 9.6 C5c cell detail 与 Manual Flow 接线

| 原方法 | 冻结行 | 决定 |
|---|---:|---|
| `_preview_manual_flow` | 3354-3421 | 删除 C3 临时壳；Command 路径通过 facade 新 adapter `_manual_flow_preview(action)` 调用 simulation service |

`ManualFlowSimulationService` 的 unit rows 改用 Projector；在 C5d 完成前 cell details 暂时继续调用 source/fork 的 `_all_cell_details`。C5d 完成后统一改为 Projector。facade 调用 service 时显式传 `beforeQuery`；模拟 service 不缓存 source/fork 任一方。

### 9.7 C5d `_cell_detail_unit` 冲突 atom

冻结 `_cell_detail_for_action` 3321-3353、`_all_cell_details` 3435-3441 和 `_cell_detail_unit` 8002-8049 作为一个 atom。后者由 mouse playtest task 拥有；owner 释放后重新获取三者 caller/行为基线，再分别 MOVE 到 `project_cell_detail`、`project_all_cell_details` 和 Projector private `_project_unit_detail(context, unit)`。三个原 facade 方法只有在以下搜索全部为零时删除：production direct、dynamic、Port、tests/tools direct、tests/tools dynamic。若 UI 仍动态调用，增加公开 Command/Session query，不保留私有 facade 壳。C5d 完成后再删除 ManualFlow 对 source/fork private cell detail 的临时调用。

### 9.8 C5 验收

每个子 atom：

```bash
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_battle_query_projector_parity.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_action_preview_single_source.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_placement_damage_preview.gd
/opt/homebrew/bin/godot --headless --path . --script tests/integration/smoke_command_snapshot_reuse.gd
```

必须断言：fixture 中每个 stable SHA 不变；Projector input/context 不变；source canonical payload/hash/version 不变；重复 3 次结果相同；board cell 数恒等 `width*height`；`ValueDamagePreviewPort` 只实现 `DamageResolver.REQUIRED_PREVIEW_PORT_METHODS` 要求的只读能力且不保存 authority。C5a/b/c/d 各自独立提交和回滚。

## 10. C6：Auto-position 去 authority 反射

### 10.1 `AutoPositionContextV1`

由 facade 在 `_build_auto_position_plan()` 内从 `_battle_query_context()` 扩展：

```gdscript
{
    "schema": "ysbzs.auto-position-context.v1",
    "query": BattleQueryContextV1,
    "side": String,
    "playerSide": "player",
    "easyDifficulty": "easy",
    "actionBudget": int,
    "constrainMovementByUnit": bool,
    "limits": {
        "candidate": int, "targetSignature": int, "approach": int,
        "standby": int, "beam": int, "survivalFinalist": int,
        "actionCountDiversity": int
    }
}
```

全部深拷贝。Evaluator/ReadPort/Planner 零 authority、零 Repository；伤害预估只经 C5 的 `ValueDamagePreviewPort`，其内部为既有 stat semantic contract 绑定的只读 Callable 不得外泄。

### 10.2 `AutoPositionEvaluator` 签名

NEW `core/battle/auto_position/auto_position_evaluator.gd`，配置 `battle_query_projector`、`action_slot_service`、`attack_option_service`、`targeting_service`、`quality_effect_registry`、`quality_hit_context_projector`、`threat_target_policy`、`auto_position_policy`。伤害统一调用 `battle_query_projector.project_damage`，不另配第二个 resolver/公式。公开：

```gdscript
func sorted_units(context: Dictionary, side: String) -> Array
func effective_move_range(context: Dictionary, unit: Dictionary) -> int
func candidates_for_unit(context: Dictionary, unit: Dictionary, options: Dictionary) -> Array
func choices_conflict(choices: Array, candidate: Dictionary) -> bool
func optimization_context(context: Dictionary) -> Dictionary
func decorate_finalists(context: Dictionary, beams: Array, side: String) -> Array
```

`decorate_finalists` 不原地改传入 beams，先深拷贝并返回新 Array。

### 10.3 精确迁移闭包

MOVE 到 Evaluator 并删除 facade：

- `_auto_position_cells_for_unit` 3876-3899。
- `_has_living_non_boss_enemy` 3900-3908。
- `_auto_position_damage_allocation` 3909-3927；若与 `AutoPositionTurnOptimizer._damage_allocation` 完全等价，统一调用 optimizer 的公开方法并删除重复公式。
- `_auto_position_damage_metrics` 3928-4002。
- `_auto_position_current_approach_distance` 4003-4012。
- `_auto_position_approach_distance` 4013-4031。
- `_auto_position_directions_for_slot` 4038-4042。
- `_auto_position_candidates_for_unit` 4043-4216。
- `_auto_position_choices_conflict` 4226-4235。
- `_auto_position_choice_positions` 4242-4255。
- `_auto_position_retaliation_summary` 4256-4276。
- `_auto_position_projected_player_states` 4277-4291。
- `_auto_position_on_death_incoming` 4292-4314。
- `_auto_position_retaliation_metrics` 4315-4388。
- `_auto_position_attach_retaliation_to_final_beams` 4401-4414。

以下 facade wrapper 删除，直接调用现有 `AutoPositionPolicy`：`_auto_position_candidate_is_better` 4032、`_auto_position_target_signature` 4035、`_auto_position_enemy_response_is_better` 4389、`_auto_position_evaluation_is_better` 4392、`_auto_position_prune_beams` 4398。C0 已删除的三个 dead wrapper 不恢复。

保留在 facade：

- `_has_used_action_slot`、`_effective_move_range`、`_enemy_attack_count`：仍被 reset/move/enemy execution/cell detail 使用。
- `_unit_ids`：仍被 enemy action 使用；C6 不为单一算法强迁。
- `_auto_position_applied_state_signature`、`_reuse_applied_auto_position_result`：权威幂等/重用判断。
- `_build_auto_position_plan`：薄 composition adapter。
- `auto_position_heroes`、`_apply_auto_position_moves_atomically`：验证、原子写、AP/方向、Trace/Result owner。

### 10.4 `AutoPositionReadPort` 重写

保留路径和 planner 调用形状，但 constructor 变为：

```gdscript
func _init(context: Dictionary, evaluator: RefCounted) -> void
```

字段只保存 context 深拷贝和 evaluator。所有方法直接调用 evaluator；删除 `_core`、全部 `_core.call()` 和 `_core.get()`。`decorate_finalists` 返回 Array；相应修改 Planner 从返回值重新赋 `beams`。Planner 的最终 public plan schema 和 priority 顺序不得改变。

### 10.5 测试和冻结行为

```bash
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_auto_position_candidate_purity.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_auto_position_turn_optimizer.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_auto_position_planner_composition.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_auto_position_search_precision.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_auto_position_kill_then_damage.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_auto_position_survival_aware.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_auto_position_difficulty_direction.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_auto_position_difficulty_order_independence.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_auto_position_execution_parity.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_enemy_auto_position_by_ap.gd
```

新增断言：Evaluator 的 context/unit/choices/beams 均不变；同 context 结果逐字相等；Planner/ReadPort 源码不含 `_core.call` / `_core.get`；调用 `_build_auto_position_plan` 不改 canonical payload，只有 `auto_position_heroes` 成功提交才写。一个提交完整包含 evaluator、read port、planner、composition、facade、tests、inventory；整体回滚。

## 11. C7：Player Operation Log 纯投影

### 11.1 目标合同

NEW `core/logging/player_operation_projector.gd`：

```gdscript
func state_summary(context: Dictionary) -> Dictionary
func event_summaries(events: Array, defaults: Dictionary) -> Array
func result_summary(value: Variant) -> Variant
func new_logs(before_logs: Array, after_logs: Array) -> Array
```

`state_summary` context 必填：`phase/day/nodeIndex/battleRound/battlePeriod/difficulty/boardWidth/boardHeight/stateVersion/selectedUnitId/selectedActionSlotIndex/ap/coins/heroHp/units`。输出键和冻结 `_player_operation_state_summary()` 1608-1641 完全一致；`boardLabel` 由 width/height 本地格式化。

`event_summaries` defaults 为 `{round, phase}`，输出键和冻结 1642-1673 一致。`result_summary` 直接用 `CommandContract.replay_json_safe`，Array 超过 32 项时保留原 `itemCount/firstItems`。`new_logs` 机械复制 1683-1700 overlap 算法，但两个输入均深拷贝。

### 11.2 caller 和顺序

迁移 `run_command`、`save_to_user`、`load_from_user` 的 before/after summary；同一位置调用 projector，不能延后到 Repository append 后。删除 facade 四个原方法。`_append_player_operation` 保留在 facade，继续唯一拥有 timestamp、system time、path、Repository append 和 warning；Projector 绝不读取时间或 I/O。

测试：扩展 `smoke_player_operation_log.gd`，对 accepted/rejected/view/save/load 的 JSONL entry 做完整 key/value/order 语义对比；模拟 preview 不产生 entry；projector input 不变；Repository append 仍恰好一次。

```bash
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_player_operation_log.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_read2_damage_attribution_logging.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_shield_damage_feedback.gd
```

一个提交；回滚不影响 C3 simulation，只恢复四个纯 helper。

## 12. C8：Replay Builder 补全与无 I/O Verifier

### 12.1 Factory 补充的 fresh create

C3a 实施时同时提供：

```gdscript
func create(authority_script: Script, content_pack: Dictionary, options: Dictionary = {}) -> Dictionary
```

它用 simulation mode + I/O guard 创建 reset 后的新 authority，不 restore source payload。options 只允许 `seed/boardDimensions`；固定顺序为 constructor -> dimensions -> seed -> hash -> guard check。`fork` 内部复用 `create` 后再 canonical restore。这样 `_replay_initial_state_hash` 和 verifier 不再自行 `get_script().new()`。

### 12.2 `ReplayBuilder.build`

扩展既有 `persistence/replay_builder.gd`：

```gdscript
static func build(input: Dictionary) -> Dictionary
```

input 必填：

```gdscript
{
    "schema": String, "schemaVersion": int, "replayVersion": String,
    "legacyReplayVersion": String, "dataVersion": String,
    "rulesVersion": String, "rngVersion": String,
    "determinism": Dictionary, "seed": String, "day": int, "period": String,
    "result": Dictionary, "initialOptions": Dictionary, "initialHash": String,
    "commandLog": Array, "storedDebugTimeline": Array, "battleTrace": Array,
    "stateVersion": int, "stateHash": String, "phase": String, "round": int,
    "units": Array
}
```

输出机械保持冻结 `replay_document()` 7461-7536 的所有字段和默认。Builder 调用自身 `command_stream/debug_timeline/...`，不算 checksum、不读 authority、不读 Repository。Facade `replay_document()` 只负责 sanitize options、用 factory fresh create 得 initial hash、组 input、调用 build、最后 `DocumentCodec.replay_checksum`。

### 12.3 `ReplayVerifier`

NEW `persistence/replay_verifier.gd`：

```gdscript
func verify(replay: Dictionary, context: Dictionary, factory: RefCounted) -> Dictionary
```

context：

```gdscript
{
    "authorityScript": Script,
    "contentPack": Dictionary,
    "contentHash": String,
    "rulesVersion": String,
    "rngVersion": String,
    "defaultBoardDimensions": Vector2i
}
```

固定校验顺序和错误码保持冻结 7551-7632：schema -> schemaVersion -> replayVersion -> content -> rules -> RNG -> checksum -> board dimensions -> fresh simulation init -> initial hash -> 逐 command checkpoint -> final。每一步首错即返回，checkpoint schema 逐字保持。

Verifier 使用 `factory.create`，只在模拟 authority 上 `dispatch`；guard attempts 非空返回新错误 `REPLAY_VERIFICATION_IO_ATTEMPT`。source canonical payload/hash/version/history/files 必须不变。

### 12.4 facade 保留与删除

保留稳定公开入口：`replay_document`、`verify_replay_document`、`save_replay_to_user`、`save_battle_trace_to_user`。删除：

- `_replay_initial_state_hash` 7682-7690；由 factory result 提供。
- C0 未删除且只转发 ReplayBuilder 的 private wrapper，在 METHOD_INVENTORY 外部 caller 为零后直接改 caller 调 `ReplayBuilder` 并删除。
- `verify_replay_document` 的内联 verifier body；保留一行 composition adapter。

Repository 仍只由 save-to-user 方法调用；不创建总 `PersistenceService`。

### 12.5 测试

新增 `tests/core/smoke_replay_verifier_isolation.gd`：合法 replay、8 个既有错误码、每个 checkpoint mismatch、final mismatch、无 I/O、source 全字段/文件树不变。另跑：

```bash
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_replay_verifier_isolation.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_persistence_composition_boundaries.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/smoke_authoritative_state_codec.gd
/opt/homebrew/bin/godot --headless --path . --script tests/integration/smoke_singleplayer_persistence.gd
/opt/homebrew/bin/godot --headless --path . --script tests/integration/smoke_save_migrations.gd
/opt/homebrew/bin/godot --headless --path . --script tests/integration/smoke_save_system.gd
/opt/homebrew/bin/godot --headless --path . --script tests/core/dump_puzzle_refactor_baseline.gd
```

Builder 与 Verifier 分两个提交；Verifier 可回滚而保留已完成的纯 Builder。

## 13. C9：最终删除、依赖审计与完成门禁

### 13.1 必须留在 facade 的最终责任

- 权威字段、`_init/reset`、composition adapter 和 initialization status。
- `dispatch/run_command` 事务、Command handler/Port 稳定能力、exactly-once record。
- `snapshot` schema assembly 与 public alias；内部 board/query 委托 Projector。
- save/load/replay/history 的公开 facade；内部 Builder/Verifier/Repository 分责。
- `_execute_selected_action_option`、`_finish_battle_result`、start/round/end 等严格顺序 mutation coordinator。
- `auto_position_heroes` 和原子应用。
- Port `REQUIRED_METHODS` 明确要求的 capability。

上述方法可以缩短但不因大而强迁。

### 13.2 最终必须为零

| 禁止项 | 检查 |
|---|---|
| 第二 runtime field registry | 除 `AuthoritativeStateCodec.FIELD_SPECS` 外不得出现 capture 字段常量表 |
| source 上 preview capture/restore | facade 不含 `_capture_runtime_state/_restore_runtime_state` |
| 自动 production fallback | 不含 `_fallback_game_data/_pet/_enemy/_build_shop` production helper |
| AutoPosition authority reflection | `auto_position_read_port.gd` 不含 `_core.call/_core.get` |
| 私有永久转发壳 | 本包 MOVE/DELETE 方法不再定义于 facade，保留表明确列出的除外 |
| Service 持有 authority | ownership smoke 搜索新增 service 的 `_authority/core/self` 字段与 constructor |
| 纯 service 写路径 | 新 Policy/Projector/Evaluator/Builder 不引用 `FileAccess/DirAccess/Time/OS/user://` |
| 测试耦合 private facade | quality/query/auto/op-log tests 不直接调用已迁 private 方法 |

### 13.3 完成矩阵

每个 atom 的任务卡必须附：

| 证据 | 必填结果 |
|---|---|
| source fingerprint | 实施前 SHA、方法数、并发 diff |
| caller closure | direct/dynamic/Port/lifecycle/test 五类均有结论 |
| ownership | target 唯一 owner、无重复 service |
| purity | input/source before-after deep equality |
| ordering | 原协调顺序 golden/trace 通过 |
| failures | 本 atom 所列全部错误/拒绝路径通过且零部分写 |
| I/O | preview/replay guard 0 attempts，文件树不变 |
| contracts | 第 1.2 节全部金丝雀不变 |
| cleanup | old path 和临时壳按表删除 |
| regression | focused + P0 + inventory + fast 全绿 |
| Git | 精确 staged 文件清单、独立 commit、任务归档 |

### 13.4 何时可以宣布完成

只有 C0-C9 的 task card 均归档、C5d 冲突已解决、完成矩阵无空项，且第 1.2 节金丝雀与正式 fast suite 通过，才能把总纲状态从 `IMPLEMENTATION_READY / NOT_IMPLEMENTED` 改为 `IMPLEMENTED / VERIFIED`。

若某 atom 因 live source 变化无法按本包执行，状态退回 `ARCHITECTURE_READY / REBASE_REQUIRED`，记录变化证据并只重做受影响 atom；不得用“基本一样”继续实施。

## 14. 普通程序员的交付拆分

建议每张实现任务卡只领一个 atom：

1. `C0-dead-code`。
2. `C1-snapshot-purity`。
3. `C2-content-init`。
4. `C3a-simulation-factory`。
5. `C3b-manual-flow-preview`。
6. `C4-quality-policy`。
7. `C5a-query-context-formatters`。
8. `C5b-query-board-preview`。
9. `C5c-query-cell-manual-flow`。
10. `C5d-query-unit-detail`。
11. `C6-auto-position-evaluator`。
12. `C7-operation-projector`。
13. `C8a-replay-builder`。
14. `C8b-replay-verifier`。
15. `C9-final-audit`。

不得把 C2+C3、C5 全部、或 C6+C8 合并为一个超大提交。实施者遇到本包未定义的 public schema 改动、第二写路径、跨 atom owner 冲突或金丝雀漂移时，停止并升级架构裁决；普通算法调试和测试修复不构成重新做架构。

## 15. 实施结果与提交矩阵

### 15.1 原子提交

| Atom | 实施提交 | 归档提交 | 已落位责任 |
|---|---|---|---|
| C0 | `3c1ce75` | `4d05ff9` | 确认无 caller 堆积删除 |
| C1 | `0b1a60b` | `55cdc05` | Snapshot purity 与 roster 写点收紧 |
| C2 | `9293c9d` | `6981f8e` | constructor/content fail-closed |
| C3a | `c6c1aef` | `a888f63` | no-I/O simulation authority factory |
| C3b | `a865406` | `f66397e` | isolated manual-flow simulation |
| C4 | `0800955` | `4a4b05e` | pure quality progression policy |
| C5 baseline | `1f9465d` | `dc61a6a` | Battle Query frozen corpus |
| C5a | `04d0dca` | `ff13778` | immutable query context / formatters |
| C5b | `3dbb4e9` | `834e399` | board/action preview projection |
| C5c | `e77fb66` | `8a75f55` | manual-flow/query projection |
| C5d | `4a93e0e` | C9 收口归档 | cell detail projection 与旧壳删除 |
| C6 | `e36f933` | `a5b0875` | AutoPosition evaluator 与 immutable read boundary |
| C7 | `6bcff91` | `611f1ef` | player operation pure projector |
| C8a | `63c9a71` | C9 收口归档 | replay document builder |
| C8b | `39c615d` | C9 收口归档 | isolated replay verifier |
| C9 | `806017d` | 独立任务归档提交 | 完成矩阵、全门禁与最终对比 |

每个实现 atom 均可按自己的实现提交独立回滚；归档提交只移动任务卡和更新任务索引，不承载运行代码。

### 15.2 最终完成矩阵

| 证据 | 最终结果 | 结论 |
|---|---|---|
| source fingerprint | 8049→6096 行，518→416 methods；SHA `09906eea...` | PASS |
| caller closure | direct/dynamic/Port/lifecycle/test 重扫；已迁私有入口无生产 caller | PASS |
| ownership | 53 services，47 direct + 6 injected-only；无孤儿/重复 owner | PASS |
| purity | Snapshot、Projector、Evaluator、Policy、Builder source before/after 不变 | PASS |
| ordering | action/trace/log/history 与 Battle Query golden 保持 | PASS |
| failures | content/init、command、replay 首错与拒绝路径零部分写 | PASS |
| I/O | preview/replay guard 无 attempt，source 文件树不变 | PASS |
| contracts | P0、save/replay checksum、六份 Battle Query golden 全部不变 | PASS |
| cleanup | capture/restore、production fallback、authority reflection、迁移壳归零 | PASS |
| regression | 20/20 关键测试，正式 fast 15/15，inventory 与 `git diff --check` 通过 | PASS |
| Git | 逐 atom 精确提交；并行 Q0/presentation/Claude WIP 未吸收 | PASS |

### 15.3 最终验证证据

clean validation worktree：`/private/tmp/codex-c5d-final-validation.gv6eyZ`。先执行完整 Godot import，再运行 `python3 tools/qa/run_qa.py --suite fast`，结果 15/15，证据目录为 `output/validation/qa/20260803-193042-fast`。

同一提交树上 20 个关键测试全部通过：Snapshot purity、state initialization fail closed、Session first bootstrap、simulation authority factory、manual-flow isolation、quality policy、Battle Query parity、AutoPosition 四组 purity/composition/precision/parity、operation log、Replay Builder/Verifier、authoritative codec、save migrations、core layer、composition ownership/complete 和 architecture boundary。

最初 clean worktree 使用 `--skip-import` 得到 10/15，是因为该 worktree 尚未生成 `.godot/imported`；完整导入后同一受 Git 管理的资源得到 15/15。该历史结果不是资产缺失，也不是交付例外。

### 15.4 规格可执行性回证

原包要求普通程序员不再自行决定 owner、schema、caller、顺序、失败、测试和回滚边界。实际实施中 C0-C9 均能按一个 atom 一笔实现提交完成，只有两类 live rebase：C5d 等待并发 lease 后迁移 cell detail；C9 更新已提交 Presentation owner 的 architecture assertion。两者都按冲突/重基线规则处理，没有改动架构不变量。

这证明本包达到 `IMPLEMENTATION_READY` 颗粒度；完成矩阵全绿后，状态升级为 `IMPLEMENTED / VERIFIED`。
