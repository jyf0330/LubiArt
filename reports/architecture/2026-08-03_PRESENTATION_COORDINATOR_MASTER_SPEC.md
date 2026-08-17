# 2026-08-03 单一 command/presentation coordinator — 纵切总纲规格（MASTER）

author: Claude（架构师）
status: IMPLEMENTED_VERIFIED（见 §13 实施闭环）
基准: BattleScene 交付 `802249d`；收口时 `HEAD=dacb290`，目标文件无并行漂移
兼容标准: `.claude/skills/godot-latest-sts2-adoption` + `.claude/skills/godot-latest-task-delivery` + `docs/15_STS2_GUIDED_ARCHITECTURE_MAP.md`
执行方: Codex（或实现方）逐阶段领租约，每阶段一个提交，精确暂存，不推送

## 0. 一句话

把当前"命令响应、外部快照、战斗 trace"**三条并存的表现入口**收敛为**单一串行表现协调器**（PresentationCoordinator）：所有"权威状态变化 → UI 渲染 → 动画播放 → 表现完结"走一条 FIFO 串行流水线；以 `reason` 显式分离"命令确认快照"与"外部同步快照"；补齐连点、乱序响应、战斗结算切页、节点销毁四类回归测试。**不照搬 STS2 GameAction 类树**（§2 裁决）。

## 1. 冻结契约（现状基线，P0 冻结对象）

以下行为用 live 行号钉死。**P0 阶段先用新增 focused 测试冻结，再开始任何分离改动。**

### 1.1 命令确认快照（command confirmation snapshot）

- 权威结算：`submit_command_and_wait` 返回 response（含 `snapshot` / `commandId` / `actionId` / `accepted` / `pending` / `actionStatus`）。
- session 层**同时** emit `snapshot_received(reason="command")`：
  - 本地 `session/local_game_session.gd:40`（`_snapshot_metadata` → `asynchronous=false`，L113-120）
  - 远程 `session/remote_game_session.gd:281`（`_apply_confirmed_snapshot(…, &"command", false)`，恒 `asynchronous=true`）
- bridge 丢弃命令确认快照（`core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd:81-84`）：
  ```gdscript
  if not bool(metadata.get("asynchronous", false)) or _awaiting_commands > 0:
      return
  ```
  本地全弃（async=false）；远程在 `_awaiting_commands > 0` 期间弃（submit_command L30 先 +1，await L31 返回后 -1）。
- **不变量 A：UI 层的命令确认快照唯一来源是 submit_command 的 response 返回值；`snapshot_received(reason="command")` 从不进入 UI。**
- 测试钉子：`tests/session/smoke_game_session_boundary.gd:147` `_snapshot_count == 1`（session 层命令**必须** emit，删除发射会破坏此契约）。

### 1.2 外部同步快照（external sync snapshot）

- 来源与 reason：remote reconnect `&"reconnect"`（L258，force=true）、local `&"load"`（L75）、local `&"history_resume"`（L102/109）。
- bridge 过滤后（async && `_awaiting_commands==0`）→ `asynchronous_snapshot_received` → `game_controller._on_asynchronous_snapshot_received`（`game_controller.gd:203-209`）→ `await three_choice.render_snapshot(snapshot, true)` → `_release_features_not_required`。
- **local load / history_resume（async=false）不经过此路径**，而是经 `game_controller._on_session_operation_requested`（L183-200）的返回值路径 `complete_session_operation_request`（`three_choice_scene.gd:193-195`）。
- **不变量 B：remote reconnect/push 经 asynchronous_snapshot_received 进入 UI；local load/history_resume 经 session-operation 返回路径进入 UI。**

### 1.3 表现完结（presentation settled）

