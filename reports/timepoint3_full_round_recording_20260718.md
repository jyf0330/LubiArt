# 第三个时间点完整战斗录屏（2026-07-18）

## 结论

PASS。修复后从读档 3 的第三个时间点第 1 回合开始，仅用真实 Godot 窗口鼠标操作，连续完成第 1-8 回合、战斗结算，并确认进入第 4 时间点奖励三选。

## 修复规则

- H5 `src/core/battle/actions.cjs::useActionSlot()` 允许作用格没有敌人：仍逐格 `applyElementToCell()`、消耗 AP 并标记行动槽已用。
- Godot 原实现的后半段本来能给空格铺元素，但 `use_selected_action_slot()`、自动计划执行和 `run_player_all_out()` 在入口要求先找到敌人，导致空地行动被跳过。
- 修复后统一从行动形状直接结算：有敌人时造成伤害并铺元素；无敌人时仍在完整作用格铺元素。

## 真实鼠标步骤

1. 启动正式 `scenes/game/ysbzs_singleplayer.tscn`。
2. 点击 `读档3`，点击三个战斗入口中的第一个，进入第三时间点第 1 回合。
3. 每个玩家回合依次点击右侧 `自动布置`、`开始行动` 并等待正式动画完成。
4. 若本次行动没有直接推进下一回合，则点击左侧 `结束玩家回合` 并等待敌方行动。
5. 第 8 回合行动结束后进入胜利结算，点击结算确认，进入第 4 时间点奖励三选。

逐回合推进：

- 第 1 回合行动后直接进入第 2 回合。
- 第 2-7 回合均完成我方行动，再结束玩家回合并等待敌方，依次进入下一回合。
- 第 8 回合行动后完成战斗，结算显示胜利、评级 A、金币更新到 10；确认后进入第 4 时间点。

## 录屏证据

- `output/single_timepoint_battle_playtest_20260718/timepoint3_full_rounds.mov`
- H.264，720x1280，15 fps，240 秒，3,150,646 字节。
- 抽帧核验：开头为第三时间点第 1 回合；中后段包含胜利结算；结尾停在第 4 时间点奖励三选。
- 为便于仓库与桌面直接播放，正式文件由无损流程录制源压缩为 H.264；436 MB 原始重复录制已移到 `/tmp/timepoint3_full_rounds_v2.raw.mov`，不纳入仓库。

## 自动化回归

- `smoke_empty_cell_element_cast.gd`: PASS，空作用格施放、AP 消耗、槽位已用、移动锁定、逐格火元素与无误伤全部成立。
- `smoke_begin_action_feedback.gd`: PASS，全部出击后仍恢复玩家原选择态，同时空地铺元素。
- `smoke_three_hit_element_settlement.gd`: PASS，三段攻击与 1 秒后统一元素结算未回归。
- `smoke_singleplayer.gd`: PASS，完整单机核心回归通过。
- `ysbzs_state.gd --check-only`: PASS。
