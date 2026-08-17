# Game 应用装配 Scene

正式启动入口：`game.tscn`。

- `Game` 根节点挂 `game_controller.gd`，唯一持有 `GameSession`（当前正式单机为 `LocalGameSession`）、Command 执行、持久化操作和 Feature Scene 生命周期。
- `ThreeChoiceScene` 是常驻的纯展示 Scene，由 Game 传入 Snapshot；它不创建 Session，也不直接执行 Command。
- `FeatureHost` 只负责挂载战斗 Scene；进入战斗时，Game 向 `BattleArtScene` 投递公共 Snapshot，并统一接收其 Command 请求。
- `GameCursor` 属于应用级交互反馈，不放进三选一美术 Scene。

装配方向固定为：

`Game -> ThreeChoiceScene / BattleArtScene`

两个 UI Scene 都不能反向成为第二个状态或流程真相源。

跨 Scene 的唯一链路是：美术 Scene 发送语义 Command，Game 等待权威 Result/Snapshot，再由 Game 决定 Feature、调用 SceneRouter 挂载，并在 `presentation_settled` 后释放不再需要的旧 Feature。按钮和美术 Scene 都不知道目标 Scene 路径。
