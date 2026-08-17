# GameSession 会话边界

> 本文描述当前代码边界和调用链，目的是帮助理解项目，不规定 AI 的工作方式；以 live source 为准。

`GameSession` 是 Godot 表现层与权威游戏核心之间的端口。UI、场景和动画只能通过它提交命令、读取快照和接收事件，不判断权威规则运行在本机还是网络服务器。

```text
Godot UI / Presenter
  -> semantic command request
  -> Game application shell
  -> GameSession.submit_command(command)
    -> LocalGameSession -> YsbzsState
    -> RemoteGameSession -> SessionTransport -> SessionAuthorityHost -> YsbzsState
  <- command response / snapshot / event trace
```

## 当前实现

- `session/game_session.gd`：表现层稳定端口；定义命令、快照、拒绝和持久化入口。
- `session/action_lifecycle.gd`：命令提交与选择暂停的薄编排状态；只记录 command/choice/result metadata，不保存生命、金币、棋盘等玩法状态。
- `session/session_factory.gd`：创建或包装本地 Session；正式 `Game` 应用壳持有它，阶段路由只把权威 Snapshot 注入常驻三选一 Scene 与惰性挂载的战斗 Scene。
- `session/local_game_session.gd`：当前单机适配器；只委托既有 `YsbzsState`，不复制可写权威字段。首次连接、读档、恢复和显式校准接收完整 Snapshot/hash；三选与商店高频命令从已确认只读投影生成命令 ID 和基线版本，消费小 Result/delta 并在本地修补展示投影。
- `session/session_protocol.gd`：版本化 JSON-safe 命令 envelope；校验纯 UI intent，生成 `commandId` 和 `baseStateVersion`，完整/远端路径再带 `baseStateHash`；远端增加 `actorId`、`clientTick`、`sessionId`，并校验收到的版本化 ViewModel。
- `session/view_model_schema.gd`：UI 读取模型的稳定 schema；负责 schema id/version、顶层字段规范化和跨本地/远端一致性校验。
- `session/session_authority_host.gd`：服务端/房主权威入口；先做协议与 actor 校验，再调用现有核心，并按 `commandId` 缓存响应保证重复投递不重复执行。
- `session/transport/session_transport.gd`：异步传输端口；WebSocket、ENet 或平台网络适配器只需实现连接、命令发送和全量快照请求。
- `session/transport/loopback_session_transport.gd`：异步回环传输，用于 listen-server、本地联调和确定性端到端回归。
- `session/remote_game_session.gd`：远程客户端适配器；只保留最后一个服务器确认快照，命令先返回 pending，确认后再发布完成/拒绝与异步快照。
- `core_ui/scripts/app/game_controller.gd`：唯一持有 Session、Command 提交、持久化请求与 Feature Scene 生命周期；把 Result / Trace / Snapshot 分发给表现 Scene。
- `core_ui/scripts/artist_flow/controllers/artist_flow_session_bridge.gd`：仅供 `Game` 集中绑定 Session、接收异步快照、复用命令响应快照并访问持久化 capability。
- `core_ui/scripts/artist_flow/scenes/three_choice_scene.gd` 与 `core_ui/scripts/battle/scenes/battle_scene.gd`：只接收 Snapshot、播放表现并发出语义操作；不创建、持有或直接调用 GameSession。

`GameSession` 同时发布 `action_lifecycle_changed`，把玩家意图在 `queued / awaiting_choice / executing / cancelled / completed / rejected` 之间推进。它是表现编排状态，不参与伤害、路线、经济、存档 hash 或规则判定；命令是否真正生效仍只看权威响应的 `accepted`、Result、Trace 和 Snapshot。

## Command 是什么

UI 提交的 Command 是一次纯玩家意图，只包含规范 `type` 与该动作在 `CommandContract.INTENT_FIELDS` 中声明的业务选择。例如移动只提交：

```json
{"type":"MOVE_HERO","unitId":"pet_001","x":3,"y":4}
```

`commandId`、`baseStateVersion`、`baseStateHash`、协议、actor、tick、session、响应字段和展示文案都不属于 UI intent。UI 传入这些字段，或传入该动作白名单之外的 `kind/cell/source_type/source_index/free/slots/day/index` 等派生、重复、规则结果字段，会在调用核心前以 `COMMAND_FIELD_NOT_ALLOWED` 拒绝。Session 只在原始 intent 通过校验后创建 authoritative command：远端和完整响应路径携带版本/hash；本地三选商店增量路径只携带已确认版本。远端 Host 还会剥离 wire 字段后二次执行同一 schema 校验。

普通本地 `CHOOSE_ROUTE(shop) / ENTER_SHOP / BUY_OFFER(pet或缺失候选拒绝) / ROLL_SHOP / EXIT_SHOP / BACK_TO_ROUTE` 返回 `snapshotMode=delta`、`stateVersion`、Result、Trace 和领域变化，不构造完整 Snapshot，也不计算完整 `stateHash`。展示层只读缓存按目标版本合并这些变化；复杂路线、非宠物商品、战斗命令、连接/读档/历史恢复、显式存储/回放导出和异常校准仍走完整 Snapshot/hash。开启显式逐命令 run-history 时也自动回退完整哈希路径。

