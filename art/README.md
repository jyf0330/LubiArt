# Art 目录规则

`art/` 是美术运行资产目录，文件类型严格分开：

```text
art/
├── scenes/      Game 装配 Scene + 两个正式 UI Scene + 独立美术调试 Scene
├── prefabs/     四个公开 prefab + 内部 UI 组件
├── images/      运行图片
└── manifests/   图片映射与 JSON manifest
```

## Game 装配、两个正式 UI Scene 与独立调试 Scene

- 应用装配入口：`res://art/scenes/app/game.tscn`
- 三选一与路线流程：`res://art/scenes/three_choice/three_choice_scene.tscn`
- 战斗：`res://art/scenes/battle/battle_art_scene.tscn`
- SpriteInfoCard 调试：`res://art/scenes/sprite_info_card_debug/sprite_info_card_debug_scene.tscn`

`project.godot` 启动 Game Scene。Game 持有唯一 Session；进入战斗时只挂载战斗 Scene 并向它投递公共 Snapshot，三选一与战斗两个 Scene 都只负责表现和发送操作请求。

路线、商店、背包、队伍、结算、按钮、HUD 和回合反馈直接属于两个正式 Scene。宠物攻击、受击、移动、死亡、跨格投射物与伤害数字归入宠物 prefab，地面元素表现归入地形 prefab；独立调试 Scene 只用于检查卡片美术，不接入正式路由。

## 四个公开 prefab 与一个内部组件

- 宠物：`res://art/prefabs/pet/pet.tscn`
- 宠物详情：`res://art/prefabs/pet/pet_detail.tscn`
- 宠物详情卡片组件：`res://art/prefabs/pet/sprite_info_card.tscn`
- 商店信息内部组件：`res://art/prefabs/shop/bazaar_info_panel.tscn`
- 地形：`res://art/prefabs/terrain/terrain.tscn`
- 地形详情：`res://art/prefabs/terrain/terrain_detail.tscn`

`pet_detail.tscn` 实例化 `sprite_info_card.tscn`；后者可独立编辑，并由调试 Scene 提供元素、品质、特性锁和数值切换检查。

## 文件边界

- `art/` 不放 `.gd`；所有 UI 脚本与 `.gd.uid` 放在 `res://core_ui/scripts/`。
- 图片只放 `art/images/`，JSON 映射只放 `art/manifests/`。
- 高分辨率原始图片使用英文文件名放在对应运行图片旁的 `sources/` 子目录；manifest 同时记录 `sourceResource` 与运行时 `resource`。
- 不恢复 `game/**`、`features/**`、`shared/prefabs/**`、`assets/**` 或 Catalog 兼容副本。
- 美术修改节点时直接打开所属正式 Scene、四个公开 prefab、卡片组件或独立调试 Scene，不复制第二份运行实现。