- 非战斗：`three_choice.render_snapshot`（L144-152）→ `_transition_to_view` → `presentation_settled.emit()`（L1140/1164/1181）→ `game_controller._on_three_choice_presentation_settled`（L212-213）→ `_release_features_not_required`。
- 战斗：`three_choice.render_battle_command_response`（L160-178）→ battle_view `render_snapshot`（L208）→ `_play_new_trace_events` 增量（L716-728，游标 `_rendered_trace_count` L53）→ `play_battle_trace` → vfx `trace_sequence_finished` → `battle_scene._on_trace_sequence_finished`（L756-784，先落位 `_pending_final_snapshot` L86，再解锁 L778，再 emit L784）→ `three_choice._await_battle_trace_sequence`（L1440-1445，`await _battle_view.trace_sequence_finished`）→ `presentation_settled`。

### 1.4 战斗结算切页（冻结行为）

`three_choice_scene.gd:173-178`：
```gdscript
if String(command.get("type", "")) == "RUN_COMBAT_ROUND" \
        and String(after_snapshot.get("phase", "")) != "battle":
    _render_battle_view(after_snapshot)
    await _await_battle_trace_sequence()
var target_view := _render_content_from_state(after_snapshot)
await _transition_to_view(target_view)
```
战斗结束那一条命令：先渲染战斗终局，等 trace 播完，再切到战后视图。

### 1.5 现有时序防护（保留为冻结输入）

- `three_choice._is_transitioning` 门闩（L70，检查点 L1434）
- `battle_scene._battle_input_locked`（L84）
- bridge `_awaiting_commands` 计数（L7）
- vfx `_trace_queue` 串行门闩（`battle_vfx_controller.gd`）
- remote `STALE_SERVER_SNAPSHOT` 版本防护（`remote_game_session.gd:272-279`）

### 1.6 双提交路径（现状）

- 路径 1：`three_choice._submit_core_command`（L1576-1598）emit `command_requested(command, request_id)` → `await command_response_received`，轮询本地 `_command_responses`。
- 路径 2：`game_controller._on_command_requested`（L176-180）→ `await submit_command` → `complete_command_request(request_id, response)` 回填。
- 战斗：`game_controller._submit_battle_command`（L229-237）→ `three_choice.render_battle_command_response`。
- 两条路径都以 `request_id` 会合；战斗路径无 `request_id`（走 `render_battle_command_response`）。

## 2. 关键架构裁决（对齐 docs/15 L59-60）

| STS2 live 证据 | 本项目落点 | 裁决 |
|---|---|---|
| `Sts2RecoveredFull/src/Core/GameActions/GameAction.cs:32` 抽象基类 + L36-40 三个 `TaskCompletionSource`（pause/executeAfterResumption/completion）+ L154 `ResumeAfterGatheringPlayerChoice` + L174 `PauseForPlayerChoice` | 玩家输入只形成 Command（已满足）；现有 `GameSession + ActionLifecycle`（queued/awaiting_choice/executing/terminal）已是命令生命周期 seam | **不迁移类树**（docs/15 L59-60 已裁定：不复制类树、不重复造 pause/resume 第二套） |
| `OnEnqueued(Action<GameAction> afterFinished, uint id)` 串行执行 + 完成回调 | PresentationCoordinator `_processing` 门闩 + FIFO 队列（复用 vfx `_trace_queue` 同构门闩，非新抽象） | **迁移**（语言无关不变量：单一串行执行 + 明确完成时机） |
| 动作完成在 checksum 前（JustBeforeFinished 语义） | `presentation_settled` 在表现完毕、权威快照落位后触发（§4.4 尾部合并） | **迁移**（完成时机 = 表现完结，语义对应） |

**不迁移清单（钉死）**：GameAction 类树、pause/resume continuation、actionManager 优先级队列、`OwnerId`/`RecordableToReplay` 式动作元数据。原因：本项目权威已在 session 层（Command handler 已分离输入），表现层只需要"串行排队渲染"，不需要"输入暂停/恢复"；重复建类树违反 docs/15 L60。

## 3. 现状风险清单（P3 回归测试目标）

