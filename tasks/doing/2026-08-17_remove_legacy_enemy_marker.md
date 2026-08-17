# 删除废弃敌方恶魔标记

- status: completed
- owner: codex-root-20260817-remove-enemy-marker
- user_authorization: 2026-08-17 使用者指明战斗单位血条上方的红色恶魔图标是废弃方案，要求直接删除
- objective: 从正式战斗与独立 LubiArt Mock 中移除废弃 `enemy_marker.png` 资源及 prefab 引用，不改变玩法、Snapshot、血条、单位朝向或节点拓扑
- write_scopes:
  - `art/images/shared/pets/battle_complete/enemy_marker.png`
  - `art/images/shared/pets/battle_complete/enemy_marker.png.import`
  - `art/prefabs/pet/pet.tscn`
  - `tasks/doing/2026-08-17_remove_legacy_enemy_marker.md`
  - `C:/Users/jyf/Documents/LubiArt/art/images/shared/pets/battle_complete/enemy_marker.png`
  - `C:/Users/jyf/Documents/LubiArt/art/images/shared/pets/battle_complete/enemy_marker.png.import`
  - `C:/Users/jyf/Documents/LubiArt/art/prefabs/pet/pet.tscn`
  - `C:/Users/jyf/Documents/LubiArt/.agents/skills/lubiart-godot-ui-art/references/conversation-synthesis.md`
- exclusive_files:
  - `art/images/shared/pets/battle_complete/enemy_marker.png`
  - `art/images/shared/pets/battle_complete/enemy_marker.png.import`
  - `art/prefabs/pet/pet.tscn`
  - `tasks/doing/2026-08-17_remove_legacy_enemy_marker.md`
- existing_wip:
  - 既有战斗、商店和控制面内容全部保留；相关旧任务卡均为 completed，本任务不改 `tasks/ai/QUEUE.md`、`tasks/ai/STATUS.md` 或其他 owner 文件
  - 正式发布目录没有 Git 元数据，因此不形成提交
- implementation_contract:
  - 只删除恶魔图片文件、Godot 导入描述与 prefab 纹理引用
  - 保留现有隐藏 `EnemyMarker_Optional/Icon` 节点，避免未另行披露确认的节点拓扑修改
  - 不修改 `pet_visual.gd`、正式状态、战斗规则、数据或交互
- validation:
  - 全仓确认不存在 `enemy_marker.png` 或其 ext_resource 引用
  - Godot 解析/专项战斗 smoke
  - 正式入口真实窗口至少五个战斗操作，确认敌方单位不再显示恶魔标记且血条、角色、交互无异常
- stop_conditions:
  - 正式项目与 LubiArt Mock 均不再包含或引用该图片
  - 可见验证覆盖入口、详情、拖拽、自动布置和行动演出中的敌方单位
  - 无节点拓扑、玩法或数据变化

## 实施与验证结果

- 正式项目和 LubiArt Mock 均删除 `enemy_marker.png`、相邻 `.import` 及 `pet.tscn` 中的 ext_resource/texture 引用；保留隐藏 `EnemyMarker_Optional/Icon` 节点，节点拓扑、脚本、血条、玩法与数据未改。
- 正式 Godot 4.7 headless editor 扫描通过；`SMOKE_BATTLE_ART_RESOURCE_CONVERGENCE_OK`、`SMOKE_BATTLE_UI_OK`、`SMOKE_BATTLE_DISPLAY_READABILITY_OK`。
- 正式 Vulkan `1920×1080` 从正式入口完成 10 个操作并输出 `FORMAL_BATTLE_OPERATION_PARITY_PASS count=10`，覆盖入口、悬停、详情、空地关闭、拖拽、取消、自动布置、开始行动和第一回合完成；人工检查关键帧确认全部敌方单位不再显示恶魔标记，血条、角色和交互正常。证据位于 `output/validation/remove-legacy-enemy-marker-20260817/after/`。
- LubiArt headless editor 扫描及 `verify_ui_mirror.sh` 通过，后者输出动画批准门禁通过与 `MOCK_UI_STANDALONE_STRUCTURE_PASS`。方向专项仍先被既有 `pal_001` 朝向元数据缺失阻断；全量 smoke 和 Battle Scene smoke 分别复现当前基线已记录的四类断言与 `scene_nodes=12 / board_children=4 / grid_children=64` 层级失败，签名未变化且与本次资源删除职责无关。
- 正式发布目录无 Git 元数据，本任务不形成提交；未修改 `tasks/ai/QUEUE.md`、`tasks/ai/STATUS.md` 或其他 owner 文件。
