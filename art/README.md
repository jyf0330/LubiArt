# Art 目录规则

`art/` 是美术运行资产目录，文件类型严格分开：

```text
art/
├── scenes/      两个正式 Scene
├── prefabs/     四个公开 prefab
├── images/      运行图片
└── manifests/   图片映射与 JSON manifest
```

## 两个正式 Scene

- 三选一与路线流程：`res://art/scenes/three_choice/three_choice_scene.tscn`
- 战斗：`res://art/scenes/battle/battle_art_scene.tscn`

`project.godot` 直接启动三选一 Scene；进入战斗时，它只挂载战斗 Scene。

路线、商店、背包、队伍、结算、按钮、HUD 和回合反馈直接属于两个正式 Scene。宠物攻击、受击、移动、死亡、跨格投射物与伤害数字归入宠物 prefab，地面元素表现归入地形 prefab；这些表现不另建第五个 `.tscn`。

## 四个公开 prefab

- 宠物：`res://art/prefabs/pet/pet.tscn`
- 宠物详情：`res://art/prefabs/pet/pet_detail.tscn`
- 地形：`res://art/prefabs/terrain/terrain.tscn`
- 地形详情：`res://art/prefabs/terrain/terrain_detail.tscn`

宠物详情卡面直接维护在 `pet_detail.tscn` 的 `Panel/SpriteInfoCard` 节点内，数据调试也由同一 prefab 承载；不另建第五个 prefab 或第三个 Scene。“可以实例化”不等于“应该做成 prefab”。

## 文件边界

- `art/` 不放 `.gd`；所有 UI 脚本与 `.gd.uid` 放在 `res://core_ui/scripts/`。
- 图片只放 `art/images/`，JSON 映射只放 `art/manifests/`。
- 不恢复 `game/**`、`features/**`、`shared/prefabs/**`、`assets/**` 或 Catalog 兼容副本。
- 美术修改节点时直接打开所属 Scene 或四个公开 prefab，不复制第二份运行实现。
