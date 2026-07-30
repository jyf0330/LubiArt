# 战斗界面独立 Mock 项目

这是交付给美术独立使用的 Godot 界面项目，用于美术、预制体、设计模式和接口联调。使用者只需要本项目和兼容的 Godot，不需要拥有原项目。

## 结构

- `art/scenes/`：保留三选一和战斗两个正式 Scene，以及独立的 SpriteInfoCard 美术调试 Scene；项目仍从 `art/scenes/three_choice/three_choice_scene.tscn` 启动
- `art/prefabs/`：保留宠物、宠物详情、地形、地形详情四个公开 prefab，以及宠物详情内部使用的 `sprite_info_card.tscn`
- `art/images/`：项目内完整图片资源
- `art/manifests/`：图片 ID、切片和资源映射 JSON
- `core_ui/scripts/`：Controller、Presenter、Adapter、Command Builder、Trace Projection 和预制体表现脚本
- `session/`：实现与正式项目一致的 `GameSession` 公共端口，只离线回放正式运行数据
- `data/mock_battle_snapshot.json`：项目方通过正式 `LocalGameSession` 读取存档槽2，再每回合执行一次“自动布置 → 开始行动”，直到战斗结算后导出的公共 Snapshot 序列
- `tests/`：独立项目契约 smoke

运行时装配链为：

`three_choice_scene.tscn -> MockGameSession -> FeatureRegistry -> SceneRouter -> battle_art_scene.tscn -> 四类公开 art/prefabs`

美术可以直接修改本项目中的两个正式 UI Scene、四个公开 prefab、`sprite_info_card.tscn` 卡片组件、独立调试 Scene、展示脚本、布局、动画和资源。图片、manifest 和脚本必须继续分别放在上述类型目录，再在类型目录内部按功能 scope 分类。项目方收到完整交付后，再通过独立集成任务审查差异并适配回正式项目。正式战斗核心、存档、远程传输和策划数据不进入这个 Mock 项目；导出的公共 Snapshot 已包含在项目内，运行时不需要正式项目。

## 验证

```bash
./tests/verify_ui_mirror.sh
godot \
  --headless \
  --path . \
  --script res://tests/smoke_mock_battle_project.gd
godot \
  --headless \
  --path . \
  --script res://tests/smoke_battle_art_scene.gd
godot \
  --headless \
  --path . \
  --script res://tests/sprite_info_card_debug/smoke_sprite_info_card_debug.gd
```

第一条默认只检查独立交付项目的必要目录和入口文件，不需要原项目。项目方在回集成时如需比较来源，可显式执行：

```bash
GODOT_LATEST_UI_SOURCE=/path/to/godot-latest ./tests/verify_ui_mirror.sh
```

美术侧不需要执行来源比较。若 `godot` 不在命令行 PATH 中，请把示例中的 `godot` 替换为本机 Godot 可执行文件路径。

## 可操作内容

- 点击棋盘宠物：打开宠物详情预制体
- 拖动己方精灵：可在当前美术预览中放到任意空白格；有单位的格子会拒绝落点并让精灵回到原位。红色攻击格只在拖动当前精灵时显示，松手后立即清除。该摆放只属于界面预览，下一份正式导出的 Snapshot 到达时会以正式站位重新渲染
- 鼠标悬停在攻击方向箭头上时，滚轮向下按“上 → 右 → 下 → 左”顺时针切换，滚轮向上按相反顺序切换。该设置只投影到当前 Mock 界面，不参与正式战斗结算
- 自动布置：回放正式项目本轮“自动布置”后的 Snapshot 和命令结果
- 开始行动：回放正式项目本轮“开始行动”后的 Snapshot、Trace、护盾、生命、元素和回合结果
- 两个按钮按“自动布置 → 开始行动”逐回合循环到结算；敌我双方每一步站位都直接来自这次正式运行
- 重置演示：回到这次正式运行数据的起点

这个项目不会读取正式存档，也不会调用正式战斗核心。数据文件不是在 Mock 中计算或手写的玩法结果；需要更新时，由项目方在正式项目重新运行导出器。修改后的 UI 由项目方另行回集成。
