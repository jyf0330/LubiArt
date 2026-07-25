# 读档2：正式项目 / UI Mock 完整战斗录像一致性报告

## 结论

两边均从正式项目读档2导出的同一份公共战斗捕获开始，按以下按钮顺序完整运行到战斗结束：

1. 自动布置
2. 开始行动
3. 自动布置
4. 开始行动
5. 自动布置
6. 开始行动

正式项目与 UI Mock 的 8 个语义检查点（初始、6 个按钮步骤、完成）完全一致：

- 棋盘：`8x7`
- 初始：`stateVersion=9`，`stateHash=d1109dbf4badafa7`，`phase=battle`
- 完成：`stateVersion=15`，`stateHash=9e8028c8ad65d26b`，`phase=battle_end`
- 战斗回合：3
- 战斗表现队列：3 段均完整播放并解锁输入
- 每一步的敌我单位 ID、阵营及棋盘坐标：完全一致

## 六步状态身份

| 步骤 | 按钮 | stateVersion | stateHash | phase |
|---|---|---:|---|---|
| 1 | 自动布置 | 10 | `ca7f72698fb3efdc` | battle |
| 2 | 开始行动 | 11 | `81b3d61d6b1dfa51` | battle |
| 3 | 自动布置 | 12 | `a312a09c77bd7428` | battle |
| 4 | 开始行动 | 13 | `8dc6609b46c70abc` | battle |
| 5 | 自动布置 | 14 | `44511200290ab7cd` | battle |
| 6 | 开始行动 | 15 | `9e8028c8ad65d26b` | battle_end |

## 录像规格

| 项目 | 正式项目 | UI Mock |
|---|---|---|
| 分辨率 | 3200x1800 | 3200x1800 |
| 编码 | H.264 / yuv420p | H.264 / yuv420p |
| 帧率 | 30 fps | 30 fps |
| 帧数 | 1413 | 1413 |
| 时长 | 47.100 秒 | 47.100 秒 |
| 首帧 SSIM | \- | 0.999598（与正式项目比较） |
| 首帧 PSNR | \- | 57.777 dB（与正式项目比较） |

同步版只裁掉了录制开始前的静止等待和 Godot 退出后的桌面画面，并在 Mock 末尾补齐静止结算帧，使两条录像规格、起点、按钮节奏和总时长一致；没有改写任何战斗帧、单位位置、伤害结果或结算内容。

## 证据文件

- 正式项目同步录像：`read2_formal_full_parity_synced_20260726.mov`
- UI Mock 同步录像：`read2_mock_full_parity_synced_20260726.mov`
- 左右并排对照录像：`read2_formal_vs_mock_side_by_side_20260726.mov`（左：正式项目；右：UI Mock）
- 正式项目运行时间线：`formal_timeline_final_20260726.jsonl`
- UI Mock 运行时间线：`mock_timeline_aligned_20260726.jsonl`
- 正式项目运行日志：`formal_runtime_final_20260726.log`
- UI Mock 运行日志：`mock_runtime_aligned_20260726.log`
- 公共捕获数据：`../../data/mock_battle_snapshot.json`

两个时间线去除 `mode`、实际耗时、输入锁和 Mock 回放游标后，初始、六步和完成检查点的结构化比较结果为 `semantic_equal=true`。
