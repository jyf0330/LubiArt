# 正式程序工程结构

> 本文是当前目录和依赖关系地图，不是 AI 工作流规则；如果目录或入口已经变化，以 live source 为准。

项目按玩家输入、规则命令、权威状态、内容模型、Godot 表现和存档端口的语义边界组织。`godot-latest` 同时承载正式运行与视觉资产，主要位于 `art/**` 和 `core_ui/**`。当前运行入口是 `art/scenes/three_choice/three_choice_scene.tscn`，该 Scene 本身同时是 authored 三选一视图与组合根，并按权威阶段惰性挂载战斗 Scene；策划运行内容从 `data/content/**/*.json` 自动装配。新人可以按 [00_NEWCOMER_CODE_GUIDE.md](00_NEWCOMER_CODE_GUIDE.md) 纵向阅读。

## 目录职责

```text
art/              所有正式场景、预制体、运行图片与图片 manifest
core_ui/scripts/  所有 UI 控制器、Presenter、状态投影和表现脚本
shared/        字体、主题、shader 等非图片公共资源骨架
core/          正式规则、计算、命令、权威状态和组合服务
session/       本地、主机/权威端、远端统一会话端口与 transport
persistence/   存档、回放、codec 和版本迁移
data/          模块化运行内容、schema、兼容数据与明确补充 JSON
debug/         仅保留开发 fixture；调试 UI 脚本归 `core_ui/scripts/debug`
tests/         按 core/session/features/integration/visible 分类的验证
```

`docs/`、`tools/`、`deploy/`、`build/`、`ui_delivery/` 和 `output/` 是工程辅助目录，不进入游戏运行时依赖链。

## 固定依赖方向

```text
Player Input -> art/core_ui -> session command -> core authority
core Snapshot/Trace -> session -> core_ui/art presentation
composition root -> persistence adapters -> filesystem
data -> GameDataRepository -> immutable content model -> core
```

外层适配器依赖稳定内层契约，组合根负责接线；禁止 UI/Node、内容或仓储反向成为玩法权威。具体门禁：

- `art` 是唯一正式视觉入口；文件类型分别进入 `art/scenes`、`art/prefabs`、`art/images`、`art/manifests`，不放 GDScript，不访问权威状态。
- `art/prefabs` 当前保存宠物、宠物详情、地形、地形详情四个公开预制体及其内部组件；新增 prefab 以独立编辑/复用/测试职责和公开接口为依据，不以数量或减少父文件行数为依据。`art/images` 保存唯一运行图片，`art/manifests` 保存图片映射和 JSON manifest。
- `core_ui` 提供 Art 入口使用的装配、路由、控制器、Presenter 和表现脚本；它通过会话提交命令、消费 Snapshot，不复制权威状态。
- `art/scenes` 当前正式玩家路由包含三选一与战斗；新增正式 Scene 必须拥有独立玩家流程或表现生命周期、通过路由注入 Session 并提供正式入口验证。调试 Scene 不接入玩家路由。
- `session` 不访问页面节点，authority 必须注入。
- `core` 不依赖 UI、feature 或美术资源。
- `persistence` 通过 Port/Codec/Repository 接收文档；领域规则不直接拼路径或读写文件系统。
- `shared` 不包含路线、商店、战斗等业务规则。
- Art prefab 不直接读取正式 `GameState`。

表现依赖固定为：

```text
Art Scene -> Art Prefab -> Art Image
         \-> core_ui -> session
```

## 当前功能映射

| 功能 | 程序路径 | 当前状态 |
|---|---|---|
| 正式装配 | `art/scenes/three_choice/` + `core_ui/scripts/app/` | 三选一 Scene 本身是 authored view，并通过 `SceneRouter` 挂载战斗 Scene |
| 美术预制体 | `art/prefabs/pet/` + `art/prefabs/terrain/` | 宠物、宠物详情、地形、地形详情四个公开 prefab；允许美术内部组件 |
| 运行图片 | `art/images/` | 按 `shared/pets`、`route`、`battle`、`debug` 分类 |
| 图片映射 | `art/manifests/` | 与图片使用同一 scope，但不把 JSON 混入图片目录 |
| 三选一/路线 | `art/scenes/three_choice/` + `core_ui/scripts/route/` | 唯一三选一 Scene 直接包含 authored 路线、商店、背包、队伍和结算节点 |
| 商店 | `art/scenes/three_choice/` + `core_ui/scripts/shop/` | 三选一 Scene 直接节点 + Presenter/Controller |
| 背包 | `art/scenes/three_choice/` + `core_ui/scripts/inventory/` | 三选一 Scene 直接节点 + Presenter/Controller |
| 队伍 | `art/scenes/three_choice/` + `core_ui/scripts/party/` | 三选一 Scene 直接节点 + Presenter/Controller |
| 战斗 | `art/scenes/battle/` + `core_ui/scripts/battle/` | 唯一战斗 Scene 直接包含 Battle View、HUD 和 VFX 节点 |
| 结算 | `core_ui/scripts/settlement/` | Presenter/Controller 复用 authored 奖励槽位 |
| 宠物表现 | `art/prefabs/pet/` + `core_ui/scripts/shared/pet/` | 三选一与战斗共用宠物、宠物详情 |