| # | 风险 | live 证据 | 机制 |
|---|---|---|---|
| R1 | 连点绕过 UI 锁 → 双提交 | 双提交路径（§1.6）+ `_is_transitioning`/`_battle_input_locked` 仅各自视图内生效 | 无跨层统一门闩；命令提交与渲染不串行 |
| R2 | 乱序响应 / 播放期间到达新快照 | remote `_pending` 延迟派发 + `STALE_SERVER_SNAPSHOT` 只挡版本回退 | 播放期间到达的更新快照无统一"落位最新"语义；external 与 command 可互相穿插 |
| R3 | 战斗结算切页悬挂 | `_await_battle_trace_sequence`（L1440-1445）在 battle view 被释放后 `await` 永不发射 | battle view 释放与 trace 播放不串行；`_on_asynchronous_snapshot_received`（game_controller L203-209）不等待 trace 就释放 feature |
| R4 | 节点销毁 → 表现卡死 | 上述 await + `_pending_final_snapshot` 落位依赖 battle view 存活（L756-784） | await 链挂在页面（three_choice/battle）而非常驻宿主 |
| R5 | 双路径渲染 | 同一快照可经 response 与 snapshot_received 双渲染（reconnect 后紧跟命令） | bridge 计数启发式，非显式 reason 分类 |

## 4. 目标架构：PresentationCoordinator

### 4.1 定位

`core_ui/scripts/app/presentation_coordinator.gd`（RefCounted，**新文件**）。宿主：`game_controller.gd`（game.tscn 常驻，切页不销毁）。是**表现编排层**：

- **不是**命令执行器（命令仍经 GameSession → Command → YsbzsState → Result/Trace/Snapshot）。
- **不是**动画播放器（`battle_vfx_controller` 的 `_trace_queue` 保留）。
- **不是**输入封装（不建 GameAction 类树，§2）。
- 唯一职责：把"权威状态变化 → 渲染 → 动画 → 完结"收敛为**单条串行流水线**，并裁决快照归属与版本。

### 4.2 公开 API

```gdscript
extends RefCounted

signal presentation_settled(snapshot: Dictionary)

func submit_command_request(command: Dictionary, request_id: int) -> Dictionary # 非战斗，完成后返回 response
func submit_battle_command(command: Dictionary) -> bool                         # 战斗，完成后返回 accepted
func enqueue_external_snapshot(snapshot: Dictionary, metadata: Dictionary) -> void
func complete_session_operation(request_id: int, result: Dictionary, operation: StringName = &"") -> void
func reset_for_session() -> void                                             # set_game_session 时清队列/游标
```

内部状态：`_queue: Array`（FIFO）、`_processing: bool`（门闩）、`_generation: int`（Session 替换取消域）、`_last_applied_version/hash/phase`、`_last_trace_cursor: int`（从 battle_scene 提升）、`_job_sequence: int`。播放期间的 external 直接折叠进队列内唯一 external job，不另建第二 pending 状态。

Job 结构：`{"sequence", "kind": "command"|"external", "command", "request_id", "snapshot", "metadata", "accepted"}`。

### 4.3 入队裁决

- `enqueue_external_snapshot(snap, meta)`：
  - `meta.reason == "command"` → **丢弃**。命令确认快照只走 response 路径（§1.1 不变量 A 的显式化，替代 bridge 计数启发式）。
  - `snap.stateVersion < _last_applied_version` → 丢弃（防御；remote STALE 已挡一层）。
  - `_processing == true` 且已有排队 external job → 折叠为最新（写入 `_pending_latest`，防 reconnect 风暴）。
  - 否则入队 `kind=external`。
- `submit_command_request` / `submit_battle_command` → 入队 `kind=command`。
- `complete_session_operation` → 入队 `kind=operation`（保持 session-operation 返回路径，§1.2 不变量 B 不动）。

### 4.4 串行流水线（每 job）

