# 战斗界面美术双向同步与 10 步逐操作对照

- status: completed
- owner: codex-root-20260817-battle-art-roundtrip
- user_authorization: 2026-08-17 用户要求“战斗界面继续”“10 张图就行了”
- objective: 以独立 LubiArt Mock 的真实战斗运行画面为左侧参考，以 `godot-latest` 正式权威战斗相同语义操作为右侧结果，固定交付 10 张逐操作并排图；先把正式公开战斗 Snapshot/Result 和批准图片同步到美术项目，再只把确认的纯 UI/资源修复回正式项目，不复制 Mock Scene、脚本、Session、固定槽位或权威规则
- write_scopes:
  - `tasks/doing/2026-08-17_battle_art_roundtrip_10_steps.md`
  - `tests/visible/capture_formal_battle_operation_parity.gd`
  - `tools/export_public_battle_capture.gd`
  - `core_ui/scripts/shared/pet/pet_visual.gd`
  - `tools/qa/build_battle_operation_comparison.py`
  - `tools/qa/check_battle_art_geometry.py`
  - `tools/qa/test_battle_operation_comparison.py`
  - `tools/qa/test_battle_art_geometry.py`
  - `/Users/ywh/Documents/godot-battle-ui-mock/data/mock_battle_snapshot.json`
  - `/Users/ywh/Documents/godot-battle-ui-mock/art/images/formal_sync/battle/**`
  - `/Users/ywh/Documents/godot-battle-ui-mock/art/images/formal_sync/shop/pets/pal_003.png`
  - `/Users/ywh/Documents/godot-battle-ui-mock/art/images/formal_sync/shop/pets/pal_003.png.import`
  - `/Users/ywh/Documents/godot-battle-ui-mock/art/images/formal_sync/shop/pets/pal_004.png`
  - `/Users/ywh/Documents/godot-battle-ui-mock/art/images/formal_sync/shop/pets/pal_004.png.import`
  - `/Users/ywh/Documents/godot-battle-ui-mock/art/manifests/battle/formal_sync_manifest.json`
  - `/Users/ywh/Documents/godot-battle-ui-mock/art/manifests/shared/pets/sheets/pet_id_map.json`
  - `/Users/ywh/Documents/godot-battle-ui-mock/tests/visible/battle_formal_sync_parity_capture.gd`
  - `/Users/ywh/Documents/godot-battle-ui-mock/tests/visible/battle_formal_sync_parity_capture.gd.uid`
  - `/Users/ywh/Documents/godot-battle-ui-mock/core_ui/scripts/battle/controllers/battle_board_drag_interaction.gd`
  - `/Users/ywh/Documents/godot-battle-ui-mock/.agents/skills/lubiart-godot-ui-art/references/conversation-synthesis.md`
  - `output/validation/battle-art-roundtrip/round-001/**`
- exclusive_files:
  - `tasks/doing/2026-08-17_battle_art_roundtrip_10_steps.md`
  - `tests/visible/capture_formal_battle_operation_parity.gd`
  - `tools/export_public_battle_capture.gd`
  - `core_ui/scripts/shared/pet/pet_visual.gd`
  - `tools/qa/build_battle_operation_comparison.py`
  - `tools/qa/check_battle_art_geometry.py`
  - `tools/qa/test_battle_operation_comparison.py`
  - `tools/qa/test_battle_art_geometry.py`
  - `/Users/ywh/Documents/godot-battle-ui-mock/tests/visible/battle_formal_sync_parity_capture.gd`
  - `/Users/ywh/Documents/godot-battle-ui-mock/core_ui/scripts/battle/controllers/battle_board_drag_interaction.gd`
- existing_wip:
  - 正式仓 `tasks/ai/QUEUE.md`、`tasks/ai/STATUS.md` 和既有巡检卡是其他 owner 的累计 WIP，本任务不改写、不暂存、不提交
  - 美术仓五个既有 `.psd.import` 修改属于其他工作资产；本任务不覆盖、不回退、不暂存
  - 当前不租用任一战斗运行时代码或 Scene；真实并排图若确认错位，先在本卡记录失败证据和责任文件，再检查租约并扩展精确写入范围；发生重叠时执行 `FILE_CONFLICT_STOP`
- ten_operations:
  1. 战斗入口稳定态
  2. 悬停我方第一只宠物
  3. 选中我方宠物并打开详情
  4. 点击空地并关闭详情
  5. 拖拽摆位预览
  6. 取消拖拽并恢复规划态
  7. 自动布置按钮悬停
  8. 自动布置完成
  9. 开始行动按下/执行
  10. 第一回合演出完成