规则派生值只由权威核心读取当前状态计算：商店刷新是否免费、拖拽物来自商店/队伍/背包、下一天编号都不能由 UI 声明。稳定对象 ID、玩家选择的目标坐标、方向、AP、技能顺序和目标槽位仍是 intent。选择状态会影响后续命令，属于 codec/hash/replay 中的权威状态；成功选择会和其他写命令一样递增 `stateVersion`。

## 联机会话保证

远程实现复用同一 `GameSession` 表面，并保持核心已有协议字段：`commandId`、`baseStateVersion`、`baseStateHash`、`stateVersion`、`stateHash`、snapshot/ViewModel 和 trace。客户端只提交玩家意图；权限、可复现 RNG、伤害、回合和结算由权威主机或服务器执行。核心按版本后 hash 的顺序校验命令基线；任一不匹配均零写入。

本地适配器同步返回最终命令响应，并把 `snapshot_received.metadata.asynchronous` 标记为 `false`。远程适配器可以立即返回 `status=pending` 的提交回执，但此时必须保持 `accepted=false`；`accepted=true` 只表示权威核心已经确认完成。表现层使用 `submit_command_and_wait()` 取得与本地一致的最终 `completed/rejected` 响应，再渲染和推进后续命令。收到服务器确认时仍会发出 `snapshot_received` 并标记 `asynchronous=true`；正在等待该命令的控制器会抑制这次中间刷新，避免同一结果重复渲染。

`GameSession.supports_persistence()` 是显式 capability。本地 authority 同时实现保存、读档、回放和战报接口时返回 `true`；尚未接入服务端持久化命令的远程会话返回 `false`，UI 不得把这种能力缺失伪装成普通保存失败。

`GameSession.supports_run_history()` 是独立 capability。本地 Session 可通过 `run_history_runs()`、`run_history_checkpoints(run_id)` 列举每日历史，通过 `run_history_checkpoint_for_day(run_id, day, kind)` 读取确定命名的单日指针，并通过 `resume_from_run_history_day(...)` 或 checkpoint ID 创建新分支。正常玩家流默认不启用逐命令历史写盘；只有显式 `run_history=true` 或调试调用 `enable_run_history(true)` 才记录每条命令。按日恢复只依赖固定运行头、单日指针和单个 checkpoint，不解析增长中的历史清单，也不重放此前所有命令；成功后必须发布 `reason=history_resume` 的全量 Snapshot。远程会话在服务端历史 API 未实现前返回 `false`，不得读取客户端本地文件冒充服务器历史。

远程适配器缓存最后一个已确认 snapshot 用于渲染，但不得自行推进权威状态。断线期间提交会以 `SESSION_DISCONNECTED` 明确拒绝；重连后会按原 `clientTick` 顺序重发尚未确认的原始 envelope，再请求完整 snapshot。权威主机默认保留最近 1024 个命令响应：相同 `commandId + payload` 返回缓存结果，相同 ID 的不同 payload 返回 `COMMAND_ID_COLLISION`，因此常规丢包重试不会重复结算；生产部署应按最大断线窗口调整缓存上限或把幂等记录持久化。稳定连接期间以后可以增加 delta，但 delta 必须校验目标 `stateVersion` 和 `stateHash`。

Snapshot 内的 `viewModel` 必须带稳定 schema id/version。`SnapshotProjector` 只从同一份权威 Snapshot 规范化读取模型，`SessionProtocol` 拒绝缺失或不支持的版本；UI 不得把 ViewModel 缓存提升为权威状态，也不得绕过命令协议直接回写其中字段。

actor 权限在会话入口采用显式注册白名单。房间服务创建对局时负责登记实际玩家；未登记 actor 即使建立传输连接也不能调用核心。缺省或 `role=player` 只能提交 `CommandContract.PLAYER_ACTIONS`；`START_BATTLE`、棋盘配置、流程自动化和内部查询等命令只允许可信配置创建的 `role=developer` actor/Session。UI 不能通过 payload 提升 scope。`SessionAuthorityHost.set_authorization_policy()` 可继续注入对局内单位归属策略，策略接收 actor、命令、当前权威快照和 actor 权限，并在调用核心前拒绝越权对象。每个 actor 的新命令还必须单调增加 `clientTick`；相同命令 ID 的正常重试优先命中幂等缓存，换 ID 重放旧 tick 会返回 `CLIENT_TICK_REPLAYED`。

## 仍由部署层提供

当前仓库已经具备完整的游戏会话协议与可替换 transport 边界，但不虚构外部基础设施。正式公网联机仍需部署层提供账号认证、房间发现/匹配、TLS WebSocket 或 ENet relay、连接保活、服务端进程托管和持久化运维；这些能力接入时不得绕过 `SessionAuthorityHost` 直接调用核心。

本边界不是完整 Event Sourcing。当前使用 append-only 命令记录、按日直接索引的 checkpoint 和战斗 trace；checkpoint 只恢复进唯一权威状态，历史仓储不成为另一套规则或状态实现。内容由全局不可变 `contentRevision` 直接寻址，分支复用修订，不复制或按当前数据重新生成旧内容。
