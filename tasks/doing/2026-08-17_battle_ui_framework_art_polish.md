# 战斗 UI 框架拆分与美术层级优化

- status: completed
- owner: codex-root-20260817-battle-ui-framework
- user_authorization: 2026-08-17 用户要求“要优化美术，要优化 UI 框架的架构”
- objective: 在不改变正式战斗权威链的前提下，把战斗宠物 UI 从“各组件重复解释 Dictionary、单脚本运行时搭整张卡”收敛为纯视觉模型、可复用基础组件和场景组装三层；同时优化战斗详情卡的信息层级、数值条清晰度和阵营/品质识别，形成可移植到其他游戏项目的独立 UI 模块
- write_scopes:
  - `tasks/doing/2026-08-17_battle_ui_framework_art_polish.md`
  - `core_ui/scripts/battle/presenters/battle_pet_view_model.gd*`
  - `core_ui/scripts/shared/components/ui_value_bar.gd*`
  - `core_ui/scripts/battle/prefabs/battle_attack_shape_grid.gd*`
  - `core_ui/scripts/shared/pet/battle_unit_status_bar.gd`
  - `core_ui/scripts/battle/prefabs/battle_compact_info_card.gd`
  - `core_ui/scripts/battle/controllers/battle_detail_controller.gd`
  - `art/prefabs/shared/ui_value_bar.tscn`
  - `art/prefabs/battle/battle_attack_shape_grid.tscn`
  - `art/prefabs/pet/battle_unit_status_bar.tscn`
  - `art/prefabs/battle/battle_compact_info_card.tscn`
  - `tests/presentation/smoke_battle_ui_component_architecture.gd*`
  - `tests/features/smoke_battle_art_resource_convergence.gd`
  - `tests/features/smoke_battle_pet_hover_detail.gd`
  - `tasks/ai/QUEUE.md`
  - `tasks/ai/STATUS.md`
- exclusive_files:
  - `core_ui/scripts/battle/presenters/battle_pet_view_model.gd`
  - `core_ui/scripts/shared/components/ui_value_bar.gd`
  - `core_ui/scripts/battle/prefabs/battle_attack_shape_grid.gd`
  - `art/prefabs/shared/ui_value_bar.tscn`
  - `art/prefabs/battle/battle_attack_shape_grid.tscn`
  - `tests/presentation/smoke_battle_ui_component_architecture.gd`
- existing_wip:
  - 开工时 `git status --short --untracked-files=all` 为空；相关旧战斗美术任务卡均为 `completed`
  - 旧巡检任务仍记录 `battle_board_drag_interaction.gd` 的精确实窗复验，本任务不修改该文件
  - 宠物图片任务保持 `paused`；不接管 `pal_279`–`pal_283` 或正式图片清单
- architecture_contract:
  - `BattlePetViewModel` 只把公开 Snapshot/详情 record 投影成稳定视觉字段，不持有 Node、不发 Command、不修改状态
  - `UiValueBar` 与 `BattleAttackShapeGrid` 只渲染显式输入，不读取 GameSession、Snapshot 或战斗规则
  - `BattleCompactInfoCard` 与 `BattleUnitStatusBar` 只编排子组件；`BattleOverlay` 继续只负责详情生命周期，不新增玩法职责
- validation:
  - 新增纯组件 smoke，覆盖别名归一化、无输入突变、数值夹取、伤害预览和攻击形状投影
  - 既有 `smoke_battle_art_resource_convergence.gd`、`smoke_battle_pet_hover_detail.gd`、`smoke_battle_ui.gd`
  - `python3 tools/qa/run_qa.py --suite fast`
  - 独立虚拟屏从正式入口重拍战斗入口、我方详情、敌方详情、拖拽和首回合至少 5 个状态；检查 1920×1080 下无裁切、遮挡、状态条与立绘相交
  - `git diff --check`
- stop_conditions:
  - 若上述运行时目标出现其他 owner 新修改，执行 `FILE_CONFLICT_STOP`
  - 不修改 `GameSession -> Command -> YsbzsState -> Result/Trace/Snapshot`、玩法数值、攻击形状规则或资产映射
  - 不复制旧 Mock 的 Scene/GDScript；保留正式项目现有资源身份和交互流程

