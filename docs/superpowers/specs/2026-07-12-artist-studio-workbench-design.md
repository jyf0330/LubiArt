# Artist Studio 美术工作台设计

日期：2026-07-12

状态：待用户审阅

## 目标

在 Godot 主工程内提供一个独立的美术调试入口。美术可以直接运行该入口，查看现有路线、商店、背包和战斗美术场景，切换典型视觉状态，单独或组合播放既有动效；整个过程不进入正式玩家流程，也不改变核心规则、存档或美术布局。

## 非目标

- 不复制或修改原始美术压缩包。
- 不重排 `artist_flow`、`battle_flow` 的节点、槽位、锚点、图层或图片。
- 不把预览状态写入 `YsbzsState`、正式存档或运行数据。
- 不把工作台工具按钮带进玩家入口。
- 不在没有动态文字层的美术画面上增加可见运行时文字。

## 架构

```text
ArtistStudio (debug-only scene)
  ├─ PreviewCanvas
  │   ├─ existing artist_flow scene instance
  │   └─ existing battle_flow scene instance / VFX prefab instances
  ├─ DebugControls (outside the artist canvas)
  ├─ ArtistPreviewCatalog
  │   ├─ artist_preview_presets.json
  │   └─ artist_motion_catalog.json
  └─ screenshot / smoke hooks
```

`ArtistStudio` 只编排既有场景与 prefab，不成为新的玩家 UI。`ArtistPreviewCatalog` 只读取 `debug/fixtures/artist_preview_snapshots.json` 的固定路线、商店和战斗快照，并包装成只读 `ArtistPreviewState`；不会读取存档、也不会按 seed 推导美术数据。正式游戏继续由自己的 `YsbzsState.snapshot()` 和真实 `battle_trace` 驱动。两条输入路径共用画面组件，但互不写入对方状态。

## 页面与状态预设

第一阶段提供以下可切换预设：

| 分组 | 预设 | 可验证内容 |
|---|---|---|
| 路线 | `route_default`、`route_selected` | 三选槽、节点图、选中状态 |
| 商店 | `shop_stocked`、`shop_sold` | 商品图、已售空槽、返回热区的视觉状态 |
| 队伍 / 背包 | `party_full`、`bag_full`、`dragging` | 固定槽位、空满状态、跟手预览 |
| 战斗 | `battle_opening`、`battle_selected`、`battle_pet_detail` | 8x8 场地、选中 / hover、详情面板 |

预设文件只保存视觉所需的页面、槽位数据、图片映射 key、选中/drag 状态和可播放动效名。它不保存数值结算、随机数、回合、伤害或存档字段。

## 动效预览

动效目录以名称和 presentation 参数描述既有 prefab：`bite`、`projectile`、`damage_number`、`round_banner`。工作台支持：

- 单个播放、暂停、停止、循环和倍率；
- 选择起点、终点、目标或伤害显示位置；
- 由预设定义的短序列，例如 `bite -> damage_number`；
- 同一个效果在正式战斗继续只由真实 `battle_trace` 触发。

工作台仅调用 prefab 对外 API；不从 controller 直接修改 prefab 内部子节点，不引入 demo 包的战斗规则。

## 美术与规则边界

- 复用 `art/scenes/artist_flow/artist_flow_view.tscn`、`art/scenes/battle/battle_view.tscn` 和已有 prefab；不修改它们。
- 新的调试控制台放在 artist canvas 之外，且仅 debug scene 可见。
- 宠物、商店和奖励图片继续读取已有显式 mapping；缺失映射只记录日志 / gap，不猜图或加“缺图”文字。
- 工作台只对其临时 state 使用既有 command 生成预览快照；不接入、不修改正式游戏 state 或存档。
- 如果某个现有 UI 必须由 `artist_ui_middle_controller.gd` 或 `battle_ui_controller.gd` 的未公开入口才能预览，本任务先记录 API gap；不触碰当前被其他 ACTIVE 任务独占的 controller 文件。

## 文件边界

本实现只新增 `art/scenes/debug/artist_studio.tscn`、`core_ui/scripts/debug/artist_studio.gd`、`core_ui/scripts/debug/artist_preview_catalog.gd`、两个 JSON 数据文件和 `tests/features/smoke_artist_studio.gd`。不修改当前 ACTIVE 任务独占的 `artist_ui_middle_controller.gd`、`smoke_artist_ui.gd`、`ysbzs_state.gd`、`smoke_singleplayer.gd` 或 `smoke_playable_flow.gd`。

## 验收

1. Godot editor 能载入整个项目和工作台场景。
2. 专用 smoke 能实例化工作台、切换至少一个路线和一个战斗预设，并播放至少一个既有 VFX prefab。
3. 在真实 Godot 窗口中运行工作台，截图确认工具条没有覆盖美术画面；运行后保留最后一个成功窗口。
4. 回归只读检查：正式玩家入口和已有 smoke 不因工作台新增文件被修改。

## 交付

美术日常使用入口为 `art/scenes/debug/artist_studio.tscn`。第一阶段不单独导出 App；待预设与动效控制稳定且美术确实需要脱离主工程时，再评估方案 B 的独立分发包。
