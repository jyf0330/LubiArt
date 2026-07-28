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
- `Board` 管棋盘背景、格子、宠物、棋盘内特效和战斗行动控件，并直接挂 `battle_board.gd` 作为该次级分组的表现入口。
- `TopInfoBar` 直接挂 `battle_top_info_bar.gd`，只管用户截图所示的日程、回合、货币与顶部功能信息；当前没有正式上方信息栏切图时保留结构位，不用程序临时画图替代美术。
- `CellDetail` 直接挂 `battle_cell_detail.gd`，只管点选格子后显示的宠物 / 地形信息。`/Users/ywh/Downloads/宠物信息栏实装.psd` 是其中宠物格子信息的正式美术源，原 476×539 画布、四档品质底板 / 攻击棋盘 / 数值格、特性位和动态数据接口都在 `pet_detail.tscn` 中维护。
- 自动布置、摆位难度、开始行动、行动面板和调试命令都属于 `Board`，不得为了右侧位置而归入 `CellDetail`。
- `BoardGrid` 重复使用地形 prefab。
- 宠物由战斗控制器从宠物 prefab 取用并重置数据。
- 宠物详情与地形详情分别使用对应详情 prefab。
- HUD、按钮、回合反馈、投射物、伤害数字和咬击直接属于战斗 Scene 或由 `BattleVfxPlayer` 的脚本类型按真实事件创建，不是 prefab。

## 美术节点规则

- 一张图片对应一个 `TextureRect` / `Sprite2D` 等视觉节点；节点矩形贴合真实视觉范围，不能用整屏透明区域扩大选择框。
- `Board`、`TopInfoBar`、`CellDetail` 是职责分组，不是假图片节点；真正图片继续放在各分组内部并保持一图一节点。
- `Board` 这类次级职责节点默认由自身脚本统一管理普通子节点、输入绑定和公开接口；普通图片、容器和按钮不逐个挂脚本。只有独立动画、独立状态、复用 prefab 或稳定公开接口等特殊子节点才单独挂脚本。
- 新格子信息 PSD 只读；切图统一放在 `art/images/shared/pets/info_panel/`，场景放 `art/prefabs/pet/`，表现脚本放 `core_ui/scripts/shared/pet/`。动态名称、元素、品质、攻击形状和六项数值不得烘进切图。
- 需要输入、状态、动画或公开接口的视觉节点可以挂表现脚本；权威 Session、Snapshot 和战斗规则不能放进图片层。
- `RoundFeedback` 是运行时创建的回合横幅图片根，直接挂 `battle_round_banner.gd` 并拥有 `Title`、`Subtitle`，不再有独立 `.tscn`。
- 修改战斗整屏、HUD 或特效层级时直接改本 Scene 或 `core_ui/scripts/battle/`；修改宠物/地形及其详情时打开对应四个 prefab。

## 禁止事项

- 不新建 Catalog、预览副本或第二套 Battle View。
- 不把按钮、HUD、特效拆成第五个 prefab。
- 不缩小正式节点来规避编辑器点击问题；应让视觉节点的矩形与图片实际范围一致。
- 不复制权威玩法状态，不用固定延迟模拟真实命中。
