# 两天真实鼠标试玩记录

状态：进行中（2026-07-15）
运行入口：`YSBZS Godot Singleplayer (DEBUG)`
输入约束：游戏内只使用真实鼠标点击、悬停、拖拽；不使用键盘、脚本命令或内部调试 API 驱动游戏状态。

## 可复跑流程

### 战斗交互矩阵

| ID | 玩家操作 | 预期 | 实测 | 证据 | 状态 |
| --- | --- | --- | --- | --- | --- |
| B01 | 从路线三选进入固定战斗 | 出现 8x8 战斗棋盘及本回合提示 | 通过：出现第 1 回合横幅、8x8 棋盘、3 我方/3 敌方和两枚战斗按钮 | Computer Use 截图：本回合横幅 | 通过 |
| B02 | 悬停我方宠物 | 仅当前格/宠物高亮，详情可读 | 未完成：本轮先覆盖点击与拖拽；待下一轮补 hover 截图 | 待补 | 待测 |
| B03 | 单击我方宠物 | 选中状态与左侧行动信息一致 | 通过：点击金鹰后左侧变为“摇盖猫”、位置 1/3、AP 1、方向向下，并显示红色行动落点 | Computer Use 截图：选中金鹰 | 通过 |
| B04 | 将我方宠物拖至合法空格 | 跟手预览、攻击范围提示；释放后单位移至目标格 | 通过：蓝色史莱姆从第 2 行第 3 列拖至相邻第 2 行第 4 列，落点正确 | Computer Use 截图：相邻移动后 | 通过 |
| B05 | 将我方宠物拖回原格 | 取消拖拽；原图、详情和高亮全部恢复 | 部分通过：拖至棋盘外背景释放后史莱姆留在源格，未出现残影或卡死 | Computer Use 截图：棋盘外释放后 | 通过 |
| B06 | 将我方宠物拖至超出移动/AP的空格 | 拒绝移动；宠物不消失且界面回到稳定状态 | 待确认：史莱姆可从第 2 行第 4 列拖至约第 6 行第 4 列；左侧显示的是行动 AP，未显示移动力。核心已有距离判定，需下一轮按实际移动力边界复测，不能据此误报 bug。 | Computer Use 截图：远距离移动后 | 待测 |
| B07 | 将我方宠物拖至被占格/敌方格 | 拒绝或按规则结算；不会错位、重复或残留预览 | 通过：从远距位置拖到敌方羊驼占格后，史莱姆停在源格，无重复或残影 | Computer Use 截图：占格释放后 | 通过 |
| B08 | 点击切换行动槽、调整方向/AP、施放行动、结束玩家回合 | 每一步能理解且状态、按钮可用性同步 | 复测通过：切槽和调方向更新文字与红色格；无效操作会在顶部工具栏显示“操作未生效”。仍可考虑在按钮旁说明无合法目标，但不是无反馈 bug。 | Computer Use 截图：顶部“操作未生效” | 通过 |
| B09 | 点击智能布置 | 全体我方宠物放置合理，棋盘和左侧状态同步 | 通过：3 只我方从底行分散到棋盘，棋盘显示完整 | Computer Use 截图：智能布置后 | 通过 |
| B10 | 每个玩家行动轮次点击“我方全部出击”，再点击“结束玩家回合” | 逐波推进并在第 5 波完成结算，无卡死 | 通过：从读档 2 的第 1 波开始，连续执行 32 个玩家行动轮次；第 5 波结束后胜利，评级 S，金币 8→14，队伍 4/4、经验 2 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_01_start.jpg` 至 `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_32_enemy_after.jpg`；`output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_result.jpg` | 通过 |
| B11 | 依次乱点空格、敌方、我方、棋盘边缘和背景装饰 | 非交互区域无副作用；交互区域反馈与当前状态一致 | 待测 | 待补 | 待测 |
| B12 | 对同一宠物/空格/按钮快速连点 | 不会重复执行、叠加选择态、跳过回合或卡住 | 待测 | 待补 | 待测 |
| B13 | 拖拽中在棋盘外、面板、工具栏和背景松开鼠标 | 取消拖拽并恢复源宠物与所有临时视觉 | 待测 | 待补 | 待测 |
| B14 | 依次点击左侧行动面板的所有可见按钮和不可用按钮 | 可用按钮只产生一次合法状态转换；不可用按钮无误导性反馈 | 待测 | 待补 | 待测 |
| B15 | 战斗横幅/结算弹窗出现时点击遮罩、空白区、底层棋盘和确认按钮 | 遮罩阻止底层误点；仅明确按钮能推进流程 | 待测 | 待补 | 待测 |

## 完整战斗逐轮截图（读档 2）

复跑步骤：点击顶部“读档2”进入第 1 波；每个玩家行动轮次先截图，再点左侧“我方全部出击”并截图，最后点“结束玩家回合”并截图。重复到第 5 波结算。此流程只使用游戏窗口内的真实鼠标点击。

截图命名：`mouse_full_battle_round_NN_start.jpg`、`mouse_full_battle_round_NN_player_after.jpg`、`mouse_full_battle_round_NN_enemy_after.jpg`。本次共 32 个玩家行动轮次、96 张过程图，另有 1 张结算图。

| 行动轮次 | 回合开始 | 我方行动后 | 敌方行动后/下一轮 |
| --- | --- | --- | --- |
| 01 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_01_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_01_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_01_enemy_after.jpg` |
| 02 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_02_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_02_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_02_enemy_after.jpg` |
| 03 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_03_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_03_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_03_enemy_after.jpg` |
| 04 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_04_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_04_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_04_enemy_after.jpg` |
| 05 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_05_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_05_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_05_enemy_after.jpg` |
| 06 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_06_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_06_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_06_enemy_after.jpg` |
| 07 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_07_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_07_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_07_enemy_after.jpg` |
| 08 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_08_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_08_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_08_enemy_after.jpg` |
| 09 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_09_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_09_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_09_enemy_after.jpg` |
| 10 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_10_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_10_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_10_enemy_after.jpg` |
| 11 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_11_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_11_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_11_enemy_after.jpg` |
| 12 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_12_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_12_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_12_enemy_after.jpg` |
| 13 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_13_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_13_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_13_enemy_after.jpg` |
| 14 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_14_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_14_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_14_enemy_after.jpg` |
| 15 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_15_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_15_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_15_enemy_after.jpg` |
| 16 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_16_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_16_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_16_enemy_after.jpg` |
| 17 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_17_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_17_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_17_enemy_after.jpg` |
| 18 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_18_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_18_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_18_enemy_after.jpg` |
| 19 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_19_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_19_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_19_enemy_after.jpg` |
| 20 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_20_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_20_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_20_enemy_after.jpg` |
| 21 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_21_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_21_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_21_enemy_after.jpg` |
| 22 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_22_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_22_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_22_enemy_after.jpg` |
| 23 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_23_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_23_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_23_enemy_after.jpg` |
| 24 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_24_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_24_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_24_enemy_after.jpg` |
| 25 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_25_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_25_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_25_enemy_after.jpg` |
| 26 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_26_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_26_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_26_enemy_after.jpg` |
| 27 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_27_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_27_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_27_enemy_after.jpg` |
| 28 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_28_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_28_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_28_enemy_after.jpg` |
| 29 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_29_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_29_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_29_enemy_after.jpg` |
| 30 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_30_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_30_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_30_enemy_after.jpg` |
| 31 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_31_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_31_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_31_enemy_after.jpg` |
| 32 | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_32_start.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_32_player_after.jpg` | `output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_round_32_enemy_after.jpg` |

波次边界：第 2 波出现在行动轮次 05 结束后；第 3 波在 13 结束后；第 4 波在 17 结束后；第 5 波在 24 结束后；行动轮次 32 结束后进入胜利结算。结算图：`output/mouse_battle_playtest_20260715/continuous_two_buttons/mouse_full_battle_result.jpg`。

## 自动布置与 H5 差异核对

### 真实窗口结论

- 读档 2 后在 1280x720 全屏窗口点击绿色“自动布置”：蜜蜂从底部站位移动到中上方；界面仍显示“回合 1”，敌人未行动、我方未出手、战斗未结算。
- 点击前：`output/mouse_battle_playtest_20260715/auto_position_h5_diff/01_before_auto_position.jpg`。
- 点击后：`output/mouse_battle_playtest_20260715/auto_position_h5_diff/02_after_auto_position.jpg`。
- 先前“自动布置触发整场战斗”的观察无效：窗口缩放/坐标判断错误，实际落点位于下方红色“开始行动”按钮。两个按钮在 1920 基准场景中只间隔 6px，缩放到 1280 宽时约 4px，容易误点，但点击区域没有发现重叠。

### 源码差异

| 项目 | H5 | Godot 当前美术战斗页 |
| --- | --- | --- |
| 自动布置命令 | `AUTO_POSITION_HEROES` | `AUTO_POSITION_HEROES` |
| 自动布置副作用 | 只移动宠物/调整行动方向；不出手、不消耗行动槽 | 只移动宠物/调整行动方向；不出手、不消耗 AP |
| 开始行动 | `RUN_PLAYER_ALL_OUT` 后自动走完本行动轮次，回到下一玩家回合 | `BeginTurnButton` 发送 `RUN_BATTLE`，会自动执行整场战斗 |
| 按钮间距 | 普通 DOM 布局 | 1920 基准下仅 6px；小窗口更容易误点 |

结论：自动布置规则本身与 H5 一致，没有触发战斗。真正的 parity 差异是 Godot 红色“开始行动”目前接成整场 `RUN_BATTLE`，而 H5 只推进一个玩家行动轮次。

## 已完成的路线前置

- Day 1：三选奖励两次，选择宠物并确认；固定战斗入口三选之一进入战斗；智能布置后开始行动，战斗结算成功并进入奖励选择。
- 当前进度：Day 1 节点 5 的商店。此前对战斗只做了 B01/B09/B10 的最小链路，未将其误判为完整战斗验收。

## 缺陷清单

| ID | 严重度 | 复现步骤 | 实际 | 预期 | 归属 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| BUG-01 | P1 | Day 1 节点 5 进入商店；点击右侧蓝色返回图标 3 次，又点击商店顶栏空白热区 | 均没有离开商店；顶部只显示“操作未生效”。其他商店按钮可响应（元素补给会扣币），因此不是整页失焦。 | 返回图标必须回到路线；若该节点不允许离开，需显示明确原因和离开路径。 | `artist_ui_middle_controller.gd` 商店退出接线 / 输入热区 | 待集中修复 |
| DIFF-01 | P1 parity | Godot 美术战斗页点击红色“开始行动” | `battle_ui_controller.gd` 发送 `RUN_BATTLE`，自动跑完整场；H5 的同名按钮只结算当前行动轮次 | 改为与 H5 相同的单轮自动链，或明确把按钮改名为“自动战斗” | `battle_ui_controller.gd::_on_begin_turn_pressed()` | 待集中修复 |
