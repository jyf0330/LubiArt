# 新人代码阅读入口

> 本文是代码导航，不是 AI 工作流规则。它描述当前实现，帮助快速找到入口和调用链；如果与 live source 不一致，以源码、Scene 引用和测试为准。

建议先运行正式玩家入口建立画面印象，再沿一条公开 Command 纵向追到权威状态，最后从返回的 Result / Trace / Snapshot 追回 UI。

如果本文与 live 源码不一致，以 `project.godot`、当前 Scene 引用、测试和代码实现为准，并在同一任务修正文档；不要继续传播旧路径或旧数量。

## 先记住主干

```text
玩家点击 / 拖拽
  -> art Scene + core_ui Controller / Presenter
  -> GameSession.submit_command()
  -> Command Handler
  -> YsbzsState 唯一权威状态
  -> Result / Trace / Snapshot
  -> GameSession
  -> core_ui / art 表现
```

三个真相源不要混淆：

- 运行状态：唯一 `YsbzsState`；UI、ViewModel、BattleWorld、存档和历史都不能成为第二份可写玩法状态。
- 当前运行内容：`data/content/**/*.json` 与明确引用的补充 JSON；`generated/` 由导出器重建，`extensions/` 保存 JSON 先行扩展。
- 美术表现：本仓 `art/**` 的 Scene / prefab / 图片 / manifest 与 `core_ui/**` 的表现代码；正式入口负责接入 Session、Snapshot、Trace、输入和信号。

## 第一阶段：先读边界，不读实现细节

依次阅读：

1. `docs/06_PROJECT_STRUCTURE.md`：目录职责、依赖方向和当前场景装配。
2. `docs/05_GAME_SESSION_BOUNDARY.md`：UI 与本地/远端权威核心共用的会话端口。
3. `docs/03_CORE_ARCHITECTURE.md`：权威 facade、组合服务和领域规则。
4. `docs/13_MODULAR_CONTENT_PACK.md`：内容包的发现、校验、排序和装配。

## 第二阶段：追正式启动

当前启动链是：

```text
project.godot
  -> art/scenes/app/game.tscn
  -> Game 根 game_controller.gd
  -> SessionFactory.create_local()
  -> LocalGameSession(YsbzsState)
  -> Game 把 Snapshot 投给常驻 ThreeChoiceScene
  -> Snapshot.phase == battle 时
     FeatureRegistry + SceneRouter
     把 battle_art_scene.tscn 挂到 FeatureHost
```

阅读顺序：

1. `project.godot` 的 `application/run/main_scene`。
2. `art/scenes/app/game.tscn` 的 `Game`、常驻 `ThreeChoiceScene` 和动态 `FeatureHost`。
3. `core_ui/scripts/app/game_controller.gd::_ready()`、`_prepare_feature_for_snapshot()` 与 `_release_features_not_required()`。
4. `art/scenes/three_choice/three_choice_scene.tscn` 与 `core_ui/scripts/artist_flow/scenes/three_choice_scene.gd` 的纯展示接口。
5. `session/session_factory.gd::create_local()`。
6. `session/local_game_session.gd::submit_command()`。
7. `core/state/game_state.gd` 的稳定 `YsbzsState` 门面。

`Game` 是唯一应用组合根。三选一 Scene 是常驻 authored view，不持有 Session；`SceneRouter` 只管理 `FeatureHost` 中的动态功能 Scene，当前默认只注册战斗 Scene。

## 第三阶段：纵向追 `CHOOSE_ROUTE`

这是最适合新人的第一条完整链：

1. `core_ui/scripts/route/controllers/route_controller.gd::choose_command()` 生成公开 Command。
2. `core_ui/scripts/route/presenters/route_presenter.gd::cards()` 把 Command 放进卡片模型。
3. `core_ui/scripts/artist_flow/scenes/three_choice_scene.gd::_on_three_pressed()` 读取按钮 metadata，`_submit_core_command()` 只发出语义 `command_requested`。
4. `core_ui/scripts/app/game_controller.gd::_on_command_requested()` 经 `artist_flow_session_bridge.gd` 提交给 Session。
5. `session/local_game_session.gd` 经 `local_authority_port.gd` 调用 `YsbzsState.run_command()`。
6. `core/state/game_state.gd::dispatch()` 先校验版本和阶段，再查 Command Handler；`YsbzsState` 是直接继承 `RefCounted` 的唯一权威门面。
7. `core/commands/handlers/route_reward_command_handler.gd` 只经 `RouteRewardCommandPort` 委托 `YsbzsState.choose_route()`；领域规则继续下沉到 `core/route/` 与 `RouteOptionService`。
8. `run_command()` 返回 Result / Trace / Snapshot；`Game` 先准备目标 Feature，再把 Snapshot 交给 Presenter；`phase == battle` 时由 `SceneRouter` 挂载战斗 Scene。

定位命令：

```bash
rg -n '"CHOOSE_ROUTE"|func choose_route|submit_command|run_command|snapshot' \
  core_ui session core tests
```

阅读每条链时只回答四个问题：输入从哪里来、谁校验、谁写权威状态、哪个 Snapshot 字段驱动显示。

## 第四阶段：再追战斗拖拽

第二条练习使用 `MOVE_HERO`：

1. `core_ui/scripts/battle/scenes/battle_scene.gd::_finish_unit_drag()` 把释放位置转换为 Command，并向 `Game` 发出 `command_requested`。
2. `core/commands/handlers/battle_command_handler.gd` 把 `MOVE_HERO` 委托给 `move_selected()`。
3. 继续追合法性、AP、落位、Trace、Snapshot 和表现回弹。
4. 对照 `tests/features/smoke_battle_move_visible_projection.gd` 与对应 core smoke，区分规则结果和可见结果。

不要从 `game_state.gd` 第一行读到最后一行。它是高内聚权威协调器；用命令名、函数名、组合服务和测试断言按需进入。

## 第五阶段：用测试当可执行说明书

先运行四个短链路测试：

```bash
python3 tools/qa/run_qa.py --test tests/session/smoke_session_first_bootstrap.gd
python3 tools/qa/run_qa.py --test tests/integration/smoke_project_structure.gd
python3 tools/qa/run_qa.py --test tests/integration/smoke_command_handler_registry.gd
python3 tools/qa/run_qa.py --test tests/core/smoke_phase_policy.gd
```

然后阅读 `tests/integration/smoke_playable_flow.gd`，观察真实路线按钮如何进入战斗、结算、奖励和存读档。需要验证时可以运行相关专项测试或 `python3 tools/qa/run_qa.py --suite fast`。

## 第一次修改建议

优先选择有独立输入输出的纯规则、Presenter、专项 smoke 或单个内容扩展。不要把第一次任务选成重写 `YsbzsState` 权威门面、复制 authored Scene、批量搬目录或建立第二套状态。
