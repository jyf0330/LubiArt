# 战斗界面独立 Mock 项目

这是从正式项目拆出的独立 Godot 界面项目，用于美术、预制体、设计模式和接口联调。

## 结构

- `game/`：从正式项目整目录镜像；保留 Composition Shell、Factory、Feature Registry 和 Scene Router
- `features/`：从正式项目整目录镜像；保留 Controller、Presenter、Adapter、Command Builder、Trace Projection 和各功能预制体
- `shared/prefabs/`：从正式项目整目录镜像；保留共享宠物、详情等复用预制体
- `assets/artist_ui/`、`assets/battle_ui/`：从正式项目整目录镜像
- `session/`：实现与正式项目一致的 `GameSession` 公共端口，但只读固定假数据
- `data/mock_battle_snapshot.json`：与正式 Snapshot 字段相似的假数据
- `tests/`：独立项目契约 smoke

运行时装配链为：

`game.tscn -> FeatureRegistry -> SceneRouter -> artist_flow_view.tscn -> battle_view.tscn -> 多个 battle/shared 预制体`

`game/`、`features/`、`shared/prefabs/` 及 UI 资源与当前 `godot-latest` 保持整目录逐字节一致。差异只允许位于 `session/`、`core/`、`data/` 和测试；正式战斗核心、存档、远程传输和策划数据不进入这个 Mock 项目。

## 验证

```bash
./tests/verify_ui_mirror.sh
/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/ywh/Documents/godot-battle-ui-mock \
  --script res://tests/smoke_mock_battle_project.gd
```

第一条会对完整 UI 层整目录逐字节比较；任何场景、脚本、预制体、Presenter、Adapter 或资源漂移都会直接失败。

## 可操作内容

- 点击棋盘宠物：打开宠物详情预制体
- 自动布置：按固定规则重新摆放我方宠物
- 开始行动：执行一轮假战斗，动态改变护盾、生命和回合
- 重置演示：恢复 JSON 初始数据

这个项目不会读取正式存档，也不会调用正式战斗核心。修改假数据不会影响正式项目。
