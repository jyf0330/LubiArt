# AI 持续工作协议

本目录是 `godot-latest` 的持续工作控制面。它让 Goal 和 Scheduled runs 在每次被唤醒后知道该读什么、选什么、何时停止，同时不把聊天上下文当成唯一记忆。

## 文件职责

- `QUEUE.md`：唯一的持续工作候选队列；只放有证据、可排序的事项。
- `STATUS.md`：当前任务、最近巡检、阻断和最近一次验证摘要。
- `prompts/CONTINUOUS_GOAL.md`：人工启动 `/goal` 时使用的总目标。
- `prompts/PATROL.md`：后台巡检任务使用；发现、分级并在安全时完成一个小闭环。
- `prompts/DAILY_REPORT.md`：每日汇报任务使用。
- `../doing/*.md`：实际执行任务卡，负责文件租约与验收证据。

## 每轮循环

1. **恢复上下文**：读取根 `AGENTS.md`、本目录三份状态文件、`tasks/doing/*.md`、当前 Git 状态和最近相关提交。
2. **收集证据**：检查明确失败的测试/CI、可复现日志、现有任务卡和用户给出的方向。不要把猜测直接变成代码任务。
3. **排序**：按 P0 阻断、P1 玩家可见/数据正确性、P2 回归与维护、P3 建议排序；同级优先确定性强、范围小、可验证的事项。
4. **声明租约**：从队列选择一项，建立 `tasks/doing/YYYY-MM-DD_<slug>.md`，写明 `write_scopes`、`exclusive_files`、`existing_wip`、`validation` 和停止条件。
5. **执行闭环**：定位根因，做最小修复，运行相关自动验证；涉及 UI 时按风险完成正式入口可见验收。
6. **收尾**：更新任务卡、队列与状态。AI 自主判断本轮改动是否完整、可独立解释、已通过验收且能与其他 WIP 隔离；满足时精确暂存当前任务文件并自动提交，无需再次询问。不满足时不提交并说明原因。除非用户明确要求，不推送。
7. **继续或停止**：还有明确、无冲突、可验收的 Ready 项时继续下一轮；否则留下简短报告并停止，等待下一次定时唤醒。

## 自动执行判定

可以自主执行：

- 已有失败证据且修复范围明确；
- 与当前 WIP/任务卡无文件重叠；
- 不改变玩法、美术方向、正式数据口径或外部服务；
- 有可重复的验证命令和明确停止条件。

必须停止询问：

- 玩法、内容、视觉方向存在多个合理选择；
- 需要删除、覆盖、发布、推送、付费、授权或处理凭证；
- 需要修改被其他任务占用的文件；
- 上游策划真相源不可写，或真实窗口验收资源与其他槽冲突；
- 连续三次尝试仍是同一阻断，且没有新的安全路径。

## 队列写法

每项必须包含来源证据、期望结果、建议验证和初步写入范围。只有可行动的事项进入 `Ready`；尚未复现的放 `Observed`；需要用户决策的放 `Needs decision`。完成项只保留一行摘要并链接任务卡，避免队列无限膨胀。

## 本机调度

- 巡检服务：`~/Library/LaunchAgents/com.ywh.godot-latest-ai-patrol.plist`，登录时运行一次，之后每 7200 秒运行。
- 日报服务：`~/Library/LaunchAgents/com.ywh.godot-latest-ai-daily-report.plist`，每天 20:30 运行。
- 启动器：`~/.local/bin/godot-latest-ai-worker`。优先使用 ChatGPT 桌面应用自带的新版 Codex CLI，避免全局旧 CLI 与当前模型不兼容。
- 运行提示镜像：`~/.local/share/godot-latest-ai/`；仓库中的 `prompts/` 是可审查真源，修改后需同步镜像。
- 运行记录：`output/automation/{patrol,daily-report}/<timestamp>/`，包含 `events.jsonl`、`final.md`、`stderr.log` 和 `status.txt`，不进入 Git。
- 巡检使用 `workspace-write`；日报使用 `read-only`。每种任务有独立锁，上一轮未结束时跳过重复运行。

查看状态：

```bash
launchctl print gui/$(id -u)/com.ywh.godot-latest-ai-patrol
launchctl print gui/$(id -u)/com.ywh.godot-latest-ai-daily-report
```

暂停或恢复时使用对应 plist 的 `launchctl bootout` / `bootstrap`；不要通过模糊进程名批量结束 Codex 或 Godot。
