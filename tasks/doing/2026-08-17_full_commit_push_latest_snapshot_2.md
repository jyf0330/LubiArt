# 全工作树二次收口、推送与最新快照压缩

- status: completed
- owner: codex-root-20260817-full-closeout-2
- user_authorization: 2026-08-17 用户再次明确要求“全部提交推送 并拉取最新的在一个新文件夹弄压缩”
- delivery_base_commit: `ab261b94`
- objective: 提交当前工作树全部 tracked / untracked 改动，安全同步并推送当前集成分支，再从最终远端提交创建全新的独立项目目录与 ZIP
- write_scopes:
  - 当前工作树中用户明确授权的全部 tracked / untracked 改动
  - `tasks/doing/2026-08-17_full_commit_push_latest_snapshot_2.md`
  - `tasks/ai/QUEUE.md`
  - `tasks/ai/STATUS.md`
  - `/Users/ywh/Documents/godot-latest-latest-20260817-103552/**`
  - `/Users/ywh/Documents/godot-latest-latest-20260817-103552.zip`
- exclusive_files:
  - `tasks/doing/2026-08-17_full_commit_push_latest_snapshot_2.md`
- existing_wip:
  - 两份累计控制面：`tasks/ai/QUEUE.md`、`tasks/ai/STATUS.md`
  - 两张已完成后台巡检卡：`2026-08-17_background_patrol_0653.md`、`2026-08-17_background_patrol_0856.md`
  - 用户明确授权“全部提交推送”，上述既有条目全部纳入本轮收口；Vanessa 策划任务已由原 owner 在 `ab261b94` 独立提交完成，不再是活跃未提交 WIP
- remote_baseline:
  - `git fetch --all --prune` 后，当前分支 `codex/full-project-structure-migration` 相对跟踪分支为 `ahead 2 / behind 0`
  - 跟踪分支是当前 HEAD 的祖先，无远端新提交、无分叉、无需合并
- validation:
  - `git diff --check` 与冲突标记扫描
  - 战斗 UI 组件架构专项 smoke
  - 推送后核对本地 HEAD、upstream、`git ls-remote`、ahead/behind 和干净工作树
  - 从最终远端提交生成独立目录；Godot headless import、专项 smoke、ZIP 完整性与 SHA-256 校验
- stop_conditions:
  - 若出现新的并发产品代码或正式数据写入，先复核归属与完整性，不覆盖或丢弃
  - 若 fetch 后出现远端分叉，先预演并按项目契约合并，不重写历史
  - 若验证失败，记录真实结果并停止推送或快照交付，不把失败误报为通过
  - 不删除现有仓库、工作树、分支、输出或用户资产

## 当前结果

- 已完成两次 `git fetch --all --prune` 与祖先关系预检；跟踪分支始终是本地 HEAD 的祖先，暂无需要拉入的远端提交或分叉。
- 已校正两轮巡检控制面中的过时 Git/任务归属描述；全部既有 tracked / untracked WIP 收口为 `de52647c`，并成功推送。
- 磁盘仅剩 124 MiB 时，首次普通复制在 1,418/4,177 个跟踪文件处明确失败；该不完整目录和本轮临时工作树已精确清理，未触碰旧快照或用户资产。
- 改用 APFS clone 重新生成 `/Users/ywh/Documents/godot-latest-latest-20260817-103552/`：4,177 个远端跟踪文件零缺失，附带已生成 `.godot` 导入缓存，不含 `.git`。

## 验证结果

- 主工作树：`git diff --check`、冲突标记与敏感信息扫描通过。
- Godot 4.7.1：`tests/presentation/smoke_battle_ui_component_architecture.gd` 在主工作树和独立目录均输出 `SMOKE_BATTLE_UI_COMPONENT_ARCHITECTURE_OK`。
- 独立目录：`project.godot` 存在、Git 元数据不存在、NUL-safe 跟踪文件清点缺失数为 0。
- 本任务记录提交后再次推送，并核对本地 HEAD、upstream 与 `git ls-remote` OID 一致、ahead/behind 为 0/0、工作树干净。
- 最终 ZIP 由上述独立目录生成；解压清单完整性与 SHA-256 在交付时单独报告。

## 遗留风险

- 旧 P1“详情保持打开时直接开始拖拽”仍缺独立虚拟屏的精确真实窗口步骤；这是此前已记录的可见验收缺口，不是本次 Git/快照交付新增失败。
- 因当前磁盘空间紧张，独立目录采用 APFS clone 节省实际占用；目录可正常运行，但若跨卷复制，系统会按完整逻辑大小占用空间。