- validation:
  - 正式公开数据导出来源、哈希、步骤和状态身份可核对；Mock 只离线重放，不接收正式存档、核心状态对象或规则代码
  - 两仓分别使用独立项目副本、`.godot`、`user://`、Godot 进程和专用虚拟屏，串行采集 1920×1080 当前轮截图
  - 每张并排图固定左美术 Mock、右正式项目，并绑定操作名称、Snapshot 身份、悬停/焦点/拖拽或命令状态
  - 人工打开并检查全部 10 张当前轮并排图；可共享区域运行几何、像素、裁切、层级和遮挡门禁
  - 相关战斗 smoke、Python 专项、Mock 独立结构/动画准入和双仓本任务范围 `git diff --check`
- stop_conditions:
  - 恰好生成并验收 10 张当前轮并排图，不用旧图冒充当前证据
  - 确认错位只修真正责任层；没有确认差异时不制造运行时改动
  - 正式权威链与 Mock 独立边界保持不变，`code_inbound=0`
  - 用户 Godot、主屏、其他虚拟屏和并行 WIP 保持不变；精确提交且不推送

## 实施结果

- 正式项目使用固定种子启动新的 `LocalGameSession`，导出完整公开回放：初始 `v1/88f57bae44d633cc`，14 个按钮步骤后结束于 `v15/bd393f73779943be`、`battle_end`。旧 slot 2 因内容哈希漂移被正式加载器拒绝，未绕过校验读取陈旧存档。
- 正式 `pal_001` 至 `pal_004` 图片和公开 JSON 先同步到独立美术项目；`pal_003`、`pal_004` 新增明确映射与同步清单。没有把正式存档、权威状态对象、规则脚本、Scene 或 Session 带入美术项目。
- 正式项目独立把四项状态 HUD 从两行调整为可容纳时的一行四列，保留四项信息并释放宠物主体高度；没有照抄 Mock 的血条实现。
- 美术项目拖拽开始时清除悬停和固定详情，拖拽预览与取消恢复不再被详情面板遮挡；该修复未回传到正式权威链。
- 两边采集器分别从各自正式入口执行十个同语义操作；美术端增加首次稳定渲染，双方取消拖拽后等待布局回稳。最终比较图固定左 Mock、右正式，共 10 张。
- 清理 86 个可重新生成的旧轮次原始截图目录，保留所有对照图、审计、修复前证据与 round-118 原始图，释放约 6.8 GiB；未删除源资源或用户项目数据。

## 验证与证据

- 10/10 操作的 Snapshot 身份一致；对照图目录：`output/validation/battle-art-roundtrip/round-001/comparison/`。
- 几何审计：`python3 tools/qa/check_battle_art_geometry.py ...`，`BATTLE_ART_GEOMETRY_PASS checks=15`；证据：`output/validation/battle-art-roundtrip/round-001/geometry_audit.json`。
- Python 专项：`python3 -m unittest test_battle_operation_comparison test_battle_art_geometry`，2/2 通过。
- 完整离线回放专项：14/14 步身份匹配，结束于 `battle_end`，最终哈希 `bd393f73779943be`。
- 正式 headless：`SMOKE_BATTLE_DISPLAY_READABILITY_OK`。
- 正式独立虚拟屏真实窗口：`SMOKE_BATTLE_VISIBLE_UNIT_LAYOUT_OK units=10 entries=8`；状态 HUD 与宠物主体无相交。
- 人工逐张检查全部 10 张当前轮对照图；没有复用旧轮截图，也没有发现裁切、越界、拖拽详情遮挡或取消后预览残留。
- 美术仓既有 `visible_formal_capture_replay.gd` / 拖拽综合测试依赖当前应用不再提供的旧 battle feature-controller 路由；既有综合 smoke 还包含新资源节点和伤害条类型漂移断言。它们在本轮前置责任层之外，未通过扩大运行时改动来迎合旧断言；本轮用直接 BattleScene 采集、完整 MockSession 回放与正式真实窗口证据覆盖实际改动。

## 遗留风险与边界

- 两边仍保留各自美术方向：Mock 为深色详情卡和血条，正式为羊皮纸详情和一行四项状态；这是明确可见差异，不宣称整屏像素一致。
- `pal_002` 在美术项目仍会提示缺少 `authored_horizontal_facing` 元数据并使用项目默认朝右；当前截图朝向正确，但后续正式接入方向性动画前应补齐元数据。
- `tasks/ai/QUEUE.md`、`tasks/ai/STATUS.md` 正有其他 owner 的未提交修改，本轮按冲突保护不覆盖、不暂存；完成事实仅写入本任务卡。
- 用户 Godot PID 5112、主屏和其他工作槽未关闭或清理；两仓只精确提交本任务文件，不推送。
