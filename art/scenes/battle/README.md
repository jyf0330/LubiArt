# BattleArtScene 美术使用说明

本目录是战斗界面的美术总装入口。美术需要查看战斗场景或寻找正式预制体时，直接打开：

- `res://art/scenes/battle/battle_art_scene.tscn`

这个场景只负责“正式运行界面 + 正式预制体索引”，不保存第二套战斗逻辑。

## 场景层级

```text
BattleArtScene
├── Runtime
│   ├── PreviewBackground
│   └── BattleView
└── PrefabCatalog
    ├── ReusablePrefabs
    │   ├── Board
    │   ├── Units
    │   └── HUD
    └── RuntimeEffects
        ├── Projectiles
        ├── HitFeedback
        └── RoundFeedback
```

- `Runtime/BattleView`：唯一正式战斗界面。运行时数据、输入、动画和特效都继续由它处理。
- `PrefabCatalog`：只用于查找正式预制体，不参与运行、输入或玩法。
- `ReusablePrefabs`：棋盘格、战斗单位、操作面板和宠物信息面板。
- `RuntimeEffects`：投射物、伤害数字、咬击和回合横幅等事件特效，默认隐藏。

## 图层节点规则

本场景按“分组 → 图片组件 → 内部动态内容”组织：

- `PrefabCatalog` 下每个正式分层组件节点必须直接对应一张图片，不再用空节点套图片节点来表达同一层。
- 图片层使用 `TextureRect`、`Sprite2D` 等节点，一层对应一张图片；节点矩形必须贴合图片的有效视觉范围，不能用整屏透明区域扩大选择框。
- 需要输入、状态、动画或公开接口的图片节点可以同时挂表现脚本；没有这些职责时不挂脚本。
- 图片组件内部允许有动态 `Label`、粒子、动画辅助节点，但不能再增加一个只为重复命名的图片包装层。
- 图片节点只负责显示和表现；权威战斗数据和流程不能放进图片层。

`Runtime/BattleView` 和表格中的正式 prefab 实例已设为“可编辑子节点”，可以直接在 Scene 树中展开，查看里面真实存在的图片层、容器层和脚本节点。

## 为什么根节点带锁

全屏 `Control`、背景和 prefab 实例根节点保留正常尺寸与 `scale = 1`，没有再缩成 1×1。

这些结构根节点使用 Godot 编辑器锁定，避免全屏根节点在 2D 画布中抢走鼠标选择。锁定只限制编辑器画布误选，不影响：

- Scene 树展开和查看子图层
- 图片的 authored 尺寸、位置与比例
- 正式运行时缩放、动画和输入
- 脚本与真实战斗事件

需要选择结构根节点时，从 Scene 树点击；需要选择图片层时，展开实例后点击对应的 `TextureRect` / `Sprite2D`。不要取消根节点锁定来修运行时视觉。

## 正式预制体位置

| Catalog 节点 | 正式场景 | 用途 |
| --- | --- | --- |
| `Board/BattleCell` | `res://art/prefabs/battle/board/battle_cell.tscn` | 棋盘格 |
| `Units/BattleUnit` | `res://art/prefabs/shared/pet/pet_visual.tscn` | 战斗宠物/单位 |
| `HUD/BattleActionPanel` | `res://art/prefabs/battle/hud/battle_action_panel.tscn` | 战斗操作面板 |
| `HUD/Details/PetDetailPanel` | `res://art/prefabs/shared/pet/pet_detail_panel.tscn` | 宠物详情遮罩与操作 |
| `HUD/Details/PetInfoPanelV2` | `res://art/prefabs/shared/pet/pet_info_panel_v2.tscn` | 宠物信息卡 |
| `Projectiles/BattleProjectile` | `res://art/prefabs/battle/effects/battle_projectile.tscn` | 投射物 |
| `HitFeedback/BattleDamageNumber` | `res://art/prefabs/battle/effects/battle_damage_number.tscn` | 伤害数字 |
| `HitFeedback/BattleBiteVfx` | `res://art/prefabs/battle/effects/battle_bite_vfx.tscn` | 咬击表现 |
| `RoundFeedback` | `res://art/prefabs/battle/hud/battle_round_banner.tscn` | 回合横幅图片与表现脚本 |

`BattleProjectile` 是 `Sprite2D`，仍与其他索引根一样保持编辑器锁定；展开或打开正式场景后可以查看其脚本与运行时图片映射。

对应代码统一在 `res://core_ui/scripts/battle/`，战斗图片统一在 `res://art/images/battle/`；不要在 `art/scenes` 或 `art/prefabs` 旁边新建 `.gd`。

## RoundFeedback 的作用

`RoundFeedback` 本身就是回合横幅的正式图片节点，并直接挂载回合反馈表现脚本，不再存在 `RoundFeedback → BattleRoundBanner → Banner` 的重复层级。

源图片 `res://art/images/battle/runtime/images/round_banner_blank.png` 四周有大块透明留白，场景通过 `AtlasTexture` 只显示有效视觉区域；1920×1080 下节点矩形约为 `902×254`，与画面中真正可见的横幅一致。表现脚本是 `res://core_ui/scripts/battle/prefabs/hud/battle_round_banner.gd`。源 PNG 不裁切、不回写，美术仍可替换原资源。

`Title` 和 `Subtitle` 是图片内部的动态文字层。正式运行时仍由 `BattleView` 的真实战斗事件触发；Catalog 中的实例只是索引，不能在这里添加固定播放逻辑。

## 美术修改流程

1. 在本页的表格中找到目标节点对应的正式 `.tscn`。
2. 先在 `battle_art_scene.tscn` 的 Scene 树中展开实例，确认目标图片层和脚本节点。
3. 在 Godot 文件系统中双击正式场景，修改图片、节点层级、authored 位置、尺寸或动画。
4. 回到 `battle_art_scene.tscn`，确认 Catalog 仍引用该正式场景，图层仍可展开。
5. 不要在 Catalog 索引实例上调整视觉来代替修改正式 prefab。
6. 运行时才显示的特效继续保持默认隐藏，由程序完成真实事件接入和验收。

## 不要在这里做

- 不要在 `PrefabCatalog` 创建 Session、Snapshot、战斗状态或玩法数据。
- 不要复制一份 `BattleView` 形成第二套运行界面。
- 不要取消结构根节点的编辑器锁定来解决画布选择问题。
- 不要把视觉节点缩小到看不见；正式实例保持原始尺寸和 `scale = 1`。
- 不要通过移动 Catalog 节点来修正式运行位置。
- 不要给运行时特效添加固定延迟或自动播放来模拟真实命中。
- 美术稿没有动态文字层时，不要自行叠加价格、名称或缺图提示。

正式视觉内容改在正式 prefab，Catalog 只负责让大家容易找到它们。