## 当前证据

- `BattleCompactInfoCard` 当前在单个脚本中运行时创建整张 380×820 卡，混合节点结构、颜色/字体、美术布局、字段别名归一化和攻击形状投影。
- `BattleUnitStatusBar` 再次独立解析 `hp/max_hp/shield/side`，详情控制器也有第三套字段投影；同一公开数据在三个表现模块中被重复解释。
- 最新 `c35212a1` 已证明战斗资源身份、单位血条和深色详情方向可用，因此本轮只做框架拆分和当前方向内的视觉层级优化，不更换美术方向。

## 实施结果

- 新增纯 `BattlePetViewModel`，统一兼容公开战斗/详情字典中的字段别名、阵营、生命、护盾、行动力、攻击形状和非数值容错；它不持有 Node、不发 Command，也不修改输入。
- 新增可复用 `UiValueBar`，封装数值夹取、文本、颜色和损失预览；单位血条和战斗详情卡现在消费同一组件。新增 `BattleAttackShapeGrid`，只把显式相对坐标投影到 7×3 网格。
- `BattleCompactInfoCard` 从运行时创建整张卡改成 `.tscn` 场景组装，脚本只绑定视觉模型和子组件；脚本由约 320 行缩到约 140 行。详情卡新增阵营色条、中文品质、分区标题、攻击范围图例和更清晰的六项属性层级。
- `BattleDetailController` 复用同一视觉模型，不再维护第三套生命/护盾/攻防/AP 字段翻译。`BattleOverlay`、正式 Session、Command/Result/Trace/Snapshot 与玩法规则未修改。
- 第一轮实窗在自动布置后发现正式 `threat` 可能是结构化字典；视觉模型原先把它直接转整数，日志出现 `SCRIPT ERROR`。已改为显式安全数值转换并补回归，第一轮证据作废，最终只采信无错误的 round-002。

## 验证与证据

- 组件专项：`SMOKE_BATTLE_UI_COMPONENT_ARCHITECTURE_OK`，覆盖输入不变、字段别名、结构化 threat 容错、数值条损失预览、7×3 攻击形状和场景组件身份。
- 既有专项全部通过：`SMOKE_BATTLE_ART_RESOURCE_CONVERGENCE_OK`、`SMOKE_BATTLE_PET_HOVER_DETAIL_OK`、`SMOKE_BATTLE_UI_OK`。
- 独立虚拟屏、隔离项目副本和独立 `user://` 的正式入口 10 步实窗为 `FORMAL_BATTLE_OPERATION_PARITY_PASS count=10`；最终截图及 manifest 位于 `output/validation/battle-ui-framework/round-002/`，1920×1080 的入口、详情、拖拽、自动布置和首回合均无裁切或遮挡。
- 10 单位正式入口布局门禁为 `SMOKE_BATTLE_VISIBLE_UNIT_LAYOUT_OK units=10 entries=8`；状态条与立绘无相交，四张过程证据位于 `output/validation/battle-ui-framework/round-002/visible-unit-layout/`。
- 完整 fast：`output/validation/qa/20260817-052615-fast/summary.json`，19/19、0 失败、353.562 秒；battle UI 15.88 秒、playable flow 173.17 秒、seed bot 104.66 秒。
- `git diff --check` 通过。

## 遗留边界

- 本轮是战斗宠物 UI 框架的第一个可独立闭环；商店/背包的旧详情卡仍有各自字段归一化，未在没有跨模块视觉验收的情况下扩展改写。
- 旧巡检的“详情打开后直接拖拽”精确步骤仍由原任务跟踪；本轮 10 步序列仍先关闭详情再拖拽，不冒充该旧 P1 的验收。
- 验证期间出现的 `tasks/doing/2026-08-17_vanessa_139_pet_planning_workbook.md` 修改属于其他 owner；未读取改动内容、未暂存、未提交。