```
_pump():
    while _queue 非空 and not _processing:
        _processing = true; await _execute(_queue.pop_front()); _processing = false

_execute(job):
    match job.kind:
        command:
            response = await session.submit_command_and_wait(job.command)
            _last_applied_version = max(_last_applied_version, version(response.snapshot))
            if 非战斗: view.complete_command_request(job.request_id, response)   # 冻结契约保留
            elif 战斗: view.render_battle_command_response(job.command, response) # 冻结契约保留
            await presentation settled（含 battle trace，见 4.5 销毁安全）
            _release_features_not_required(response.snapshot)
        external:
            view.render_snapshot(snapshot, true)                                  # 冻结契约保留
            await presentation settled
            _release_features_not_required(snapshot)
        operation:
            view.complete_session_operation_request(job.request_id, result)       # 冻结契约保留
    # 尾部合并（对应 STS2 JustBeforeFinished 语义）
    if _pending_latest 非空 and version(_pending_latest) > _last_applied_version:
        _last_applied_version = version(_pending_latest)
        view.render_snapshot(_pending_latest, true)   # 增量：trace 游标已跳过已播
        await presentation settled
        _release_features_not_required(_pending_latest)
        _pending_latest = {}
```

### 4.5 节点销毁安全（R3/R4 修复）

- 所有 `await` 集中在 coordinator（game_controller 常驻宿主）；页面只 emit 请求，不持有 await 链。
- 等待 battle trace 前检查 `is_instance_valid(battle_view)`：视图已释放则跳过动画阶段，直接经 three_choice（常驻）渲染最终快照并 settle。
- `_release_features_not_required` 由 coordinator 在 settle **之后**调用（现在 `_on_asynchronous_snapshot_received` 在渲染前/中就可能释放，是 R3 根因）。

### 4.6 trace 游标提升

- `battle_scene._rendered_trace_count` **保持内部实现**，Coordinator 持有跨 BattleScene 实例的表现游标 `_last_trace_cursor`。
- 按 `a16c16d` 的冻结公开 API，不改变 `render_snapshot(snapshot)` 签名；新增 `configure_trace_cursor(cursor)` / `get_trace_cursor()` 两个纯表现接口，在挂载前注入、每个 job settle 时回读。
- 进入新 battle、load 或 trace 缩短时，以 incoming `battleTrace.size()` 重置游标；同一 battle 重挂载则继承游标，避免重播和旧游标污染新快照。
- 收益：battle view 重挂载/切页不丢播放位置；节点销毁不会把游标和 await 链绑死在页面实例上。

## 5. 分阶段实施计划（每阶段一个提交，精确暂存）

| 阶段 | 内容 | 验证 | 提交 |
|---|---|---|---|
| **P0** | 新增 `tests/presentation/smoke_presentation_frozen_contract.gd` 冻结 §1 契约（T1 不变量 A、T2 不变量 B、T3 battle remount 不重播、T4 战斗结算切页、T5 完结链）。**当前代码全绿**。 | V0（P0 门禁） | 1 |
| **P1** | 分离：bridge `_on_snapshot_received` 由计数启发式改为 `reason` 显式分类（§6 改动清单）。命令确认快照 → 丢弃（reason=command）；reconnect → 转发。**P0 测试仍全绿（行为零漂移的证明）。** | V1 + V0 | 1 |
| **P2** | 新增 `presentation_coordinator.gd`；game_controller 四条渲染入口改经 coordinator（§6 改动清单）；battle trace 游标提升；`_await_battle_trace_sequence` 改销毁安全。**P0/P1 测试仍全绿。** | V1 + V0 | 1 |
| **P3** | 新增四类回归测试：连点、乱序响应、战斗结算切页、节点销毁（§7）。 | V1 + V0 + V2 | 1 |

### P0 冻结测试（`tests/presentation/smoke_presentation_frozen_contract.gd`）

