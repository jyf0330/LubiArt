# 战斗右下角按钮图标与快捷键位置对齐

- status: completed
- owner: codex-root-20260817-battle-control-icons
- user_authorization: 2026-08-17 用户最新明确确认左到右必须是 `R / TAB / A`；R 回溯我方精灵到本场入场状态，TAB 打开攻击顺序二级界面，A 执行自动布置；现有按钮图标与大图标的对应关系保持
- objective: 在正式战斗入口把三组“按钮节点 + 大功能图案 + 实际功能”落到左到右 `R / TAB / A`，恢复同序白色快捷键提示并继续隐藏背包；将三个可见大按钮之间的水平间距统一为 `3px`，不改变节点拓扑、功能实现或快捷键绑定
- write_scopes:
  - `tasks/doing/2026-08-17_battle_control_icon_alignment.md`
  - `art/prefabs/battle/hud/battle_map_controls.tscn`
  - `art/images/battle/map_controls/shortcut_hints.png`
  - `tests/features/smoke_battle_map_controls_icon_alignment.gd`
  - `tests/features/smoke_battle_map_controls_icon_alignment.gd.uid`
  - `tests/presentation/smoke_battle_map_controls.gd`
  - `output/validation/battle-control-icon-alignment/**`
- exclusive_files:
  - `art/prefabs/battle/hud/battle_map_controls.tscn`
  - `art/images/battle/map_controls/shortcut_hints.png`
  - `tests/features/smoke_battle_map_controls_icon_alignment.gd`
  - `tests/features/smoke_battle_map_controls_icon_alignment.gd.uid`
  - `tests/presentation/smoke_battle_map_controls.gd`
- existing_wip:
  - `battle_map_controls.tscn` 当前未提交差异来自已完成的战斗美术视觉收敛任务；本任务保留其按钮位置、日志按钮语义等既有改动，只在当前内容上更正三项纹理引用并恢复背包隐藏
  - `tasks/ai/QUEUE.md`、`tasks/ai/STATUS.md` 与其他任务卡属于既有 WIP，本任务不覆盖其内容
- validation:
  - 专项 smoke 断言左到右为 Reset/R、AttackOrder/TAB、AutoArrange/A，并同时验证鼠标按钮与键盘触发的实际信号
  - 从正式 `art/scenes/app/game.tscn` 入口检查至少五个不同状态，并验证 TAB 二级界面、A 自动布置、R 回溯功能链
  - `git diff --check`
- stop_conditions:
  - 若 `battle_map_controls.tscn` 在本任务执行期间出现新的外部改动，执行 `FILE_CONFLICT_STOP`
  - 不修改节点名称、功能脚本、快捷键绑定、Command/Session/Snapshot 或玩法逻辑；只允许三组既有功能节点在三个既有槽位间恢复正确排列

## 2026-08-17 用户澄清后的续作记录

- 前一版 `TAB / A / R` 解释已被用户本轮明确澄清替代，旧证据保存在 `output/validation/battle-control-icon-alignment/before_function_order_correction/`，不得继续当作现行验收结论。
- 当前实现恢复原始 `R / TAB / A` 白色提示图，并把 Reset、AttackOrder、AutoArrange 三个既有功能节点分别放回左、中、右三个既有槽位；各节点继续携带自身大图标、点击信号和快捷键绑定。没有新增、删除、改名或重新挂载节点。
- 最终三组位置为：Reset/R `x=1704..1770`、AttackOrder/TAB `x=1773..1838`、AutoArrange/A `x=1841..1907`。两个可见水平间距均为 `3px`。大图标仍分别引用 `reset_normal.png`、`attack_order_normal.png`、`auto_arrange_normal.png`；`BagButton.visible = false`。
- `shortcut_hints.png` 已恢复为原始 `R / TAB / A` 透明图，SHA-256 为 `ec13a334cde0eab36bc66674aa30088d178fbd8ea5bac6c6b0699b84c4b94f9b`，Godot 已重新导入。没有生成新图片，也没有改变画布或透明通道。
- 专项 `smoke_battle_map_controls_icon_alignment.gd` 同时验证三个位置、三枚大图标、背包隐藏、鼠标按钮和 `R / TAB / A` 键盘触发顺序，输出 `SMOKE_BATTLE_MAP_CONTROLS_ICON_ALIGNMENT_OK`。同步更新的通用 prefab smoke 输出 `BATTLE_MAP_CONTROLS_SMOKE_PASS`。
- 正式战斗职责 smoke 输出 `SMOKE_BATTLE_ART_CONTROLS_OK`，确认 R 提交 `RESET_PETS`、TAB 打开八项攻击顺序界面；正式 OpenGL `1920×1080` 十状态输出 `FORMAL_BATTLE_OPERATION_PARITY_PASS count=10`，并确认自动布置命令被正式 Session 接受。五状态聚焦图与来源记录位于 `output/validation/battle-control-icon-alignment/after/`。
- 额外运行 `smoke_position_difficulty_toggle.gd` 时，三次自动布置命令均成功执行，但该测试在后续“战斗达到第 3 回合并解锁”尾部断言失败；失败发生在本轮按钮映射职责之外，未作为当前功能验收依据。本轮用专项信号断言和正式十状态中的 `AUTO_POSITION_HEROES` 接受结果覆盖 A 功能链。
- 目标文件 `git diff --check` 通过。未更新其他 owner 的 `tasks/ai/STATUS.md` 与 `tasks/ai/QUEUE.md`，避免覆盖其既有控制面 WIP。
- 未形成提交：目标 prefab 相对 HEAD 只剩本任务前已有的战斗日志按钮 WIP；本轮恢复的三组位置与快捷键图片本身回到已跟踪基线。新增测试和任务卡仍与该同文件既有 WIP 无法安全组成独立提交。

## 2026-08-17 三按钮等间距修正

- 用户指出当前 `R / TAB / A` 三枚大按钮的水平间距不一致。根因是 Reset→AttackOrder 为 `2px`，AttackOrder→AutoArrange 为 `4px`。
- 仅把既有 `AttackOrderButton` 从 `x=1772..1837` 向右移动 `1px` 到 `x=1773..1838`，使两侧间距都为 `3px`；R/TAB/A 大图标、快捷键提示、按钮尺寸、纵向位置、信号、功能绑定和隐藏背包均未改变。
- 专项输出 `SMOKE_BATTLE_MAP_CONTROLS_ICON_ALIGNMENT_OK` 与 `BATTLE_MAP_CONTROLS_SMOKE_PASS`；正式 Godot 4.7 OpenGL `1920×1080` 十状态输出 `FORMAL_BATTLE_OPERATION_PARITY_PASS count=10`。入口态和自动布置完成态并排图位于 `output/validation/battle-control-icon-alignment/after/two_state_controls_contact_sheet.png`，修改前证据保存在 `before_spacing_correction/`。
- 修改前后入口态按钮区域的差异包围盒为全图 `x=1772..1838, y=915..977`，只覆盖中间 TAB 按钮旧/新位置，没有外溢到 R、A、白色快捷键提示或下方“全军出击”按钮。
- 目标文件与长期记录的 `git diff --check` 均通过；因 `battle_map_controls.tscn` 仍含本任务前已有的日志按钮 WIP，本轮继续不形成提交。
