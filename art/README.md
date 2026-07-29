# Art 目录规则

`art/` 是美术运行资产目录，文件类型严格分开：

```text
art/
├── scenes/      两个正式 Scene + 一个独立调试 Scene
├── prefabs/     四个公开 prefab + 一个详情卡片组件
├── images/      运行图片
└── manifests/   图片映射与 JSON manifest
```

## 两个正式 Scene 与独立调试 Scene

- 三选一与路线流程：`res://art/scenes/three_choice/three_choice_scene.tscn`
- 战斗：`res://art/scenes/battle/battle_art_scene.tscn`
- SpriteInfoCard 调试：`res://art/scenes/sprite_info_card_debug/sprite_info_card_debug_scene.tscn`

`project.godot` 直接启动三选一 Scene；进入战斗时，它只挂载战斗 Scene。

路线、商店、背包、队伍、结算、按钮、HUD、回合反馈、投射物、伤害数字和咬击表现都直接属于两个正式 Scene 的节点树或表现脚本；调试 Scene 仅用于独立检查 `SpriteInfoCard`。

## 四个公开 prefab 与一个内部组件

- 宠物：`res://art/prefabs/pet/pet.tscn`
- 宠物详情：`res://art/prefabs/pet/pet_detail.tscn`
- 宠物详情卡片组件：`res://art/prefabs/pet/sprite_info_card.tscn`
- 地形：`res://art/prefabs/terrain/terrain.tscn`
- 地形详情：`res://art/prefabs/terrain/terrain_detail.tscn`

`sprite_info_card.tscn` 只由 `pet_detail.tscn` 实例化，用于单独编辑卡片和调试数据；其余四个是跨位置或跨流程公开复用的 prefab。“可以实例化”不等于“应该做成 prefab”。

## 文件边界

- `art/` 不放 `.gd`；所有 UI 脚本与 `.gd.uid` 放在 `res://core_ui/scripts/`。
- 图片只放 `art/images/`，JSON 映射只放 `art/manifests/`。
- 不恢复 `game/**`、`features/**`、`shared/prefabs/**`、`assets/**` 或 Catalog 兼容副本。
- 美术修改节点时直接打开所属 Scene、四个公开 prefab 或 `sprite_info_card.tscn`，不复制第二份运行实现。