- **T1 不变量 A**：本地 submit_command 后 `snapshot_received(reason="command", async=false)` 被 bridge 丢弃（`asynchronous_snapshot_received` 不发射）；远程（loopback transport）命令响应期间 `_awaiting_commands>0`，reason=command 快照被丢弃。
- **T2 不变量 B**：远程 reconnect（`_on_full_snapshot_received`）且无 pending 命令 → `asynchronous_snapshot_received` 发射。
- **T3 battle remount 不重播**：`battle_scene` 挂载 → 渲染快照 A（trace 游标推进）→ 释放 → 重挂载 → 渲染快照 A（游标重置 -1）→ `_play_new_trace_events` 不重播（`new_events` 空断言）。
- **T4 战斗结算切页**：stub battle view + 虚假 RUN_COMBAT_ROUND response（phase != battle）→ `render_battle_command_response` 先渲染终局、`await trace_sequence_finished`、再 `_transition_to_view`（用信号/调用序断言）。
- **T5 完结链**：非战斗 render_snapshot → `presentation_settled` → 释放回调；battle trace 完结 → `trace_sequence_finished` → three_choice await → `presentation_settled`。

### P1 bridge 改动清单（精确）

`artist_flow_session_bridge.gd:81-84` 替换为：

```gdscript
func _on_snapshot_received(snapshot: Dictionary, metadata: Dictionary) -> void:
    if String(metadata.get("reason", "")) == "command":
        return            # 命令确认快照只走 response 路径（不变量 A）
    if not bool(metadata.get("asynchronous", false)):
        return            # local load/history_resume 仍走 session-operation 返回路径（不变量 B）
    asynchronous_snapshot_received.emit(snapshot.duplicate(true))
```

`_awaiting_commands`（L7/L30-33）**保留不动**（submit_command 仍计数，P2 前作为防御）；P2 收口后若 coordinator 串行化证明其冗余，再删（独立子步骤，带证据）。

**语义等价证明（P1 不破坏冻结行为）**：
- 旧逻辑丢弃集 = {async=false 全部} ∪ {async=true 且 awaiting>0}。
- 新逻辑丢弃集 = {reason=command} ∪ {async=false}。
- async=true 的快照 reason 仅 ∈ {command, reconnect}（remote L281 唯一发射点）；旧逻辑丢弃其中 reason=command 且 awaiting>0 的 → 新逻辑丢弃 reason=command 的全部 → 交集（awaiting>0 时到达的）被新逻辑覆盖；差异仅在 awaiting==0 时 reason=command 快照：旧逻辑**不丢弃会转发**，新逻辑丢弃。核实：awaiting==0 时 remote 不会为本地命令 emit reason=command（本地命令必 await），因此该差异不可达 → 行为零漂移。P0 T1/T2 全绿即证明。

### P2 game_controller 接线（精确）

- `_on_command_requested`（L176-180）：改为 `_coordinator.submit_command_request(command, request_id)`，删除内部 `await submit_command` 与渲染（渲染归 coordinator）。
- `_on_battle_command_requested` / `_submit_battle_command`（L216-237）：改为 `_coordinator.submit_battle_command(command)`（RUN_BATTLE 自动战斗分支 `_run_visible_auto_battle` L240-255 保留，其内部逐条命令也改经 `_coordinator.submit_battle_command`）。
- `_on_asynchronous_snapshot_received`（L203-209）：改为 `_coordinator.enqueue_external_snapshot(snapshot, metadata)`（metadata 由 bridge 透传 reason/stateVersion）。
- `_on_three_choice_presentation_settled`（L212-213）：**删除** feature 释放（改由 coordinator 在 settle 后统一释放，§4.4）。
- `_on_session_operation_requested`（L183-200）：改经 `_coordinator.complete_session_operation`（或保持现状直接返回——实施时选一，P0 测试断言 session-op 路径行为不变）。
- `_prepare_feature_for_snapshot` / `_mount_battle` / `_release_features_not_required`（L305-316）：保留，成为 coordinator 调用的私有工具；`_mount_battle` 的 `render_snapshot(current)`（L273）传 coordinator 游标。
- `set_game_session`（L61-71）：调用 `_coordinator.reset_for_session()`。

