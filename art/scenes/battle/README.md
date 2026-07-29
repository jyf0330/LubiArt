# 战斗 Scene 美术说明

正式战斗界面只有：

`res://art/scenes/battle/battle_art_scene.tscn`

它本身就是运行 Scene，不再包含 `Runtime`、`PrefabCatalog`、`ReusablePrefabs` 或 `RuntimeEffects` 等索引包装层。

## 层级职责

```text
BattleArtScene
├── Board（棋盘）
│   ├── BoardBG
│   ├── BoardGrid
│   │   └── 64 个 terrain.tscn 实例
│   ├── BattleVfxPlayer
│   ├── BattleActionPanel
│   ├── AutoArrangeButton
│   ├── PositionDifficultyButton
│   ├── BeginTurnButton
│   └── BattleCommandTools（运行时调试）
├── TopInfoBar（上方信息栏）
└── CellDetail（格子详情）
    ├── BattlePetDetailPanel（运行时）
    └── BattleElementDetailPanel（运行时）
```

- `BattleArtScene` 根节点下只允许以上三个直接次级节点；新增战斗 UI 必须先归入对应职责，不得再平铺到根节点。
- `Board` 管棋盘背景、格子、宠物实例、战斗事件编排和行动控件，并直接挂 `battle_board.gd` 作为该次级分组的表现入口。
- `TopInfoBar` 直接挂 `battle_top_info_bar.gd`，只管用户截图所示的日程、回合、货币与顶部功能信息；当前没有正式上方信息栏切图时保留结构位，不用程序临时画图替代美术。
- `CellDetail` 直接挂 `battle_cell_detail.gd`，只管点选格子后显示的宠物 / 地形信息。交付文件 `宠物信息栏实装(修改).psd` 是其中宠物格子信息的美术源；476×539 卡片、动态数据接口、遮罩、操作与调试容器统一在 `pet_detail.tscn` 中维护，项目运行时不依赖 PSD 或其本机路径。
- 自动布置、摆位难度、开始行动、行动面板和调试命令都属于 `Board`，不得为了右侧位置而归入 `CellDetail`。
- `BoardGrid` 重复使用地形 prefab。
- 宠物由战斗控制器从宠物 prefab 取用并重置数据。
- 宠物详情与地形详情分别使用对应详情 prefab。
- 宠物攻击、受击、移动、死亡、跨格投射物和伤害数字由 `pet.tscn` 内的对应表现层创建；地面元素标记与命中特效由 `terrain.tscn` 创建。`BattleVfxPlayer` 只保留真实事件的播放时序、预制体调用协调和回合横幅。

## 美术节点规则

- 一张图片对应一个 `TextureRect` / `Sprite2D` 等视觉节点；节点矩形贴合真实视觉范围，不能用整屏透明区域扩大选择框。
- `Board`、`TopInfoBar`、`CellDetail` 是职责分组，不是假图片节点；真正图片继续放在各分组内部并保持一图一节点。
- `Board` 这类次级职责节点默认由自身脚本统一管理普通子节点、输入绑定和公开接口；普通图片、容器和按钮不逐个挂脚本。只有独立动画、独立状态、复用 prefab 或稳定公开接口等特殊子节点才单独挂脚本。
- 新格子信息 PSD 只读；切图统一放在 `art/images/shared/pets/info_panel/`，场景放 `art/prefabs/pet/`，表现脚本放 `core_ui/scripts/shared/pet/`。动态名称、元素、品质、攻击形状和六项数值不得烘进切图。
- 需要输入、状态、动画或公开接口的视觉节点可以挂表现脚本；权威 Session、Snapshot 和战斗规则不能放进图片层。
- `RoundFeedback` 是运行时创建的回合横幅图片根，直接挂 `battle_round_banner.gd` 并拥有 `Title`、`Subtitle`，不再有独立 `.tscn`。
- 修改战斗整屏、HUD、事件时序、回合横幅或特效层级时直接改本 Scene 或 `core_ui/scripts/battle/`；修改宠物战斗表现、详情卡面、遮罩、操作、调试面板或地面元素表现时打开对应四个 prefab。

## 禁止事项

- 不新建 Catalog、预览副本或第二套 Battle View。
- 不把按钮、HUD、特效或调试面板再拆成新的 prefab。
- 不缩小正式节点来规避编辑器点击问题；应让视觉节点的矩形与图片实际范围一致。
- 不复制权威玩法状态，不用固定延迟模拟真实命中。
