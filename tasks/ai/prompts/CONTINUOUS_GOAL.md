# 持续目标提示词

将下面内容作为 Goal 启动：

```text
/goal 持续推进 /Users/ywh/Documents/godot-latest，使当前单机游戏在不破坏既有工作和项目权威边界的前提下，逐步达到稳定、可验证、可交付的状态。

每轮先读取根 AGENTS.md、tasks/ai/README.md、tasks/ai/QUEUE.md、tasks/ai/STATUS.md、tasks/doing/*.md 和 git status。只从有证据的 Ready 项选择一个最高价值、可独立验收且与当前 WIP 不冲突的任务；修改前建立任务卡并声明 write_scopes、exclusive_files、existing_wip、validation 和停止条件。

先定位真正责任层，再做最小修改。完成专项自动测试；涉及可见 UI 时从正式入口做真实窗口验证，连续时序有风险时录屏。完成后更新任务卡、队列和状态，然后继续下一项。

不要为了保持工作而制造重构或功能。未经明确授权，不推送、不部署、不发布、不改变玩法/美术/正式数据方向、不删除资产、不处理凭证、不覆盖用户或其他 Agent 的改动。文件租约重叠、上游数据冲突或需要产品选择时执行 FILE_CONFLICT_STOP 并向用户报告。

停止条件：队列中没有有证据、无冲突、可验收的 Ready 项；或剩余事项都需要用户决策。停止前给出完成内容、验证证据、阻断和建议下一步。
```