## 6. 验证门禁

| 门禁 | 命令 | 期望 |
|---|---|---|
| V0 | `godot --headless --script tests/presentation/smoke_presentation_frozen_contract.gd` | pass（P0/P1/P2 每阶段） |
| V1 | `godot --headless --check-only --script core/state/game_state.gd` | exit 0 |
| V2 | 新增四类回归（§7）：`godot --headless --script tests/presentation/smoke_presentation_regressions.gd` | pass |
| V3 | 状态层三哈希不变：`godot --headless --script tests/core/dump_puzzle_refactor_baseline.gd` | `normalizedSha256` / save / replay 逐项一致（本规格不触碰 authority，哈希必须零漂移） |
| V4 | `git diff --check` | 无输出 |
| V5 | 全量 session + features smoke 回归 | 全绿（含 `smoke_game_session_boundary.gd:147`） |

## 7. 四类回归测试（P3，`tests/presentation/smoke_presentation_regressions.gd`）

| 测试 | 场景 | 断言（期望新行为） |
|---|---|---|
| RG1 连点 | 同一按钮快速触发 N 个命令（绕过 UI 锁，直发 `_coordinator.submit_command_request`） | 命令逐个串行提交；渲染与 `presentation_settled` 一一对应不重叠；`_processing` 永不为真时入队 >1 |
| RG2 乱序响应 | remote loopback 延迟投递两个命令响应 + 播放期间到达外部快照 | 旧版本快照丢弃/不重播；播放期间到达的外部快照在当 job settle 后落位（尾部合并）；UI 最终等于最新权威快照 |
| RG3 战斗结算切页 | RUN_COMBAT_ROUND 结算 phase != battle，trace 播放中收到外部快照 | coordinator 先等 trace 完结，再渲染战后视图，再释放 battle view；无悬挂（加超时断言） |
| RG4 节点销毁 | trace 播放中释放 battle view（模拟 `_release_features_not_required` / 外部快照触发） | coordinator 跳过动画阶段、经常驻 three_choice 落位最终快照、正常 settle；`await` 不悬挂（加超时断言） |

RG3/RG4 必须带**超时门闩**（如 `await get_tree().create_timer(2.0).timeout` 守卫 + settled 计数），否则悬挂会挂死测试进程。实施时给出具体断言工具函数。

## 8. 受影响测试清单（实现方核对）

- `tests/session/smoke_game_session_boundary.gd`（L130-137 本地快照、L147 命令 emit、L177 load reason）——**契约不变，必须仍绿**。
- `tests/session/smoke_remote_game_session.gd`（L65-76）——**契约不变**。
- 现有 UI smoke（`tests/features/*`、`tests/ui/*` 若有）——行为零漂移验证。
- 新增：`smoke_presentation_frozen_contract.gd`、`smoke_presentation_regressions.gd`。

## 9. 非目标（钉死，超出本纵切范围）

- 不迁移 local load/history_resume 到 coordinator 的 external 路径（保持 session-operation 返回路径；若未来统一，独立规格）。
- 不重写 `battle_vfx_controller._trace_queue`、`battle_scene` 增量播放内部实现、`three_choice._transition_to_view` 动画。
- 不动 `ActionLifecycle`、`GameSession` 信号契约、Command handler、YsbzsState、save/replay/协议。
- 不建 GameAction 类树 / actionManager / pause-resume continuation（§2）。
- 不处理 85 个 15-29 行第二梯队方法（facade 下沉另一纵切，见 `2026-08-03_FACADE_DESCENT_MASTER_SPEC.md`）。

## 10. 冲突审计