## ArtistFlow 当前装配

路线、商店、背包和队伍当前共用一个完整 authored UI；这棵节点树保留在 `art/scenes/three_choice/three_choice_scene.tscn`，并通过根展示脚本接入。Session 生命周期由 `art/scenes/app/game.tscn` 的 `Game` 通过 `artist_flow_session_bridge.gd` 持有，舞台显隐和 authored 动画委托给 `artist_flow_stage_presenter.gd`，资源映射委托给 `artist_flow_asset_registry.gd`，业务读取与命令模型分别由 route/shop/inventory/party/settlement presenter 输出。

正式启动顺序为 `project.godot -> app/game.tscn（根脚本 GameController）-> SessionFactory.create_local() -> LocalGameSession(YsbzsState) -> Game 把完整连接 Snapshot 投给常驻 ThreeChoiceScene`。之后三选商店高频命令可由 Session 把小 Result/delta 合并到只读展示投影；它不是第二份可写权威状态。三选一 Scene 已经存活，不由 `SceneRouter` 创建；只有完整权威 Snapshot 进入 `battle` 阶段时，`FeatureRegistry + SceneRouter` 才把 `battle_art_scene.tscn` 挂到 `FeatureHost` 并投递同一份 Snapshot，离开战斗阶段且表现结束后释放。Scene、prefab 和 Presenter 都不得创建、持有或直接调用 Session，也不得保存第二份可写权威状态。

当美术交付形成可独立实例化的功能视图，且每个视图都能通过公开接口完成生命周期、状态注入和验证时，可以拆分当前 `artist_flow` 组合场景。不能只为缩短文件或复制节点树来伪装完成拆分。

`main_menu` 尚无正式 authored 页面和运行规则，不保留空目录骨架。有真实功能任务时以本仓 art commit 的 authored 结构为基线，并按独立流程 / 组件职责决定是否新增 Scene 或 prefab；不得由新节点创建第二权威状态。

## 测试结构

`tests/integration/smoke_singleplayer.gd` 只保留 `路线 -> 商店 -> 战斗 -> 奖励 -> 路线` 的短权威 E2E。bootstrap、路线经济、持久化、站位移动和 UI 投影分别由相邻 `smoke_singleplayer_*.gd` 独立进程验证；共享 fixture、纯查询 helper 和失败汇总位于 `tests/helpers/singleplayer_smoke_suite.gd` / `singleplayer_smoke_context.gd`。历史机制、品质、旧三段行动与预览/商店混合矩阵已按 `qa/retired_tests.json` 退役，仍具权威性的断言由 focused core/feature smoke 作为发布门禁。新增规则必须进入所属专项 smoke，不得重新堆回单一 E2E，也不得仅按行数切片。

正式 UI 的权威短流程由 `tests/integration/smoke_playable_flow.gd`、`tests/features/smoke_art_main_scene.gd` 与 `tests/features/smoke_artist_flow_presenters.gd` 覆盖。旧 Artist UI monolith、3/5/5 槽位和 RunTools 层级探针已退役；启动内容只允许显式官方映射的八宠 manifest，禁止用随机或 fallback 图片让门禁假绿。

`tests/integration/smoke_architecture_boundaries.gd` 和 `tests/core/smoke_core_layer_structure.gd` 固定 P0/P1 服务委托、公开契约、依赖方向和唯一权威，防止职责重新回流；不按契约数量或代码行数失败。

## 目录准入规则

- 组件在拥有跨 scope 的稳定语义和所有权时进入 `shared`；不要求先复制两份，也不因“未来也许复用”提前抽象。
- 页面私有节点留在所属正式 Scene，图片留在 `art/images` 对应 scope，不提前抽象为 prefab。
- 所有 UI GDScript 放在 `core_ui/scripts`；`art/scenes`、`art/prefabs`、`art/images`、`art/manifests` 分别只承载对应文件类型，`core_ui` 内禁止 `.tscn` 和运行图片。
- `data/content/generated/` 由导出器机械重建，`data/content/extensions/` 保存可独立新增的 JSON 扩展；CSV 上游仍位于 `ysbzs` 仓库。
- 旧 `scripts/`、`scenes/`、`game/`、`features/`、`assets/` 根目录不得恢复；`art/` 不存放重复运行实现、权威状态或 PSD 等美术源文件。
