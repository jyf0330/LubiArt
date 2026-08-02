# 战斗 Scene 美术说明

正式战斗界面只有：

`res://art/scenes/battle/battle_art_scene.tscn`

它本身就是运行 Scene，不再包含 `Runtime`、`PrefabCatalog`、`ReusablePrefabs` 或 `RuntimeEffects` 等索引包装层。

项目正式从 `res://art/scenes/app/game.tscn` 启动。`BattleArtScene` 根挂 `battle_scene.gd`，只接收 Game 投递的公共 Snapshot、绑定节点、处理输入和播放表现；它不创建、不保存、不暴露也不直接调用 GameSession。单独实例化本 Scene 时，需要测试或调试入口显式调用 `render_snapshot()` 才会显示战斗数据。

## 层级职责

```text
BattleArtScene
├── Board（棋盘）
│   ├── Background（棋盘背景）
│   ├── CellHost（56 个 terrain.tscn 运行时实例）
│   ├── UnitHost（按 unitId 复用的 pet.tscn 实例）
│   └── VfxHost（事件表现协调）
├── Hud（battle_hud.tscn）
└── OverlayHost（详情 prefab 与全屏覆盖层）
```

- 正式 Scene 固定为 8 个节点：根、`Board`、四个 Board 容器、`Hud` 和 `OverlayHost`。根展示脚本只对接 Snapshot 与 Command 请求。
- `CellHost` 根据 Snapshot 的棋盘尺寸创建 8×7 个地形 prefab；格子本身只处理地形、元素和输入，不持有宠物节点。
- `UnitHost` 以 `unitId` 为键挂载宠物 prefab；离场实例进入对象池，下一次需要时复用并重置展示数据。
- `Hud` 是独立可编辑的完整美术 prefab，内部统一维护顶部信息、自动布置、摆位难度、开始行动、行动面板和攻击方向抽屉。
- `OverlayHost` 按需挂载宠物详情与地形详情 prefab。交付文件 `宠物信息栏实装(修改).psd` 只是美术源；项目运行时不依赖 PSD 或本机路径。
- 宠物详情与地形详情分别使用对应详情 prefab。
- 宠物攻击、受击、移动、死亡、跨格投射物和伤害数字由 `pet.tscn` 内对应表现层创建；地面元素标记与命中特效由 `terrain.tscn` 创建。`VfxHost` 只保留真实事件的播放时序、预制体调用协调和回合横幅。

## 美术节点规则

- 一张图片对应一个 `TextureRect` / `Sprite2D` 等视觉节点；节点矩形贴合真实视觉范围，不能用整屏透明区域扩大选择框。
- `Board`、`Hud`、`OverlayHost` 是职责分组，不是假图片节点；真正图片继续放在各分组或 prefab 内并保持一图一节点。
- 页面逻辑只挂在 `BattleArtScene` 根节点；`Hud` 与复用 prefab 只拥有自身稳定展示接口，不持有 Session 或路由权。
- 新格子信息 PSD 只读；切图统一放在 `art/images/shared/pets/info_panel/`，场景放 `art/prefabs/pet/`，表现脚本放 `core_ui/scripts/shared/pet/`。动态名称、元素、品质、攻击形状和六项数值不得烘进切图。
- 需要输入、状态、动画或公开接口的视觉节点可以挂表现脚本；权威 Session、Snapshot 和战斗规则不能放进图片层。
- 回合横幅由既有 VFX 表现层按事件创建和释放，不在正式 Scene 中常驻可能数量的临时节点。
- 修改战斗整屏、HUD、事件时序、回合横幅或特效层级时直接改本 Scene 或 `core_ui/scripts/battle/`；修改宠物战斗表现、详情容器、卡片组件、遮罩、操作、调试面板或地面元素表现时打开对应 prefab。

## 禁止事项

- 不新建 Catalog、预览副本或第二套 Battle View。
- 不把按钮、HUD 或一次性特效机械拆成新的 prefab；独立可编辑、可调试的 UI 组件可以拆分。
- 不缩小正式节点来规避编辑器点击问题；应让视觉节点的矩形与图片实际范围一致。
- 不复制权威玩法状态，不用固定延迟模拟真实命中。