- 无 doing 任务将 `game_controller.gd` / `artist_flow_session_bridge.gd` / `session/*.gd` / `three_choice_scene.gd` / `battle_scene.gd` 声明为排他（核对 `tasks/doing/*.md`）。
- `2026-07-30_sync-art-authority` 声明宽泛 `core_ui/scripts/**` 写范围（美术表现适配）——**P2 触及 three_choice/battle/battle_vfx 前必须与其 owner 协调**；`battle_vfx_controller.gd` 若需改动须先协商（本规格默认不改，仅游标经 render_snapshot 参数传入）。
- `2026-07-15_mouse-playtest-day1-day2` 为 reports-only，无冲突。
- 本规格不触碰 `core/state/game_state.gd`（V3 哈希零漂移，见 §6）。
- 实现阶段正式任务卡须逐阶段声明 `write_scopes` + `exclusive_files`，与 §5 提交边界一致。

## 11. 规格缺口与状态

**现状：IMPLEMENTED_VERIFIED。** 原五项缺口已由 §13 的 live 实现与测试闭合：

1. P2 coordinator 的 `version(snapshot)` 取键（snapshot 内 `stateVersion`）与 `_pending_latest` 折叠的精确合并条件需在实施包以 battle snapshot schema 实测确认。
2. P2 中 `_on_session_operation_requested` 走 coordinator 还是保持直连，二选一需 P0 测试断言后定案。
3. P0 测试的 stub battle view 构造方式（复用真实 battle_scene 最小装配 or 替身）需实施时按现有 tests 装配模式定。
4. RG3/RG4 的超时门闩与断言工具函数签名需在实施包给出。
5. `_await_battle_trace_sequence` 改造为销毁安全的精确替换块（当前仅指方向：`is_instance_valid` 前置 + 常驻 three_choice 落位）。

若后续 BattleScene 四个公开展示方法、Session snapshot metadata 或 `stateVersion/stateHash` schema 漂移，重新标记 `REBASE_REQUIRED`。

## 12. 完成态

- 单一 `presentation_coordinator.gd` 作为唯一表现入口；四条渲染入口（命令响应/战斗响应/外部快照/session-op）全部经它串行。
- "命令确认快照"与"外部同步快照"以 `reason` 显式分离；bridge 计数启发式退役（若证明冗余）。
- battle trace 游标由 coordinator 持有，切页/重挂载/节点销毁不丢播放位置、不悬挂。
- P0 冻结契约 + P3 四类回归（连点/乱序/结算切页/节点销毁）全绿；V3 状态层哈希零漂移。
- 表现层不再照搬 STS2 GameAction 类树；只迁移了"串行门闩 + 明确完成时机"两个语言无关不变量。

## 13. 2026-08-03 实施闭环

- 唯一入口：新增 `core_ui/scripts/app/presentation_coordinator.gd`；Game 的 command、battle command、external snapshot、session operation 四条入口全部入同一 FIFO。
- 显式归属：bridge 仅按 `metadata.reason == "command"` 丢弃命令确认快照，删除 `_awaiting_commands` 启发式，并透传 external metadata。
- 版本裁决：低版本丢弃；同版本同 hash 去重；播放期间排队的 external 只保留最高版本（同版本以后到者为准）；手动刷新用 `force=true` 保留既有 API 语义。
- 生命周期：Session reset 递增 generation 并取消旧等待者；feature 只在 render/trace/transition settle 后释放；BattleScene 销毁时 ThreeChoice 的 trace 等待按实例有效性退出。
- Battle API 重基线：保留 `command_requested`、`trace_sequence_finished`、`render_snapshot`、`play_battle_trace`、`get_runtime_view`、`is_battle_input_locked`；追加纯表现游标 getter/configurer；missing mapping 直接调用 `runtime_root/Board.missing_mapping_report()`，未在 root 添加兼容转发。
- 回归：冻结 command/external contract；覆盖快速连点 FIFO、外部乱序折叠、battle settle 后 external 才开始、load 游标重置、Battle 节点销毁超时门闩。权威 normalized/save/replay 值未变化，fast QA 15/15 通过。
