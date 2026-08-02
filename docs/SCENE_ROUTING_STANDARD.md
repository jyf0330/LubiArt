# 美术 Scene 路由规范

本规范约束正式入口、页面切换、Session 所有权和脚本挂载。它借鉴 STS2 的职责链：常驻应用壳负责顶层生命周期，玩家输入先成为 Action / Command，权威状态确认后再替换容器中的 Scene。只借鉴职责与依赖方向，不复制其专有实现、节点密度或资源。

## 1. 唯一总控制

- `art/scenes/app/game.tscn` 是唯一正式启动入口。
- `Game/game_controller.gd` 是唯一 Session、Command、持久化和 Feature Scene 生命周期拥有者。
- `FeatureHost` 是动态 Feature Scene 的唯一挂载容器。
- `SceneRouter` 只做实例化、挂载和释放；它不读取 Snapshot，不判断玩法阶段，也不执行 Command。

## 2. 标准按钮链路

跨 Scene 的按钮固定走这条链：

```text
场景中已有 Button
→ 当前美术 Scene 根脚本发送语义 Command
→ Game 提交给 GameSession
→ GameSession 返回 Result + Snapshot
→ Game 根据 Snapshot 选择需要的 Feature
→ SceneRouter 在 FeatureHost 挂载目标 Scene
→ Game 注入 Snapshot
→ 目标 Scene 根脚本渲染并播放过渡
→ 当前 Scene 报告 presentation_settled
→ Game 释放 Snapshot 已不再需要的旧 Feature
```

关键点：按钮只知道“玩家做了什么”，不知道“要打开哪个 `.tscn`”；当前美术 Scene 也不决定目标 Scene 的创建和销毁。

## 3. 脚本数量与挂载

- 每个正式美术 Scene 默认只有 `1` 个页面级根展示脚本；确有第二个完整页面职责时上限为 `2`，且必须挂在该职责根节点。
- 普通图片、文本、容器、按钮和纯布局节点不挂脚本，点击信号由所属 Scene / prefab 的职责根统一连接。
- Scene 可以实例化带根脚本的 prefab；prefab 内部脚本不成为页面路由脚本，也不得持有 Session。
- `Board`、`Hud`、`OverlayHost` 等完整职责分组可保留分组根脚本，但只能处理本组展示、动画、输入或稳定公开接口，不能加载别的页面或裁决流程。
- 静态位置、尺寸、点击矩形和基准纹理保存在 `.tscn`；脚本只写动态内容、同构实例排布、交互状态和动画过程。

## 4. 三类不同操作

### 跨 Scene

必须走完整 Command / Snapshot / Game / SceneRouter 链路。例如路线选择后进入战斗。

### 同 Scene 面板切换

由当前 Scene 根脚本直接切换已有节点显隐或播放动画。例如打开背包。它不经过 SceneRouter，也不伪造玩法阶段。

### 当前 Scene 拥有的详情 prefab

由当前 Scene 根脚本向场景中已经实例化的详情 prefab 传入展示数据。例如打开宠物详情。详情 prefab 可以有自己的根展示脚本，但不能创建 Session 或跳转页面。

## 5. 禁止项

- Button 或普通子节点直接 `change_scene*()`、加载目标 Scene 路径或操作 `FeatureHost`。
- `ThreeChoiceScene`、`BattleArtScene` 或 prefab 创建、缓存、替换、保存或直接调用 GameSession。
- 美术 Scene 通过 `feature_view_requested` 一类信号要求创建特定页面；它只能发送语义 Command 和报告表现完成。
- SceneRouter 根据 `phase`、业务字段或按钮名称判断目标页面。
- 为了路由在普通节点上新增空脚本，或在脚本中临时拼装静态 UI。

## 6. 本项目映射

```text
Game
├── ThreeChoiceScene       常驻美术展示 Scene
├── FeatureHost            动态挂载 BattleArtScene
└── GameCursor             应用级输入反馈
```

当前路由规则只有一条：`Snapshot.phase == "battle"` 时 Game 确保 `BattleArtScene` 已挂载；其他阶段在表现过渡完成后由 Game 释放战斗 Scene。以后新增结算、图鉴或设置等独立 Scene 时，也只能在 Game 的 Snapshot → Feature 映射中登记，不能把目标路径写回按钮或美术 Scene。
