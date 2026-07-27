# Art 场景入口

`art/` 是项目唯一的运行视觉目录，给美术、策划和程序共同维护场景、预制体与图片。

## 目录约定

- 正式启动入口固定为 `res://art/scenes/art.tscn`，不再从 `game.tscn` 启动。
- 场景统一放在 `art/scenes/<scene_id>/`；可复用预制体统一放在 `art/prefabs/<scope>/`。
- 图片统一放在 `art/images/<scope>/`；图片映射和随图 manifest 单独放在 `art/manifests/<scope>/`。两个类型目录内部都按 `shared/pets`、`route`、`battle`、`debug` 分类。
- `art/` 不放 `.gd`；场景控制器、Presenter 和预制体表现脚本统一放在 `core_ui/scripts/<scope>/`。
- 总装 `.tscn` 只实例化正式场景和正式预制体，不复制它们的内部节点或脚本。
- 场景根节点是可运行的组合边界；需要包住正式运行视图时，只提供视图查询和装配关系，不复制控制器、Session、Snapshot 或玩法状态。
- `PrefabCatalog` 用于一次找到该页面依赖的全部预制体；战斗场景按 `Board`、`Units`、`HUD` 和 `RuntimeEffects` 继续分类。
- `RuntimeEffects` 下的目录实例默认隐藏；它们只在投射物命中、伤害结算、回合切换等游戏时机由正式运行视图创建或播放。
- 修改视觉或节点结构时，应打开实例指向的正式预制体源文件；总装场景负责汇总，不建立第二份实现。
- 不再新增 `features/**`、`game/**`、`shared/prefabs/**` 或 `assets/**` UI 路径；旧路径已经迁入 `art/` / `core_ui/scripts/`，禁止复制兼容副本。

## 当前场景

- 正式入口：`res://art/scenes/art.tscn`
- 路线：`res://art/scenes/route/route_art_scene.tscn`
- 战斗：`res://art/scenes/battle/battle_art_scene.tscn`

## 对应脚本与图片

- 主装配、路由、功能控制器：`res://core_ui/scripts/`
- 战斗脚本：`res://core_ui/scripts/battle/`
- 共享宠物脚本：`res://core_ui/scripts/shared/pet/`
- 路线图片：`res://art/images/route/`
- 战斗图片：`res://art/images/battle/`
- 共享宠物图片：`res://art/images/shared/pets/`
- 图片映射与 manifest：`res://art/manifests/`
