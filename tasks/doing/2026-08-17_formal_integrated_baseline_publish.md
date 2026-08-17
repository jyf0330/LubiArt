# 老板整合版新项目基线提交与推送

- status: git_delivery_complete_validation_blocked
- owner: codex-root-20260817-formal-integrated-publish
- user_authorization: 2026-08-17 用户明确要求总结修改并提交、推送“新的这个项目”
- delivery_base_commit: `ecdb7b17`
- objective: 审计并提交 `godot-latest-latest-20260817-103552` 的老板整合版完整工作树，在独立分支发布新项目基线，不改写旧 LubiArt 分支
- write_scopes:
  - 当前新项目中老板整合版的全部正式源码、资源、数据、测试、工具、文档与 Git 控制文件
  - `.gitignore`
  - `.agents/skills/lubiart-godot-ui-art/references/conversation-synthesis.md`
  - `.agents/skills/lubiart-godot-ui-art/references/current-baseline.md`
  - `tasks/doing/2026-08-17_formal_integrated_baseline_publish.md`
- exclusive_files:
  - `tasks/doing/2026-08-17_formal_integrated_baseline_publish.md`
- existing_wip:
  - 当前工作树是老板整合版相对旧 Mock 基点的整体差异；Git 接入记录确认约 1331 个跟踪差异和 545 个未跟踪入口尚未形成基线提交
  - 历史任务卡、暂停宠物草稿和已有验收记录属于整合项目交付内容，本轮只做完整基线收口，不改变其完成或批准状态
  - 本地 `tmp/`、Python 缓存、日志、Office 锁文件、Godot 缓存和已忽略验证录制不属于发布内容，保留本地但不暂存
- validation:
  - 核对远端、分支祖先关系、改动数量、最大文件、冲突标记、绝对依赖与敏感信息
  - `git diff --cached --check`
  - Godot headless 项目扫描与现有正式专项/fast 门禁（按当前 Windows 环境可运行范围）
  - 推送后核对本地 HEAD、远端分支 OID、ahead/behind 与剩余未暂存内容
- stop_conditions:
  - 发现密钥、超过 GitHub 单文件限制的对象、项目外绝对运行依赖或远端分叉时停止发布并报告
  - 不删除或覆盖老板整合版文件，不强推，不把临时缓存或未批准候选误作正式批准资源

## 当前结果

- 已确认工作目录为 `C:\Users\jyf\Documents\godot-latest-latest-20260817-103552`，当前分支为 `codex/formal-integrated-20260817`，远端为 `https://github.com/jyf0330/LubiArt.git`。
- 基点与远端 `origin/codex/battle-ui-work-20260806` 同为 `ecdb7b17`；整合基线主提交为 `6fd880cc`，已以普通新分支推送到 `origin/codex/formal-integrated-20260817`。
- 完整暂存包含 `4325` 个路径：`3126` 个新增、`1034` 个删除、`119` 个修改及 `46` 个重命名；总计约 `359141` 行新增、`99023` 行删除。最大文件为 `27.7 MB` PSD，未超过 GitHub 单文件限制。
- `git diff --cached --check`、冲突标记、敏感信息签名和符号链接检查通过；Godot 4.7 headless 项目扫描退出码为 `0`。
- 路线商店战斗推进、战斗按钮映射和战斗 UI 组件架构三项专项通过。增量命令专项连续两次仅在宠物购买 `100ms` 门槛失败，实测分别为 `108ms`、`104ms`；其余增量结果与功能断言正常。该性能门禁作为整合基线已知失败记录，不在本次 Git 收口中改写阈值或产品实现。
- 推送后本地 `HEAD`、upstream 与远端分支 OID 均为 `6fd880cc67bdce9ddf1ba68d66681cf1c20807ff`，ahead/behind 为 `0/0`。Git 交付已完成；产品全绿验收仍受上述性能门禁阻挡。
